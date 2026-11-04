import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transit_pro/widgets/avatar_image.dart';

/// Source-level guards for three bugs that are easy to reintroduce and
/// invisible in a widget test, because each is about what a screen *does
/// not* do.
void main() {
  final lib = Directory('lib');

  List<File> dartFiles(String under) => Directory(under)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  setUpAll(() {
    expect(lib.existsSync(), isTrue, reason: 'run from the package root');
  });

  group('alerts addressed to someone else never fire locally', () {
    // `NotificationService.show()` raises a banner on *this* phone. Using
    // it to "send" an alert is why a driver's SOS notified the driver, and
    // why the attendance screen's bulk alerts reached nobody at all. It is
    // still correct for a geofence crossing this device detected.
    const allowed = {
      // Raises the alert for the crossing this phone just detected.
      'lib/app/notification_service.dart',
      // The family's own "your child was picked up" confirmation, about
      // something that happened to them.
      'lib/screens/parent/pickup_dropoff_confirmation_screen.dart',
      'lib/screens/parent/emergency_alerts_screen.dart',
    };

    test('no driver screen raises a local banner to "send" an alert', () {
      final offenders = <String>[];
      for (final f in dartFiles('lib/screens/driver')) {
        final path = f.path.replaceAll(r'\', '/');
        if (allowed.contains(path)) continue;
        final src = f.readAsStringSync();
        if (src.contains('NotificationService.instance.show(') ||
            src.contains('_notifSvc.show(')) {
          offenders.add(path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'These send to the sender\'s own phone. Write the recipient\'s '
            'inbox through PushSender instead.',
      );
    });
  });

  group('driver screens read the real trip, not local tracking state', () {
    // `TrackingService.route != null` means "this phone is holding a route
    // object", which is not the same as "a trip is running". Deriving the
    // status chip from it is what made Driver -> Profile read
    // "Active - On Route" for a driver sitting at home.
    test('no driver screen derives route status from TrackingService', () {
      final offenders = <String>[];
      for (final f in dartFiles('lib/screens/driver')) {
        final src = f.readAsStringSync();
        if (src.contains('TrackingService.instance.route != null')) {
          offenders.add(f.path.replaceAll(r'\', '/'));
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Use ActiveTripService.instance.isOnRoute.',
      );
    });

    test('ActiveTripService is bound and unbound with the session', () {
      final session = File(
        'lib/app/session_service.dart',
      ).readAsStringSync();
      expect(session, contains('ActiveTripService.instance.bindToDriver('));
      expect(session, contains('ActiveTripService.instance.unbind()'));
    });
  });

  group('chat actually sends', () {
    test('neither chat screen fakes a reply with a Timer', () {
      for (final path in [
        'lib/screens/parent/driver_chat_screen.dart',
        'lib/screens/student/student_driver_chat.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(
          src.contains('has received it and will reply shortly'),
          isFalse,
          reason: '$path still answers itself instead of sending.',
        );
        expect(
          src,
          contains('ConversationScreen'),
          reason: '$path should delegate to the real thread.',
        );
      }
    });

    test('the rules accept the roles the app actually sends', () {
      // `ChatService` stamps 'driver' / 'parent' / 'student' on each
      // message. The rule used to allow only 'user', so every message a
      // driver or a family sent would have been rejected — and the screen
      // would have looked exactly as broken as the fake one it replaced.
      final rules = File('firestore.rules').readAsStringSync();
      for (final role in ['parent', 'student', 'driver']) {
        expect(
          rules,
          contains("'$role'"),
          reason: 'firestore.rules refuses senderRole $role',
        );
      }
      // The impersonation guard this widened must still hold.
      expect(rules, isNot(contains("senderRole == 'ai'")));
    });

    test('sending a message alerts the recipient', () {
      final src = File('lib/app/chat_service.dart').readAsStringSync();
      expect(src, contains('MessagingRepository.instance.sendMessage('));
      expect(src, contains('PushSender.instance.notifyOne('));
    });
  });

  group('AvatarImage photo precedence', () {
    testWidgets('falls back when there is no photo at all', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AvatarImage(
            localFile: null,
            photoUrl: null,
            size: 44,
            fallback: Text('🧒'),
          ),
        ),
      );
      expect(find.text('🧒'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('an empty URL is treated as no photo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AvatarImage(
            localFile: null,
            photoUrl: '',
            size: 44,
            fallback: Text('🧒'),
          ),
        ),
      );
      expect(find.text('🧒'), findsOneWidget);
    });

    testWidgets('a stored URL renders rather than the fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AvatarImage(
            localFile: null,
            photoUrl: 'https://example.invalid/photo.jpg',
            size: 44,
            fallback: Text('🧒'),
          ),
        ),
      );
      // The network fetch fails in a test, but the widget tree is what
      // matters: an Image was built from the URL, which is the half that
      // was missing everywhere and made photos vanish on restart.
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('uploading draws a spinner over the avatar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AvatarImage(
            localFile: null,
            photoUrl: null,
            size: 44,
            uploading: true,
            fallback: Text('🧒'),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    test('riderGlyph tells a university rider from a school child', () {
      expect((riderGlyph('University') as Text).data, '🎓');
      expect((riderGlyph('college') as Text).data, '🎓');
      expect((riderGlyph('School') as Text).data, '🧒');
      expect((riderGlyph('') as Text).data, '🧒');
    });
  });

  group('every rider and driver avatar reads a photo', () {
    // Each of these drew a bare emoji, so a photo that had been uploaded
    // and saved was never shown to anybody.
    const sites = [
      'lib/screens/driver/driver_profile.dart',
      'lib/screens/driver/driver_attendance.dart',
      'lib/screens/driver/driver_booked_students_screen.dart',
      'lib/screens/driver/driver_ride_requests_screen.dart',
      'lib/screens/parent/driver_details_screen.dart',
      'lib/screens/student/student_driver_details_screen.dart',
      'lib/screens/parent/find_drivers_screen.dart',
    ];

    for (final path in sites) {
      test('$path uses AvatarImage', () {
        expect(File(path).readAsStringSync(), contains('AvatarImage('));
      });
    }

    test('a seat request carries the rider photo to the driver', () {
      // The driver has no read access to a student who is only *asking*
      // for a seat, so the photo has to travel on the request itself.
      expect(
        File('lib/data/ride_request_repository.dart').readAsStringSync(),
        contains('studentPhotoUrl: student.photoUrl'),
      );
    });
  });
}
