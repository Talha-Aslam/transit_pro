import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import '../data/trip_repository.dart';

/// Where a child is, right now, as far as the family is concerned.
///
/// Ordered from "nothing arranged" to "the ride is over", which is also the
/// order the UI colours them in.
enum RideStage {
  /// No driver has accepted this child yet.
  unassigned,

  /// The family has marked them off for today.
  absent,

  /// A ride is arranged for today and has not started, or has started
  /// without this child being marked aboard.
  scheduled,

  /// The van is inside the arrival radius of this child's stop — at the
  /// gate in the morning, at the door in the afternoon.
  arriving,

  /// The driver has marked them aboard.
  onTheBus,

  /// They have been handed over at the other end — at the institute in the
  /// morning, at home in the afternoon.
  reached,
}

/// [RideStage] plus what the badge should say.
///
/// Carries a translation *key* rather than a sentence, because the badge is
/// read by families who have the app in Urdu. [place] is the one variable
/// part — "Reached" on its own leaves a parent asking *reached where*, so
/// the institute's name is substituted into the key's `{place}`.
class ChildRideStatus {
  final RideStage stage;
  final String labelKey;
  final String? place;

  const ChildRideStatus(this.stage, this.labelKey, {this.place});

  static const unknown = ChildRideStatus(
    RideStage.unassigned,
    'status_no_driver',
  );
}

/// The single answer to "where is my child?", for every child a family has.
///
/// Four screens used to decide this for themselves, and the parent dashboard
/// decided it from whether the child had a driver *at all* — so a card read
/// "On the Bus" at nine at night, on a Sunday, and for a child whose driver
/// had ended the route an hour earlier. The only honest sources are the
/// driver's trip and the attendance they marked on it, and both of them live
/// in Firestore, so this watches them.
///
/// One subscription per driver, not per child: two siblings riding with the
/// same driver share a trip, and watching it twice would double the reads
/// for an identical answer.
/// How one leg of a child's day stands — the ride in, or the ride home.
enum TodayLeg {
  /// Not run yet today.
  upcoming,

  /// The van is out on this leg now.
  onTheWay,

  /// Ridden: collected and delivered.
  done,

  /// Off today, or recorded as not riding.
  absent,

  /// The leg ran but the driver recorded nothing for this child.
  unrecorded,
}

class ChildStatusService extends ChangeNotifier {
  ChildStatusService._();
  static final ChildStatusService instance = ChildStatusService._();

  /// Keyed by student id.
  final statuses = ValueNotifier<Map<String, ChildRideStatus>>({});

  final _tripSubs = <String, StreamSubscription<Trip?>>{};

  /// Keyed `tripId/studentId`: one row per child per trip.
  final _attendanceSubs = <String, StreamSubscription<AttendanceRecord?>>{};

  /// Live trip per driver id.
  final _trips = <String, Trip?>{};

  /// Attendance per trip id, by student.
  final _attendance = <String, Map<String, AttendanceStatus>>{};

  /// The trips each driver finished today, newest first, so "Reached"
  /// survives the trip ending — a parent should not watch the status fall
  /// back to "Scheduled" the moment the driver closes the route. All of
  /// them, not just the newest: with several rounds the newest may be a
  /// round this child is not on.
  final _lastFinished = <String, List<Trip>>{};
  final _historySubs = <String, StreamSubscription<List<Trip>>>{};

  List<Student> _children = const [];

  /// Points the service at [children]. Safe to call on every change of the
  /// family's roster; subscriptions for drivers nobody rides with any more
  /// are dropped, and existing ones are left alone.
  void watchChildren(List<Student> children) {
    _children = children;
    final wanted = {
      for (final c in children)
        if ((c.driverId ?? '').isNotEmpty) c.driverId!,
    };

    for (final driverId in _tripSubs.keys.toList()) {
      if (wanted.contains(driverId)) continue;
      _tripSubs.remove(driverId)?.cancel();
      _historySubs.remove(driverId)?.cancel();
      _trips.remove(driverId);
      _lastFinished.remove(driverId);
    }

    for (final driverId in wanted) {
      if (_tripSubs.containsKey(driverId)) continue;
      _tripSubs[driverId] = TripRepository.instance
          .watchActiveTripForDriver(driverId)
          .listen(
            (trip) => _onTrip(driverId, trip),
            onError: (Object e) => debugPrint('child status trip: $e'),
          );
      _historySubs[driverId] = TripRepository.instance
          .watchTripsForDriver(driverId, limit: 10)
          .listen(
            (trips) => _onHistory(driverId, trips),
            onError: (Object e) => debugPrint('child status history: $e'),
          );
    }

    _recompute();
  }

