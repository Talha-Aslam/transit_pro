import 'dart:async';

import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart' hide StopStatus;

import '../../app/driver_data_service.dart';
import '../../app/language_provider.dart';
import '../../app/route_service.dart';
import '../../app/session_service.dart';
import '../../app/tracking_service.dart';
import '../../app/geofence_service.dart';
import '../../app/notification_service.dart';
import '../../data/trip_repository.dart';
import '../../map/route_map_view.dart';
import '../../models/route_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

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

  /// Distance from the bus to its destination stop, refreshed periodically
  /// via `RouteService.fetchDistanceDuration` (real Mapbox directions) rather
  /// than the '4.2 km' literal this screen used to show regardless of where
  /// the bus actually was.
  String? _liveDistance;
  Timer? _distanceTimer;

  /// The trip this driver currently has open, or null when nothing is
  /// running. This — not `_tracking.route` — is the source of truth for
  /// whether a route is "live": it comes straight from Firestore via
  /// [TripRepository.watchActiveTripForDriver], so a trip started on this
  /// screen a moment ago and a trip still open from before the app was
  /// killed both show up the same way.
  Trip? _activeTrip;
  StreamSubscription<Trip?>? _tripSub;
  bool _startingTrip = false;
  bool _endingTrip = false;

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

    final uid = _session.uid;
    if (uid != null) {
      _tripSub = TripRepository.instance
          .watchActiveTripForDriver(uid)
          .listen(_onActiveTripChanged);
    }

    _distanceTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshDistance(),
    );
  }

  void _onLangChanged() => setState(() {});

  void _onLocationSharingChanged() => setState(() {});

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
    _buildLiveRoute(schedule).then((liveRoute) {
      if (!mounted || liveRoute == null || _activeTrip?.id != trip.id) return;
      _tracking.start(liveRoute);
      setState(() {});
    });
  }

  void _onBusPositionChanged() {
    final r = _tracking.route;
    if (r == null) return;
    _geofence.evaluate(_tracking.busPosition.value, r.stops);
  }

  void _onGeofenceAlert() {
    final alerts = _geofence.alerts.value;
    if (alerts.isNotEmpty) {
      _notifSvc.fromGeofence(alerts.last);
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
    if (!mounted || result == null) return;
    setState(() => _liveDistance = result.distance);
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
      if ((s.direction == ScheduleDirection.pickup) == wantsPickup) return s;
    }
    return schedules.first;
  }

  /// Builds a real [RouteData] for [schedule] from this driver's actual
  /// roster and service area — the "what's real" replacement for
  /// `MockRouteBuilder.buildMorningRoute()`. Returns null when there isn't
  /// enough real data to build anything meaningful (no roster, or nobody on
  /// this round has a pickup/drop-off pin).
  Future<RouteData?> _buildLiveRoute(DriverSchedule schedule) async {
    final driver = _session.driver.value;
    if (driver == null) return null;

    final roster = _rosterForSchedule(schedule);
    if (roster.isEmpty) return null;

    final isPickup = schedule.direction == ScheduleDirection.pickup;

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

    final stops = <StopData>[];
    if (!isPickup && destination != null) {
      stops.add(StopData(
        name: destinationName,
        location: destination,
        scheduledTime: schedule.startTime,
      ));
    }
    for (final s in roster) {
      // Pickup collects a child from home; drop-off delivers them back —
      // the same point would be wrong for the other direction.
      final point = isPickup ? s.pickupLocation : s.dropoffLocation;
      if (point == null) continue;
      stops.add(StopData(
        name: s.name,
        location: point,
        scheduledTime: isPickup ? schedule.startTime : schedule.endTime,
        studentCount: 1,
        note: isPickup ? 'Pickup' : 'Drop-off',
      ));
    }
    if (isPickup && destination != null) {
      stops.add(StopData(
        name: destinationName,
        location: destination,
        scheduledTime: schedule.endTime,
      ));
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

      final liveRoute = await _buildLiveRoute(schedule);
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
        busId: _session.bus.value?.id ?? '',
        type: schedule.direction == ScheduleDirection.pickup
            ? TripType.morning
            : TripType.afternoon,
        students: roster,
      );

      _selectedSchedule = schedule;
      _tracking.start(liveRoute);
      if (!mounted) return;
      setState(() => _activeTrip = trip);
    } catch (e) {
      if (mounted) {
        _showSnack('Could not start the route. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _startingTrip = false);
    }
  }

  Future<void> _endRoute() async {
    final trip = _activeTrip;
    if (trip == null || _endingTrip) return;

    setState(() => _endingTrip = true);
    try {
      final schedule = _selectedSchedule ?? _scheduleForTrip(trip);
      final verdict = schedule == null ? null : _onTimeVerdict(schedule);
      await TripRepository.instance.endTrip(
        trip.id,
        onTime: verdict?.$1,
        delayMinutes: verdict?.$2,
      );
      _tracking.stop();
      _geofence.reset();
      if (!mounted) return;
      setState(() {
        _activeTrip = null;
        _selectedSchedule = null;
        _liveDistance = null;
      });
    } catch (e) {
      if (mounted) {
        _showSnack('Could not end the route. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _endingTrip = false);
    }
  }

  /// `(onTime, delayMinutes)` from comparing now against [schedule]'s
  /// scheduled end time. Null when that time can't be parsed.
  (bool, int)? _onTimeVerdict(DriverSchedule schedule) {
    final parts = schedule.endTime.split(':');
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _svc.locationSharing.removeListener(_onLocationSharingChanged);
    _tracking.busPosition.removeListener(_onBusPositionChanged);
    _geofence.alerts.removeListener(_onGeofenceAlert);
    _distanceTimer?.cancel();
    _tripSub?.cancel();
    _tracking.stop();
    _geofence.reset();
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppStrings.t('live_route_map'),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
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
                                  const SizedBox(width: 10),
                                  const Text(
                                    '⚡ ',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  ValueListenableBuilder<int>(
                                    valueListenable: _tracking.speed,
                                    builder: (_, spd, _) => Text(
                                      '$spd km/h',
                                      style: const TextStyle(
                                        color: AppTheme.driverAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
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
                  Row(
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: _tracking.etaMinutes,
                        builder: (_, eta, _) => _LiveStatCard(
                          icon: '⏱️',
                          label: AppStrings.t('eta_school'),
                          value: '$eta min',
                        ),
                      ),
                      const SizedBox(width: 10),
                      _LiveStatCard(
                        icon: '📏',
                        label: AppStrings.t('distance_left'),
                        value: _liveDistance ?? '—',
                      ),
                      const SizedBox(width: 10),
                      ValueListenableBuilder<int>(
                        valueListenable: _tracking.speed,
                        builder: (_, spd, _) => _LiveStatCard(
                          icon: '⚡',
                          label: AppStrings.t('avg_speed'),
                          value: '$spd km/h',
                        ),
                      ),
                    ],
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
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
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
            Text(icon, style: const TextStyle(fontSize: 16)),
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
