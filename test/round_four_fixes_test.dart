import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_pro/app/driver_link.dart';

String read(String p) => File(p).readAsStringSync();

void main() {
  test('the direction is asked, never guessed from the clock', () {
    final route = read('lib/screens/driver/driver_route.dart');
    expect(route, contains('_askDirection('));
    expect(route, isNot(contains('_legIsPickup')));
    expect(route, isNot(contains('showBoardingChecklist')));
  });

  test('attendance is marked explicitly, unmarked is not absent', () {
    final src = read('lib/screens/driver/driver_attendance.dart');
    expect(src, isNot(contains('_toggleStatus')));
    expect(src, contains('AttendanceStatus.pending'));
    expect(src, contains("label: 'Absent'"));
    expect(src, isNot(contains('roster.length - boardedCount')));
  });

  test("today's route reads the round itself", () {
    final src = read('lib/screens/driver/driver_dashboard.dart');
    expect(src, contains('TripSession.instance.controller'));
    expect(src, contains('c.trip?.riderIds'));
    expect(src, isNot(contains('seats free across')));
  });

  test('the driver profile has no empty route card', () {
    expect(
      read('lib/screens/driver/driver_profile.dart'),
      isNot(contains("label: AppStrings.t('route_lbl')")),
    );
  });

  test('forgot password says why it did nothing', () {
    expect(
      read('lib/screens/forgot_password_screen.dart'),
      contains('Email is required.'),
    );
  });

  test('a push that arrives with the app open is shown', () {
    expect(
      read('lib/app/push_notification_service.dart'),
      contains('showForegroundPush('),
    );
    expect(
      read('lib/app/notification_service.dart'),
      isNot(contains('_deliveredByPush')),
    );
  });

  test('a driver can open the child from the chat', () {
    expect(
      read('lib/screens/chat/conversation_screen.dart'),
      contains('StudentLogistics(student: s)'),
    );
  });

  test('a released seat with a bus left on it is no driver', () {
    const leftover = Student(id: 's', name: 'S', parentId: 'p', busId: 'b');
    const bus = Bus(id: 'b', busNumber: '1', driverId: 'd');
    expect(isLinkedToDriver(leftover), isFalse);
    expect(driverIdOf(leftover, bus), isEmpty);
    const booked = Student(
      id: 's',
      name: 'S',
      parentId: 'p',
      busId: 'b',
      driverId: 'd2',
    );
    expect(driverIdOf(booked, bus), 'd2');
    const routed = Student(
      id: 's',
      name: 'S',
      parentId: 'p',
      busId: 'b',
      routeId: 'r',
    );
    expect(driverIdOf(routed, bus), 'd');
  });

  test('expected times survive a save and reload', () {
    const d = Driver(
      id: 'd',
      name: 'D',
      expectedTimes: {
        's1': ExpectedTimes(pickup: '07:12', dropoff: '13:41', scheduleId: 'r'),
      },
    );
    final back = Driver.fromMap('d', d.toMap());
    expect(back.expectedTimes['s1']!.pickup, '07:12');
    expect(back.expectedTimes['s1']!.dropoff, '13:41');
  });
}
