import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/active_trip_service.dart';
import '../../app/driver_data_service.dart';
import '../../app/language_provider.dart';
import '../../app/location_permissions.dart';
import '../../app/push_sender.dart';
import '../../app/session_service.dart';
import '../../app/tracking_service.dart';
import '../../app/trip_controller.dart';
import '../../app/trip_session.dart';
import '../../data/trip_repository.dart';
import '../../map/trip_map_view.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/app_glyph.dart';
import 'trip_panel.dart';

/// The driver's Route tab.
///
/// A view onto [TripSession]: the round itself — the order of the stops,
/// the route, arrivals, who is on board — lives in [TripController] and
/// keeps running while the driver is on another tab. This screen starts and
/// ends it, and shows it.
class DriverRoute extends StatefulWidget {
  const DriverRoute({super.key});

  @override
  State<DriverRoute> createState() => _DriverRouteState();
}

class _DriverRouteState extends State<DriverRoute> {
  final _svc = DriverDataService.instance;
  final _session = SessionService.instance;
  final _tracking = TrackingService.instance;

  TripSession get _tripSession => TripSession.instance;
  TripController get _ctl => _tripSession.controller;

  /// The trip this driver has open, straight from Firestore — also true for
  /// a round started before the app was last closed, which [TripSession]
  /// picks back up on its own.
  Trip? _activeTrip;
  bool _startingTrip = false;
  bool _endingTrip = false;

  /// Which round is selected in the Start Route picker.
  DriverSchedule? _selectedSchedule;

