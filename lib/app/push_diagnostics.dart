import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';

import '../data/user_repository.dart';
import 'push_sender.dart';
import 'session_service.dart';

/// Sends this account a test push, end to end, and says plainly where it
/// stopped if it did not arrive: notifications switched off, no push token
/// on this phone, the push server unreachable, or the phone itself holding
/// it back.
///
/// Pushes travel through four parties — this phone, Firestore, the push
/// Worker and Google — and a missing one looks the same from the outside
/// whichever of them dropped it. This tells them apart.
Future<void> runPushTest(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text, {bool ok = false}) => messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 6),
      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
    ),
  );

  final uid = SessionService.instance.uid;
  if (uid == null) return;
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return say(
        'Notifications are switched off for Transit Pro. Turn them on in the '
        "phone's Settings → Apps → Transit Pro → Notifications.",
      );
    }
    final token = await messaging.getToken();
    if (token == null) {
      return say(
        'This phone has no push token. Check the internet connection and '
        'that Google Play services are up to date.',
      );
    }
    // Saved again in case it never was — the commonest reason a phone hears
    // nothing.
    await UserRepository.instance.addFcmToken(uid, token);

    final docId = await MessagingRepository.instance.push(
      uid,
      const UserNotification(
        id: '',
        type: NotificationType.system,
        title: 'Test notification',
        body: 'Push notifications reach this phone.',
      ),
    );
    final sent = await PushSender.instance.deliver(docId: docId, uids: [uid]);
    if (sent == null) {
      return say('The push server could not be reached. Try again shortly.');
    }
    if (sent == 0) {
      return say('The push server found no device for this account.');
    }
    say(
      'Sent. A test notification should appear now. If it never does, allow '
      "Transit Pro to auto-start and run in the background in the phone's "
      'battery settings.',
      ok: true,
    );
  } catch (e) {
    say('The test could not run: $e');
  }
}
