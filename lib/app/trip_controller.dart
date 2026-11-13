import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import '../map/geo_utils.dart';
import 'location_fix.dart';
import 'route_optimization_service.dart';

/// Which way a leg carries the children.
enum TripLegKind { pickup, dropoff }

/// What a family is told about, as the round goes on.
enum FamilyEvent {
  /// The van is within [TripController.nearbyLead] of the child's pickup.
  nearby,
  arriving,
  boarded,
  absent,
  droppedOff,
  reachedInstitute,
}

/// A child as the controller needs them: who, whose, and where they get on
/// or off on this leg.
class RiderInfo {
  final String id;
  final String name;

  /// Who is told about this child — the parent, or the student themself
  /// when they signed up on their own.
  final String notifyUid;
  final GeoCoord? point;

  const RiderInfo({
    required this.id,
    required this.name,
    required this.notifyUid,
    this.point,
    this.institute,
    this.school = '',
  });

  /// The institute's name, as the family typed it — what an institute stop
  /// is called on the driver's screen.
  final String school;

  /// Where this child is set down in the morning — their own institute pin.
  /// Null falls back to the round's destination.
  final GeoCoord? institute;

  /// [Student] → rider for one leg.
  ///
  /// Both legs use the home pin. `dropoffLocation` on a student is the
  /// *institute* (it is written from the school search at sign-up), so the
  /// ride home has to end at `pickupLocation` — reading `dropoffLocation`
  /// for the afternoon is what put every drop-off stop inside the school.
  factory RiderInfo.fromStudent(Student s) => RiderInfo(
    id: s.id,
    name: s.name.trim().isEmpty ? 'Student' : s.name.trim(),
    notifyUid: s.parentId.trim().isEmpty ? s.id : s.parentId.trim(),
    point: s.pickupLocation,
    institute: s.dropoffLocation,
    school: s.school.trim(),
  );
}

/// The Arriving card: which stop, who is there, and whether the van has
/// been sitting still long enough that it is probably time to confirm.
class ArrivalPrompt {
  final TripStop stop;
  final List<RiderInfo> riders;
  final bool suggested;
  const ArrivalPrompt(this.stop, this.riders, {this.suggested = false});
}

/// Everything the controller does to the outside world.
///
/// Firestore, push and the legacy tracking screens in production; a
/// recorder in the tests, which is what lets a whole A-B-C round be driven
/// in a unit test.
abstract class TripBackend {
  Future<void> createTrip(Trip trip, List<Student> manifest);
  Future<void> saveProgress(
    String tripId, {
    required List<TripStop> stops,
    required TripRoutePlan? route,
    required TripPhase phase,
  });
  Future<void> markAttendance(
    String tripId,
    String studentId,
    AttendanceStatus status,
  );
  Future<Map<String, AttendanceStatus>> fetchAttendance(String tripId);
  Future<void> completeTrip(String tripId);
  void notifyFamily(RiderInfo rider, FamilyEvent event, TripLegKind leg);
}

/// What a driver's Start Route needs to know.
class TripStartRequest {
  final String driverId;
  final String busId;
  final String routeId;
  final String scheduleId;

  /// The direction the driver chose: home → institute, or back.
  final TripLegKind leg;
  final List<Student> riders;
  final GeoCoord origin;

  /// The institute for a child with no institute pin of their own: where
  /// the morning ends, and where the ride home starts.
  final GeoCoord? destination;

  const TripStartRequest({
    required this.driverId,
    required this.busId,
    required this.routeId,
    required this.scheduleId,
    required this.leg,
    required this.riders,
    required this.origin,
    this.destination,
  });
}

/// The driver's round, from Start Route to the last stop.
///
/// Owns the order of the stops, the route being followed, where the van is
/// on it, and what happens at each stop. Screens read it and call its
/// actions; nothing about the trip is decided inside a widget.
///
/// Google is asked for a route only when something has changed what the
/// route should be: the trip starting, a stop being resolved, the van
/// leaving the line, and a refresh every [etaRefresh] so the minutes stay
/// honest in traffic. Never per GPS fix — a round of ten stops costs about
/// fifteen requests, not the thousands a per-fix refresh would.
class TripController extends ChangeNotifier {
  TripController({
    required this.optimizer,
    required this.backend,
    DateTime Function()? clock,
    this.arrivalRadiusMeters = 100,
    this.groupRadiusMeters = 30,
    this.offRouteMeters = 50,
    this.offRouteFixes = 3,
    this.offRouteCooldown = const Duration(seconds: 30),
    this.etaRefresh = const Duration(minutes: 2, seconds: 30),
    this.dwellBeforeSuggest = const Duration(seconds: 20),
    this.dwellPerStop = const Duration(seconds: 45),
    this.nearbyLead = const Duration(minutes: 5),
    this.instituteGroupMeters = 150,
  }) : _now = clock ?? DateTime.now;

  final RouteOptimizer optimizer;
  final TripBackend backend;
  final DateTime Function() _now;

  final double arrivalRadiusMeters;
  final double groupRadiusMeters;
  final double offRouteMeters;
  final int offRouteFixes;
  final Duration offRouteCooldown;
  final Duration etaRefresh;
  final Duration dwellBeforeSuggest;

  /// Time a pickup or drop-off takes, added to every later stop's ETA.
  final Duration dwellPerStop;

  /// Institute pins within this of each other are one drop: two children's
  /// pins on the same campus are rarely the same spot.
  final double instituteGroupMeters;

