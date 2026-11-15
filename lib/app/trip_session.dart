import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:transit_core/transit_core.dart' hide StopStatus;

import '../data/trip_repository.dart';
import '../data/user_repository.dart';
import '../models/route_data.dart';
import 'active_trip_service.dart';
import 'driver_data_service.dart';
import 'location_fix.dart';
import 'push_sender.dart';
import 'route_optimization_service.dart';
import 'session_service.dart';
import 'tracking_service.dart';
import 'trip_controller.dart';

/// [TripBackend] over Firestore and push.
class FirestoreTripBackend implements TripBackend {
  final TripSession _session;
  FirestoreTripBackend(this._session);

  String get _uid => SessionService.instance.uid ?? '';

  @override
  Future<void> createTrip(Trip trip, List<Student> manifest) =>
      TripRepository.instance.createPlannedTrip(trip, manifest);

  @override
  Future<void> saveProgress(
    String tripId, {
    required List<TripStop> stops,
    required TripRoutePlan? route,
    required TripPhase phase,
  }) => TripRepository.instance.saveTripProgress(
    tripId,
    stops: stops,
    route: route,
    phase: phase,
  );

  @override
  Future<void> markAttendance(
    String tripId,
    String studentId,
    AttendanceStatus status,
  ) => TripRepository.instance.markAttendance(
    tripId: tripId,
    studentId: studentId,
    status: status,
    markedBy: _uid,
  );

  @override
  Future<Map<String, AttendanceStatus>> fetchAttendance(String tripId) =>
      TripRepository.instance.fetchAttendanceMap(tripId);

  @override
  Future<void> completeTrip(String tripId) => _session._finish();

  @override
  void notifyFamily(RiderInfo rider, FamilyEvent event, TripLegKind leg) {
    final name = rider.name;
    final home = leg == TripLegKind.dropoff;
    final (type, title, body) = switch (event) {
      FamilyEvent.routeStarted => (
        NotificationType.routeStarted,
        home ? '$name is heading home' : 'Your driver has started the route',
        home
            ? 'The driver has started the ride home. You will be told when '
                  'the van is about ${_session.controller.nearbyLead.inMinutes} '
                  "minutes from $name's drop-off point."
            : 'The van is on its way to collect $name. You will be told when '
                  'it is about ${_session.controller.nearbyLead.inMinutes} '
                  'minutes away.',
      ),
      FamilyEvent.nearby => (
        NotificationType.busApproaching,
        home
            ? '$name is about ${_session.controller.nearbyLead.inMinutes} '
                  'min from home'
            : 'Driver is reaching within '
                  '${_session.controller.nearbyLead.inMinutes} min',
        home
            ? "The van will be at $name's drop-off point in about "
                  '${_session.controller.nearbyLead.inMinutes} minutes.'
            : 'Please get $name ready — the van will be at the pickup point '
                  'in about ${_session.controller.nearbyLead.inMinutes} '
                  'minutes.',
      ),
      FamilyEvent.arriving => (
        NotificationType.busArrived,
        home ? '$name is almost home' : 'The van is at your stop',
        home
            ? "The van is pulling up at $name's drop-off point."
            : "The van has reached $name's pickup point.",
      ),
      FamilyEvent.boarded => (
        NotificationType.boarded,
        '$name has boarded',
        '$name is on the van.',
      ),
      FamilyEvent.absent => (
        NotificationType.absent,
        home ? '$name was not on the van' : '$name was marked absent',
        home
            ? '$name did not ride home on the van today.'
            : '$name was not at the pickup point, so the van went on.',
      ),
      FamilyEvent.droppedOff => (
        NotificationType.busArrived,
        'Your child $name dropped off',
        '$name has been dropped off by the driver.',
      ),
      FamilyEvent.reachedInstitute => (
        NotificationType.busArrived,
        '$name has reached school',
        'The van has arrived and $name has been dropped off.',
      ),
    };
    unawaited(
      PushSender.instance.notifyOne(
        rider.notifyUid,
        UserNotification(
          id: '',
          type: type,
          title: title,
          body: body,
          data: {
            'studentId': rider.id,
            if (_session.controller.trip != null)
              'tripId': _session.controller.trip!.id,
          },
        ),
      ),
    );
  }
}

