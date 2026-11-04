import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart' hide StopStatus;

import '../../app/active_trip_service.dart';
import '../../app/driver_data_service.dart';
import '../../app/language_provider.dart';
import '../../app/location_permissions.dart';
import '../../app/route_service.dart';
import '../../app/push_sender.dart';
import '../../app/session_service.dart';
import '../../app/tracking_service.dart';
import '../../app/geofence_service.dart';
import '../../app/notification_service.dart';
import '../../data/trip_repository.dart';
import '../../map/route_map_view.dart';
import '../../models/route_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/app_glyph.dart';

class DriverRoute extends StatefulWidget {
  const DriverRoute({super.key});

  @override
  State<DriverRoute> createState() => _DriverRouteState();
}

class _DriverRouteState extends State<DriverRoute> {
  final _svc = DriverDataService.instance;
  final _session = SessionService.instance;
  final _tracking = TrackingService.instance;
  final _geofence = GeofenceService.instance;
  final _notifSvc = NotificationService.instance;

  bool _followCamera = true;
  bool _togglingLive = false;

  /// Refreshes the road-aware distance and duration from Google's Routes
  /// API and hands them to [TrackingService], which owns both figures now.
  ///
  /// This screen used to keep the distance string to itself and leave the
  /// ETA to a simulation-only estimate, so on a real GPS trip the distance
  /// moved every eight seconds while "ETA to school" never moved at all.
  /// Both now come from the same place, and so does the copy a parent sees.
  Timer? _distanceTimer;

  /// The trip this driver currently has open, or null when nothing is
  /// running. This — not `_tracking.route` — is the source of truth for
  /// whether a route is "live": it comes straight from Firestore via
  /// [TripRepository.watchActiveTripForDriver], so a trip started on this
  /// screen a moment ago and a trip still open from before the app was
  /// killed both show up the same way.
  Trip? _activeTrip;
  bool _startingTrip = false;
  bool _endingTrip = false;

  /// True while a hand-over batch is in flight, so a geofence that fires
  /// `arrived` repeatedly at the gate does not repeat the write.
  bool _handingOver = false;

  /// Which round is selected in the Start-Route picker (only shown when the
  /// driver runs more than one). Also remembered across a resumed trip so
  /// [_endRoute] knows which schedule's end time to check "on time" against.
  DriverSchedule? _selectedSchedule;

  bool get _sharingLocation => _svc.locationSharing.value;
  bool get _hasActiveTrip => _activeTrip != null;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _svc.locationSharing.addListener(_onLocationSharingChanged);
    _notifSvc.init();

    _tracking.busPosition.addListener(_onBusPositionChanged);
    _geofence.alerts.addListener(_onGeofenceAlert);

    // Shared with the dashboard and the profile chip, rather than a fourth
    // subscription to the same query that could disagree with them.
    _activeTrip = ActiveTripService.instance.trip.value;
    ActiveTripService.instance.trip.addListener(_onActiveTripFromService);