  /// How long before the van reaches a pickup its family is told to be
  /// ready. Sent once per stop, by push, so it reaches a phone whose app is
  /// closed.
  final Duration nearbyLead;

  // ── State ────────────────────────────────────────────────────────────────

  Trip? _trip;
  TripLegKind _leg = TripLegKind.pickup;
  TripPhase _phase = TripPhase.enRoute;
  List<TripStop> _stops = const [];
  final Map<String, RiderInfo> _riders = {};
  final Map<String, AttendanceStatus> _marks = {};

  /// Children with a gate on this leg — the ones the van is out for.
  final Set<String> _onRoute = {};

  /// Children their family has kept home today. Left unmarked — only the
  /// driver marks anyone — but the van does not go for them.
  final Set<String> _offToday = {};

  /// The road ahead as last planned: `_legs[i]` ends at the i-th open stop.
  List<PlannedLeg> _legs = const [];
  List<GeoCoord> _line = const [];

  /// Metres along [_line] at which each leg ends.
  List<double> _legEnds = const [];
  DateTime? _plannedAt;
  bool _approximate = false;
  String? _warning;

  GeoCoord? _position;
  double _heading = 0;
  double _speedKmh = 0;
  PolylineProjection? _progress;

  int _offRouteCount = 0;
  DateTime? _lastOffRouteReplan;
  DateTime? _slowSince;
  bool _suggest = false;
  bool _completed = false;

  bool _planning = false;
  bool? _queuedOptimize;
  Future<void>? _planFuture;

  Trip? get trip => _trip;
  TripLegKind get leg => _leg;
  TripPhase get phase => _phase;
  bool get isRunning => _trip != null && !_completed;
  bool get isCompleted => _completed;
  bool get isPlanning => _planning;
  bool get isApproximate => _approximate;
  String? get warning => _warning;
  GeoCoord? get position => _position;
  double get heading => _heading;
  double get speedKmh => _speedKmh;
  List<TripStop> get stops => List.unmodifiable(_stops);
  RiderInfo? rider(String id) => _riders[id];
  AttendanceStatus markFor(String studentId) =>
      _marks[studentId] ?? AttendanceStatus.pending;

  /// Kept home by their family today.
  bool isOffToday(String studentId) => _offToday.contains(studentId);
  DateTime? get plannedAt => _plannedAt;

  /// Stops still to visit, in order, destination last.
  List<TripStop> get openStops => [
    for (final s in _stops)
      if (s.isOpen) s,
  ];

  /// The stop the van is heading for.
  TripStop? get nextStop {
    for (final s in _stops) {
      if (s.isOpen) return s;
    }
    return null;
  }

  /// Children counted aboard right now.
  List<RiderInfo> get onBoard => [
    for (final e in _marks.entries)
      if (e.value == AttendanceStatus.boarded && _riders[e.key] != null)
        _riders[e.key]!,
  ];

  /// What an institute stop is called: the institute's own name, as the
  /// families gave it — never the children's names, which read like a home.
  String instituteName(TripStop s) {
    final names = <String>{
      for (final r in ridersAt(s))
        if (r.school.isNotEmpty) r.school,
    };
    return names.isEmpty ? 'Institute' : names.join(' / ');
  }

  List<RiderInfo> ridersAt(TripStop stop) => [
    for (final id in stop.studentIds)
      if (_riders[id] != null) _riders[id]!,
  ];

  /// Set while the van is inside the arrival radius of the stop it is
  /// heading for, and that stop still has someone to mark.
  ArrivalPrompt? get arrival {
    final next = nextStop;
    if (next == null || !asksDriverAt(next)) return null;
    if (next.status != TripStopStatus.arriving) return null;
    final waiting = _waitingAt(next);
    if (waiting.isEmpty) return null;
    return ArrivalPrompt(next, waiting, suggested: _suggest);
  }

  /// Where children get on: their gate in the morning, their institute on
  /// the way home.
  bool isBoardingStop(TripStop s) => _leg == TripLegKind.pickup
      ? s.kind == TripStopKind.pickup
      : s.kind == TripStopKind.institute;

  /// Where the driver confirms each child by hand: every boarding stop, and
  /// each home on the way back. Institutes in the morning hand children
  /// over by themselves.
  bool asksDriverAt(TripStop s) =>
      isBoardingStop(s) || (_leg == TripLegKind.dropoff && s.isChildStop);

  /// The mark a child has at [s] until the driver acts there: not yet on
  /// the van where they board, aboard where they get off.
  AttendanceStatus _awaitedAt(TripStop s) =>
      isBoardingStop(s) ? AttendanceStatus.pending : AttendanceStatus.boarded;

  /// Still to be carried: aboard, or on the route and not yet collected.
  bool _active(String id) {
    final mark = markFor(id);
    if (mark == AttendanceStatus.boarded) return true;
    return mark == AttendanceStatus.pending &&
        _onRoute.contains(id) &&
        !_offToday.contains(id);
  }

  /// The children at [s] the driver still has to mark.
  List<RiderInfo> _waitingAt(TripStop s) => [
    for (final r in ridersAt(s))
      if (markFor(r.id) == _awaitedAt(s) && _active(r.id)) r,
  ];

  // ── Drawing ──────────────────────────────────────────────────────────────

  /// The whole road still ahead, starting where the van is.
  List<GeoCoord> get remainingLine {
    final p = _progress;
    if (_line.length < 2) return _line;
    return p == null ? _line : GeoUtils.ahead(_line, p);
  }

  /// The road already driven since the last plan.
  List<GeoCoord> get travelledLine {
    final p = _progress;
    if (p == null || _line.length < 2) return const [];
    return GeoUtils.behind(_line, p);
  }