  void unbind() {
    for (final s in _tripSubs.values) {
      s.cancel();
    }
    for (final s in _attendanceSubs.values) {
      s.cancel();
    }
    for (final s in _historySubs.values) {
      s.cancel();
    }
    _tripSubs.clear();
    _attendanceSubs.clear();
    _historySubs.clear();
    _trips.clear();
    _attendance.clear();
    _lastFinished.clear();
    _children = const [];
    statuses.value = {};
  }

  void _onTrip(String driverId, Trip? trip) {
    _trips[driverId] = trip;
    if (trip != null) _watchAttendanceOn(trip);
    _recompute();
  }

  void _onHistory(String driverId, List<Trip> trips) {
    final today = todayKey();
    final finished =
        [
          for (final t in trips)
            if (t.dateKey == today &&
                t.status == TripStatus.completed &&
                _carriesAnyChild(t))
              t,
        ]..sort(
          (a, b) =>
              (b.endedAt ?? DateTime(0)).compareTo(a.endedAt ?? DateTime(0)),
        );
    if (finished.isEmpty) {
      _lastFinished.remove(driverId);
    } else {
      _lastFinished[driverId] = finished;
      // The attendance of a finished trip is what says whether this child
      // was on it; without it a completed afternoon run would read as
      // "reached" for a child who was off sick.
      finished.forEach(_watchAttendanceOn);
    }
    _recompute();
  }

  bool _carriesAnyChild(Trip trip) => _children.any((c) => trip.carries(c.id));

  /// Follows this family's own children's rows on [trip] — one document
  /// each. The whole `attendance` subcollection was watched before, which
  /// the rules refuse to anyone but the driver and an admin: a family's
  /// listener failed silently and no badge ever saw "boarded".
  void _watchAttendanceOn(Trip trip) {
    for (final child in _children) {
      if (!trip.carries(child.id)) continue;
      final key = '${trip.id}/${child.id}';
      if (_attendanceSubs.containsKey(key)) continue;
      _attendanceSubs[key] = TripRepository.instance
          .watchAttendanceForStudent(trip.id, child.id)
          .listen(
            (record) => _onAttendance(trip.id, child.id, record),
            onError: (Object e) => debugPrint('child status attendance: $e'),
          );
    }
  }

  void _onAttendance(String tripId, String childId, AttendanceRecord? record) {
    final marks = _attendance.putIfAbsent(tripId, () => {});
    if (record == null) {
      marks.remove(childId);
    } else {
      marks[childId] = record.status;
    }
    _recompute();
  }

  void _recompute() {
    final today = todayKey();
    final next = <String, ChildRideStatus>{};
    for (final child in _children) {
      next[child.id] = _statusFor(child, today);
    }
    statuses.value = next;
    notifyListeners();
  }

