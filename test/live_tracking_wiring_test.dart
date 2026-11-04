import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Integration check over the live-tracking chain.
///
/// The driver publishes a position to `liveLocations/{busId}`; a watching
/// family resolves which bus to follow from `trip.busId`. Those are two
/// separate expressions in two separate files, and for a while they
/// disagreed: the broadcast fell back to the driver's uid while the trip
/// stored `''`, so a self-signup driver with no admin `Bus` document
/// broadcast into a node nobody could name. Nothing failed — the family
/// simply never saw a bus.
///
/// There is no Firebase in a unit test, so these assert the wiring in the
/// source instead: the links that have no compiler or runtime check of
/// their own, and that went wrong silently when they broke.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('driver broadcast', () {
    late final String route;
    setUpAll(() => route = read('lib/screens/driver/driver_route.dart'));

    test('starting a route starts the broadcast', () {
      expect(route, contains('_startBroadcast'));
      expect(route, contains('startBroadcast('));
    });

    test('the trip records the same bus key the broadcast uses', () {
      // Both must resolve a missing Bus document the same way, or the
      // family looks for the wrong node.
      final matches = RegExp(r'busId: _session\.bus\.value\?\.id \?\? (\w+)')
          .allMatches(route)
          .map((m) => m.group(1))
          .toSet();
      expect(
        matches,
        {'uid'},
        reason: 'trip.busId and the RTDB broadcast key must agree; found '
            '$matches',
      );
      expect(matches.length, 1);
    });

    test('ending a route stops the broadcast', () {
      // `TrackingService.stop()` calls `stopBroadcast()`, so the bus leaves
      // every watching map when the round closes.
      expect(
        read('lib/app/tracking_service.dart'),
        contains('stopBroadcast()'),
      );
    });

    test('the published ping carries the trip it belongs to', () {
      expect(read('lib/app/tracking_service.dart'), contains('tripId:'));
    });
  });

  group('family side', () {
    test('somebody actually reads liveLocations', () {
      // For most of this project's life, nothing did: the driver published
      // and no screen subscribed.
      final readers = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('live_location_repository.dart'))
          .where((f) {
            final src = f.readAsStringSync();
            return src.contains('LiveLocationRepository.instance') &&
                src.contains('.watchBus(');
          })
          .toList();
      expect(
        readers,
        isNotEmpty,
        reason: 'the driver broadcasts to RTDB but nothing subscribes',
      );
    });

    for (final screen in const [
      'lib/screens/parent/parent_dashboard.dart',
      'lib/screens/student/student_dashboard.dart',
    ]) {
      test('${screen.split('/').last} follows the live bus', () {
        final src = read(screen);
        expect(src, contains('LiveBusService'));
        expect(src, contains('watchActiveTripForDriver'));
      });

      test('${screen.split('/').last} no longer shows the local ETA', () {
        // `TrackingService.etaMinutes` is a local notifier seeded with 8
        // that only the driver's own device advances. Reading it on a
        // family screen is what made the dashboard say "8 min to school"
        // with no route running.
        final src = read(screen);
        expect(
          src.contains('TrackingService.instance.etaMinutes'),
          isFalse,
          reason: '$screen must read LiveBusService, not the local '
              'TrackingService',
        );
      });

      test('${screen.split('/').last} distinguishes "not started" from '
          '"no fix yet"', () {
        final src = read(screen);
        // Both states are localised now, so assert the keys rather than
        // the English copy — the point is that the two are distinguished at
        // all, not what either one says in one language.
        // `dart format` may wrap the argument onto its own line, so match
        // the key rather than the whole call.
        expect(src, contains("'route_not_started'"));
        expect(src, contains("'waiting_for_bus"));
      });
    }
  });

  group('attendance manifest', () {
    test('a trip and its attendance rows commit together', () {
      final repo = read('lib/data/trip_repository.dart');
      expect(repo, contains('Db.fs.batch()'));
      expect(repo, contains('batch.commit()'));
    });

    test('each attendance row carries the driver that wrote it', () {
      // The Firestore rule for the seeding case falls back to this field,
      // because the parent trip does not exist yet while the batch is
      // checked. Drop it and Start Route returns PERMISSION_DENIED again.
      expect(read('lib/data/trip_repository.dart'), contains('driverId: driverId'));
      expect(read('firestore.rules'), contains('request.resource.data.driverId == uid()'));
    });

    test('the rule still refuses an attendance row under someone '
        'else\'s trip', () {
      final rules = read('firestore.rules');
      expect(rules, contains('.data.driverId == uid()'));
      expect(rules, contains('exists(/databases/\$(database)/documents/trips/\$(tripId))'));
    });
  });
}