  /// The van to the stop it is heading for.
  List<GeoCoord> get currentLegLine {
    if (_legs.isEmpty) return const [];
    final p = _progress;
    final first = _legs.first.points;
    if (p == null || first.length < 2) return first;
    final legProjection = GeoUtils.project(p.point, first);
    return legProjection == null ? first : GeoUtils.ahead(first, legProjection);
  }

  // ── Live figures ─────────────────────────────────────────────────────────

  double get _along => _progress?.alongMeters ?? 0;

  /// Road metres from the van to [stop], or null when it is not ahead.
  double? metersTo(TripStop stop) {
    final i = openStops.indexWhere((s) => s.id == stop.id);
    if (i < 0 || i >= _legEnds.length) return null;
    return math.max(0, _legEnds[i] - _along);
  }

  /// Seconds from now to [stop]: the planned time scaled by how much of the
  /// distance is left, plus a stop's dwell for each stop before it.
  int? secondsTo(TripStop stop) {
    final i = openStops.indexWhere((s) => s.id == stop.id);
    if (i < 0 || i >= _legs.length) return null;
    var plannedMeters = 0.0;
    var plannedSeconds = 0.0;
    for (var k = 0; k <= i; k++) {
      plannedMeters += _legs[k].meters;
      plannedSeconds += _legs[k].seconds;
    }
    final left = metersTo(stop) ?? 0;
    final lineMeters = i < _legEnds.length ? _legEnds[i] : plannedMeters;
    final share = lineMeters <= 0 ? 0.0 : (left / lineMeters).clamp(0.0, 1.0);
    return (plannedSeconds * share + dwellPerStop.inSeconds * i).round();
  }

  /// Seconds to the end of the leg.
  int? get secondsToEnd {
    final open = openStops;
    return open.isEmpty ? null : secondsTo(open.last);
  }

  double? get metersToEnd {
    final open = openStops;
    return open.isEmpty ? null : metersTo(open.last);
  }

  // ── Start / resume ───────────────────────────────────────────────────────

  /// Opens a trip: decides who rides, groups shared pins into one stop, asks
  /// for the best order from where the van is now, and writes it all in one
  /// go so a family's map has the route from the first second.
  ///
  /// Returns the trip, or throws [StateError] with a sentence for the
  /// driver when there is nobody to collect.
  Future<Trip> start(TripStartRequest req, {required String tripId}) async {
    final today = Trip.dateKeyFor(_now());
    _reset();
    _leg = req.leg;
    _position = req.origin;

    // Nobody is marked at the start, either way round: the driver marks
    // each child as they get on. A child the family has kept home is left
    // unmarked too — the van simply does not go for them.
    final riding = <Student>[];
    for (final s in req.riders) {
      _riders[s.id] = RiderInfo.fromStudent(s);
      _marks[s.id] = AttendanceStatus.pending;
      if (s.isAbsentOn(today)) {
        _offToday.add(s.id);
      } else {
        riding.add(s);
      }
    }

    final routable = [
      for (final s in riding)
        if (s.pickupLocation != null) s,
    ];
    if (routable.isEmpty) {
      throw StateError(
        riding.isEmpty
            ? 'Everyone on this round is marked absent today.'
            : 'None of the students on this round has a home pin set.',
      );
    }
    _onRoute.addAll(routable.map((s) => s.id));
    final riders = [for (final s in routable) _riders[s.id]!];

    final List<TripStop> stops;
    if (req.leg == TripLegKind.pickup) {
      // Home → institute: every gate, then each child's own institute.
      final gates = groupIntoStops(
        riders,
        kind: TripStopKind.pickup,
        radiusMeters: groupRadiusMeters,
      );
      stops = [
        ...gates,
        ...instituteStops(
          riders,
          fallback: req.destination,
          from: gates,
          radiusMeters: instituteGroupMeters,
        ),
      ];
    } else {
      // Institute → home: the institute(s) the children are collected from
      // first, then every home. The round ends at the last home.
      stops = [
        ...boardingStops(
          riders,
          fallback: req.destination ?? req.origin,
          start: req.origin,
          radiusMeters: instituteGroupMeters,
        ),
        ...groupIntoStops(
          riders,
          kind: TripStopKind.drop,
          radiusMeters: groupRadiusMeters,
        ),
      ];
    }
    _stops = stops;

    await _plan(optimize: true, persist: false);

    final trip = Trip(
      id: tripId,
      routeId: req.routeId,
      busId: req.busId,
      driverId: req.driverId,
      dateKey: today,
      type: req.leg == TripLegKind.pickup
          ? TripType.morning
          : TripType.afternoon,
      status: TripStatus.inProgress,
      startedAt: _now(),
      studentsExpected: req.riders.length,
      scheduleId: req.scheduleId,
      stops: _stops,
      route: _routePlan(),
      riderIds: [for (final s in req.riders) s.id],
    );
    _trip = trip;
    await backend.createTrip(trip, req.riders);

    // The first pickup can already be minutes away when the round starts.
    if (_flagNearby()) unawaited(_persist());
    notifyListeners();
    return trip;
  }