  ChildRideStatus _statusFor(Student child, String today) {
    final driverId = child.driverId ?? '';
    if (driverId.isEmpty) return ChildRideStatus.unknown;

    // The family's own word comes first. They know their child is at home
    // with a fever; nothing the driver does should overrule that.
    if (child.isAbsentOn(today)) {
      return const ChildRideStatus(RideStage.absent, 'status_off_today');
    }

    // The driver's running trip only counts if it is this child's round;
    // while another round is out, this child is simply not on the road yet.
    final running = _trips[driverId];
    final live = running != null && running.carries(child.id) ? running : null;
    if (live != null) {
      final mark = _attendance[live.id]?[child.id];
      switch (mark) {
        case AttendanceStatus.boarded:
          // On the ride home the child is aboard from the start, so "the van
          // is at your door" is the boarded child's arriving moment.
          if (live.type != TripType.morning && _vanAtStop(live, child)) {
            return const ChildRideStatus(
              RideStage.arriving,
              'status_almost_home',
            );
          }
          return ChildRideStatus(
            RideStage.onTheBus,
            live.type == TripType.morning
                ? 'status_on_the_bus'
                : 'status_heading_home',
          );
        case AttendanceStatus.droppedOff:
          return _reached(live, child);
        case AttendanceStatus.absent:
          return const ChildRideStatus(
            RideStage.absent,
            'status_marked_absent',
          );
        case AttendanceStatus.pending:
        case null:
          if (_vanAtStop(live, child)) {
            return const ChildRideStatus(
              RideStage.arriving,
              'status_bus_arriving',
            );
          }
          // Deliberately *not* "on the bus". The bus moving says nothing
          // about whether this particular child got on it, and a family
          // trusting that badge is the whole reason it has to be earned.
          return const ChildRideStatus(
            RideStage.scheduled,
            'status_waiting_to_board',
          );
      }
    }

    // No trip running. A ride that finished today stays "reached" until the
    // next one starts, rather than falling back to "scheduled" and looking
    // like the child is waiting for a bus that already brought them home.
    final finished = _lastFinished[driverId]
        ?.where((t) => t.carries(child.id))
        .firstOrNull;
    if (finished != null) {
      final mark = _attendance[finished.id]?[child.id];
      if (mark == AttendanceStatus.boarded ||
          mark == AttendanceStatus.droppedOff) {
        return _reached(finished, child);
      }
      if (mark == AttendanceStatus.absent) {
        return const ChildRideStatus(RideStage.absent, 'status_marked_absent');
      }
    }

    return const ChildRideStatus(RideStage.scheduled, 'status_scheduled');
  }

  /// How [studentId]'s ride in ([morning]) or ride home stands today, from
  /// the same trips and attendance the status badge reads.
  TodayLeg legToday(String studentId, {required bool morning}) {
    final child = _children.where((c) => c.id == studentId).firstOrNull;
    if (child == null) return TodayLeg.upcoming;
    if (child.isAbsentOn(todayKey())) return TodayLeg.absent;
    final driverId = child.driverId ?? '';
    bool isThisLeg(Trip t) =>
        (t.type == TripType.morning) == morning && t.carries(child.id);

    final live = _trips[driverId];
    if (live != null && isThisLeg(live)) {
      return switch (_attendance[live.id]?[child.id]) {
        AttendanceStatus.absent => TodayLeg.absent,
        AttendanceStatus.droppedOff => TodayLeg.done,
        _ => TodayLeg.onTheWay,
      };
    }
    for (final t in _lastFinished[driverId] ?? const <Trip>[]) {
      if (!isThisLeg(t)) continue;
      return switch (_attendance[t.id]?[child.id]) {
        AttendanceStatus.boarded ||
        AttendanceStatus.droppedOff => TodayLeg.done,
        AttendanceStatus.absent => TodayLeg.absent,
        _ => TodayLeg.unrecorded,
      };
    }
    return TodayLeg.upcoming;
  }

  /// Whether the driver's app has this child's stop as the one the van is
  /// pulling up to.
  bool _vanAtStop(Trip trip, Student child) =>
      trip.stopFor(child.id)?.status == TripStopStatus.arriving;

  /// "Reached" is not an answer on its own — reached *where*.
  ChildRideStatus _reached(Trip trip, Student child) {
    if (trip.type != TripType.morning) {
      return const ChildRideStatus(RideStage.reached, 'status_reached_home');
    }
    final place = child.school.trim();
    return place.isEmpty
        ? const ChildRideStatus(RideStage.reached, 'status_reached')
        : ChildRideStatus(
            RideStage.reached,
            'status_reached_place',
            place: place,
          );
  }

  /// `yyyy-MM-dd` for today, matching `Trip.dateKey`.
  static String todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
