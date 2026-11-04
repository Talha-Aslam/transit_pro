import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:transit_core/transit_core.dart';

/// Asks the push Worker to deliver a notification the app has just written.
///
/// Writing `notifications/{uid}/items/{docId}` is what puts an alert in
/// someone's inbox; a device with the app open raises its own banner from
/// that stream. A phone that is asleep, or has the app closed, hears nothing
/// — and for a bus-tracking app that is most of the time it matters. This
/// closes that half.
///
/// It sends only the document id and the recipients. The Worker reads the
/// document back and delivers exactly what is stored, so a caller cannot use
/// this to put arbitrary words on a parent's lock screen.
///
/// Every method here is best-effort and never throws: the inbox record is
/// already committed by the time this runs, so a failed push means a late
/// notification, not a lost one. With no Worker URL configured the app
/// behaves exactly as it did before — in-app banners only.
class PushSender {
  PushSender._();
  static final PushSender instance = PushSender._();

  /// Overridable for tests.
  @visibleForTesting
  http.Client client = http.Client();

  bool get isConfigured => AppConfig.pushWorkerUrl.isNotEmpty;

  /// Delivers the notification [docId] to [uids].
  ///
  /// Returns the number of devices reached, or null when the send could not
  /// be attempted at all (no Worker configured, nobody signed in).
  Future<int?> deliver({
    required String docId,
    required List<String> uids,
  }) async {
    if (!isConfigured || docId.isEmpty || uids.isEmpty) return null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      // The Worker verifies this against Google's published keys, so it can
      // tell a real signed-in user of this project from anyone who found
      // the URL.
      final idToken = await user.getIdToken();
      if (idToken == null) return null;

      final response = await client
          .post(
            Uri.parse('${AppConfig.pushWorkerUrl}/send'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: json.encode({'docId': docId, 'uids': uids}),
          )
          // A push that is still in flight after this is not worth blocking
          // the UI for; the inbox record has already landed.
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        debugPrint(
          'PushSender: worker returned ${response.statusCode} — '
          '${response.body}',
        );
        return null;
      }
      final body = json.decode(response.body) as Map<String, dynamic>;
      return (body['sent'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('PushSender: delivery failed — $e');
      return null;
    }
  }

  /// Writes a notification to one recipient's inbox and pushes it.
  Future<void> notifyOne(String uid, UserNotification notification) async {
    if (uid.trim().isEmpty) return;
    try {
      final docId = await MessagingRepository.instance.push(uid, notification);
      unawaited(deliver(docId: docId, uids: [uid]));
    } catch (e) {
      debugPrint('PushSender.notifyOne failed — $e');
    }
  }

  /// Writes a notification to several inboxes and pushes it to all of them.
  ///
  /// Returns how many inboxes were written, which is the number that matters
  /// for "did this reach anyone" — delivery to a sleeping phone follows and
  /// is reported separately in the debug log.
  Future<int> notifyMany(
    List<String> uids,
    UserNotification notification,
  ) async {
    final recipients = uids
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toSet()
        .toList();
    if (recipients.isEmpty) return 0;
    try {
      final docId = await MessagingRepository.instance.pushToMany(
        recipients,
        notification,
      );
      unawaited(deliver(docId: docId, uids: recipients));
      return recipients.length;
    } catch (e) {
      debugPrint('PushSender.notifyMany failed — $e');
      return 0;
    }
  }
}