  /// Picks a running trip back up after the app was closed: the stops, their
  /// order and the last route from the trip document, who was marked from
  /// the attendance rows, and a fresh route from wherever the van is now.
  Future<void> resume(
    Trip trip, {
    required List<Student> roster,
    GeoCoord? position,
  }) async {
    if (_trip?.id == trip.id) return;
    _reset();
    _trip = trip;
    _leg = trip.type == TripType.morning
        ? TripLegKind.pickup
        : TripLegKind.dropoff;
    _phase = trip.phase;
    _position = position;
    for (final s in roster) {
      _riders[s.id] = RiderInfo.fromStudent(s);
    }
    try {
      _marks.addAll(await backend.fetchAttendance(trip.id));
    } catch (e) {
      debugPrint('trip resume: attendance unavailable — $e');
    }
    final today = Trip.dateKeyFor(_now());
    for (final s in roster) {
      if (s.isAbsentOn(today) && markFor(s.id) == AttendanceStatus.pending) {
        _offToday.add(s.id);
      }
    }

    if (trip.stops.isNotEmpty) {
      _stops = List.of(trip.stops);
      for (final st in _stops) {
        if (st.isChildStop) _onRoute.addAll(st.studentIds);
      }
      final route = trip.route;
      if (route != null && route.legs.isNotEmpty) {
        _applyLegs([
          for (final l in route.legs)
            PlannedLeg(
              meters: l.distanceMeters,
              seconds: l.durationSeconds,
              points: GeoUtils.decodePolyline(l.encodedPolyline),
            ),
        ], at: route.computedAt ?? _now());
        _approximate = route.approximate;
      }
    } else {
      // A trip opened by an older build has no stop list. Build one from
      // the roster so the round can still be driven.
      final riders = [
        for (final s in roster)
          if (s.pickupLocation != null &&
              markFor(s.id) != AttendanceStatus.absent)
            _riders[s.id]!,
      ];
      _stops = groupIntoStops(
        riders,
        kind: _leg == TripLegKind.pickup
            ? TripStopKind.pickup
            : TripStopKind.drop,
        radiusMeters: groupRadiusMeters,
      );
      _onRoute.addAll(riders.map((r) => r.id));
    }
    notifyListeners();
    if (position != null && _phase == TripPhase.enRoute) {
      await _plan(optimize: false);
    }
  }

  void _reset() {
    _trip = null;
    _phase = TripPhase.enRoute;
    _stops = const [];
    _riders.clear();
    _marks.clear();
    _onRoute.clear();
    _offToday.clear();
    _legs = const [];
    _line = const [];
    _legEnds = const [];
    _plannedAt = null;
    _approximate = false;
    _warning = null;
    _progress = null;
    _offRouteCount = 0;
    _lastOffRouteReplan = null;
    _slowSince = null;
    _suggest = false;
    _completed = false;
    _queuedOptimize = null;
  }

  /// Forgets the round. Called when the driver closes it.
  void clear() {
    _reset();
    _position = null;
    notifyListeners();
  }

  // ── GPS ──────────────────────────────────────────────────────────────────

  /// Every accepted fix. Cheap: geometry only, and Google is asked for
  /// nothing unless the van has left the line or the refresh is due.
  void onFix(LocationFix fix) {
    if (!isRunning) return;
    final now = fix.at;
    _position = fix.coord;
    if (fix.heading != null) _heading = fix.heading!;
    _speedKmh = fix.speedKmh;

    if (_line.length >= 2) {
      final from = math.max(0, (_progress?.segment ?? 0) - 2);
      var p = GeoUtils.project(fix.coord, _line, fromSegment: from);
      // Far from everything ahead: match against the whole line in case the
      // van went round a block and came back on to an earlier stretch.
      if (p != null && p.offsetMeters > offRouteMeters * 4 && from > 0) {
        final whole = GeoUtils.project(fix.coord, _line);
        if (whole != null && whole.offsetMeters < p.offsetMeters) p = whole;
      }
      _progress = p;

      if (p != null && p.offsetMeters > offRouteMeters) {
        _offRouteCount++;
      } else {
        _offRouteCount = 0;
      }
      final last = _lastOffRouteReplan;
      final cooled = last == null || now.difference(last) >= offRouteCooldown;
      if (_offRouteCount >= offRouteFixes && cooled && !_planning) {
        _lastOffRouteReplan = now;
        _offRouteCount = 0;
        unawaited(_plan(optimize: false));
      }
    }

    _checkArrival(fix);
    if (_flagNearby()) unawaited(_persist());

    final planned = _plannedAt;
    if (planned != null &&
        !_planning &&
        _phase == TripPhase.enRoute &&
        now.difference(planned) >= etaRefresh) {
      unawaited(_plan(optimize: false));
    }
    notifyListeners();
  }

  void _checkArrival(LocationFix fix) {
    final next = nextStop;
    if (next == null) return;
    final d = GeoUtils.distance(fix.coord, next.location);
    if (d > arrivalRadiusMeters) {
      _slowSince = null;
      _suggest = false;
      return;
    }

    // Morning institutes hand their children over on their own.
    if (_leg == TripLegKind.pickup && next.isInstitute) {
      unawaited(_arriveAtInstitute(next));
      return;
    }

    if (next.status == TripStopStatus.pending) {
      _replaceStop(next.copyWith(status: TripStopStatus.arriving));
      // Families hear "the van is at your gate" and "almost home" — not the
      // van reaching school on the way back, where the child already is.
      final atInstitute = _leg == TripLegKind.dropoff && next.isInstitute;
      if (!atInstitute) {
        for (final r in _waitingAt(next)) {
          backend.notifyFamily(r, FamilyEvent.arriving, _leg);
        }
      }
      unawaited(_persist());
    }

    // Parked at the gate for a while: probably time to confirm. Only a
    // nudge — the driver still has to tap.
    if (fix.speedKmh < 5) {
      _slowSince ??= fix.at;
      _suggest = fix.at.difference(_slowSince!) >= dwellBeforeSuggest;
    } else {
      _slowSince = null;
      _suggest = false;
    }
  }

