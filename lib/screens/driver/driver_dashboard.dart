import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
// `route_data.dart`'s StopData/RouteData declare their own StopStatus enum,
// distinct from transit_core's — hide the latter rather than prefix every
// reference in this file, matching the convention already used by
// driver_route.dart and tracking_service.dart for the same conflict.
import 'package:transit_core/transit_core.dart' hide StopStatus;
import 'package:url_launcher/url_launcher.dart';
import '../../data/live_location_repository.dart';
import '../../data/messaging_repository.dart';
import '../../app/driver_alerts_service.dart';
import '../../app/driver_data_service.dart';
import '../../app/notification_service.dart';
import '../../app/language_provider.dart';
import '../../app/session_service.dart';
import '../../app/tracking_service.dart';
import '../../models/route_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

/// The vehicle this driver actually drives, for use in messages sent to families.
///
/// The alert and SOS bodies were hardcoded to `'Bus #42'`. That is worse than
/// vague in an emergency: a parent reading "SOS – Bus #42" about a driver who runs
/// Bus #7 will look for the wrong vehicle. Falls back to a neutral phrase rather
/// than inventing a number.
String driverVehicleLabel() {
  final bus = SessionService.instance.bus.value;
  final number = bus?.busNumber.trim() ?? '';
  if (number.isNotEmpty) return number;
  final plate = bus?.plateNumber.trim() ?? '';
  if (plate.isNotEmpty) return plate;
  return 'your child\'s vehicle';
}

/// Writes one notification into every family's inbox on this driver's roster.
///
/// `NotificationService.show()` raises a notification on the *driver's own phone*
/// and nowhere else, so every "alert all parents" button in this screen was a
/// no-op with a success animation. This is the write that actually reaches them:
/// `notifications/{parentUid}/items`, which each family's app streams live.
///
/// Recipients come from `SessionService.roster` — the students whose ride request
/// this driver accepted — plus `routeStudents` for anyone an admin assigned.
/// De-duplicated, because a parent with two children on the same vehicle should
/// get one alert, not two.
///
/// Returns the number of families reached, so the UI can say "sent to 6 families"
/// instead of an unqualified tick. Zero is worth surfacing: it means the roster is
/// empty and the alert went nowhere.
Future<int> broadcastToFamilies({
  required NotificationType type,
  required String title,
  required String body,
}) async {
  final session = SessionService.instance;
  final recipients = <String>{};
  for (final s in [...session.roster.value, ...session.routeStudents.value]) {
    final parentId = s.parentId.trim();
    if (parentId.isNotEmpty) recipients.add(parentId);
    // A self-registered student is their own recipient — they have no parent
    // account to route through, and skipping them would silently exclude every
    // student who signed up without one.
    if (parentId.isEmpty) recipients.add(s.id);
  }
  if (recipients.isEmpty) return 0;

  try {
    await MessagingRepository.instance.pushToMany(
      recipients.toList(),
      UserNotification(id: '', type: type, title: title, body: body),
    );
    return recipients.length;
  } catch (e) {
    debugPrint('broadcastToFamilies failed: $e');
    return 0;
  }
}

class DriverDashboard extends StatefulWidget {
  final void Function(int) onNavigate;
  const DriverDashboard({super.key, required this.onNavigate});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  /// Whether a real trip is currently running — true only once this driver
  /// has tapped Start Route on `driver_route.dart`, which is the only thing
  /// that makes `TrackingService.instance.route` non-null. This used to be a
  /// hardcoded `true`, which is why the "In Progress" badge and a fake 55%
  /// progress bar showed for every driver, including one who never started
  /// anything today.
  bool _routeStarted = false;

  @override
  void initState() {
    super.initState();
    _routeStarted = TrackingService.instance.route != null;
    // Neither `route` nor its containing `RouteData` is itself a
    // `Listenable` — `isSimulating`/`isLive` are the notifiers that actually
    // flip when `start()`/`stop()` run, so those are what this screen
    // listens to in order to react to a trip starting or ending.
    TrackingService.instance.isSimulating.addListener(_onTrackingChanged);
    TrackingService.instance.isLive.addListener(_onTrackingChanged);
  }