    _distanceTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshDistance(),
    );
  }

  void _onLangChanged() => setState(() {});

  void _onActiveTripFromService() =>
      _onActiveTripChanged(ActiveTripService.instance.trip.value);

  /// The driver's "share my location" switch applies mid-trip too: turning
  /// it off stops the pings without ending the round, turning it back on
  /// resumes them.
  void _onLocationSharingChanged() {
    setState(() {});
    final trip = _activeTrip;
    if (!_svc.locationSharing.value) {
      _tracking.stopBroadcast();
    } else if (trip != null) {
      _startBroadcast(trip);
    }
  }

  /// Reacts to the live `trips/{tripId}` query — not just this screen's own
  /// [_startRoute]/[_endRoute] calls. A trip that was already running when
  /// this screen opens (app relaunch, tab switch back) needs its local
  /// simulation rebuilt here, since [TrackingService] itself remembers
  /// nothing across a `stop()`/dispose.
  void _onActiveTripChanged(Trip? trip) {
    if (!mounted) return;
    final alreadyTracking = _tracking.route != null;
    setState(() => _activeTrip = trip);
    if (trip == null || alreadyTracking) return;

    final schedule = _scheduleForTrip(trip);
    if (schedule == null) return;
    _selectedSchedule = schedule;
    // From the trip, not the clock: rebuilding a morning run at noon after
    // an app relaunch must not turn it into the ride home.
    _buildLiveRoute(
      schedule,
      isPickup: trip.type == TripType.morning,
    ).then((liveRoute) async {
      if (!mounted || liveRoute == null || _activeTrip?.id != trip.id) return;
      await _tracking.start(liveRoute);
      await _startBroadcast(trip);
      if (mounted) setState(() {});
    });
  }

  void _onBusPositionChanged() {
    final r = _tracking.route;
    if (r == null) return;
    _geofence.evaluate(_tracking.busPosition.value, r.stops);
  }

  void _onGeofenceAlert() {
    final alerts = _geofence.alerts.value;
    if (alerts.isEmpty) return;
    final alert = alerts.last;
    _notifSvc.fromGeofence(alert);

    // Arriving at the far end of the leg is the hand-over. Doing it here
    // rather than waiting for the driver to close the round is what lets a
    // family see "Reached" while the driver is still parking.
    if (alert.event == GeofenceEvent.arrived &&
        alert.stop.status == StopStatus.destination) {
      unawaited(_handOverEveryoneAboard());
    }
  }

  /// Marks everyone still aboard as handed over, once.
  ///
  /// Guarded because the geofence can fire `arrived` more than once while
  /// the bus sits at the gate, and each repeat would be a pointless batch
  /// write against the same documents.
  Future<void> _handOverEveryoneAboard() async {
    final trip = _activeTrip;
    final uid = _session.uid;
    if (trip == null || uid == null || _handingOver) return;
    _handingOver = true;
    try {
      await TripRepository.instance.markRemainingDroppedOff(
        tripId: trip.id,
        markedBy: uid,
      );
    } catch (e) {
      debugPrint('hand-over failed: $e');
    } finally {
      _handingOver = false;
    }
  }

  /// Tells the driver, and each affected family, about children nobody
  /// recorded either way.
  ///
  /// Silence here used to be indistinguishable from "nothing happened": the
  /// family was left reading "waiting to board" for a ride that had already
  /// finished, and the driver had no idea they had skipped anyone.
  Future<void> _reportUnmarkedAttendance(Trip trip) async {
    final uid = _session.uid;
    if (uid == null) return;
    try {
      final missing = await TripRepository.instance.unmarkedStudents(trip.id);
      if (missing.isEmpty) return;

      final roster = <String, Student>{
        for (final s in _session.roster.value) s.id: s,
        for (final s in _session.routeStudents.value) s.id: s,
      };
      final names = <String>[];
      for (final studentId in missing) {
        final student = roster[studentId];
        if (student == null) continue;
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

  Future<void> _refreshDistance() async {
    final r = _tracking.route;
    if (r == null) return;
    final stops = r.stops;
    if (stops.isEmpty) return;
    StopData? destination;
    for (final s in stops) {
      if (s.status == StopStatus.destination) {
        destination = s;
        break;
      }
    }
    destination ??= stops.last;
    final result = await RouteService.instance.fetchDistanceDuration(
      origin: _tracking.busPosition.value,
      destination: destination.location,
    );
    // No key, no network, no route found: the service falls back to its own
    // along-the-polyline estimate, which is less accurate but never stale.
    if (!mounted || result == null) return;
    _tracking.applyRouteEstimate(
      meters: result.meters,
      seconds: result.seconds,
    );
  }

  Future<void> _toggleLive() async {
    setState(() => _togglingLive = true);
    try {
      await _tracking.toggleLive();
    } finally {
      if (mounted) setState(() => _togglingLive = false);
    }
  }

  // ── Start / End route ───────────────────────────────────────────────────

  /// The driver's own roster and admin-assigned students, merged and
  /// de-duplicated by id — same rule `DriverBookedStudentsScreen` uses:
  /// `SessionService.roster` (the real, self-signed-up path) wins on a
  /// collision with `SessionService.routeStudents` (the legacy admin path).
  List<Student> _rosterForSchedule(DriverSchedule schedule) {
    final merged = <String, Student>{};
    for (final s in _session.roster.value) {
      merged[s.id] = s;
    }
    for (final s in _session.routeStudents.value) {
      merged.putIfAbsent(s.id, () => s);
    }
    return merged.values.where((s) => s.scheduleId == schedule.id).toList();
  }

  /// Best-effort match for resuming a trip that's already running:
  /// [Trip] itself doesn't record which round started it, only [Trip.type],
  /// so this picks the first schedule whose direction matches that
  /// (`morning` → pickup, `afternoon` → drop-off) and falls back to the
  /// first schedule at all when nothing matches. Good enough to resume
  /// *something* sensible; a driver running two same-direction rounds could
  /// have the wrong one picked, which only affects the on-screen stop list,
  /// never the trip document itself.
  DriverSchedule? _scheduleForTrip(Trip trip) {
    final schedules = _session.driver.value?.orderedSchedules ?? const [];
    if (schedules.isEmpty) return null;
    final wantsPickup = trip.type == TripType.morning;
    for (final s in schedules) {
      if (wantsPickup ? s.hasPickup : s.hasDropoff) return s;
    }
    return schedules.first;
  }

  /// Whether the leg being driven takes the children *to* their institute.
  ///
  /// A round is a pair now, so this is no longer a property of the round. A
  /// running trip records which leg it is; for one about to start, the clock
  /// decides — a driver tapping Start at 06:40 means the morning run and the
  /// same driver at 13:20 means the way home, and asking them would be
  /// asking a question the time already answers.
  bool _legIsPickup(DriverSchedule schedule) {
    if (!schedule.hasDropoff) return true;
    if (!schedule.hasPickup) return false;
    final now = TimeOfDay.now();
    final minutes = now.hour * 60 + now.minute;
    int distanceTo(String hhmm) {
      final parts = hhmm.split(':');
      final h = int.tryParse(parts.first);
      final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
      if (h == null || m == null) return 1 << 20;
      return (minutes - (h * 60 + m)).abs();
    }

    return distanceTo(schedule.pickupStart) <=
        distanceTo(schedule.dropoffStart);
  }

  /// Builds a real [RouteData] for [schedule] from this driver's actual
  /// roster and service area — the "what's real" replacement for
  /// `MockRouteBuilder.buildMorningRoute()`. Returns null when there isn't
  /// enough real data to build anything meaningful (no roster, or nobody on
  /// this round has a pickup/drop-off pin).
  Future<RouteData?> _buildLiveRoute(
    DriverSchedule schedule, {
    required bool isPickup,
  }) async {
    final driver = _session.driver.value;
    if (driver == null) return null;

    final roster = _rosterForSchedule(schedule);
    if (roster.isEmpty) return null;

    // Where "school" is, for whichever end of the round isn't the students'
    // homes. A driver may serve several institutions; the first one with a
    // pin wins — there's no per-round link to a specific service area today.
    GeoCoord? destination;
    String destinationName = 'School';
    for (final area in driver.serviceAreas) {
      if (area.location != null) {
        destination = area.location;
        destinationName = area.name;
        break;
      }
    }
    destination ??= driver.baseLocation;

    // This leg's own clock. The round holds both pairs; stamping the
    // morning times onto the way home would have every stop on the
    // afternoon run read as hours late.
    final legStart = isPickup ? schedule.pickupStart : schedule.dropoffStart;
    final legEnd = isPickup ? schedule.pickupEnd : schedule.dropoffEnd;

    final stops = <StopData>[];
    if (!isPickup && destination != null) {
      stops.add(
        StopData(
          name: destinationName,
          location: destination,
          scheduledTime: legStart,
        ),
      );
    }
    for (final s in roster) {
      // Pickup collects a child from home; drop-off delivers them back —
      // the same point would be wrong for the other direction.
      final point = isPickup ? s.pickupLocation : s.dropoffLocation;
      if (point == null) continue;
      stops.add(
        StopData(
          name: s.name,
          location: point,
          scheduledTime: isPickup ? legStart : legEnd,
          studentCount: 1,
          note: isPickup ? 'Pickup' : 'Drop-off',
        ),
      );
    }
    if (isPickup && destination != null) {
      stops.add(
        StopData(
          name: destinationName,
          location: destination,
          scheduledTime: legEnd,
        ),
      );
    }
    if (stops.isEmpty) return null;
    // Whichever end is "school" (or, failing that, the last child) never
    // auto-completes as the bus passes near it — see
    // `TrackingService._updateStopStatuses`, which never touches a stop
    // already marked `destination`.
    stops.last.status = StopStatus.destination;

    final waypoints = stops.map((s) => s.location).toList();
    final polyline = await RouteService.instance.fetchRoute(
      origin: waypoints.first,
      destination: waypoints.last,
      waypoints: waypoints.length > 2
          ? waypoints.sublist(1, waypoints.length - 1)
          : const [],
    );

    return RouteData(
      id: schedule.id,
      name: schedule.label,
      busNumber: _session.bus.value?.busNumber ?? '',
      driverName: driver.name,
      stops: stops,
      polylinePoints: polyline,
    );
  }

  Future<void> _startRoute() async {
    final driver = _session.driver.value;
    final uid = _session.uid;
    if (driver == null || uid == null || _startingTrip) return;

    final schedules = driver.orderedSchedules;
    if (schedules.isEmpty) {
      _showSnack(
        'Add a round under "Where do you drive?" in your profile before '
        'starting a route.',
      );
      return;
    }
    final schedule = _selectedSchedule ?? schedules.first;

    setState(() => _startingTrip = true);
    try {
      final roster = _rosterForSchedule(schedule);
      if (roster.isEmpty) {
        _showSnack('No students are booked on "${schedule.label}" yet.');
        return;
      }

      final isPickup = _legIsPickup(schedule);
      final liveRoute = await _buildLiveRoute(schedule, isPickup: isPickup);
      if (!mounted) return;
      if (liveRoute == null) {
        _showSnack(
          'Could not build a route — make sure your students have a '
          'pickup or drop-off pin set.',
        );
        return;
      }

      final adminRoute = _session.route.value;
      final trip = await TripRepository.instance.startTrip(
        route: adminRoute ?? BusRoute(id: '', name: schedule.label),
        driverId: uid,
        // Same fallback `_startBroadcast` uses for the RTDB key, and that
        // is the point: a watching parent resolves the bus to follow from
        // `trip.busId`. With '' here, a self-signup driver with no admin
        // `Bus` document broadcast under their uid while the trip pointed at
        // nothing, so the family had no way to find the live position.
        busId: _session.bus.value?.id ?? uid,
        type: isPickup ? TripType.morning : TripType.afternoon,
        students: roster,
      );

      _selectedSchedule = schedule;
      final live = await _tracking.start(liveRoute);
      await _startBroadcast(trip);
      if (!mounted) return;
      setState(() => _activeTrip = trip);
      if (!live) {
        // Name the actual block and offer the screen that fixes it, rather
        // than telling the driver to go hunting in settings.
        if (mounted) {
          await ensureLocationOrExplain(context, accent: AppTheme.driverCyan);
        }
      }
    } on FirebaseException catch (e) {
      // "Please try again" is useless advice for the one failure that
      // actually happens here: rules that have not been deployed, or a
      // signed-in account whose `users/{uid}.role` is not `driver`. Name it.
      if (mounted) {
        _showSnack(
          e.code == 'permission-denied'
              ? 'The server refused to open this trip. Your account may not '
                    'be registered as a driver, or the Firestore rules need '
                    'deploying.'
              : 'Could not start the route (${e.code}).',
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Could not start the route. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _startingTrip = false);
    }
  }

  /// Starts publishing this trip's position for parents and the admin fleet
  /// map. Falls back to the driver's own uid as the key for a self-signup
  /// driver who has no admin-assigned `Bus` document — same rule the
  /// dashboard's sharing toggle uses.
  ///
  /// Only broadcasts a real fix: pushing the simulation's invented position
  /// out to families would be worse than showing them nothing.
  Future<void> _startBroadcast(Trip trip) async {
    final uid = _session.uid;
    if (uid == null || !_tracking.isLive.value) return;
    if (!_svc.locationSharing.value) return;
    await _tracking.startBroadcast(
      busId: _session.bus.value?.id ?? uid,
      driverId: uid,
      tripId: trip.id,
    );
  }

  Future<void> _endRoute() async {
    final trip = _activeTrip;
    if (trip == null || _endingTrip) return;

    setState(() => _endingTrip = true);
    try {
      final schedule = _selectedSchedule ?? _scheduleForTrip(trip);
      final verdict = schedule == null
          ? null
          : _onTimeVerdict(
              schedule,
              isPickup: trip.type == TripType.morning,
            );
      // Anyone still marked aboard is handed over now, in case the
      // destination had no pin for the geofence to catch.
      await _handOverEveryoneAboard();
      await _reportUnmarkedAttendance(trip);
      await TripRepository.instance.endTrip(
        trip.id,
        onTime: verdict?.$1,
        delayMinutes: verdict?.$2,
      );
      // `stop()` ends the broadcast as well, so the bus disappears from
      // every watching parent's map the moment the round is closed.
      _tracking.stop();
      _geofence.reset();
      if (!mounted) return;
      setState(() {
        _activeTrip = null;
        _selectedSchedule = null;

      });
    } catch (e) {
      if (mounted) {
        _showSnack('Could not end the route. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _endingTrip = false);
    }
  }

  /// `(onTime, delayMinutes)` from comparing now against the scheduled end
  /// of the leg that was actually driven. Null when that time can't be
  /// parsed, or when the round does not time that leg.
  (bool, int)? _onTimeVerdict(DriverSchedule schedule, {required bool isPickup}) {
    final end = isPickup ? schedule.pickupEnd : schedule.dropoffEnd;
    final parts = end.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    final now = DateTime.now();
    final scheduled = DateTime(now.year, now.month, now.day, h, m);
    final delay = now.difference(scheduled).inMinutes;
    return (delay <= 5, delay > 0 ? delay : 0);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _svc.locationSharing.removeListener(_onLocationSharingChanged);
    _tracking.busPosition.removeListener(_onBusPositionChanged);
    _geofence.alerts.removeListener(_onGeofenceAlert);
    _distanceTimer?.cancel();
    ActiveTripService.instance.trip.removeListener(_onActiveTripFromService);
    // An open trip keeps tracking and broadcasting while the driver is on
    // another tab. Stopping unconditionally here blanked the bus off every
    // watching parent's map the moment the driver opened their messages,
    // and only brought it back when they navigated to this screen again.
    if (_activeTrip == null) {
      // Deferred, not immediate: both of these publish to notifiers that
      // other mounted screens are listening to (the dashboard's live stat
      // cards watch `liveRevision`), and writing to them while Flutter has
      // the element tree locked for this teardown throws
      // "markNeedsBuild() called when widget tree was locked". The trip is
      // already over, so a microtask later is not observable.
      _tracking.stopAfterFrame();
      final geofence = _geofence;
      scheduleMicrotask(geofence.reset);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveColor = _sharingLocation ? AppTheme.success : Colors.grey;
    final liveTextColor = _sharingLocation
        ? AppTheme.successLight
        : Colors.grey;
    final route = _tracking.route;

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
                        route?.name ?? 'No active route',
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
                          boxShadow: _sharingLocation
                              ? [
                                  BoxShadow(
                                    color: AppTheme.success.withValues(
                                      alpha: 0.6,
                                    ),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: liveTextColor,
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

                if (_hasActiveTrip && route != null) ...[
                  // ── Live map ───────────────────────────────────────
                  GlassCard(
                    backgroundColor: const Color(0xCC05081E),
                    borderRadius: 20,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          // Title, both toggles and the speed read-out need
                          // ~344px of the 294px this card gives them, so the
                          // single Row they used to share overflowed by 50px
                          // on every phone. Two lines: the speed stays beside
                          // the title where it is glanced at, the toggles sit
                          // under it.
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      AppStrings.t('live_route_map'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ValueListenableBuilder<int>(
                                    valueListenable: _tracking.avgSpeed,
                                    builder: (_, spd, _) => Text(
                                      '⚡ $spd km/h',
                                      style: const TextStyle(
                                        color: AppTheme.driverAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Follow-camera toggle
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => _followCamera = !_followCamera,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _followCamera
                                            ? AppTheme.driverCyan.withValues(
                                                alpha: 0.2,
                                              )
                                            : const Color(0x10FFFFFF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _followCamera
                                              ? AppTheme.driverCyan
                                              : const Color(0x20FFFFFF),
                                        ),
                                      ),
                                      child: Text(
                                        _followCamera ? '📍 Follow' : '🗺 Free',
                                        style: TextStyle(
                                          color: _followCamera
                                              ? AppTheme.driverCyan
                                              : Colors.white54,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Real vs simulated GPS. Wired to
                                  // `TrackingService.toggleLive`, which
                                  // actually switches the position source.
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _tracking.isLive,
                                    builder: (_, isLive, _) => GestureDetector(
                                      onTap: _togglingLive ? null : _toggleLive,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isLive
                                              ? AppTheme.success.withValues(
                                                  alpha: 0.2,
                                                )
                                              : const Color(0x10FFFFFF),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: isLive
                                                ? AppTheme.success
                                                : const Color(0x20FFFFFF),
                                          ),
                                        ),
                                        child: Text(
                                          _togglingLive
                                              ? '…'
                                              : (isLive
                                                    ? '📡 Live GPS'
                                                    : '🧪 Simulated'),
                                          style: TextStyle(
                                            color: isLive
                                                ? AppTheme.success
                                                : Colors.white54,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: Color(0x10FFFFFF), height: 1),
                        RouteMapView(
                          height: 320,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          routeColor: AppTheme.driverCyan,
                          upcomingStopColor: AppTheme.driverCyan,
                          followBus: _followCamera,
                          interactive: true,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              _LegendDot(
                                color: AppTheme.success,
                                label: 'Completed',
                              ),
                              const SizedBox(width: 14),
                              _LegendDot(
                                color: AppTheme.purple,
                                label: 'Current',
                              ),
                              const SizedBox(width: 14),
                              _LegendDot(color: AppTheme.info, label: 'Next'),
                              const SizedBox(width: 14),
                              _LegendDot(
                                color: AppTheme.warning,
                                label: 'School',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Location sharing toggle ───────────────────────────
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _sharingLocation
                                  ? Icons.location_on
                                  : Icons.location_off,
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

                  // ── Live stats bar ────────────────────────────────────
                  // One builder for all three, driven by `liveRevision` —
                  // the notifier that fires whenever any live figure moves.
                  // Watching `etaMinutes` instead (as this used to) meant the
                  // distance and speed cards only repainted on the minute.
                  ValueListenableBuilder<int>(
                    valueListenable: _tracking.liveRevision,
                    builder: (_, _, _) {
                      final running = _tracking.route != null;
                      final eta = _tracking.etaMinutes.value;
                      return Row(
                        children: [
                          _LiveStatCard(
                            icon: '⏱️',
                            label: AppStrings.t('eta_school'),
                            // An honest dash beats "0 min", which reads as
                            // "you have arrived" when nothing is running.
                            value: !running
                                ? '—'
                                : eta <= 0
                                ? AppStrings.t('arriving_now')
                                : '$eta min',
                          ),
                          const SizedBox(width: 10),
                          _LiveStatCard(
                            icon: '📏',
                            label: AppStrings.t('distance_left'),
                            value: _tracking.distanceLabel ?? '—',
                          ),
                          const SizedBox(width: 10),
                          _LiveStatCard(
                            icon: '⚡',
                            label: AppStrings.t('avg_speed'),
                            value: running
                                ? '${_tracking.avgSpeed.value} km/h'
                                : '—',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── Route stops ───────────────────────────────────────
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route Stops',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ValueListenableBuilder<int>(
                          // stopStatusRevision, not busPosition — this list
                          // no longer rebuilds on every 150ms tick now that
                          // RouteMapView owns the map's own redraws.
                          valueListenable: _tracking.stopStatusRevision,
                          builder: (_, _, _) {
                            final stops = _tracking.route?.stops ?? const [];
                            return Column(
                              children: stops
                                  .asMap()
                                  .entries
                                  .map(
                                    (e) => _StopRow(
                                      stop: e.value,
                                      isLast: e.key == stops.length - 1,
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shown once a route is running: trip summary + the button that closes it
  /// out for real, via [TripRepository.endTrip] — not just a local
  /// `TrackingService.stop()`.
  Widget _buildEndRouteCard() {
    final schedule = _selectedSchedule;
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
                  schedule?.label ?? 'Route in progress',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Tap End Route when you\'ve finished this run.',
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

  /// Shown when nothing is running: a round picker (only when there's more
  /// than one) and the button that turns on real tracking for real students
  /// — replacing the old unconditional `_tracking.start(mockRoute)`.
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
                          : 'Start a round to begin live tracking.',
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

// ── Helper Widgets ─────────────────────────────────────────────────────────────

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
        // Three of these sit side by side, and two are wrapped in a
        // `ValueListenableBuilder` that rebuilds every tick (ETA, speed) — the
        // blur pass would repeat on every one of those updates.
        enableBlur: false,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            AppGlyph(icon, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: context.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  final StopData stop;
  final bool isLast;
  const _StopRow({required this.stop, required this.isLast});

  Color get _color => switch (stop.status) {
    StopStatus.completed => AppTheme.success,
    StopStatus.current => AppTheme.purple,
    StopStatus.destination => AppTheme.warning,
    _ => AppTheme.info,
  };

  String get _icon => switch (stop.status) {
    StopStatus.completed => '✓',
    StopStatus.destination => '🏫',
    _ => '📍',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _color, width: 2),
                  boxShadow: stop.status == StopStatus.current
                      ? [
                          BoxShadow(
                            color: _color.withValues(alpha: 0.5),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: stop.status == StopStatus.completed
                      ? Text(
                          '✓',
                          style: TextStyle(
                            color: _color,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Text(_icon, style: const TextStyle(fontSize: 13)),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 30,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: stop.status == StopStatus.completed
                      ? AppTheme.success.withValues(alpha: 0.4)
                      : context.cardBgElevated,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          stop.name,
                          style: TextStyle(
                            color:
                                stop.status == StopStatus.current ||
                                    stop.status == StopStatus.destination
                                ? context.textPrimary
                                : context.textSecondary,
                            fontSize: 14,
                            fontWeight: stop.status == StopStatus.current
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        if (stop.status == StopStatus.current) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.purple.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppTheme.purple.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Text(
                              'NEXT',
                              style: TextStyle(
                                color: AppTheme.parentAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (stop.note != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        stop.note!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      stop.scheduledTime,
                      style: TextStyle(
                        color: switch (stop.status) {
                          StopStatus.completed => AppTheme.successLight,
                          StopStatus.current => AppTheme.parentAccent,
                          StopStatus.destination => AppTheme.warning,
                          _ => AppTheme.driverAccent,
                        },
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (stop.studentCount > 0)
                      Text(
                        '👦 ${stop.studentCount}',
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Back button helper removed: navbar-managed pages handle back navigation.