  /// Tells the family at every pickup the van will reach within
  /// [nearbyLead], once per stop. Returns whether any stop was flagged, so
  /// the caller can save it.
  bool _flagNearby() {
    if (_trip == null || _leg != TripLegKind.pickup) return false;
    var flagged = false;
    for (final s in openStops) {
      if (s.kind != TripStopKind.pickup ||
          s.nearbyAlerted ||
          s.status != TripStopStatus.pending) {
        continue;
      }
      final secs = secondsTo(s);
      if (secs == null || secs > nearbyLead.inSeconds) continue;
      _replaceStop(s.copyWith(nearbyAlerted: true));
      for (final r in _waitingAt(s)) {
        backend.notifyFamily(r, FamilyEvent.nearby, _leg);
      }
      flagged = true;
    }
    return flagged;
  }

  // ── Stop actions ─────────────────────────────────────────────────────────

  /// On the van: at their gate in the morning, at the institute on the way
  /// home. Only ever set by the driver.
  Future<void> markPresent(String studentId) =>
      _mark(studentId, AttendanceStatus.boarded);

  /// Not there at a pickup, or not on the van at a drop.
  Future<void> markAbsent(String studentId) =>
      _mark(studentId, AttendanceStatus.absent);

  /// Handed over at home.
  Future<void> markDropped(String studentId) =>
      _mark(studentId, AttendanceStatus.droppedOff);

  /// Passes a stop without stopping. Everyone there who has not been marked
  /// is recorded as not riding, so nobody is left reading "waiting".
  Future<void> skipStop(String stopId) async {
    final stop = _stops.where((s) => s.id == stopId).firstOrNull;
    if (stop == null || !stop.isOpen || !asksDriverAt(stop)) return;
    final trip = _trip;
    // Skipping is the driver's own call, so it is the driver marking them.
    for (final r in _waitingAt(stop)) {
      _marks[r.id] = AttendanceStatus.absent;
      if (trip != null) {
        unawaited(
          backend.markAttendance(trip.id, r.id, AttendanceStatus.absent),
        );
      }
      backend.notifyFamily(r, FamilyEvent.absent, _leg);
    }
    _replaceStop(stop.copyWith(status: TripStopStatus.skipped, clearEta: true));
    await _afterStopResolved();
  }

  Future<void> _mark(String studentId, AttendanceStatus status) async {
    final trip = _trip;
    if (trip == null || !isRunning) return;
    _marks[studentId] = status;
    final rider = _riders[studentId];
    notifyListeners();

    unawaited(backend.markAttendance(trip.id, studentId, status));
    if (rider != null) {
      backend.notifyFamily(rider, switch (status) {
        AttendanceStatus.boarded => FamilyEvent.boarded,
        AttendanceStatus.droppedOff => FamilyEvent.droppedOff,
        _ => FamilyEvent.absent,
      }, _leg);
    }

    // The stop this mark belongs to: the first one still open where the
    // driver confirms this child — the institute before their home, on the
    // way back.
    final stop = _stops
        .where(
          (s) =>
              s.isOpen && asksDriverAt(s) && s.studentIds.contains(studentId),
        )
        .firstOrNull;
    if (stop == null) {
      // Marked from the attendance list with no stop of theirs left open.
      await _afterStopResolved(replan: false);
      return;
    }
    if (_waitingAt(stop).isNotEmpty) return;

    final nobodyRode = stop.studentIds.every(
      (id) => markFor(id) == AttendanceStatus.absent || _offToday.contains(id),
    );
    _replaceStop(
      stop.copyWith(
        status: nobodyRode ? TripStopStatus.skipped : TripStopStatus.done,
        clearEta: true,
      ),
    );
    await _afterStopResolved();
  }

  /// A stop just closed. Re-plan the rest from where the van is, or finish.
  ///
  /// The round ends by itself the moment nobody is left to carry: every
  /// child delivered, or every child marked absent — there is nobody to
  /// pick up or drop off, so there is nothing for the van to drive to.
  Future<void> _afterStopResolved({bool replan = true}) async {
    _slowSince = null;
    _suggest = false;
    _skipStopsNobodyNeeds();
    if (!_riders.keys.any(_active)) {
      await _complete();
      return;
    }
    if (openStops.isEmpty) {
      await _complete();
      return;
    }
    if (replan) await _plan(optimize: true);
  }

  /// Closes stops nobody still to be carried needs — a gate whose children
  /// were all marked absent, an institute none of whose children got on —
  /// so the van is not sent to them. Marks nobody.
  void _skipStopsNobodyNeeds() {
    for (final s in openStops) {
      if (s.studentIds.isEmpty) continue;
      if (s.studentIds.any(_active)) continue;
      _replaceStop(s.copyWith(status: TripStopStatus.skipped, clearEta: true));
    }
  }

  /// The family has said today is off, after the round was planned. The
  /// van stops going for their child. Their mark is left alone: only the
  /// driver marks anyone.
  Future<void> applyFamilyAbsences(Iterable<Student> roster) async {
    if (!isRunning) return;
    final today = Trip.dateKeyFor(_now());
    var changed = false;
    for (final s in roster) {
      if (!s.isAbsentOn(today)) continue;
      if (markFor(s.id) != AttendanceStatus.pending) continue;
      changed = _offToday.add(s.id) || changed;
    }
    if (changed) {
      await _afterStopResolved();
    } else {
      notifyListeners();
    }
  }

