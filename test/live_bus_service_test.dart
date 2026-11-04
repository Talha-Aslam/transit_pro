import 'package:flutter_test/flutter_test.dart';
import 'package:transit_pro/app/live_bus_service.dart';

/// `RouteService.fetchDistanceDuration` hands back a human string, not a
/// number, so the dashboards depend on reading minutes back out of it. Every
/// shape `_formatDuration` can produce is covered here, because a miss shows
/// up on screen as "--" next to a bus that is plainly moving.
void main() {
  group('parseDurationMinutes', () {
    test('reads plain minutes', () {
      expect(parseDurationMinutes('7 min'), 7);
      expect(parseDurationMinutes('45 min'), 45);
    });

    test('reads a whole number of hours', () {
      expect(parseDurationMinutes('1 hr'), 60);
      expect(parseDurationMinutes('2 hr'), 120);
    });

    test('adds hours and minutes together', () {
      expect(parseDurationMinutes('1 hr 12 min'), 72);
      expect(parseDurationMinutes('2 hr 5 min'), 125);
    });

    test('accepts the longer spellings other formatters use', () {
      expect(parseDurationMinutes('7 minutes'), 7);
      expect(parseDurationMinutes('1 hour 30 minutes'), 90);
      expect(parseDurationMinutes('3 mins'), 3);
    });

    test('is case insensitive', () {
      expect(parseDurationMinutes('1 HR 20 MIN'), 80);
    });

    test('rounds a sub-minute trip to the nearest sensible minute', () {
      expect(parseDurationMinutes('45 secs'), 1);
      expect(parseDurationMinutes('12 secs'), 0);
    });

    test('zero stays zero rather than becoming unknown', () {
      // "0 min" is a real answer — the bus is at the stop. Returning null
      // here would make the card show "--" at the one moment it matters.
      expect(parseDurationMinutes('0 min'), 0);
    });

    test('returns null when there is no number to read', () {
      expect(parseDurationMinutes(''), isNull);
      expect(parseDurationMinutes('unknown'), isNull);
      expect(parseDurationMinutes('--'), isNull);
    });
  });

  group('LiveBusService initial state', () {
    test('starts following nothing, with no position and no ETA', () {
      final svc = LiveBusService.instance;
      expect(svc.isFollowing.value, isFalse);
      expect(svc.busId, isNull);
      expect(svc.position.value, isNull);
      // Null, never a number: the whole bug this service exists to fix was a
      // notifier seeded with 8 that read as a real ETA on a dashboard where
      // no trip was running.
      expect(svc.etaMinutes.value, isNull);
      expect(svc.distanceLabel.value, isNull);
    });

    test('stop() is safe to call when nothing is being followed', () {
      final svc = LiveBusService.instance;
      svc.stop();
      svc.stop();
      expect(svc.isFollowing.value, isFalse);
      expect(svc.position.value, isNull);
    });

    test('an empty busId is not followed', () {
      final svc = LiveBusService.instance;
      svc.follow(busId: '');
      expect(svc.isFollowing.value, isFalse);
      expect(svc.busId, isNull);
    });
  });
}
