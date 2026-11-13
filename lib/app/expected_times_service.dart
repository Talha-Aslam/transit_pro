import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import '../data/user_repository.dart';
import 'route_optimization_service.dart';
import 'session_service.dart';
import 'trip_controller.dart';

/// When the van can be expected at each booked child, morning and evening.
///
/// A round has one start time, but the children on it are collected one
/// after another, so "the round starts at 7:00" tells a family little. This
/// works out each child's own time on the driver's phone: the round's
/// homes in the order the route takes them (Google's optimiser, the same
/// one a live round uses), the drive between each, and a short stop at
/// every gate — added to the round's start time.
///
/// The answers are written to the driver's own document as
/// `expectedTimes`, which every family already follows live, so a seat
/// accepted on the driver's phone puts the time on the family's schedule
/// within moments. Re-worked whenever the roster, a child's pin or a
/// round's times change — not on a timer, so it costs a couple of route
/// requests per change, not per minute.
class ExpectedTimesService {
  ExpectedTimesService({RouteOptimizer? optimizer})
    : _optimizer = optimizer ?? GoogleRouteOptimizer.instance;

  static final ExpectedTimesService instance = ExpectedTimesService();

  final RouteOptimizer _optimizer;

  /// Time spent at each gate, matching what a live round allows.
  static const dwell = Duration(seconds: 45);

  /// Changes arrive in bursts — an accept moves the request, the seat count
  /// and the roster within a second — so the work waits for them to settle.
  static const _settle = Duration(seconds: 4);

  Timer? _debounce;
  String? _lastSignature;
  bool _bound = false;

  /// Starts following the signed-in driver's roster and rounds.
  void bindToDriver() {
    if (_bound) return;
    _bound = true;
    final session = SessionService.instance;
    session.roster.addListener(_onChanged);
    session.routeStudents.addListener(_onChanged);
    session.driver.addListener(_onChanged);
    _onChanged();
  }

  void unbind() {
    if (!_bound) return;
    _bound = false;
    final session = SessionService.instance;
    session.roster.removeListener(_onChanged);
    session.routeStudents.removeListener(_onChanged);
    session.driver.removeListener(_onChanged);
    _debounce?.cancel();
    _lastSignature = null;
  }

  void _onChanged() {
    final driver = SessionService.instance.driver.value;
    if (driver == null) return;
    final signature = _signature(driver, _roster());
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    _debounce?.cancel();
    _debounce = Timer(_settle, () => unawaited(recompute()));
  }

  List<Student> _roster() {
    final merged = <String, Student>{};
    for (final s in SessionService.instance.roster.value) {
      merged[s.id] = s;
    }
    for (final s in SessionService.instance.routeStudents.value) {
      merged.putIfAbsent(s.id, () => s);
    }
    return merged.values.toList();
  }

  /// Everything the times depend on, and nothing they produce — so writing
  /// the answer back to the driver's document does not set it off again.
  static String _signature(Driver d, List<Student> roster) {
    final rounds = [
      for (final r in d.orderedSchedules)
        '${r.id}:${r.pickupStart}:${r.dropoffStart}:${r.institutes.join(',')}',
    ];
    final kids = [
      for (final s in roster)
        '${s.id}:${s.scheduleId}:${s.pickupLocation?.lat}:'
            '${s.pickupLocation?.lng}:${s.dropoffLocation?.lat}',
    ]..sort();
    return '${d.baseLocation?.lat}:${d.baseLocation?.lng}|'
        '${rounds.join(';')}|${kids.join(';')}';
  }

  /// Works out every booked child's times and saves them.
  Future<void> recompute() async {
    final uid = SessionService.instance.uid;
    final driver = SessionService.instance.driver.value;
    if (uid == null || driver == null) return;
    final roster = _roster();
    final all = <String, ExpectedTimes>{};
    for (final round in driver.orderedSchedules) {
      final riders = [
        for (final s in roster)
          if (s.scheduleId == round.id) s,
      ];
      if (riders.isEmpty) continue;
      try {
        all.addAll(
          await forRound(
            round,
            riders,
            start: driver.baseLocation,
            institute: instituteFor(driver, round, riders),
          ),
        );
      } catch (e) {
        debugPrint('expected times for ${round.id} failed: $e');
      }
    }
    try {
      await UserRepository.instance.updateDriver(uid, {
        'expectedTimes': {
          for (final e in all.entries) e.key: e.value.toMap(),
        },
      });
    } catch (e) {
      debugPrint('saving expected times failed: $e');
    }
  }

  /// The institute a round runs to: one it names, then a child's own pin.
  static GeoCoord? instituteFor(
    Driver driver,
    DriverSchedule round,
    List<Student> riders,
  ) {
    for (final area in driver.serviceAreas) {
      if (area.location != null && round.serves(area.name)) {
        return area.location;
      }
    }
    for (final s in riders) {
      if (s.dropoffLocation != null) return s.dropoffLocation;
    }
    return null;
  }

  /// One round's times for each of [riders].
  ///
  /// Mornings run from [start] (the driver's base, when set) through every
  /// home to the institute, beginning at the round's pickup time. The way
  /// home runs from the institute through every home, beginning at its
  /// drop-off time.
  Future<Map<String, ExpectedTimes>> forRound(
    DriverSchedule round,
    List<Student> riders, {
    GeoCoord? start,
    GeoCoord? institute,
  }) async {
    final infos = [
      for (final s in riders)
        if (s.pickupLocation != null) RiderInfo.fromStudent(s),
    ];
    if (infos.isEmpty) return const {};
    final gates = TripController.groupIntoStops(
      infos,
      kind: TripStopKind.pickup,
    );
    final planStops = [for (final g in gates) PlanStop(g.id, g.location)];

    final pickup = <String, String>{};
    if (round.hasPickup) {
      final plan = await _optimizer.plan(
        origin: start ?? gates.first.location,
        destination: institute,
        stops: planStops,
      );
      pickup.addAll(_timesAlong(plan, gates, round.pickupStart));
    }
    final dropoff = <String, String>{};
    if (round.hasDropoff) {
      final plan = await _optimizer.plan(
        origin: institute ?? gates.first.location,
        stops: planStops,
      );
      dropoff.addAll(_timesAlong(plan, gates, round.dropoffStart));
    }
    return {
      for (final r in infos)
        r.id: ExpectedTimes(
          pickup: pickup[r.id] ?? '',
          dropoff: dropoff[r.id] ?? '',
          scheduleId: round.id,
        ),
    };
  }

  /// Each child's clock time along [plan], starting at [startHhmm].
  static Map<String, String> _timesAlong(
    RoutePlanResult plan,
    List<TripStop> gates,
    String startHhmm,
  ) {
    final start = _minutes(startHhmm);
    if (start == null) return const {};
    final byId = {for (final g in gates) g.id: g};
    final out = <String, String>{};
    var seconds = 0;
    for (var i = 0; i < plan.order.length; i++) {
      if (i < plan.legs.length) seconds += plan.legs[i].seconds;
      final gate = byId[plan.order[i]];
      if (gate == null) continue;
      final at = _hhmm(start + (seconds / 60).round());
      for (final id in gate.studentIds) {
        out[id] = at;
      }
      seconds += dwell.inSeconds;
    }
    return out;
  }

  static int? _minutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    return h == null || m == null ? null : h * 60 + m;
  }

  static String _hhmm(int minutes) {
    final m = minutes % (24 * 60);
    return '${(m ~/ 60).toString().padLeft(2, '0')}:'
        '${(m % 60).toString().padLeft(2, '0')}';
  }
}