/// The driver's running round, wired to the phone.
///
/// One instance for the app's life, so a round keeps going while the driver
/// is on another tab. Feeds GPS fixes to [controller], keeps the older
/// screens that read `TrackingService.route` in step with it, and picks a
/// round back up when the app is reopened in the middle of one.
class TripSession {
  TripSession._() {
    controller = TripController(
      optimizer: GoogleRouteOptimizer.instance,
      backend: FirestoreTripBackend(this),
    );
    controller.addListener(_onControllerChanged);
    _fixSub = TrackingService.instance.fixes.listen(controller.onFix);
    ActiveTripService.instance.trip.addListener(_onActiveTrip);
    SessionService.instance.roster.addListener(_onRosterChanged);
  }

  static final TripSession instance = TripSession._();

  late final TripController controller;
  // Lives as long as the app; never cancelled.
  // ignore: unused_field
  StreamSubscription<LocationFix>? _fixSub;
  DateTime? _syncedPlan;
  int _syncedStops = -1;
  bool _resuming = false;
  bool _finishing = false;

  final _tracking = TrackingService.instance;

  /// The driver's own roster and admin-assigned students, de-duplicated.
  List<Student> rosterFor(String? scheduleId) {
    final merged = <String, Student>{};
    for (final s in SessionService.instance.roster.value) {
      merged[s.id] = s;
    }
    for (final s in SessionService.instance.routeStudents.value) {
      merged.putIfAbsent(s.id, () => s);
    }
    return [
      for (final s in merged.values)
        if (scheduleId == null || s.scheduleId == scheduleId) s,
    ];
  }

