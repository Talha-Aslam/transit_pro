import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_pro/app/family_stats.dart';
import 'package:transit_pro/app/family_trip_times.dart';
import 'package:transit_pro/app/ride_match_service.dart';
import 'package:transit_pro/app/round_display.dart';
import 'package:transit_pro/app/vehicle_capacity.dart';
import 'package:transit_pro/data/ride_request_repository.dart';
import 'package:transit_pro/screens/driver/driver_service_screen.dart';

DriverSchedule round(
  String id, {
  String label = 'Round',
  int seats = 12,
  int booked = 0,
  String pickup = '07:00',
  String dropoff = '',
}) => DriverSchedule(
  id: id,
  label: label,
  pickupStart: pickup,
  dropoffStart: dropoff,
  totalSeats: seats,
  bookedSeats: booked,
);

String read(String p) => File(p).readAsStringSync();

void main() {
  group('My Service: rounds save as edited', () {
    test('an edited round keeps the seats already booked on it', () {
      final merged = RideMatchService.mergeRounds(
        [round('r1', label: 'Old', booked: 3)],
        [round('r1', label: 'DHA morning', seats: 14)],
      );
      expect(merged.single.label, 'DHA morning');
      expect(merged.single.totalSeats, 14);
      expect(merged.single.bookedSeats, 3);
    });

    test('a new round is added and an empty one removed', () {
      final merged = RideMatchService.mergeRounds(
        [round('r1'), round('r2')],
        [round('r1'), round('r3', label: 'Evening')],
      );
      expect([for (final r in merged) r.id], ['r1', 'r3']);
      expect(merged.last.bookedSeats, 0);
    });

    test('a round with families on it cannot be deleted', () {
      expect(
        () => RideMatchService.mergeRounds(
          [round('r1'), round('r2', label: 'Early', booked: 2)],
          [round('r1')],
        ),
        throwsA(
          isA<RideRequestException>().having(
            (e) => e.message,
            'message',
            contains('"Early"'),
          ),
        ),
      );
    });

    test('seats cannot drop below what is booked', () {
      expect(
        () => RideMatchService.mergeRounds(
          [round('r1', booked: 5)],
          [round('r1', seats: 4)],
        ),
        throwsA(isA<RideRequestException>()),
      );
    });

    test('each round is checked before anything is written', () {
      expect(roundProblem(round('r1')), isNull);
      expect(roundProblem(round('r1', pickup: '')), contains('start time'));
      expect(roundProblem(round('r1', pickup: '', dropoff: '14:00')), isNull);
      expect(roundProblem(round('r1', seats: 0)), contains('seats'));
      expect(roundProblem(round('r1', seats: 2, booked: 3)), contains('3'));
    });

    test('areas and rounds go in one write, and errors show by Save', () {
      final repo = read('lib/data/user_repository.dart');
      expect(repo, contains('Future<void> replaceService('));
      expect(repo, isNot(contains('replaceServiceAreas(')));
      final screen = read('lib/screens/driver/driver_service_screen.dart');
      expect(screen, contains('saveService('));
      expect(
        screen,
        contains(
          'if (_error.isNotEmpty) _errorBanner(),\n'
          '                            _saveButton(),',
        ),
      );
      expect(screen, contains('Scrollable.ensureVisible'));
    });
  });

  group('Track: the times a family waits on', () {
    final now = DateTime(2026, 11, 9, 7, 30);
    TripStop stop(
      String id,
      TripStopKind kind, {
      List<String> kids = const [],
      TripStopStatus status = TripStopStatus.pending,
      DateTime? eta,
    }) => TripStop(
      id: id,
      location: const GeoCoord(31.5, 74.3),
      kind: kind,
      studentIds: kids,
      status: status,
      etaAt: eta,
    );

    Trip trip(TripType type, List<TripStop> stops) => Trip(
      id: 't',
      routeId: '',
      busId: 'bus',
      driverId: 'd',
      dateKey: '2026-11-09',
      type: type,
      stops: stops,
    );

    test('morning: pickup time first, then the school', () {
      final t = trip(TripType.morning, [
        stop('s1', TripStopKind.pickup, kids: ['A'], eta: now),
        stop(
          'i',
          TripStopKind.destination,
          eta: now.add(const Duration(minutes: 20)),
        ),
      ]);
      final times = FamilyTripTimes.of(t, 'A');
      expect(times.toSchool, isTrue);
      expect(times.pickupAt, now);
      expect(times.arriveAt, now.add(const Duration(minutes: 20)));
      expect(
        times.headline(mark: AttendanceStatus.pending, school: 'LGS'),
        startsWith('Pickup at '),
      );
      expect(
        times.headline(mark: AttendanceStatus.boarded, school: 'LGS'),
        startsWith('Reaching LGS at '),
      );
    });

    test('morning, once collected: no pickup time left to give', () {
      final t = trip(TripType.morning, [
        stop(
          's1',
          TripStopKind.pickup,
          kids: ['A'],
          status: TripStopStatus.done,
        ),
        stop('i', TripStopKind.destination, eta: now),
      ]);
      expect(FamilyTripTimes.of(t, 'A').pickupAt, isNull);
    });

    test('ride home: the drop-off time at this child\'s door', () {
      final t = trip(TripType.afternoon, [
        stop(
          's1',
          TripStopKind.drop,
          kids: ['A'],
          eta: now.add(const Duration(minutes: 12)),
        ),
      ]);
      final times = FamilyTripTimes.of(t, 'A');
      expect(times.toSchool, isFalse);
      expect(times.pickupAt, isNull);
      expect(times.arriveAt, now.add(const Duration(minutes: 12)));
      expect(
        times.headline(mark: AttendanceStatus.boarded, school: 'LGS'),
        startsWith('Drop-off at '),
      );
      expect(
        times.headline(mark: AttendanceStatus.droppedOff, school: 'LGS'),
        isNull,
      );
    });

    test('the five-minute flag survives a save and a reload', () {
      final s = stop(
        's1',
        TripStopKind.pickup,
        kids: ['A'],
      ).copyWith(nearbyAlerted: true);
      expect(TripStop.fromMap(s.toMap()).nearbyAlerted, isTrue);
      expect(
        TripStop.fromMap(stop('s2', TripStopKind.pickup).toMap()).nearbyAlerted,
        isFalse,
      );
    });

    test('pushes: five-minute warning and "dropped off" wording', () {
      final session = read('lib/app/trip_session.dart');
      expect(session, contains('Driver is reaching within'));
      expect(session, contains(r"'Your child $name dropped off'"));
      // The attendance screen marks through the round so the family is told.
      expect(
        read('lib/screens/driver/driver_attendance.dart'),
        contains('round.markPresent(student.id)'),
      );
    });
  });

  group('Find a driver: seats and round names', () {
    test('the card shows the vehicle, not a sum of rounds', () {
      final d = Driver(
        id: 'd',
        name: 'D',
        schedules: [round('r1', seats: 12), round('r2', seats: 12)],
      );
      expect(VehicleCapacity.estimate(d), 12);
      expect(VehicleCapacity.current(d), 12);
      final card = read('lib/screens/parent/find_drivers_screen.dart');
      expect(card, contains("label: 'TOTAL SEATS'"));
      expect(card, isNot(contains("label: 'SEATS FREE'")));
    });

    test('a round is called by the name its driver gave it', () {
      final d = Driver(
        id: 'd',
        name: 'D',
        schedules: [round('r1', label: 'DHA morning')],
      );
      expect(roundNameFor(d, 'r1', fallback: 'Round 1 · 7-8'), 'DHA morning');
      expect(roundNameFor(d, 'gone', fallback: 'Round 1'), 'Round 1');
      expect(roundNameFor(null, 'r1'), '');
      final tracking = read('lib/screens/parent/parent_tracking.dart');
      expect(tracking, contains('trip.scheduleId'));
      expect(tracking, isNot(contains('scheduleById(trip.routeId)')));
    });
  });

  group('Parent Home: figures from real rides', () {
    AttendanceRecord rec(
      String trip,
      AttendanceStatus status, {
      DateTime? at,
    }) => AttendanceRecord(
      studentId: 'A',
      studentName: 'A',
      tripId: trip,
      dateKey: '2026-11-09',
      driverId: 'd',
      status: status,
      markedAt: at,
    );

    test(
      'a finished ride counts — dropped off is where every ride ends',
      () async {
        final now = DateTime(2026, 11, 9, 16);
        final trips = {
          't1': Trip(
            id: 't1',
            routeId: '',
            busId: 'b',
            driverId: 'd',
            dateKey: '2026-11-09',
            onTime: true,
            startedAt: now.subtract(const Duration(hours: 8)),
          ),
          't2': Trip(
            id: 't2',
            routeId: '',
            busId: 'b',
            driverId: 'd',
            dateKey: '2026-11-09',
            onTime: false,
            startedAt: now.subtract(const Duration(hours: 2)),
          ),
          't3': Trip(
            id: 't3',
            routeId: '',
            busId: 'b',
            driverId: 'd',
            dateKey: '2026-10-01',
            startedAt: DateTime(2026, 10, 1),
          ),
        };
        final stats = await familyTripStats(
          [
            rec('t1', AttendanceStatus.droppedOff),
            rec('t2', AttendanceStatus.droppedOff),
            rec('t3', AttendanceStatus.boarded),
            rec('t4', AttendanceStatus.absent),
            rec('t5', AttendanceStatus.pending),
          ],
          tripFor: (id) async => trips[id],
          now: now,
        );
        expect(stats.totalTrips, 3);
        expect(stats.onTimePct, 50);
        expect(stats.thisWeek, 2);
      },
    );

    test('the figures and statuses read rows a family is allowed to read', () {
      final rules = read('firestore.rules');
      expect(rules, contains('match /{path=**}/attendance/{rowId}'));
      final status = read('lib/app/child_status_service.dart');
      expect(status, contains('watchAttendanceForStudent(trip.id, child.id)'));
      expect(status, isNot(contains('.watchAttendance(')));
      final home = read('lib/screens/parent/parent_dashboard.dart');
      expect(home, contains('watchAttendanceHistory('));
      expect(home, contains('legToday('));
      expect(home, isNot(contains("AppStrings.t('done'),\n")));
    });
  });

  group('Student Home: the same real figures', () {
    test('a ride counts once the student was on the van', () {
      AttendanceRecord rec(AttendanceStatus s) => AttendanceRecord(
        studentId: 'A',
        studentName: 'A',
        tripId: 't',
        dateKey: '2026-11-09',
        driverId: 'd',
        status: s,
      );
      expect(rodeOn(rec(AttendanceStatus.boarded)), isTrue);
      expect(rodeOn(rec(AttendanceStatus.droppedOff)), isTrue);
      expect(rodeOn(rec(AttendanceStatus.absent)), isFalse);
      expect(rodeOn(rec(AttendanceStatus.pending)), isFalse);
    });

    test('stats follow the student, live, with real on-time verdicts', () {
      final svc = read('lib/app/student_data_service.dart');
      expect(svc, contains('watchAttendanceHistory(id)'));
      expect(svc, contains('onTimeRate.value = stats.onTimePct'));
      expect(svc, isNot(contains('routeId == null || routeId.isEmpty')));
    });

    test("today's schedule reads the round and what really happened", () {
      final home = read('lib/screens/student/student_dashboard.dart');
      // The student's own school hours, not the van's times.
      expect(home, contains('WeeklyTimes.on(me)'));
      expect(home, contains('legToday('));
      expect(home, isNot(contains('_isPast(')));
      expect(home, contains('_etaDestinationLabel(),'));
      expect(home, contains('watchAttendanceHistory(studentId)'));
    });
  });
}