  /// The van is at an institute on the way to the destination: the children
  /// who study here get off, their families are told, and the round goes on.
  Future<void> _arriveAtInstitute(TripStop stop) async {
    if (!stop.isOpen) return;
    final trip = _trip;
    for (final id in stop.studentIds) {
      if (_marks[id] != AttendanceStatus.boarded) continue;
      _marks[id] = AttendanceStatus.droppedOff;
      if (trip != null) {
        unawaited(
          backend.markAttendance(trip.id, id, AttendanceStatus.droppedOff),
        );
      }
      final r = _riders[id];
      if (r != null) {
        backend.notifyFamily(r, FamilyEvent.reachedInstitute, _leg);
      }
    }
    if (stop.isDestination) {
      _phase = TripPhase.arrivedInstitute;
      // Anyone aboard with no institute stop of their own gets off at the
      // last one.
      for (final e in _marks.entries.toList()) {
        if (e.value != AttendanceStatus.boarded) continue;
        _marks[e.key] = AttendanceStatus.droppedOff;
        if (trip != null) {
          unawaited(
            backend.markAttendance(trip.id, e.key, AttendanceStatus.droppedOff),
          );
        }
        final r = _riders[e.key];
        if (r != null) {
          backend.notifyFamily(r, FamilyEvent.reachedInstitute, _leg);
        }
      }
    }
    _replaceStop(stop.copyWith(status: TripStopStatus.done, clearEta: true));
    await _afterStopResolved();
  }

  Future<void> _complete() async {
    if (_completed) return;
    _completed = true;
    _legs = const [];
    _line = const [];
    _legEnds = const [];
    _progress = null;
    notifyListeners();
    await _persist();
    final trip = _trip;
    if (trip != null) await backend.completeTrip(trip.id);
  }

  void _replaceStop(TripStop updated) {
    _stops = [for (final s in _stops) s.id == updated.id ? updated : s];
    notifyListeners();
  }

  // ── Planning ─────────────────────────────────────────────────────────────

  /// Asks for a route through the open stops from where the van is.
  ///
  /// One at a time: a second request while one is in flight is folded into
  /// a single follow-up, so a burst of three stop marks costs two requests,
  /// not three overlapping ones racing to be applied last.
  Future<void> _plan({required bool optimize, bool persist = true}) {
    if (_planning) {
      _queuedOptimize = (_queuedOptimize ?? false) || optimize;
      return _planFuture ?? Future.value();
    }
    _planFuture = _runPlan(optimize: optimize, persist: persist);
    return _planFuture!;
  }

  Future<void> _runPlan({required bool optimize, required bool persist}) async {
    _planning = true;
    notifyListeners();
    try {
      final origin = _position;
      final open = openStops;
      final institutes = [
        for (final s in open)
          if (s.kind == TripStopKind.institute) s,
      ];
      final applied = origin != null && institutes.isNotEmpty
          ? await _planWithInstitutes(
              origin,
              optimize: optimize,
              persist: persist,
            )
          : await _planDirect(
              origin,
              open,
              optimize: optimize,
              persist: persist,
            );
      if (!applied) return;
    } finally {
      _planning = false;
      notifyListeners();
    }
    if (persist) await _persist();

    final queued = _queuedOptimize;
    if (queued != null) {
      _queuedOptimize = null;
      await _plan(optimize: queued);
    }
  }

  /// The usual round: every open stop optimised from the van to the end of
  /// the leg in one request. Returns false when nothing was planned.
  Future<bool> _planDirect(
    GeoCoord? origin,
    List<TripStop> open, {
    required bool optimize,
    required bool persist,
  }) async {
    final destination = open.where((s) => s.isDestination).firstOrNull;
    final childStops = [
      for (final s in open)
        if (!s.isDestination) s,
    ];
    if (origin == null || (childStops.isEmpty && destination == null)) {
      return false;
    }

    // Never reorder away from a stop the van is already pulling up to.
    final pinned =
        childStops.isNotEmpty &&
        childStops.first.status == TripStopStatus.arriving;
    final result = await optimizer.plan(
      origin: origin,
      destination: destination?.location,
      stops: [for (final s in childStops) PlanStop(s.id, s.location)],
      optimize: optimize && !pinned,
    );
    if (_trip == null && persist) return false; // cleared while waiting

    final byId = {for (final s in childStops) s.id: s};
    final ordered = <TripStop>[
      for (final id in result.order)
        if (byId[id] != null) byId[id]!,
    ];
    // Anything the optimiser did not mention keeps its place at the end.
    for (final s in childStops) {
      if (!ordered.contains(s)) ordered.add(s);
    }
    if (destination != null) ordered.add(destination);

    final closed = [
      for (final s in _stops)
        if (!s.isOpen) s,
    ];
    var n = closed.length;
    _stops = [...closed, for (final s in ordered) s.copyWith(order: ++n)];
    _approximate = result.approximate;
    _warning = result.warning;
    _applyLegs(result.legs, at: _now());
    _stampEtas();
    _flagNearby();
    return true;
  }

