import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  group('a family saying "not today"', () {
    test('an absence survives a write and a read', () {
      const student = Student(
        id: 's1',
        parentId: 'p1',
        name: 'Ali',
        absentDates: ['2026-11-02', '2026-11-05'],
      );
      final back = Student.fromMap('s1', student.toMap());
      expect(back.isAbsentOn('2026-11-02'), isTrue);
      expect(back.isAbsentOn('2026-11-03'), isFalse);
    });

    test('a child with nothing recorded is not absent', () {
      const student = Student(id: 's1', parentId: 'p1', name: 'Ali');
      expect(student.isAbsentOn('2026-11-02'), isFalse);
    });
  });

  group('handing the children over', () {
    test('droppedOff is a real state, not a second absence', () {
      // `boarded` was a one-way door: the last thing a family was ever told
      // was that their child got on.
      final record = AttendanceRecord.fromMap('s1', {
        'studentId': 's1',
        'status': 'droppedOff',
      });
      expect(record.status, AttendanceStatus.droppedOff);
    });

    test('an unknown status falls back rather than throwing', () {
      final record = AttendanceRecord.fromMap('s1', {
        'studentId': 's1',
        'status': 'whatever-the-admin-app-writes-next',
      });
      expect(record.status, AttendanceStatus.pending);
    });

    test('the driver hands over on arrival and on closing the round', () {
      final src = read('lib/screens/driver/driver_route.dart');
      expect(src, contains('GeofenceEvent.arrived'));
      expect(src, contains('_handOverEveryoneAboard'));
      expect(
        src,
        contains('_reportUnmarkedAttendance'),
        reason: 'silence used to be indistinguishable from nothing happening',
      );
    });

    test('the status badge is no longer "has a driver at all"', () {
      final src = read('lib/screens/parent/parent_dashboard.dart');
      expect(src, contains('RideStatusBadge'));
      expect(
        src.contains("StatusBadge(\n"),
        isFalse,
        reason: 'the hardcoded badge is gone from the child card',
      );
    });
  });

  group('the family\'s requested timings are a request', () {
    test('saving sets it pending and clears the old answer', () {
      final src = read('lib/screens/parent/edit_weekly_schedule_screen.dart');
      expect(src, contains('ScheduleRequestStatus.pending.name'));
      expect(src, contains("'scheduleRequestNote': null"));
      expect(src, contains('/driver/timetables'));
    });

    test('the driver has a screen to answer on, and a route to it', () {
      expect(
        read('lib/app/router.dart'),
        contains("path: '/driver/timetables'"),
      );
      final screen = read('lib/screens/driver/driver_timetables_screen.dart');
      expect(screen, contains('ScheduleRequestStatus.accepted.name'));
      expect(screen, contains('ScheduleRequestStatus.rejected.name'));
    });

    test('the rules let a driver write that answer and nothing more', () {
      final rules = read('firestore.rules');
      expect(rules, contains("'scheduleRequestStatus'"));
      expect(rules, contains("'scheduleRequestNote'"));
      // The allow-list is the security boundary: a driver must still not be
      // able to rename a child or move them to another parent.
      expect(rules, isNot(contains("onlyChanges(['name'")));
    });

    test('a status survives a write and a read', () {
      const student = Student(
        id: 's1',
        parentId: 'p1',
        name: 'Ali',
        scheduleRequestStatus: ScheduleRequestStatus.rejected,
        scheduleRequestNote: 'I am at your gate at 06:50',
      );
      final back = Student.fromMap('s1', student.toMap());
      expect(back.scheduleRequestStatus, ScheduleRequestStatus.rejected);
      expect(back.scheduleRequestNote, 'I am at your gate at 06:50');
    });
  });

  group('a week is not done because the date passed', () {
    test('the schedule reads real attendance, not the calendar', () {
      final src = read('lib/screens/parent/parent_schedule.dart');
      expect(
        src.contains('weekday < todayWeekday'),
        isFalse,
        reason: 'on a Sunday that marked the entire week completed at once',
      );
      expect(src, contains('fetchAttendanceForStudent'));
      expect(src, contains('no_trip_that_day'));
    });
  });

  group('one conversation per child', () {
    test('two children with one driver get two threads', () {
      final a = ChatThread.idFor('parent1', 'driver1', studentId: 'kidA');
      final b = ChatThread.idFor('parent1', 'driver1', studentId: 'kidB');
      expect(a, isNot(b));
    });

    test('the pair ordering is unchanged, so old threads still resolve', () {
      expect(
        ChatThread.idFor('b', 'a'),
        ChatThread.idFor('a', 'b'),
      );
      expect(ChatThread.idFor('a', 'b'), 'a__b');
      expect(ChatThread.idFor('a', 'b', studentId: ''), 'a__b');
    });

    test('a rating is per child, and old ids still block the week', () {
      final src = read('lib/data/rating_repository.dart');
      expect(src, contains('String? studentId'));
      final parent = read('lib/app/parent_data_service.dart');
      expect(parent, contains('_ratingKey('));
      expect(
        parent,
        contains('driverRatings.value[_driverKey(child)]'),
        reason: 'a rating given before this still counts against the week',
      );
    });
  });
}