  @override
  void dispose() {
    TrackingService.instance.isSimulating.removeListener(_onTrackingChanged);
    TrackingService.instance.isLive.removeListener(_onTrackingChanged);
    super.dispose();
  }

  void _onTrackingChanged() {
    final started = TrackingService.instance.route != null;
    if (started != _routeStarted && mounted) {
      setState(() => _routeStarted = started);
    }
  }

  /// `AppTheme.warningLight`/`successLight` are tuned for the dark theme's
  /// near-black background — a pale amber "NOT STARTED" label on the light
  /// theme's near-white scaffold reads as almost invisible. Light mode gets
  /// the same hues at full saturation instead.
  Color _badgeTextColor(BuildContext context, bool active) {
    if (context.isDark) {
      return active ? AppTheme.successLight : AppTheme.warningLight;
    }
    return active ? AppTheme.success : const Color(0xFFB45309);
  }

  // ── Quick action handlers ──────────────────────────────────────────────

  /// Gates Emergency/Alert All/Share Location/Update Route on real admin
  /// verification — these used to open unconditionally for any driver,
  /// including one whose documents were never approved, matching the same
  /// `isApproved` check `ride_match_service.dart`/`missed_bus_service.dart`
  /// already enforce for accepting a ride.
  bool _requireApproved() {
    final driver = SessionService.instance.driver.value;
    if (driver?.isApproved == true) return true;
    showDialog(
      context: context,
      builder: (_) => _VerificationRequiredDialog(status: driver?.status),
    );
    return false;
  }