  /// A morning round dropping at more than one institute.
  ///
  /// Every child is collected before anyone is set down — Google's optimiser
  /// knows nothing of "pick up before drop off", so the two are planned
  /// apart: the pickups optimised from the van to the first institute, then
  /// the institutes in the order fixed when the round started, ending at the
  /// destination. Two requests instead of one, only for these rounds.
  Future<bool> _planWithInstitutes(
    GeoCoord origin, {
    required bool optimize,
    required bool persist,
  }) async {
    if (_leg == TripLegKind.dropoff) {
      return _planFromInstitutes(origin, optimize: optimize, persist: persist);
    }
    final open = openStops;
    final gates = [
      for (final s in open)
        if (s.isChildStop) s,
    ];
    final tail = [
      for (final s in open)
        if (s.isInstitute) s,
    ];
    final pinned =
        gates.isNotEmpty && gates.first.status == TripStopStatus.arriving;

    final ordered = <TripStop>[];
    final legs = <PlannedLeg>[];
    var approximate = false;
    String? warning;

    if (gates.isNotEmpty) {
      final first = await optimizer.plan(
        origin: origin,
        destination: tail.first.location,
        stops: [for (final s in gates) PlanStop(s.id, s.location)],
        optimize: optimize && !pinned,
      );
      final byId = {for (final s in gates) s.id: s};
      ordered.addAll([
        for (final id in first.order)
          if (byId[id] != null) byId[id]!,
      ]);
      for (final s in gates) {
        if (!ordered.contains(s)) ordered.add(s);
      }
      legs.addAll(first.legs);
      approximate = first.approximate;
      warning = first.warning;
      if (tail.length > 1) {
        final rest = await optimizer.plan(
          origin: tail.first.location,
          destination: tail.last.location,
          stops: [
            for (final s in tail.sublist(1, tail.length - 1))
              PlanStop(s.id, s.location),
          ],
          optimize: false,
        );
        legs.addAll(rest.legs);
        approximate = approximate || rest.approximate;
        warning ??= rest.warning;
      }
      ordered.addAll(tail);
    } else {
      final rest = await optimizer.plan(
        origin: origin,
        destination: tail.last.location,
        stops: [
          for (final s in tail.sublist(0, tail.length - 1))
            PlanStop(s.id, s.location),
        ],
        optimize: false,
      );
      ordered.addAll(tail);
      legs.addAll(rest.legs);
      approximate = rest.approximate;
      warning = rest.warning;
    }
    if (_trip == null && persist) return false; // cleared while waiting

    final closed = [
      for (final s in _stops)
        if (!s.isOpen) s,
    ];
    var n = closed.length;
    _stops = [...closed, for (final s in ordered) s.copyWith(order: ++n)];
    _approximate = approximate;
    _warning = warning;
    _applyLegs(legs, at: _now());
    _stampEtas();
    _flagNearby();
    return true;
  }

  /// The way home: the institutes the children are collected from, in the
  /// order fixed at the start, then every home — optimised from the last
  /// institute, ending at whichever home is best last.
  Future<bool> _planFromInstitutes(
    GeoCoord origin, {
    required bool optimize,
    required bool persist,
  }) async {
    final open = openStops;
    final head = [
      for (final s in open)
        if (s.kind == TripStopKind.institute) s,
    ];
    final homes = [
      for (final s in open)
        if (s.isChildStop) s,
    ];
    final ordered = <TripStop>[...head];
    final legs = <PlannedLeg>[];

    final toInstitutes = await optimizer.plan(
      origin: origin,
      destination: head.last.location,
      stops: [
        for (final s in head.sublist(0, head.length - 1))
          PlanStop(s.id, s.location),
      ],
      optimize: false,
    );
    legs.addAll(toInstitutes.legs);
    var approximate = toInstitutes.approximate;
    var warning = toInstitutes.warning;

    if (homes.isNotEmpty) {
      final toHomes = await optimizer.plan(
        origin: head.last.location,
        stops: [for (final s in homes) PlanStop(s.id, s.location)],
        optimize: optimize,
      );
      final byId = {for (final s in homes) s.id: s};
      ordered.addAll([
        for (final id in toHomes.order)
          if (byId[id] != null) byId[id]!,
      ]);
      for (final s in homes) {
        if (!ordered.contains(s)) ordered.add(s);
      }
      legs.addAll(toHomes.legs);
      approximate = approximate || toHomes.approximate;
      warning ??= toHomes.warning;
    }
    if (_trip == null && persist) return false; // cleared while waiting

    final closed = [
      for (final s in _stops)
        if (!s.isOpen) s,
    ];
    var n = closed.length;
    _stops = [...closed, for (final s in ordered) s.copyWith(order: ++n)];
    _approximate = approximate;
    _warning = warning;
    _applyLegs(legs, at: _now());
    _stampEtas();
    return true;
  }

  void _applyLegs(List<PlannedLeg> legs, {required DateTime at}) {
    _legs = legs;
    _line = [
      for (var i = 0; i < legs.length; i++)
        ...(i == 0 ? legs[i].points : legs[i].points.skip(1)),
    ];
    final ends = <double>[];
    var along = 0.0;
    for (final l in legs) {
      along += GeoUtils.length(l.points);
      ends.add(along);
    }
    _legEnds = ends;
    _plannedAt = at;
    _offRouteCount = 0;
    final pos = _position;
    _progress = pos == null ? null : GeoUtils.project(pos, _line);
  }

  /// Writes each open stop's ETA and distance as absolute times, for the
  /// families' screens to count down from.
  void _stampEtas() {
    final now = _now();
    _stops = [
      for (final s in _stops)
        if (!s.isOpen)
          s
        else
          () {
            final secs = secondsTo(s);
            final meters = metersTo(s);
            return s.copyWith(
              etaAt: secs == null ? null : now.add(Duration(seconds: secs)),
              distanceMeters: meters?.round(),
            );
          }(),
    ];
  }