  /// Where the phone is now, as precisely as a few seconds allow.
  static Future<GeoCoord?> currentPosition() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return GeoCoord(p.latitude, p.longitude);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      return last == null ? null : GeoCoord(last.latitude, last.longitude);
    }
  }

  /// Start Route. Throws [StateError] with a sentence for the driver.
  Future<Trip> start({
    required DriverSchedule schedule,
    required TripLegKind leg,
    required GeoCoord? destination,
  }) async {
    final uid = SessionService.instance.uid;
    if (uid == null) throw StateError('You are signed out.');
    final origin = await currentPosition();
    if (origin == null) {
      throw StateError(
        'Could not find your location. Make sure location is on and try '
        'again.',
      );
    }

    final busId = SessionService.instance.bus.value?.id ?? uid;
    final trip = await controller.start(
      TripStartRequest(
        driverId: uid,
        // The same key the van broadcasts under, so a family can find it.
        busId: busId,
        routeId: SessionService.instance.route.value?.id ?? schedule.id,
        scheduleId: schedule.id,
        leg: leg,
        riders: rosterFor(schedule.id),
        origin: origin,
        destination: destination,
      ),
      tripId: TripRepository.instance.newTripId(),
    );

    await _startTracking(trip);
    unawaited(
      UserRepository.instance.touchPresence(uid, status: DriverStatus.onTrip),
    );
    return trip;
  }

  Future<void> _startTracking(Trip trip) async {
    final uid = SessionService.instance.uid;
    await _tracking.start(_legacyRoute());
    _syncedPlan = null;
    _onControllerChanged();
    if (uid != null &&
        _tracking.isLive.value &&
        DriverDataService.instance.locationSharing.value) {
      await _tracking.startBroadcast(
        busId: trip.busId.isEmpty ? uid : trip.busId,
        driverId: uid,
        tripId: trip.id,
      );
    }
  }

  /// A round still open from before the app was closed: carry on with it.
  Future<void> _onActiveTrip() async {
    final trip = ActiveTripService.instance.trip.value;
    if (trip == null) {
      if (controller.isRunning && !_finishing) {
        // Ended from somewhere else (the admin, another device).
        controller.clear();
        _tracking.stop();
      }
      return;
    }
    if (controller.trip?.id == trip.id || _resuming) return;
    _resuming = true;
    try {
      final position = await currentPosition();
      await controller.resume(
        trip,
        roster: rosterFor(trip.scheduleId),
        position: position,
      );
      await _startTracking(trip);
    } catch (e) {
      debugPrint('trip resume failed: $e');
    } finally {
      _resuming = false;
    }
  }

  void _onRosterChanged() {
    if (!controller.isRunning) return;
    unawaited(
      controller.applyFamilyAbsences(rosterFor(controller.trip?.scheduleId)),
    );
  }

  /// End Route, by the driver.
  Future<void> end() => _finish();

  Future<void> _finish() async {
    final trip = controller.trip;
    if (trip == null || _finishing) return;
    _finishing = true;
    try {
      final verdict = _onTimeVerdict(trip);
      final delivered = await TripRepository.instance.markRemainingDroppedOff(
        tripId: trip.id,
        markedBy: SessionService.instance.uid ?? '',
      );
      // Children still aboard when the driver ends the round were delivered
      // without a tap of their own — their families hear it all the same.
      for (final id in delivered) {
        final rider = controller.rider(id);
        if (rider == null) continue;
        controller.backend.notifyFamily(
          rider,
          controller.leg == TripLegKind.pickup
              ? FamilyEvent.reachedInstitute
              : FamilyEvent.droppedOff,
          controller.leg,
        );
      }
      await TripRepository.instance.endTrip(
        trip.id,
        onTime: verdict?.$1,
        delayMinutes: verdict?.$2,
      );
      final uid = SessionService.instance.uid;
      if (uid != null) {
        unawaited(
          UserRepository.instance.touchPresence(
            uid,
            status: DriverStatus.online,
          ),
        );
      }
      _tracking.stop();
      controller.clear();
    } finally {
      _finishing = false;
    }
  }

  /// `(onTime, delayMinutes)` against the end time of the leg driven.
  (bool, int)? _onTimeVerdict(Trip trip) {
    final round = SessionService.instance.driver.value?.scheduleById(
      trip.scheduleId ?? '',
    );
    if (round == null) return null;
    final end = trip.type == TripType.morning
        ? round.pickupEnd
        : round.dropoffEnd;
    final parts = end.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    final now = DateTime.now();
    final delay = now.difference(DateTime(now.year, now.month, now.day, h, m));
    return (delay.inMinutes <= 5, delay.inMinutes > 0 ? delay.inMinutes : 0);
  }

  // ── Keeping the older screens in step ───────────────────────────────────

  void _onControllerChanged() {
    if (!controller.isRunning) return;
    final planned = controller.plannedAt;
    final closed = controller.stops.where((s) => !s.isOpen).length;
    if (planned != _syncedPlan || closed != _syncedStops) {
      _syncedPlan = planned;
      _syncedStops = closed;
      _tracking.adoptRoute(_legacyRoute());
    }
    final meters = controller.metersToEnd;
    final seconds = controller.secondsToEnd;
    if (meters != null && seconds != null) {
      _tracking.applyRouteEstimate(meters: meters, seconds: seconds);
    }
  }

  /// The controller's round in the shape the dashboard's cards read.
  RouteData _legacyRoute() {
    final next = controller.nextStop;
    return RouteData(
      id: controller.trip?.scheduleId ?? '',
      name:
          SessionService.instance.driver.value
              ?.scheduleById(controller.trip?.scheduleId ?? '')
              ?.label ??
          'Route',
      busNumber: SessionService.instance.bus.value?.busNumber ?? '',
      driverName: SessionService.instance.driver.value?.name ?? '',
      stops: [
        for (final s in controller.stops)
          StopData(
            name: s.isInstitute
                ? controller.instituteName(s)
                : controller.ridersAt(s).map((r) => r.name).join(', '),
            location: s.location,
            scheduledTime: '',
            studentCount: s.studentIds.length,
            status: s.isInstitute && s.isOpen
                ? StopStatus.destination
                : !s.isOpen
                ? StopStatus.completed
                : s.id == next?.id
                ? StopStatus.current
                : StopStatus.upcoming,
          ),
      ],
      polylinePoints: controller.remainingLine,
    );
  }
}