  bool get _sharingLocation => _svc.locationSharing.value;
  bool get _hasActiveTrip => _activeTrip != null || _ctl.isRunning;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_rebuild);
    _svc.locationSharing.addListener(_onLocationSharingChanged);
    _activeTrip = ActiveTripService.instance.trip.value;
    ActiveTripService.instance.trip.addListener(_onActiveTrip);
    _ctl.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onActiveTrip() {
    if (!mounted) return;
    setState(() => _activeTrip = ActiveTripService.instance.trip.value);
  }

  /// The driver's "share my location" switch applies mid-trip too: off
  /// stops the pings without ending the round, on resumes them.
  void _onLocationSharingChanged() {
    setState(() {});
    final trip = _ctl.trip ?? _activeTrip;
    if (!_svc.locationSharing.value) {
      _tracking.stopBroadcast();
    } else if (trip != null) {
      _startBroadcast(trip);
    }
  }

  /// Publishes under the key the trip records, so a family following
  /// `trip.busId` finds this van.
  Future<void> _startBroadcast(Trip trip) async {
    final uid = _session.uid;
    if (uid == null || !_tracking.isLive.value) return;
    if (!_svc.locationSharing.value) return;
    await _tracking.startBroadcast(
      busId: trip.busId.isEmpty ? uid : trip.busId,
      driverId: uid,
      tripId: trip.id,
    );
  }

  /// Whether the leg about to be driven takes the children *to* their
  /// institute. A round holds both legs; the clock decides which one a tap
  /// on Start means — 06:40 is the morning run, 13:20 the way home.
  /// Asks which way this round runs today. Required, every time.
  ///
  /// The direction used to be guessed from the clock — whichever of the
  /// round's two start times was nearer now — so a driver starting a little
  /// early or late got the other leg, and the route seemed to flip between
  /// going to the institute and coming home at random. A leg the round does
  /// not run is shown but cannot be chosen.
  Future<TripLegKind?> _askDirection(DriverSchedule schedule) {
    return showModalBottomSheet<TripLegKind>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ctx.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Which way is "${schedule.label}" going?',
                style: TextStyle(
                  color: ctx.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _DirectionOption(
                emoji: '🏠 → 🏫',
                title: 'Home to Institute',
                subtitle: schedule.hasPickup
                    ? 'Collect everyone from home, then drop at the institute.'
                    : 'This round does not run this way.',
                enabled: schedule.hasPickup,
                onTap: () => Navigator.pop(ctx, TripLegKind.pickup),
              ),
              const SizedBox(height: 10),
              _DirectionOption(
                emoji: '🏫 → 🏠',
                title: 'Institute to Home',
                subtitle: schedule.hasDropoff
                    ? 'Start at the institute, then drop everyone home.'
                    : 'This round does not run this way.',
                enabled: schedule.hasDropoff,
                onTap: () => Navigator.pop(ctx, TripLegKind.dropoff),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The round's institute, for a child with no institute pin of their own
  /// — preferably one this round names, then another child's institute,
  /// then any pinned service area. Each child with a pin of their own goes
  /// to, and on the way home is collected from, that pin instead.
  GeoCoord? _destinationFor(DriverSchedule schedule, List<Student> roster) {
    final driver = _session.driver.value;
    if (driver == null) return null;
    for (final area in driver.serviceAreas) {
      if (area.location != null && schedule.serves(area.name)) {
        return area.location;
      }
    }
    for (final s in roster) {
      if (s.dropoffLocation != null) return s.dropoffLocation;
    }
    for (final area in driver.serviceAreas) {
      if (area.location != null) return area.location;
    }
    return driver.baseLocation;
  }

  Future<void> _startRoute() async {
    final driver = _session.driver.value;
    if (driver == null || _startingTrip) return;
    final schedules = driver.orderedSchedules;
    if (schedules.isEmpty) {
      _showSnack(
        'Add a round under "Where do you drive?" in your profile before '
        'starting a route.',
      );
      return;
    }
    final schedule = _selectedSchedule ?? schedules.first;
    final roster = _tripSession.rosterFor(schedule.id);
    if (roster.isEmpty) {
      _showSnack('No students are booked on "${schedule.label}" yet.');
      return;
    }

    if (!await ensureLocationOrExplain(context, accent: AppTheme.driverCyan)) {
      return;
    }
    if (!mounted) return;
    await offerBackgroundLocation(context);
    if (!mounted) return;

    final leg = await _askDirection(schedule);
    if (leg == null || !mounted) return;
    final isPickup = leg == TripLegKind.pickup;

    setState(() => _startingTrip = true);
    try {
      // The round's institute, for any child without one of their own:
      // where the morning ends and where the ride home begins.
      final institute = _destinationFor(schedule, roster);
      if (isPickup &&
          institute == null &&
          roster.every((s) => s.dropoffLocation == null)) {
        _showSnack(
          'Set your school or institute location in your profile so the '
          'route knows where to end.',
        );
        return;
      }
      final trip = await _tripSession.start(
        schedule: schedule,
        leg: leg,
        destination: institute,
      );
      if (!mounted) return;
      setState(() {
        _selectedSchedule = schedule;
        _activeTrip = trip;
      });
      if (!_tracking.isLive.value) {
        _showSnack(
          'Real GPS is not available, so the van is not being shared with '
          'families. Check location permission.',
        );
      }
    } on StateError catch (e) {
      _showSnack(e.message);
    } on FirebaseException catch (e) {
      // The one failure that really happens here: rules not deployed, or an
      // account whose `users/{uid}.role` is not `driver`.
      _showSnack(
        e.code == 'permission-denied'
            ? 'The server refused to open this trip. Your account may not '
                  'be registered as a driver, or the Firestore rules need '
                  'deploying.'
            : 'Could not start the route (${e.code}).',
      );
    } catch (e) {
      debugPrint('start route failed: $e');
      _showSnack('Could not start the route. Please try again.');
    } finally {
      if (mounted) setState(() => _startingTrip = false);
    }
  }

  /// Tells the driver, and each affected family, about children nobody
  /// recorded either way. Silence used to be indistinguishable from
  /// "nothing happened".
  Future<void> _reportUnmarkedAttendance(Trip trip) async {
    final uid = _session.uid;
    if (uid == null) return;
    try {
      final missing = await TripRepository.instance.unmarkedStudents(trip.id);
      if (missing.isEmpty) return;
      final roster = {for (final s in _tripSession.rosterFor(null)) s.id: s};
      final names = <String>[];
      final today = Trip.dateKeyFor(DateTime.now());
      for (final studentId in missing) {
        final student = roster[studentId];
        if (student == null) continue;
        // Kept home by their family: the van never went for them, so there
        // was nothing for the driver to mark.
        if (student.isAbsentOn(today)) continue;
        names.add(student.name);
        final recipient = student.parentId.trim().isEmpty
            ? student.id
            : student.parentId.trim();
        unawaited(
          PushSender.instance.notifyOne(
            recipient,
            UserNotification(
              id: '',
              type: NotificationType.absent,
              title: 'Attendance not recorded',
              body:
                  'Your driver did not mark ${student.name} on or off '
                  "today's round. Please check with them.",
              data: {'studentId': student.id},
            ),
          ),
        );
      }
      if (names.isEmpty) return;
      unawaited(
        PushSender.instance.notifyOne(
          uid,
          UserNotification(
            id: '',
            type: NotificationType.absent,
            title: 'You missed some attendance',
            body:
                '${names.length} student${names.length == 1 ? '' : 's'} were '
                'never marked on this round: ${names.join(', ')}. Their '
                'families have been told.',
            data: {'tripId': trip.id, 'route': '/driver/attendance'},
          ),
        ),
      );
    } catch (e) {
      debugPrint('unmarked attendance report failed: $e');
    }
  }

  Future<void> _endRoute() async {
    final trip = _ctl.trip ?? _activeTrip;
    if (trip == null || _endingTrip) return;
    setState(() => _endingTrip = true);
    try {
      await _reportUnmarkedAttendance(trip);
      await _tripSession.end();
      if (!mounted) return;
      setState(() {
        _activeTrip = null;
        _selectedSchedule = null;
      });
    } catch (e) {
      debugPrint('end route failed: $e');
      if (mounted) _showSnack('Could not end the route. Please try again.');
    } finally {
      if (mounted) setState(() => _endingTrip = false);
    }
  }

  Future<void> _confirmSkip() async {
    final next = _ctl.nextStop;
    if (next == null || !next.isChildStop) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip this stop?'),
        content: Text(
          '${stopNames(_ctl, next)} will be marked as not riding today, and '
          'their family will be told.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
    if (ok == true) await _ctl.skipStop(next.id);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_rebuild);
    _svc.locationSharing.removeListener(_onLocationSharingChanged);
    ActiveTripService.instance.trip.removeListener(_onActiveTrip);
    _ctl.removeListener(_rebuild);
    // An open trip keeps tracking while the driver is on another tab. With
    // nothing running, the tracker is reset — deferred, because writing to
    // notifiers other mounted screens watch while Flutter has the tree
    // locked for this teardown throws "markNeedsBuild() called when widget
    // tree was locked".
    if (!_hasActiveTrip) _tracking.stopAfterFrame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveColor = _sharingLocation ? AppTheme.success : Colors.grey;
    final round =
        _selectedSchedule ??
        _session.driver.value?.scheduleById(_ctl.trip?.scheduleId ?? '');

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 150),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                      Text(
                        AppStrings.t('route_navigator'),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _hasActiveTrip
                            ? (round?.label ?? 'Route in progress')
                            : 'No active route',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_hasActiveTrip)
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: liveColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: liveColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _hasActiveTrip ? _buildEndRouteCard() : _buildStartRouteCard(),
                const SizedBox(height: 12),
                if (_hasActiveTrip) ..._buildRunning(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRunning() {
    final c = _ctl;
    if (!c.isRunning) {
      // The trip is open in Firestore but this phone is still picking it
      // up (app just reopened).
      return [
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Picking up your round where you left off…',
                  style: TextStyle(color: context.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    final arrived = c.phase == TripPhase.arrivedInstitute;
    return [
      TripStatusBanners(controller: c),
      if (arrived)
        ArrivedCard(onEnd: _endRoute, ending: _endingTrip)
      else ...[
        if (c.arrival != null) ...[
          ArrivalCard(controller: c),
          const SizedBox(height: 12),
        ],
        NextStopCard(controller: c, onSkip: _confirmSkip),
      ],
      const SizedBox(height: 12),

      // ── Live map ─────────────────────────────────────────────────────
      GlassCard(
        backgroundColor: context.cardBg,
        borderRadius: 20,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.t('live_route_map'),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '⚡ ${c.speedKmh.round()} km/h',
                    style: const TextStyle(
                      color: AppTheme.driverAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: context.surfaceBorder, height: 1),
            Stack(
              children: [
                TripMapView(
                  controller: c,
                  height: 340,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _MapExpandButton(
                    onTap: () => context.push('/driver/track/map'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // ── Live figures ─────────────────────────────────────────────────
      Row(
        children: [
          _LiveStatCard(
            icon: '⏱️',
            label: c.leg == TripLegKind.pickup
                ? AppStrings.t('eta_school')
                : 'To last stop',
            value: formatEta(c.secondsToEnd),
          ),
          const SizedBox(width: 10),
          _LiveStatCard(
            icon: '📏',
            label: AppStrings.t('distance_left'),
            value: formatMeters(c.metersToEnd),
          ),
          const SizedBox(width: 10),
          _LiveStatCard(
            icon: '👦',
            label: 'On board',
            value: '${c.onBoard.length}',
          ),
        ],
      ),
      const SizedBox(height: 12),

      // ── Location sharing toggle ──────────────────────────────────────
      GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  _sharingLocation ? Icons.location_on : Icons.location_off,
                  color: _sharingLocation
                      ? AppTheme.success
                      : context.textTertiary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Share Location',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Switch(
              value: _sharingLocation,
              activeThumbColor: AppTheme.success,
              onChanged: _svc.setLocationSharing,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TripStopList(controller: c),
      const SizedBox(height: 12),
      OnBoardList(controller: c),
      const SizedBox(height: 12),
    ];
  }

  /// Trip summary and the button that closes it out for real.
  Widget _buildEndRouteCard() {
    final c = _ctl;
    final left = c.openStops.where((s) => s.isChildStop).length;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppTheme.success.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('🚌', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.leg == TripLegKind.pickup ? 'Morning pickup' : 'Ride home',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  c.isRunning
                      ? '$left stop${left == 1 ? '' : 's'} left'
                      : "Tap End Route when you've finished this run.",
                  style: TextStyle(color: context.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _endingTrip ? null : _endRoute,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.error.withValues(alpha: 0.4),
                ),
              ),
              child: _endingTrip
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.error,
                      ),
                    )
                  : const Text(
                      'End Route',
                      style: TextStyle(
                        color: AppTheme.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// A round picker (only with more than one round) and Start Route.
  Widget _buildStartRouteCard() {
    final schedules = _session.driver.value?.orderedSchedules ?? const [];
    final multipleRounds = schedules.length > 1;
    _selectedSchedule ??= schedules.firstOrNull;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.driverCyan.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🚏', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No route running',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      schedules.isEmpty
                          ? 'Add a round in your profile to get started.'
                          : 'Start a round to plan the best route from '
                                'where you are.',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (multipleRounds) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: schedules.map((s) {
                final selected = _selectedSchedule?.id == s.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSchedule = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.driverCyan.withValues(alpha: 0.2)
                          : context.cardBgElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppTheme.driverCyan
                            : context.inputBorder,
                      ),
                    ),
                    child: Text(
                      '${s.label} · ${s.timeRange}',
                      style: TextStyle(
                        color: selected
                            ? AppTheme.driverCyan
                            : context.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          GradientButton(
            label: 'Start Route',
            gradient: AppTheme.driverGradient,
            glowColor: AppTheme.driverCyan,
            isLoading: _startingTrip,
            isEnabled: schedules.isNotEmpty,
            onTap: schedules.isEmpty ? null : _startRoute,
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────

class _LiveStatCard extends StatelessWidget {
  final String icon, label, value;
  const _LiveStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        enableBlur: false,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            AppGlyph(icon, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.textTertiary, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the round on a full screen. A button rather than a tap anywhere on
/// the map, which has to keep its own pan and zoom.
class _MapExpandButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MapExpandButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: context.surfaceBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.open_in_full_rounded,
              size: 14,
              color: AppTheme.driverCyan,
            ),
            const SizedBox(width: 7),
            Text(
              'Full map',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One choice in the direction sheet.
class _DirectionOption extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
  const _DirectionOption({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardBgElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.driverCyan.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
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
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
