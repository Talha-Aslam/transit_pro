import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_pro/app/expected_times_service.dart';
import 'package:transit_pro/app/live_bus_service.dart';
import 'package:transit_pro/app/location_fix.dart';
import 'package:transit_pro/app/route_optimization_service.dart';
import 'package:transit_pro/app/trip_controller.dart';
import 'package:transit_pro/map/geo_utils.dart';

/// Nearest-first with straight lines, counted — Google's answer shape
/// without Google.
class FakeOptimizer implements RouteOptimizer {
  int calls = 0;
  final optimizeFlags = <bool>[];

  @override
  int get callCount => calls;

  @override
  Future<RoutePlanResult> plan({
    required GeoCoord origin,
    GeoCoord? destination,
    required List<PlanStop> stops,
    bool optimize = true,
  }) async {
    calls++;
    optimizeFlags.add(optimize);
    final r = GoogleRouteOptimizer.fallbackPlan(
      origin: origin,
      destination: destination,
      stops: stops,
      keepOrder: !optimize,
    );
    return RoutePlanResult(
      order: r.order,
      legs: r.legs,
      destination: r.destination,
    );
  }
}

class FakeBackend implements TripBackend {
  Trip? created;
  int saves = 0;
  TripPhase? lastPhase;
  List<TripStop> lastStops = const [];
  final marks = <String, AttendanceStatus>{};
  final events = <(String, FamilyEvent)>[];
  bool completed = false;

  @override
  Future<void> createTrip(Trip trip, List<Student> manifest) async {
    created = trip;
  }

  @override
  Future<void> saveProgress(
    String tripId, {
    required List<TripStop> stops,
    required TripRoutePlan? route,
    required TripPhase phase,
  }) async {
    saves++;
    lastStops = stops;
    lastPhase = phase;
  }

  @override
  Future<void> markAttendance(
    String tripId,
    String studentId,
    AttendanceStatus status,
  ) async {
    marks[studentId] = status;
  }

  @override
  Future<Map<String, AttendanceStatus>> fetchAttendance(String tripId) async =>
      Map.of(marks);

  @override
  Future<void> completeTrip(String tripId) async => completed = true;

  @override
  void notifyFamily(RiderInfo rider, FamilyEvent event, TripLegKind leg) {
    events.add((rider.id, event));
  }
}

// Scenario: the driver starts at O. B is nearest, then A, then C, then the
// institute — so a correct optimiser visits B → A → C.
const o = GeoCoord(31.4700, 74.2700);
const a = GeoCoord(31.4750, 74.2800);
const b = GeoCoord(31.4720, 74.2740);
const c = GeoCoord(31.4800, 74.2900);
const institute = GeoCoord(31.4850, 74.3000);

Student kid(String id, GeoCoord home, {List<String> absent = const []}) =>
    Student(
      id: id,
      parentId: 'parent-$id',
      name: id,
      pickupLocation: home,
      absentDates: absent,
    );