  TripRoutePlan _routePlan() => TripRoutePlan(
    legs: [
      for (final l in _legs)
        TripRouteLeg(
          distanceMeters: l.meters,
          durationSeconds: l.seconds,
          encodedPolyline: GeoUtils.encodePolyline(l.points),
        ),
    ],
    totalDistanceMeters: _legs.fold(0, (s, l) => s + l.meters),
    totalDurationSeconds: _legs.fold(0, (s, l) => s + l.seconds),
    computedAt: _plannedAt,
    approximate: _approximate,
  );

  Future<void> _persist() async {
    final trip = _trip;
    if (trip == null) return;
    try {
      await backend.saveProgress(
        trip.id,
        stops: _stops,
        route: _legs.isEmpty ? null : _routePlan(),
        phase: _phase,
      );
    } catch (e) {
      // Firestore queues the write offline and retries it; a failure here
      // is not a reason to stop the round.
      debugPrint('trip progress not saved yet — $e');
    }
  }

  // ── Stop grouping ────────────────────────────────────────────────────────

  /// The institutes a morning round sets children down at, one stop per
  /// campus, each naming the children who get off there.
  ///
  /// Every child goes to their own institute pin; a child without one goes
  /// wherever [fallback] says the round ends. Visited nearest-first from
  /// where the pickups are, the farthest last as the round's destination.
  static List<TripStop> instituteStops(
    List<RiderInfo> riders, {
    required GeoCoord? fallback,
    required List<TripStop> from,
    double radiusMeters = 150,
  }) {
    final groups = <(GeoCoord, List<String>)>[];
    for (final r in riders) {
      final at = r.institute ?? fallback;
      if (at == null) continue;
      final i = groups.indexWhere(
        (g) => GeoUtils.distance(g.$1, at) <= radiusMeters,
      );
      if (i >= 0) {
        groups[i] = (groups[i].$1, [...groups[i].$2, r.id]);
      } else {
        groups.add((at, [r.id]));
      }
    }
    if (groups.isEmpty) {
      return fallback == null
          ? const []
          : [
              TripStop(
                id: 'destination',
                location: fallback,
                kind: TripStopKind.destination,
              ),
            ];
    }

    // Nearest-first from the middle of the pickups.
    var here = _centroid([for (final s in from) s.location]) ?? groups.first.$1;
    final left = [...groups];
    final ordered = <(GeoCoord, List<String>)>[];
    while (left.isNotEmpty) {
      left.sort(
        (a, b) => GeoUtils.distance(
          here,
          a.$1,
        ).compareTo(GeoUtils.distance(here, b.$1)),
      );
      final next = left.removeAt(0);
      ordered.add(next);
      here = next.$1;
    }
    return [
      for (var i = 0; i < ordered.length; i++)
        TripStop(
          id: i == ordered.length - 1 ? 'destination' : 'institute-$i',
          location: ordered[i].$1,
          kind: i == ordered.length - 1
              ? TripStopKind.destination
              : TripStopKind.institute,
          studentIds: ordered[i].$2,
        ),
    ];
  }

  /// Where the children are collected on the way home: one stop per
  /// institute, each naming who boards there, nearest-first from where the
  /// van starts. A child with no institute pin boards at [fallback].
  static List<TripStop> boardingStops(
    List<RiderInfo> riders, {
    required GeoCoord fallback,
    required GeoCoord start,
    double radiusMeters = 150,
  }) {
    final groups = <(GeoCoord, List<String>)>[];
    for (final r in riders) {
      final at = r.institute ?? fallback;
      final i = groups.indexWhere(
        (g) => GeoUtils.distance(g.$1, at) <= radiusMeters,
      );
      if (i >= 0) {
        groups[i] = (groups[i].$1, [...groups[i].$2, r.id]);
      } else {
        groups.add((at, [r.id]));
      }
    }
    var here = start;
    final left = [...groups];
    final ordered = <(GeoCoord, List<String>)>[];
    while (left.isNotEmpty) {
      left.sort(
        (a, b) => GeoUtils.distance(
          here,
          a.$1,
        ).compareTo(GeoUtils.distance(here, b.$1)),
      );
      final next = left.removeAt(0);
      ordered.add(next);
      here = next.$1;
    }
    return [
      for (var i = 0; i < ordered.length; i++)
        TripStop(
          id: 'board-$i',
          location: ordered[i].$1,
          kind: TripStopKind.institute,
          studentIds: ordered[i].$2,
        ),
    ];
  }

  static GeoCoord? _centroid(List<GeoCoord> points) {
    if (points.isEmpty) return null;
    var lat = 0.0;
    var lng = 0.0;
    for (final p in points) {
      lat += p.lat;
      lng += p.lng;
    }
    return GeoCoord(lat / points.length, lng / points.length);
  }

  /// One stop per place: riders whose pins are within [radiusMeters] of a
  /// stop already made join it instead of making their own.
  static List<TripStop> groupIntoStops(
    List<RiderInfo> riders, {
    required TripStopKind kind,
    double radiusMeters = 30,
  }) {
    final stops = <TripStop>[];
    for (final r in riders) {
      final point = r.point;
      if (point == null) continue;
      final i = stops.indexWhere(
        (s) => GeoUtils.distance(s.location, point) <= radiusMeters,
      );
      if (i >= 0) {
        stops[i] = stops[i].copyWith(
          studentIds: [...stops[i].studentIds, r.id],
        );
      } else {
        stops.add(
          TripStop(
            id: 'stop-${r.id}',
            location: point,
            kind: kind,
            studentIds: [r.id],
          ),
        );
      }
    }
    return stops;
  }
}