  void _onEmergency() {
    if (!_requireApproved()) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EmergencySheet(),
    );
  }

  void _onAlertAll() {
    if (!_requireApproved()) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AlertAllSheet(),
    );
  }

  void _onShareLocation() {
    if (!_requireApproved()) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShareLocationSheet(),
    );
  }

  void _onUpdateRoute() {
    if (!_requireApproved()) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UpdateRouteSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return ListenableBuilder(
      listenable: LanguageProvider.instance,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 130),
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.driverCyan.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('👋', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  AppTheme.driverGradient.createShader(
                                    Rect.fromLTWH(
                                      0,
                                      0,
                                      bounds.width,
                                      bounds.height,
                                    ),
                                  ),
                              blendMode: BlendMode.srcIn,
                              child: Text(
                                greeting,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ValueListenableBuilder<DriverInfo>(
                          valueListenable:
                              DriverDataService.instance.driverInfo,
                          builder: (_, info, _) {
                            // Vehicle and route are only known once an admin
                            // has assigned them, so say so rather than showing
                            // a bus this driver does not drive.
                            final assignment = [
                              info.busNumber,
                              info.route,
                            ].where((s) => s.isNotEmpty).join(' · ');

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  info.name,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  assignment.isEmpty
                                      ? 'No vehicle assigned yet'
                                      : assignment,
                                  style: const TextStyle(
                                    color: AppTheme.driverAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => widget.onNavigate(4),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: context.cardBgElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.inputBorder),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/notification_bell.gif',
                              width: 22,
                              height: 22,
                              cacheWidth: 44,
                              cacheHeight: 44,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable:
                              DriverAlertsService.instance.unreadCount,
                          builder: (_, unread, _) {
                            if (unread == 0) return const SizedBox.shrink();
                            return Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: AppTheme.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$unread',
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // ── Route status ─────────────────────────────────────────
                  GlassCard(
                    gradient: LinearGradient(
                      colors: _routeStarted
                          ? [
                              AppTheme.success.withValues(alpha: 0.15),
                              AppTheme.success.withValues(alpha: 0.05),
                            ]
                          : [
                              AppTheme.driverCyan.withValues(alpha: 0.15),
                              AppTheme.driverCyan.withValues(alpha: 0.05),
                            ],
                    ),
                    borderColor:
                        (_routeStarted ? AppTheme.success : AppTheme.driverCyan)
                            .withValues(alpha: 0.25),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.t('todays_route'),
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _routeStarted
                                        ? (TrackingService
                                                      .instance
                                                      .route
                                                      ?.name
                                                      .isNotEmpty ==
                                                  true
                                              ? TrackingService
                                                    .instance
                                                    .route!
                                                    .name
                                              : DriverDataService
                                                    .instance
                                                    .driverInfo
                                                    .value
                                                    .route)
                                        : 'No active route',
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (_routeStarted
                                            ? AppTheme.success
                                            : AppTheme.warning)
                                        .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      (_routeStarted
                                              ? AppTheme.success
                                              : AppTheme.warning)
                                          .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _routeStarted
                                          ? AppTheme.success
                                          : AppTheme.warning,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _routeStarted
                                        ? AppStrings.t('in_progress_badge')
                                        : AppStrings.t('not_started_badge'),
                                    style: TextStyle(
                                      color: _badgeTextColor(
                                        context,
                                        _routeStarted,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Progress bar, stop/student counts and time left —
                        // all derived from the live `RouteData` while a trip
                        // is running. Before that, there is nothing real to
                        // show, so this shows an honest "not started" line
                        // instead of a 0% bar that would look like a stalled
                        // trip.
                        Builder(
                          builder: (context) {
                            if (!_routeStarted) {
                              return Text(
                                "You haven't started a route yet. Start a "
                                'round to see live progress here.',
                                style: TextStyle(
                                  color: context.textTertiary,
                                  fontSize: 12,
                                ),
                              );
                            }
                            // `etaMinutes` ticks on every simulation frame
                            // while a trip is running — it is the notifier
                            // that fires often enough to keep the stop
                            // progress and student counts below current
                            // without this screen polling for them.
                            return ValueListenableBuilder<int>(
                              valueListenable:
                                  TrackingService.instance.etaMinutes,
                              builder: (_, eta, _) {
                                final route = TrackingService.instance.route;
                                if (route == null) {
                                  return Text(
                                    "You haven't started a route yet.",
                                    style: TextStyle(
                                      color: context.textTertiary,
                                      fontSize: 12,
                                    ),
                                  );
                                }
                                final stopsTotal = route.stops.length;
                                final stopsDone = route.completedStops;
                                final progress = stopsTotal == 0
                                    ? 0.0
                                    : stopsDone / stopsTotal;
                                final studentsTotal = route.stops.fold<int>(
                                  0,
                                  (sum, s) => sum + s.studentCount,
                                );
                                final studentsPicked = route.stops
                                    .where(
                                      (s) => s.status == StopStatus.completed,
                                    )
                                    .fold<int>(
                                      0,
                                      (sum, s) => sum + s.studentCount,
                                    );
                                return Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          AppStrings.t('route_progress'),
                                          style: TextStyle(
                                            color: context.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          '${(progress * 100).round()}%',
                                          style: TextStyle(
                                            color: AppTheme.successLight,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor:
                                            context.cardBgElevated,
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                          AppTheme.success,
                                        ),
                                        minHeight: 8,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        _RouteStatChip(
                                          icon:
                                              'assets/images/utilities/check.png',
                                          label: AppStrings.t('stops_done'),
                                          value: '$stopsDone/$stopsTotal',
                                        ),
                                        const SizedBox(width: 8),
                                        _RouteStatChip(
                                          icon:
                                              'assets/images/navbar/student.png',
                                          label: AppStrings.t('students'),
                                          value: studentsTotal == 0
                                              ? '$studentsPicked'
                                              : '$studentsPicked/$studentsTotal',
                                        ),
                                        const SizedBox(width: 8),
                                        _RouteStatChip(
                                          icon:
                                              'assets/images/stats/on_time.png',
                                          label: AppStrings.t('time_left'),
                                          value: '$eta min',
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Next stop card ────────────────────────────────────────
                  GlassCard(
                    onTap: () => widget.onNavigate(2),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.driverCyan.withValues(alpha: 0.15),
                        AppTheme.driverTeal.withValues(alpha: 0.08),
                      ],
                    ),
                    borderColor: AppTheme.driverCyan.withValues(alpha: 0.25),
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: AppTheme.driverGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.driverCyan.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/utilities/next_stop.png',
                              width: 28,
                              height: 28,
                              cacheWidth: 56,
                              cacheHeight: 56,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.t('next_stop'),
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Mirrors the same null-route guard used
                              // elsewhere in this file: `route` and its
                              // `currentStop` are only real once a trip is
                              // running, and `etaMinutes` never resets on its
                              // own once one ends.
                              Builder(
                                builder: (context) {
                                  if (!_routeStarted) {
                                    return Text(
                                      "You haven't started a route yet",
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    );
                                  }
                                  return ValueListenableBuilder<int>(
                                    valueListenable:
                                        TrackingService.instance.etaMinutes,
                                    builder: (_, eta, _) {
                                      final route =
                                          TrackingService.instance.route;
                                      if (route == null) {
                                        return Text(
                                          "You haven't started a route yet",
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        );
                                      }
                                      final stop =
                                          route.currentStop ??
                                          route.nextStop ??
                                          (route.stops.isNotEmpty
                                              ? route.stops.last
                                              : null);
                                      final stopName = stop?.name ?? '—';
                                      final scheduled = stop?.scheduledTime;
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            stopName,
                                            style: TextStyle(
                                              color: context.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            (scheduled == null ||
                                                    scheduled.isEmpty)
                                                ? '~$eta minutes away'
                                                : '~$eta minutes away · '
                                                      '$scheduled scheduled',
                                            style: TextStyle(
                                              color: AppTheme.driverAccent,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.driverCyan.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '→',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Seat requests & service setup ─────────────────────────
                  const _SeatRequestsBanner(),

                  // ── Quick actions ─────────────────────────────────────────
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.t('quick_actions'),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GridView.count(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 2.6,
                          children: [
                            _QuickActionBtn(
                              icon: 'assets/images/utilities/emergency.png',
                              label: AppStrings.t('emergency'),
                              color: AppTheme.error,
                              onTap: _onEmergency,
                            ),
                            _QuickActionBtn(
                              icon: 'assets/images/alert.png',
                              label: AppStrings.t('alert_all'),
                              color: AppTheme.warning,
                              onTap: _onAlertAll,
                            ),
                            _QuickActionBtn(
                              icon:
                                  'assets/images/navbar/track_transparent.png',
                              label: AppStrings.t('share_location'),
                              color: AppTheme.success,
                              onTap: _onShareLocation,
                            ),
                            _QuickActionBtn(
                              icon: 'assets/images/utilities/edit_pencil.png',
                              label: AppStrings.t('update_route'),
                              color: AppTheme.info,
                              onTap: _onUpdateRoute,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Today's stats ─────────────────────────────────────────
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.t('todays_stats'),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Builder(
                          builder: (context) {
                            final route = TrackingService.instance.route;
                            final int studentsTotal;
                            final int studentsPicked;
                            if (route != null) {
                              studentsTotal = route.stops.fold<int>(
                                0,
                                (sum, s) => sum + s.studentCount,
                              );
                              studentsPicked = route.stops
                                  .where(
                                    (s) => s.status == StopStatus.completed,
                                  )
                                  .fold<int>(
                                    0,
                                    (sum, s) => sum + s.studentCount,
                                  );
                            } else {
                              // No trip is running right now, so the honest
                              // "students" figure is this driver's own
                              // accepted-request roster — not an admin route
                              // assignment, which most self-signed-up
                              // drivers in this pilot never have.
                              studentsTotal =
                                  SessionService.instance.roster.value.length;
                              studentsPicked = 0;
                            }
                            final routeProgress = (route == null)
                                ? null
                                : (route.stops.isEmpty
                                      ? 0.0
                                      : route.completedStops /
                                            route.stops.length);
                            return Column(
                              children: [
                                _StatBar(
                                  label: AppStrings.t('students_picked'),
                                  value: studentsPicked,
                                  total: studentsTotal,
                                  color: AppTheme.success,
                                  suffix: null,
                                ),
                                const SizedBox(height: 12),
                                routeProgress == null
                                    ? _StatBarPlaceholder(
                                        label: AppStrings.t(
                                          'route_completion',
                                        ),
                                        message: 'Not started yet',
                                      )
                                    : _StatBar(
                                        label: AppStrings.t(
                                          'route_completion',
                                        ),
                                        value: (routeProgress * 100).round(),
                                        total: 100,
                                        color: AppTheme.driverAccent,
                                        suffix: '%',
                                      ),
                                const SizedBox(height: 12),
                                // No per-trip attendance/on-time history is
                                // wired into this screen yet (that lives in
                                // `TripRepository`, used by
                                // `driver_performance_screen.dart`) — showing
                                // a placeholder here is honest; a fabricated
                                // percentage would not be.
                                _StatBarPlaceholder(
                                  label: AppStrings.t('on_time_perf'),
                                  message: 'No data yet',
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteStatChip extends StatelessWidget {
  final String icon, label, value;
  const _RouteStatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Image.asset(
              icon,
              width: 20,
              height: 20,
              cacheWidth: 40,
              cacheHeight: 40,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: context.textTertiary, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live seat-request state, and the way into the inbox.
///
/// Sits on the dashboard rather than only in the profile menu because a pending
/// request is time-sensitive — a family is waiting on an answer — and because for
/// a driver who has not finished setting up their service, this is the one place
/// the app can tell them why nothing is arriving.
///
/// Rebuilds off [SessionService], so accepting a request on the inbox screen
/// updates this banner without the dashboard being revisited.
class _SeatRequestsBanner extends StatelessWidget {
  const _SeatRequestsBanner();

  @override
  Widget build(BuildContext context) {
    final session = SessionService.instance;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final driver = session.driver.value;
        final pending = session.pendingRideRequests.length;
        final booked = session.acceptedRideRequests.length;

        final notSetUp = driver != null &&
            (driver.serviceAreas.isEmpty || driver.schedules.isEmpty);

        final Color accent;
        final String emoji;
        final String title;
        final String subtitle;
        final String route;

        if (notSetUp) {
          accent = AppTheme.warning;
          emoji = '🗺️';
          title = 'Parents cannot find you yet';
          subtitle = driver.serviceAreas.isEmpty
              ? 'Add the schools you drive to and your daily rounds.'
              : 'Add at least one round so families can book a seat.';
          route = '/driver/service';
        } else if (pending > 0) {
          accent = AppTheme.warning;
          emoji = '📬';
          title = '$pending seat request${pending == 1 ? '' : 's'} waiting';
          subtitle = 'Tap to accept or decline.';
          route = '/driver/ride-requests';
        } else {
          accent = AppTheme.success;
          emoji = '🧒';
          title = booked == 0
              ? 'No students booked yet'
              : '$booked student${booked == 1 ? '' : 's'} on your roster';
          subtitle = driver == null
              ? 'Loading your rounds…'
              : '${driver.totalAvailableSeats} of '
                  '${driver.totalSeatsOffered} seats free across '
                  '${driver.schedules.length} round'
                  '${driver.schedules.length == 1 ? '' : 's'}.';
          route = '/driver/ride-requests';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            borderColor: accent.withValues(alpha: 0.4),
            onTap: () => context.push(route),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.textTertiary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final String icon, label;
  final Color color;
  final VoidCallback? onTap;
  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Image.asset(
              icon,
              width: 26,
              height: 26,
              cacheWidth: 52,
              cacheHeight: 52,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final int value, total;
  final Color color;
  final String? suffix;
  const _StatBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    // `total` can legitimately be 0 (e.g. a driver with an empty roster and
    // no trip running) — guard against the NaN/Infinity that `value / 0`
    // would otherwise feed into `LinearProgressIndicator`.
    final pct = total == 0 ? 0.0 : value / total;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
            Text(
              suffix != null ? '$value$suffix' : '$value/$total',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: context.cardBgElevated,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

/// The same visual shape as [_StatBar], for a stat that has no real number
/// to show yet (no trip today, no attendance history). Shows [message]
/// instead of a value and leaves the bar empty, rather than rendering a
/// plausible-looking percentage nobody measured.
class _StatBarPlaceholder extends StatelessWidget {
  final String label;
  final String message;
  const _StatBarPlaceholder({required this.label, required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
            Text(
              message,
              style: TextStyle(
                color: context.textTertiary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: 0,
            backgroundColor: context.cardBgElevated,
            valueColor: AlwaysStoppedAnimation(context.textTertiary),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ─── Bottom-sheet helper ──────────────────────────────────────────────────────

class _SheetBase extends StatelessWidget {
  final String title;
  final Widget child;
  const _SheetBase({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

// ─── Verification-required dialog ───────────────────────────────────────────

class _VerificationRequiredDialog extends StatelessWidget {
  final DriverStatus? status;
  const _VerificationRequiredDialog({this.status});

  String get _statusLine => switch (status) {
        DriverStatus.suspended =>
          'Your account has been suspended. Contact support for details.',
        _ => 'Your documents are still pending admin verification.',
      };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.cardBgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                color: AppTheme.warning,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Verification required',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statusLine,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Close',
                      style: TextStyle(color: context.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.driverCyan,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/driver/documents');
                    },
                    child: const Text('View Documents'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Emergency sheet ─────────────────────────────────────────────────────────

class _EmergencySheet extends StatefulWidget {
  @override
  State<_EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends State<_EmergencySheet> {
  bool _sent = false;

  Future<void> _callEmergency() async {
    final uri = Uri(scheme: 'tel', path: '1122');
    if (await canLaunchUrl(uri)) {
      launchUrl(uri);
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _sendSOS() async {
    final vehicle = driverVehicleLabel();
    await NotificationService.instance.show(
      title: '🚨 SOS – $vehicle',
      body: 'Driver has triggered an emergency alert. Authorities notified.',
      type: 'alert',
      icon: '🚨',
      color: AppTheme.error,
    );
    // Reaches the families. `NotificationService.show` above only raises a
    // notification on *this* phone, which is why an SOS previously never left the
    // vehicle — the driver got a confirmation for an alert nobody received.
    await broadcastToFamilies(
      type: NotificationType.emergency,
      title: '🚨 Emergency alert – $vehicle',
      body: 'The driver has triggered an emergency alert. '
          'You will be contacted shortly.',
    );
    if (!mounted) return;
    setState(() => _sent = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: '🚨 Emergency',
      child: Column(
        children: [
          if (_sent)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'SOS sent to all parents & dispatchers.',
                style: TextStyle(color: AppTheme.successLight, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          _ActionRow(
            icon: '📞',
            label: 'Call Emergency Services (1122)',
            color: AppTheme.error,
            onTap: _callEmergency,
          ),
          const SizedBox(height: 10),
          _ActionRow(
            icon: '📢',
            label: 'Send SOS to All Parents',
            color: AppTheme.warning,
            onTap: _sent ? null : _sendSOS,
          ),
          const SizedBox(height: 10),
          _ActionRow(
            icon: '✖',
            label: 'Cancel',
            color: Colors.white24,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ─── Alert All sheet ─────────────────────────────────────────────────────────

class _AlertAllSheet extends StatefulWidget {
  @override
  State<_AlertAllSheet> createState() => _AlertAllSheetState();
}

class _AlertAllSheetState extends State<_AlertAllSheet> {
  int? _selected;

  /// Message templates. `{vehicle}` is substituted with the driver's real vehicle
  /// at send time — these were hardcoded to `'Bus #42'`, which told every family
  /// on every vehicle to look out for a bus that mostly does not exist.
  static const _messages = [
    (
      icon: '⏱️',
      label: 'Running 10 min late',
      body: '{vehicle} is running approximately 10 minutes behind schedule '
          'today.',
    ),
    (
      icon: '⚠️',
      label: 'Minor breakdown – wait 15 min',
      body: '{vehicle} has a minor issue. Expect a 15-minute delay. Stay at '
          'your stop.',
    ),
    (
      icon: '✅',
      label: 'Running ahead of schedule',
      body: '{vehicle} is running 5 minutes ahead of schedule. Please be at '
          'your stop now.',
    ),
    (
      icon: '🌧️',
      label: 'Delayed due to weather',
      body: '{vehicle} is delayed due to weather conditions. We will update you '
          'shortly.',
    ),
  ];

  Future<void> _send() async {
    if (_selected == null) return;
    final m = _messages[_selected!];
    final vehicle = driverVehicleLabel();
    final body = m.body.replaceAll('{vehicle}', vehicle);

    await NotificationService.instance.show(
      title: '${m.icon} Alert – $vehicle',
      body: body,
      type: 'alert',
      icon: m.icon,
      color: AppTheme.warning,
    );

    // The write that actually reaches the families. Without it this button only
    // notified the driver's own phone — see [broadcastToFamilies].
    final reached = await broadcastToFamilies(
      type: NotificationType.delay,
      title: '${m.icon} $vehicle update',
      body: body,
    );
    if (mounted && reached == 0) {
      // Silence here would read as success. A driver who has nobody on their
      // roster needs to know the alert went nowhere.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No families on your roster yet, so this alert was not sent to '
            'anyone.',
          ),
          backgroundColor: AppTheme.warning,
        ),
      );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: '📢 Alert All Parents',
      child: Column(
        children: [
          ..._messages.asMap().entries.map((e) {
            final selected = _selected == e.key;
            return GestureDetector(
              onTap: () => setState(() => _selected = e.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.warning.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppTheme.warning.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Text(e.value.icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.value.label,
                        style: TextStyle(
                          color: selected
                              ? AppTheme.warningLight
                              : Colors.white70,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.warning,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected != null ? _send : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Send to All Parents',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Share Location sheet ────────────────────────────────────────────────────

class _ShareLocationSheet extends StatefulWidget {
  @override
  State<_ShareLocationSheet> createState() => _ShareLocationSheetState();
}

class _ShareLocationSheetState extends State<_ShareLocationSheet> {
  bool _copied = false;
  bool _sharing = false;
  bool _starting = false;

  /// True only if this sheet is the one that switched tracking into live GPS
  /// mode — so stopping only turns it back off when nothing else (an active
  /// trip already in live mode) depends on it staying on.
  bool _weStartedLive = false;

  Timer? _publishTimer;
  String? _busId;

  GeoCoord get _position => TrackingService.instance.busPosition.value;

  @override
  void dispose() {
    if (_sharing) _stopSharingSync();
    super.dispose();
  }

  Future<void> _openInMaps() async {
    final p = _position;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${p.lat},${p.lng}',
    );
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyCoords() {
    final p = _position;
    Clipboard.setData(ClipboardData(text: '${p.lat}, ${p.lng}'));
    setState(() => _copied = true);
  }

  /// Starts publishing this driver's real GPS to `liveLocations/{busId}`
  /// every `AppConfig.locationPublishInterval` — wiring up
  /// `LiveLocationRepository`, which existed fully built but was never
  /// called from anywhere in the app before this.
  Future<void> _startSharing() async {
    final driver = SessionService.instance.driver.value;
    final uid = SessionService.instance.uid;
    if (driver == null || uid == null || _starting) return;
    setState(() => _starting = true);

    if (!TrackingService.instance.isLive.value) {
      await TrackingService.instance.toggleLive();
      if (!TrackingService.instance.isLive.value) {
        // Permission denied or unavailable — toggleLive() no-ops in that case.
        if (mounted) setState(() => _starting = false);
        return;
      }
      _weStartedLive = true;
    }

    // Falls back to the driver's own uid so a self-signup driver with no
    // admin-assigned `Bus` document still gets a stable, unique RTDB key.
    _busId = SessionService.instance.bus.value?.id ?? uid;
    final busId = _busId!;

    await LiveLocationRepository.instance.armDisconnectCleanup(busId);
    _publishTimer = Timer.periodic(AppConfig.locationPublishInterval, (
      _,
    ) async {
      final p = TrackingService.instance.busPosition.value;
      await LiveLocationRepository.instance.publish(
        LiveLocation(
          busId: busId,
          lat: p.lat,
          lng: p.lng,
          heading: TrackingService.instance.busHeading.value,
          speedKmh: TrackingService.instance.speed.value.toDouble(),
          driverId: uid,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });

    if (mounted) {
      setState(() {
        _sharing = true;
        _starting = false;
      });
    }
  }

  /// Fire-and-forget cleanup used from `dispose()`, where an async gap isn't
  /// possible — best-effort, relies on `armDisconnectCleanup`'s server-side
  /// removal as the backstop if these calls don't land before the app dies.
  void _stopSharingSync() {
    final busId = _busId;
    _publishTimer?.cancel();
    _publishTimer = null;
    if (busId != null) {
      LiveLocationRepository.instance.clear(busId);
      LiveLocationRepository.instance.cancelDisconnectCleanup(busId);
    }
    if (_weStartedLive) TrackingService.instance.toggleLive();
  }

  Future<void> _stopSharing() async {
    final busId = _busId;
    _publishTimer?.cancel();
    _publishTimer = null;
    if (busId != null) {
      await LiveLocationRepository.instance.clear(busId);
      await LiveLocationRepository.instance.cancelDisconnectCleanup(busId);
    }
    if (_weStartedLive) {
      await TrackingService.instance.toggleLive();
      _weStartedLive = false;
    }
    if (mounted) setState(() => _sharing = false);
  }

  Future<void> _notifyParents() async {
    final reached = await broadcastToFamilies(
      type: NotificationType.system,
      title: '📍 Bus Location Shared',
      body: '${driverVehicleLabel()} is now sharing its live location.',
    );
    if (!mounted) return;
    if (reached == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No families on your roster yet, so this was not sent to '
            'anyone.',
          ),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = _position;
    return _SheetBase(
      title: '📍 Share Location',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.success.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppTheme.success,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                GestureDetector(
                  onTap: _copyCoords,
                  child: Text(
                    _copied ? '✔ Copied' : 'Copy',
                    style: TextStyle(
                      color: _copied
                          ? AppTheme.successLight
                          : AppTheme.driverCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ActionRow(
            icon: _sharing ? '🛑' : '📡',
            label: _starting
                ? 'Starting…'
                : _sharing
                ? 'Stop Sharing Live Location'
                : 'Start Sharing Live Location',
            color: _sharing ? AppTheme.error : AppTheme.driverCyan,
            onTap: _starting
                ? () {}
                : (_sharing ? _stopSharing : _startSharing),
          ),
          const SizedBox(height: 10),
          _ActionRow(
            icon: '🗺️',
            label: 'Open in Google Maps',
            color: AppTheme.info,
            onTap: _openInMaps,
          ),
          const SizedBox(height: 10),
          _ActionRow(
            icon: '📬',
            label: 'Notify All Parents of Current Position',
            color: AppTheme.success,
            onTap: _notifyParents,
          ),
          const SizedBox(height: 10),
          _ActionRow(
            icon: '✖',
            label: 'Cancel',
            color: Colors.white24,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ─── Update Route sheet ──────────────────────────────────────────────────────

class _UpdateRouteSheet extends StatefulWidget {
  @override
  State<_UpdateRouteSheet> createState() => _UpdateRouteSheetState();
}

class _UpdateRouteSheetState extends State<_UpdateRouteSheet> {
  int? _selected;

  static const _options = [
    (icon: '✅', label: 'On Time', body: 'Bus #42 is back on schedule.'),
    (
      icon: '⏱️',
      label: 'Delayed – 5 min',
      body: 'Bus #42 is running 5 minutes behind schedule.',
    ),
    (
      icon: '⏱️',
      label: 'Delayed – 10 min',
      body: 'Bus #42 is running 10 minutes behind schedule.',
    ),
    (
      icon: '🔀',
      label: 'Route Deviation',
      body:
          'Bus #42 has taken an alternate route due to road conditions. ETA updated.',
    ),
    (
      icon: '🛑',
      label: 'Route Suspended',
      body:
          'Bus #42 route is temporarily suspended. Please arrange alternative transport.',
    ),
  ];

  Future<void> _apply() async {
    if (_selected == null) return;
    final o = _options[_selected!];
    await NotificationService.instance.show(
      title: '${o.icon} Route Update – Bus #42',
      body: o.body,
      type: _selected == 0 ? 'success' : 'alert',
      icon: o.icon,
      color: _selected == 0 ? AppTheme.success : AppTheme.warning,
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: '🔄 Update Route Status',
      child: Column(
        children: [
          ..._options.asMap().entries.map((e) {
            final sel = _selected == e.key;
            return GestureDetector(
              onTap: () => setState(() => _selected = e.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: sel
                      ? AppTheme.info.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel
                        ? AppTheme.info.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Text(e.value.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.value.label,
                        style: TextStyle(
                          color: sel ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (sel)
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.info,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected != null ? _apply : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.info,
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Notify Parents',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable action row ─────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final String icon, label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: onTap != null ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
