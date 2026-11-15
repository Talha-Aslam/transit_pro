import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_pro/app/notification_service.dart';

String read(String path) => File(path).readAsStringSync();

AppNotification note(NotificationType? kind) => AppNotification(
  id: 0,
  type: 'info',
  icon: '',
  title: '',
  message: '',
  time: '',
  date: 'Today',
  color: const Color(0xFF000000),
  kind: kind,
);

DriverRating rating(double r) => DriverRating(
  id: 'x',
  driverId: 'd',
  raterId: 'p',
  rating: r,
  weekKey: '2026-W46',
);

void main() {
  group('driver rating summary', () {
    test('averages the ratings and labels a new driver', () {
      expect(const DriverRatingSummary().label, 'New');
      final s = DriverRatingSummary.of([rating(5), rating(4), rating(3)]);
      expect(s.count, 3);
      expect(s.average, closeTo(4, 1e-9));
      expect(s.label, '4.0 (3)');
    });

    test('top rated needs a high average from enough families', () {
      expect(DriverRatingSummary.of([rating(5), rating(5)]).isTopRated, false);
      expect(
        DriverRatingSummary.of([rating(5), rating(5), rating(4)]).isTopRated,
        true,
      );
      expect(
        DriverRatingSummary.of([rating(5), rating(4), rating(4)]).isTopRated,
        false,
      );
    });
  });

  group('presence', () {
    final now = DateTime(2026, 11, 15, 10);
    AppUser user({required bool online, DateTime? seen}) => AppUser(
      uid: 'u',
      role: UserRole.parent,
      name: 'P',
      isOnline: online,
      lastSeenAt: seen,
    );

    test('online only while the heartbeat is fresh', () {
      expect(
        user(
          online: true,
          seen: now.subtract(const Duration(seconds: 50)),
        ).isOnlineAt(now),
        true,
      );
      expect(
        user(
          online: true,
          seen: now.subtract(const Duration(minutes: 5)),
        ).isOnlineAt(now),
        false,
        reason: 'an app killed by the OS never writes offline',
      );
      expect(user(online: false, seen: now).isOnlineAt(now), false);
    });

    test('presence is never written by a profile save', () {
      final map = user(online: true, seen: now).toMap();
      expect(map.containsKey('isOnline'), false);
      expect(map.containsKey('lastSeenAt'), false);
    });
  });

  test('the Alerts tab holds every activity, not only emergencies', () {
    for (final kind in [
      NotificationType.chat,
      NotificationType.rideRequest,
      NotificationType.rideRequestAnswered,
      NotificationType.payment,
      NotificationType.missedBus,
      NotificationType.routeStarted,
      NotificationType.busApproaching,
      NotificationType.emergency,
    ]) {
      expect(AppNotification.isAlert(note(kind)), true, reason: kind.name);
    }
    expect(AppNotification.isAlert(note(NotificationType.system)), false);
  });

  group('source checks', () {
    test('Google sign-in validates the profile before the session starts', () {
      final src = read('lib/app/auth_service.dart');
      final fn = src.substring(
        src.indexOf('Future<GoogleOutcome> signInWithGoogle'),
        src.indexOf('Future<GoogleOutcome> registerGoogleAccount'),
      );
      final check = fn.indexOf('if (profile.role != role)');
      final start = fn.indexOf('SessionService.instance.start(user.uid)');
      expect(check, greaterThan(0));
      expect(start, greaterThan(check));
      expect(fn, contains('GoogleNotRegistered('));
    });

    test('a child chip keeps family-wide alerts', () {
      expect(
        read('lib/screens/parent/parent_notifications.dart'),
        contains('_childOf(n) == null || _childOf(n) == childId'),
      );
    });

    test('a completed ride counts towards rating the driver', () {
      expect(
        read('lib/app/parent_data_service.dart'),
        contains('r.status == AttendanceStatus.droppedOff'),
      );
    });

    test('every missed-bus step is pushed to the other side', () {
      final src = read('lib/app/missed_bus_service.dart');
      for (final step in [
        'Future<void> sendBid',
        'Future<void> acceptOffer',
        'Future<void> rejectOffer',
        'Future<void> markPickedUp',
        'Future<void> markCompleted',
      ]) {
        final body = src.substring(src.indexOf(step));
        final end = body.indexOf('\n  }\n');
        expect(
          body.substring(0, end),
          anyOf(contains('_tellFamily('), contains('_tellDriver(')),
          reason: step,
        );
      }
      expect(src, contains("route: '/driver/missed-bus-job'"));
    });

    test('the driver can start a chat from a passenger', () {
      expect(
        read('lib/screens/driver/driver_booked_students_screen.dart'),
        contains('_ChatButtons(student: student)'),
      );
    });
  });
}
