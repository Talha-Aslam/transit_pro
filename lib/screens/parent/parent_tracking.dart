import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/language_provider.dart';
import '../../app/parent_data_service.dart';
import '../../app/geofence_service.dart';
import '../../app/notification_service.dart';
import '../../data/trip_repository.dart';
import '../../map/route_map_view.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ParentTracking extends StatefulWidget {
  final VoidCallback onBack;
  const ParentTracking({super.key, required this.onBack});

  @override
  State<ParentTracking> createState() => _ParentTrackingState();
}

class _ParentTrackingState extends State<ParentTracking> {
  final _geofence = GeofenceService.instance;
  final _notifSvc = NotificationService.instance;

  /// The live `trips/{tripId}` document for the selected child's driver, or
  /// null when nothing is running. This is what decides whether the Route
  /// Progress card and stats row render at all. It used to start a mock
  /// route unconditionally in `initState`, which is why a brand-new account
  /// with no driver could still see a full "Route Progress" timeline moving
  /// on its own.
  Trip? _activeTrip;
  StreamSubscription<Trip?>? _tripSub;
  String? _watchedDriverId;

  /// This child's own row on the active trip's attendance manifest — the
  /// only per-stop detail a parent is both allowed to read (see
  /// `firestore.rules`'s `ownsStudent` check) and should see: every other
  /// child's pickup point is another family's information, not this one's.
  AttendanceRecord? _myAttendance;
  StreamSubscription<AttendanceRecord?>? _attendanceSub;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _geofence.alerts.addListener(_onGeofenceAlert);
  }

  void _onLangChanged() => setState(() {});

  void _onGeofenceAlert() {
    final alerts = _geofence.alerts.value;
    if (alerts.isNotEmpty) {
      _notifSvc.fromGeofence(alerts.last);
    }
  }

  /// Called from [build] every time the selected child (and therefore their
  /// driver) might have changed. Cheap no-op when it hasn't — only resets
  /// the trip/attendance subscriptions on an actual change.
  void _ensureWatching(ChildInfo? child) {
    final driverId = child?.driver;
    if (driverId == _watchedDriverId) return;
    _watchedDriverId = driverId;

    _tripSub?.cancel();
    _tripSub = null;
    _attendanceSub?.cancel();
    _attendanceSub = null;
    _activeTrip = null;
    _myAttendance = null;

    if (driverId == null || driverId.isEmpty) return;
    _tripSub = TripRepository.instance
        .watchActiveTripForDriver(driverId)
        .listen((trip) => _onActiveTripChanged(trip, child!.id));
  }

  void _onActiveTripChanged(Trip? trip, String childId) {
    if (!mounted) return;
    setState(() => _activeTrip = trip);

    _attendanceSub?.cancel();
    _attendanceSub = null;
    if (trip == null) {
      setState(() => _myAttendance = null);
      return;
    }
    _attendanceSub = TripRepository.instance
        .watchAttendanceForStudent(trip.id, childId)
        .listen((record) {
      if (!mounted) return;
      setState(() => _myAttendance = record);
    });
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _geofence.alerts.removeListener(_onGeofenceAlert);
    _tripSub?.cancel();
    _attendanceSub?.cancel();
    _geofence.reset();
    super.dispose();
  }

  String _relativeStart(DateTime? startedAt) {
    if (startedAt == null) return '—';
    final mins = DateTime.now().difference(startedAt).inMinutes;
    if (mins < 1) return 'Just now';
    if (mins < 60) return '$mins min ago';
    final hours = mins ~/ 60;
    return '$hours hr ago';
  }

  String _attendanceLabel(AttendanceRecord? record) {
    switch (record?.status) {
      case AttendanceStatus.boarded:
        return 'Picked up';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.pending:
      case null:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = ParentDataService.instance;

    return ValueListenableBuilder<List<ChildInfo>>(
      valueListenable: svc.children,
      builder: (context, children, _) {
        return ValueListenableBuilder<int>(
          valueListenable: svc.selectedChildIndex,
          builder: (context, selIdx, _) {
            final child = svc.currentChild;
            _ensureWatching(child);
            final trip = _activeTrip;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  _Header(
                    title: AppStrings.t('live_tracking'),
                    onBack: widget.onBack,
                    child: child,
                    children: children,
                    onChildSelected: (idx) {
                      svc.selectedChildIndex.value = idx;
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // ── Live map ─────────────────────────────────────
                        GlassCard(
                          enableBlur: false,
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: SizedBox(
                              height: 220,
                              child: Stack(
                                children: [
                                  RouteMapView(
                                    height: 220,
                                    highlightedStopName: child?.stop,
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: trip == null
                                        ? StatusBadge(
                                            label: 'Not started',
                                            color: AppTheme.warning,
                                          )
                                        : const StatusBadge(
                                            label: '● LIVE',
                                            color: AppTheme.success,
                                          ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        child?.route.isNotEmpty == true
                                            ? '📍 ${child!.route}'
                                            : '📍 No route assigned',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Expands to a fullscreen, pannable/
                                  // zoomable map — this 220px preview stays
                                  // gesture-locked so it doesn't fight the
                                  // page's own scroll (see `RouteMapView`'s
                                  // `interactive` doc comment).
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: () => context.push(
                                        '/parent/track/map',
                                        extra: {
                                          'highlightedStopName': child?.stop,
                                        },
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.fullscreen,
                                          color: Colors.white70,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Bus status ──────────────────────────────────
                        GlassCard(
                          enableBlur: false,
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.success.withValues(alpha: 0.12),
                              AppTheme.success.withValues(alpha: 0.04),
                            ],
                          ),
                          borderColor: AppTheme.success.withValues(alpha: 0.2),
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.studentGradient,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Text(
                                    '🚌',
                                    style: TextStyle(fontSize: 26),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Builder(
                                      builder: (_) {
                                        final assignment = [
                                          child?.busNumber ?? '',
                                          child?.route ?? '',
                                        ]
                                            .where((s) => s.isNotEmpty)
                                            .join(' · ');
                                        return Text(
                                          assignment.isEmpty
                                              ? 'No bus assigned yet'
                                              : assignment,
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${AppStrings.t('driver')}: ${child?.driver ?? "N/A"}',
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // No trip running has nothing to compare a
                              // live ETA against, so it gets its own honest
                              // label instead of an "On Time" that was
                              // previously shown even before a driver had
                              // started anything.
                              StatusBadge(
                                label: trip == null
                                    ? 'Waiting for driver'
                                    : AppStrings.t('on_time'),
                                color: trip == null
                                    ? AppTheme.warning
                                    : AppTheme.success,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (trip == null)
                          GlassCard(
                            enableBlur: false,
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const Text('🚏', style: TextStyle(fontSize: 28)),
                                const SizedBox(height: 10),
                                Text(
                                  "Your driver hasn't started the route yet",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "You'll see live progress here once the "
                                  'route begins.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: context.textTertiary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          // ── Trip stat row ────────────────────────────
                          GlassCard(
                            enableBlur: false,
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _StatChip(
                                  icon: '⏱️',
                                  label: 'Started',
                                  value: _relativeStart(trip.startedAt),
                                  color: AppTheme.studentAmber,
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: context.surfaceBorder,
                                ),
                                _StatChip(
                                  icon: '🧍',
                                  label: 'Your status',
                                  value: _attendanceLabel(_myAttendance),
                                  color: AppTheme.purple,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Route progress ────────────────────────────
                          //
                          // Just this child's own leg — every other
                          // family's pickup point is information this
                          // account has no business seeing, and Firestore's
                          // rules agree (a parent can only read their own
                          // child's attendance document).
                          GlassCard(
                            enableBlur: false,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.t('route_progress'),
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Builder(builder: (_) {
                                  final boarded = _myAttendance?.status ==
                                      AttendanceStatus.boarded;
                                  return Column(
                                    children: [
                                      _StopTimelineItem(
                                        name: child?.stop.isNotEmpty == true
                                            ? child!.stop
                                            : 'Your stop',
                                        time: '',
                                        isDone: boarded,
                                        isCurrent: !boarded,
                                        isLast: false,
                                        isYourStop: true,
                                      ),
                                      _StopTimelineItem(
                                        name: child?.school.isNotEmpty == true
                                            ? child!.school
                                            : 'School',
                                        time: '',
                                        isDone: false,
                                        isCurrent: boarded,
                                        isLast: true,
                                        isYourStop: false,
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final ChildInfo? child;
  final List<ChildInfo> children;
  final Function(int) onChildSelected;

  const _Header({
    required this.title,
    required this.onBack,
    required this.child,
    required this.children,
    required this.onChildSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.cardBgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.inputBorder),
                  ),
                  child: Center(
                    child: Text(
                      '←',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (children.length > 1) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: children.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final isSelected = children[idx].name == child?.name;
                  return GestureDetector(
                    onTap: () => onChildSelected(idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.parentPurple.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.parentPurple
                              : context.surfaceBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          children[idx].name,
                          style: TextStyle(
                            color: isSelected
                                ? context.textPrimary
                                : context.textSecondary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon, label, value;
  final Color color;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 10),
        ),
      ],
    );
  }
}

class _StopTimelineItem extends StatelessWidget {
  final String name, time;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;
  final bool isYourStop;

  const _StopTimelineItem({
    required this.name,
    required this.time,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
    required this.isYourStop,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = isDone;
    final bool isPastOrCurrent = isCompleted || isCurrent;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline line and dot ──────────────────────────────────────────
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // Top line (connector)
                // Container(width: 2, height: 4, color: isPastOrCurrent ? AppTheme.success : context.surfaceBorder),
                const SizedBox(height: 6),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isPastOrCurrent
                        ? AppTheme.success
                        : context.surfaceBorder,
                    shape: BoxShape.circle,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: AppTheme.success.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      // The line below should only be green if NEXT is completed/current.
                      // But for simplicity in a stateless widget without next-stop context,
                      // we use isCompleted as a proxy.
                      color: isCompleted
                          ? AppTheme.success
                          : context.surfaceBorder.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // ── Name and Time ──────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isYourStop
                          ? "$name (${AppStrings.t('your_stop')})"
                          : name,
                      style: TextStyle(
                        color: (isYourStop || isCurrent)
                            ? context.textPrimary
                            : context.textSecondary,
                        fontSize: 15,
                        fontWeight: (isYourStop || isCurrent)
                            ? FontWeight.w600
                            : FontWeight.w400,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