void main() {
  late DateTime now;
  late FakeOptimizer optimizer;
  late FakeBackend backend;
  late TripController ctl;

  setUp(() {
    now = DateTime(2026, 11, 9, 7, 0);
    optimizer = FakeOptimizer();
    backend = FakeBackend();
    ctl = TripController(
      optimizer: optimizer,
      backend: backend,
      clock: () => now,
      // The fixtures' distances were laid out around a five-minute lead; the
      // app's own default (ten) is checked on its own below.
      nearbyLead: const Duration(minutes: 5),
    );
  });

  LocationFix fix(GeoCoord at, {double speed = 25}) =>
      LocationFix(coord: at, at: now, speedKmh: speed, heading: 0);

  Future<Trip> startPickup(List<Student> riders) => ctl.start(
    TripStartRequest(
      driverId: 'd',
      busId: 'bus',
      routeId: '',
      scheduleId: 'round-1',
      leg: TripLegKind.pickup,
      riders: riders,
      origin: o,
      destination: institute,
    ),
    tripId: 'trip-1',
  );

  List<String> openOrder() => [
    for (final s in ctl.openStops)
      s.isDestination ? 'I' : s.studentIds.join('+'),
  ];

  group('morning round A, B, C', () {
    test(
      'starts from the driver, in the optimised order, school last',
      () async {
        final trip = await startPickup([
          kid('S1', a),
          kid('S2', b),
          kid('S3', c),
        ]);

        expect(openOrder(), ['S2', 'S1', 'S3', 'I']);
        expect([for (final s in ctl.stops) s.order], [1, 2, 3, 4]);
        expect(optimizer.calls, 1);
        // The route starts where the van is, not at the first child's door.
        expect(GeoUtils.distance(ctl.remainingLine.first, o), lessThan(1));
        // Written once, with the route, so a family's map has it at once.
        expect(backend.created?.id, trip.id);
        expect(backend.created!.stops, hasLength(4));
        expect(backend.created!.route!.legs, hasLength(4));
        expect(backend.created!.scheduleId, 'round-1');
        // ETAs count up along the round.
        final etas = [for (final s in ctl.openStops) s.etaAt!];
        for (var i = 1; i < etas.length; i++) {
          expect(etas[i].isAfter(etas[i - 1]), isTrue);
        }
      },
    );

    test('arriving, present, and the route recomputes from the van', () async {
      await startPickup([kid('S1', a), kid('S2', b), kid('S3', c)]);

      ctl.onFix(fix(const GeoCoord(31.47205, 74.27405), speed: 3));
      expect(ctl.arrival?.stop.studentIds, ['S2']);
      expect(backend.events, contains(('S2', FamilyEvent.arriving)));

      await ctl.markPresent('S2');
      expect(backend.marks['S2'], AttendanceStatus.boarded);
      expect(backend.events, contains(('S2', FamilyEvent.boarded)));
      expect([for (final r in ctl.onBoard) r.id], ['S2']);
      expect(openOrder(), ['S1', 'S3', 'I']);
      expect(optimizer.calls, 2);
      expect(ctl.arrival, isNull);
    });

    test('absent removes the stop and recomputes', () async {
      await startPickup([kid('S1', a), kid('S2', b), kid('S3', c)]);
      await ctl.markAbsent('S2');

      expect(backend.marks['S2'], AttendanceStatus.absent);
      expect(
        ctl.stops.firstWhere((s) => s.studentIds.contains('S2')).status,
        TripStopStatus.skipped,
      );
      expect(openOrder(), ['S1', 'S3', 'I']);
      expect(optimizer.calls, 2);
    });

    test(
      'leaving the line for three fixes recomputes, once per cooldown',
      () async {
        await startPickup([kid('S1', a), kid('S2', b), kid('S3', c)]);
        const lost = GeoCoord(31.4600, 74.2700); // ~1 km south of everything

        ctl.onFix(fix(lost));
        ctl.onFix(fix(lost));
        expect(optimizer.calls, 1);
        ctl.onFix(fix(lost));
        await Future<void>.delayed(Duration.zero);
        expect(optimizer.calls, 2);
        expect(
          optimizer.optimizeFlags.last,
          isFalse,
          reason: 'a detour must not reshuffle the stops',
        );

        // The new route starts where the van went, so sitting there is on
        // route now. A second wrong turn, inside the cooldown: no request.
        const lostAgain = GeoCoord(31.4500, 74.2500);
        now = now.add(const Duration(seconds: 10));
        for (var i = 0; i < 3; i++) {
          ctl.onFix(fix(lostAgain));
        }
        await Future<void>.delayed(Duration.zero);
        expect(optimizer.calls, 2);

        now = now.add(const Duration(seconds: 25));
        for (var i = 0; i < 3; i++) {
          ctl.onFix(fix(lostAgain));
        }
        await Future<void>.delayed(Duration.zero);
        expect(optimizer.calls, 3);
      },
    );

    test('the ETA refreshes every couple of minutes, not every fix', () async {
      await startPickup([kid('S1', a), kid('S2', b), kid('S3', c)]);
      for (var i = 0; i < 20; i++) {
        now = now.add(const Duration(seconds: 4));
        ctl.onFix(fix(o));
      }
      await Future<void>.delayed(Duration.zero);
      expect(optimizer.calls, 1, reason: '80 seconds of fixes, no request');

      now = now.add(const Duration(seconds: 80));
      ctl.onFix(fix(o));
      await Future<void>.delayed(Duration.zero);
      expect(optimizer.calls, 2);
    });

    test('everyone collected → institute only → arrival hands over', () async {
      await startPickup([kid('S1', a), kid('S2', b), kid('S3', c)]);
      await ctl.markPresent('S2');
      await ctl.markPresent('S1');
      await ctl.markAbsent('S3');
      expect(openOrder(), ['I']);

      ctl.onFix(fix(institute));
      await Future<void>.delayed(Duration.zero);
      expect(ctl.phase, TripPhase.arrivedInstitute);
      expect(backend.lastPhase, TripPhase.arrivedInstitute);
      expect(backend.marks['S1'], AttendanceStatus.droppedOff);
      expect(backend.marks['S2'], AttendanceStatus.droppedOff);
      expect(backend.marks['S3'], AttendanceStatus.absent);
      expect(backend.events, contains(('S1', FamilyEvent.reachedInstitute)));
      // Everyone delivered: the round ends by itself.
      expect(backend.completed, isTrue);

      // stops + 3 is the budget in the brief; this round used 4 for 3 stops.
      expect(optimizer.calls, lessThanOrEqualTo(3 + 3));
    });

    test('a child the family marked off today never becomes a stop', () async {
      final today = Trip.dateKeyFor(now);
      await startPickup([
        kid('S1', a, absent: [today]),
        kid('S2', b),
      ]);
      expect(openOrder(), ['S2', 'I']);
      await Future<void>.delayed(Duration.zero);
      // Not marked absent for the driver: only the driver marks anyone.
      expect(backend.marks.containsKey('S1'), isFalse);
      expect(ctl.markFor('S1'), AttendanceStatus.pending);
      expect(ctl.isOffToday('S1'), isTrue);
    });

    test('a family marking off mid-round takes the stop away', () async {
      await startPickup([kid('S1', a), kid('S2', b)]);
      final today = Trip.dateKeyFor(now);
      await ctl.applyFamilyAbsences([
        kid('S1', a, absent: [today]),
      ]);
      expect(openOrder(), ['S2', 'I']);
      expect(optimizer.calls, 2);
    });

    test('siblings at one gate are one stop', () async {
      await startPickup([
        kid('S1', a),
        kid('S1b', const GeoCoord(31.47502, 74.28003)), // ~4 m away
        kid('S2', b),
      ]);
      expect(openOrder(), ['S2', 'S1+S1b', 'I']);

      await ctl.markPresent('S1');
      // Still open: the sibling has not been marked.
      expect(openOrder(), contains('S1+S1b'));
      await ctl.markAbsent('S1b');
      expect(openOrder(), ['S2', 'I']);
    });

    test('nobody to collect is said plainly', () async {
      final today = Trip.dateKeyFor(now);
      expect(
        () => startPickup([
          kid('S1', a, absent: [today]),
        ]),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('institute to home', () {
    Student rider(String id, GeoCoord home) => Student(
      id: id,
      parentId: 'parent-$id',
      name: id,
      school: 'Allied School',
      pickupLocation: home,
      dropoffLocation: institute,
    );

    Future<void> startHome(List<Student> riders) => ctl.start(
      TripStartRequest(
        driverId: 'd',
        busId: 'bus',
        routeId: '',
        scheduleId: 'round-1',
        leg: TripLegKind.dropoff,
        riders: riders,
        origin: institute,
        destination: institute,
      ),
      tripId: 'trip-2',
    );

    test('starts at the institute, with nobody marked aboard', () async {
      await startHome([rider('S1', a), rider('S2', b), rider('S3', c)]);
      final first = ctl.stops.first;
      expect(first.kind, TripStopKind.institute);
      expect(first.studentIds, unorderedEquals(['S1', 'S2', 'S3']));
      expect(ctl.instituteName(first), 'Allied School');
      expect(ctl.onBoard, isEmpty);
      expect(backend.marks, isEmpty);
      expect(ctl.stops.any((s) => s.isDestination), isFalse);
    });

    test('board at the institute, then drop each home, then finish', () async {
      await startHome([rider('S1', a), rider('S2', b), rider('S3', c)]);
      ctl.onFix(fix(institute, speed: 2));
      final prompt = ctl.arrival!;
      expect(ctl.isBoardingStop(prompt.stop), isTrue);
      expect(prompt.riders, hasLength(3));
      for (final id in ['S1', 'S2', 'S3']) {
        await ctl.markPresent(id);
      }
      expect(ctl.onBoard, hasLength(3));
      expect(ctl.nextStop!.kind, TripStopKind.drop);

      while (!ctl.isCompleted) {
        final stop = ctl.nextStop!;
        ctl.onFix(fix(stop.location, speed: 2));
        expect(ctl.arrival?.stop.id, stop.id);
        for (final id in stop.studentIds) {
          await ctl.markDropped(id);
        }
      }
      expect(backend.completed, isTrue);
      expect(backend.events, contains(('S3', FamilyEvent.droppedOff)));
    });

    test('a child not at the institute is passed by at home', () async {
      await startHome([rider('S1', a), rider('S2', b)]);
      ctl.onFix(fix(institute, speed: 2));
      await ctl.markAbsent('S1');
      await ctl.markPresent('S2');
      expect(openOrder(), ['S2']);
      expect(backend.marks['S1'], AttendanceStatus.absent);
    });

    test('nobody on the van ends the round at once', () async {
      await startHome([rider('S1', a), rider('S2', b)]);
      ctl.onFix(fix(institute, speed: 2));
      await ctl.markAbsent('S1');
      await ctl.markAbsent('S2');
      expect(backend.completed, isTrue);
    });
  });

  group('the driver marks everyone', () {
    test('nobody is marked when a morning round starts', () async {
      await startPickup([kid('S1', a), kid('S2', b)]);
      await pumpEventQueue();
      expect(backend.marks, isEmpty);
      expect(ctl.markFor('S1'), AttendanceStatus.pending);
    });

    test('every child marked absent ends the round by itself', () async {
      await startPickup([kid('S1', a), kid('S2', b), kid('S3', c)]);
      await ctl.markAbsent('S1');
      await ctl.markAbsent('S2');
      expect(backend.completed, isFalse);
      await ctl.markAbsent('S3');
      expect(backend.completed, isTrue);
      expect(ctl.isCompleted, isTrue);
    });

    test('a family absence mid-round leaves the mark to the driver', () async {
      await startPickup([kid('S1', a), kid('S2', b)]);
      final today = Trip.dateKeyFor(now);
      await ctl.applyFamilyAbsences([
        kid('S1', a, absent: [today]),
      ]);
      expect(ctl.markFor('S1'), AttendanceStatus.pending);
      expect(backend.marks.containsKey('S1'), isFalse);
    });
  });

  group('resume after the app was killed', () {
    test('picks the round up from the trip document', () async {
      final trip = await startPickup([
        kid('S1', a),
        kid('S2', b),
        kid('S3', c),
      ]);
      await ctl.markPresent('S2');
      final saved = trip.copyWith(stops: backend.lastStops);

      final again = TripController(
        optimizer: optimizer,
        backend: backend,
        clock: () => now,
      );
      await again.resume(
        saved,
        roster: [kid('S1', a), kid('S2', b), kid('S3', c)],
        position: b,
      );
      expect(again.isRunning, isTrue);
      expect(again.markFor('S2'), AttendanceStatus.boarded);
      expect(
        [
          for (final s in again.openStops)
            s.isDestination ? 'I' : s.studentIds.join(),
        ],
        ['S1', 'S3', 'I'],
      );
    });
  });

  group('one driver, several rounds', () {
    test(
      'the trip records every child on the round, absent ones too',
      () async {
        final trip = await startPickup([
          kid('S1', a),
          kid('S2', b, absent: ['2026-11-09']),
        ]);
        expect(trip.riderIds, unorderedEquals(['S1', 'S2']));
        expect(backend.created!.riderIds, unorderedEquals(['S1', 'S2']));
        expect(trip.carries('S2'), isTrue);
        expect(Trip.fromMap(trip.id, trip.toMap()).riderIds, trip.riderIds);
      },
    );

    test("round A's trip is not round B's family's to see", () async {
      final roundA = await startPickup([kid('A1', a), kid('A2', b)]);
      expect(roundA.carries('A1'), isTrue);
      expect(roundA.carries('B1'), isFalse);
      expect(roundA.carries(''), isFalse);
    });

    test('older trips fall back to their stops, then to the driver', () {
      const stop = TripStop(
        id: 's',
        studentIds: ['A1'],
        location: a,
        kind: TripStopKind.pickup,
        order: 1,
      );
      const withStops = Trip(
        id: 't',
        routeId: '',
        busId: 'bus',
        driverId: 'd',
        dateKey: '2026-11-09',
        stops: [stop],
      );
      expect(withStops.carries('A1'), isTrue);
      expect(withStops.carries('B1'), isFalse);
      const legacy = Trip(
        id: 't',
        routeId: '',
        busId: 'bus',
        driverId: 'd',
        dateKey: '2026-11-09',
      );
      expect(legacy.carries('B1'), isTrue);
    });

    test('the family map refuses to follow another round', () async {
      final roundA = await startPickup([kid('A1', a)]);
      final live = LiveBusService.instance;
      live.follow(busId: 'bus', trip: roundA, studentId: 'B1');
      expect(live.isFollowing.value, isFalse);
      expect(live.trip.value, isNull);
    });
  });

  test('families are warned ten minutes ahead by default', () {
    expect(
      TripController(optimizer: optimizer, backend: backend).nearbyLead,
      const Duration(minutes: 10),
    );
  });

  test('every family on the round hears the route has started', () async {
    await startPickup([
      kid('S1', a),
      kid('S2', b, absent: ['2026-11-09']),
      kid('S3', c),
    ]);
    final started = [
      for (final e in backend.events)
        if (e.$2 == FamilyEvent.routeStarted) e.$1,
    ];
    expect(started, unorderedEquals(['S1', 'S3']), reason: 'S2 is off today');
  });

  group('five minutes before a pickup', () {
    List<String> warned() => [
      for (final e in backend.events)
        if (e.$2 == FamilyEvent.nearby) e.$1,
    ];

    test(
      'the families already within five minutes are told at start',
      () async {
        // From O: B is about a minute and a half away and A under five
        // minutes behind it; C is well beyond.
        await startPickup([kid('S1', a), kid('S2', b), kid('S3', c)]);
        expect(warned(), unorderedEquals(['S1', 'S2']));

        ctl.onFix(fix(o));
        expect(warned(), hasLength(2), reason: 'once per stop, not per fix');
      },
    );

    test('a later stop is told when the van comes within range', () async {
      await startPickup([kid('S1', a), kid('S2', b), kid('S3', c)]);
      expect(warned(), isNot(contains('S3')));

      ctl.onFix(fix(b, speed: 2));
      await ctl.markPresent('S2');
      ctl.onFix(fix(a, speed: 2));
      await ctl.markPresent('S1');
      expect(warned(), contains('S3'));
      expect(warned().where((id) => id == 'S3'), hasLength(1));
    });

    test('a child marked off is not warned', () async {
      await startPickup([
        kid('S1', a),
        kid('S2', b, absent: ['2026-11-09']),
      ]);
      expect(warned(), ['S1']);
    });

    test('the ride home warns nobody before they are on board', () async {
      await ctl.start(
        TripStartRequest(
          driverId: 'd',
          busId: 'bus',
          routeId: '',
          scheduleId: 'round-1',
          leg: TripLegKind.dropoff,
          riders: [kid('S1', a), kid('S2', b)],
          origin: o,
        ),
        tripId: 'trip-2',
      );
      expect(warned(), isEmpty);
    });

    test('a round picked up again does not warn twice', () async {
      final trip = await startPickup([kid('S1', a), kid('S2', b)]);
      await pumpEventQueue();
      expect(backend.lastStops.where((s) => s.nearbyAlerted), hasLength(2));
      expect(
        Trip.fromMap(
          trip.id,
          trip.copyWith(stops: backend.lastStops).toMap(),
        ).stops.where((s) => s.nearbyAlerted),
        hasLength(2),
      );

      backend.events.clear();
      final again = TripController(
        optimizer: optimizer,
        backend: backend,
        clock: () => now,
      );
      await again.resume(
        trip.copyWith(stops: backend.lastStops),
        roster: [kid('S1', a), kid('S2', b)],
        position: o,
      );
      expect(warned(), isEmpty);
    });
  });

  group('a round dropping at more than one institute', () {
    // S1 studies near `c`, S2 at the institute; both are collected first.
    const otherCampus = GeoCoord(31.4790, 74.2880);
    Student student(String id, GeoCoord home, GeoCoord campus) => Student(
      id: id,
      parentId: 'parent-$id',
      name: id,
      pickupLocation: home,
      dropoffLocation: campus,
    );

    test(
      'every child is collected first, then set down at their own',
      () async {
        await startPickup([
          student('S1', a, otherCampus),
          student('S2', b, institute),
        ]);
        final kinds = [for (final s in ctl.stops) s.kind];
        expect(kinds.take(2), everyElement(TripStopKind.pickup));
        expect(kinds.skip(2), [
          TripStopKind.institute,
          TripStopKind.destination,
        ]);
        final trip = ctl.trip!;
        expect(trip.instituteStopFor('S1')!.location, otherCampus);
        expect(trip.instituteStopFor('S2')!.location, institute);
        expect(trip.childStopFor('S1')!.kind, TripStopKind.pickup);
      },
    );

    test('each child gets off at their own institute, told there', () async {
      await startPickup([
        student('S1', a, otherCampus),
        student('S2', b, institute),
      ]);
      ctl.onFix(fix(b, speed: 2));
      await ctl.markPresent('S2');
      ctl.onFix(fix(a, speed: 2));
      await ctl.markPresent('S1');

      // The nearer campus comes first: only S1 gets off there.
      ctl.onFix(fix(otherCampus, speed: 2));
      await pumpEventQueue();
      expect(ctl.markFor('S1'), AttendanceStatus.droppedOff);
      expect(ctl.markFor('S2'), AttendanceStatus.boarded);
      expect(backend.events, contains(('S1', FamilyEvent.reachedInstitute)));
      expect(
        backend.events,
        isNot(contains(('S2', FamilyEvent.reachedInstitute))),
      );

      ctl.onFix(fix(institute, speed: 2));
      await pumpEventQueue();
      expect(ctl.markFor('S2'), AttendanceStatus.droppedOff);
      expect(ctl.phase, TripPhase.arrivedInstitute);
    });

    test('an institute nobody is going to is passed by', () async {
      await startPickup([
        student('S1', a, otherCampus),
        student('S2', b, institute),
      ]);
      ctl.onFix(fix(b, speed: 2));
      await ctl.markPresent('S2');
      ctl.onFix(fix(a, speed: 2));
      await ctl.markAbsent('S1');
      final campus = ctl.stops.firstWhere(
        (s) => s.kind == TripStopKind.institute,
      );
      expect(campus.status, TripStopStatus.skipped);
      expect(ctl.nextStop!.isDestination, isTrue);
    });

    test('marking at a gate never closes an institute stop', () async {
      await startPickup([
        student('S1', a, otherCampus),
        student('S2', b, institute),
      ]);
      ctl.onFix(fix(b, speed: 2));
      await ctl.markPresent('S2');
      final open = [
        for (final s in ctl.stops)
          if (s.isInstitute && s.isOpen) s.kind,
      ];
      expect(open, [TripStopKind.institute, TripStopKind.destination]);
    });
  });

  group("each child's expected times", () {
    test(
      'the order of the stops sets each time, from the round start',
      () async {
        const round = DriverSchedule(
          id: 'r1',
          label: 'Morning',
          pickupStart: '07:00',
          dropoffStart: '13:30',
          totalSeats: 8,
        );
        final times = await ExpectedTimesService(optimizer: optimizer).forRound(
          round,
          [kid('S1', a), kid('S2', b), kid('S3', c)],
          start: o,
          institute: institute,
        );
        int minutes(String hhmm) {
          final p = hhmm.split(':');
          return int.parse(p[0]) * 60 + int.parse(p[1]);
        }

        // Morning: B is nearest the start, then A, then C.
        final pick = {for (final e in times.entries) e.key: e.value.pickup};
        expect(minutes(pick['S2']!), greaterThanOrEqualTo(7 * 60));
        expect(minutes(pick['S2']!), lessThan(minutes(pick['S1']!)));
        expect(minutes(pick['S1']!), lessThan(minutes(pick['S3']!)));
        // Home: from the institute, C is nearest.
        final drop = {for (final e in times.entries) e.key: e.value.dropoff};
        expect(minutes(drop['S3']!), lessThan(minutes(drop['S1']!)));
        expect(minutes(drop['S3']!), greaterThanOrEqualTo(13 * 60 + 30));
        expect(times['S1']!.scheduleId, 'r1');
      },
    );

    test('a leg the round does not run has no time', () async {
      const round = DriverSchedule(
        id: 'r1',
        label: 'Evening only',
        dropoffStart: '16:00',
        totalSeats: 8,
      );
      final times = await ExpectedTimesService(
        optimizer: optimizer,
      ).forRound(round, [kid('S1', a)], institute: institute);
      expect(times['S1']!.pickup, isEmpty);
      expect(times['S1']!.dropoff, isNotEmpty);
    });
  });
}
