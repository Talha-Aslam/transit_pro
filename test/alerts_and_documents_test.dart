import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards for two fixes that are invisible in a widget test,
/// because each is about a screen doing something it previously did *not*.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('a tapped alert goes somewhere', () {
    // Both screens used to mark the notification read and stop there. A chat
    // alert left the family reading a 140-character preview with no way to
    // answer it, and a "seat confirmed" left them hunting for the driver it
    // was about even though the sender had put a route in the payload.
    const screens = {
      'lib/screens/parent/parent_notifications.dart': '/parent/driver-chat',
      'lib/screens/student/student_notifications.dart': '/student/driver-chat',
    };

    screens.forEach((path, chatRoute) {
      test('$path opens the conversation for a chat alert', () {
        final src = read(path);
        expect(src, contains('NotificationType.chat'));
        expect(src, contains("'$chatRoute'"));
        expect(
          src,
          contains('context.push(to)'),
          reason: 'the destination is computed but never navigated to',
        );
      });
    });

    test('both chat routes exist in the router', () {
      final router = read('lib/app/router.dart');
      for (final route in ['/parent/driver-chat', '/student/driver-chat']) {
        expect(router, contains("path: '$route'"));
      }
    });

    test('a student marking an alert read persists it', () {
      // The optimistic local flag was all this screen did, so every
      // notification a student opened came back unread on the next snapshot.
      expect(
        read('lib/screens/student/student_notifications.dart'),
        contains('_svc.markRead(notif)'),
      );
    });

    test('an SOS is louder than a fee reminder', () {
      final src = read('lib/app/notification_service.dart');
      expect(src, contains('transit_pro_emergency'));
      expect(src, contains('Importance.max'));
    });

    test('the domain type survives into the UI model', () {
      // `type` is one of three display buckets, so a chat message and a fee
      // reminder are both `info` — not enough to decide where a tap goes.
      final src = read('lib/app/notification_service.dart');
      expect(src, contains('final NotificationType? kind;'));
      expect(src, contains('kind: n.type,'));
      expect(
        src,
        contains('kind: kind,'),
        reason: 'copyWith drops it, so marking read loses the destination',
      );
    });
  });

  group('driver documents', () {
    test('neither removed document is offered any more', () {
      final src = read('lib/screens/driver/driver_documents_screen.dart');
      expect(src, isNot(contains('School Contract')));
      expect(src, isNot(contains('Route Permit')));
      expect(src, contains('Driving License'));
      expect(src, contains('Medical Fitness Certificate'));
    });

    test('"All verified" is gated on every required document', () {
      // This counted only the documents that happened to exist, so one
      // uploaded-and-approved document out of four read as fully checked out.
      final src = read('lib/screens/driver/driver_profile.dart');
      expect(src, contains('kRequiredDriverDocuments'));
      expect(src, contains('not uploaded'));
    });
  });
}
