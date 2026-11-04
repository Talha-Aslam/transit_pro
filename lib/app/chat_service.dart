import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import 'push_sender.dart';

/// Sending a chat message, including the part that makes it arrive.
///
/// `MessagingRepository.sendMessage` writes the message and updates the
/// thread summary, which is enough for somebody already sitting on the
/// thread. It is not enough for anybody else: a parent messaging their
/// driver at 6am about a child who is off sick needs the driver's phone to
/// ring, not a badge the driver will see after the round. This pairs the
/// write with a notification into the recipient's inbox, which the push
/// Worker then delivers to a closed app.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  /// Sends [text] from [senderId] to [recipientId], creating the thread if
  /// this is the first message, and alerting the recipient.
  ///
  /// [senderName] is what the notification is titled with — the recipient
  /// needs to know who is messaging them from the lock screen, and the
  /// thread id is two opaque uids.
  ///
  /// [route] is the deep link the notification carries, so tapping it opens
  /// the conversation rather than the notification list.
  ///
  /// [studentId] is the child the conversation is about. A parent with two
  /// children riding with one driver otherwise had both in a single thread,
  /// where "he has a fever today" named nobody.
  ///
  /// Returns the thread id. Throws only if the *message* failed to send:
  /// the alert is best-effort, because a message that arrived without a
  /// banner is a late message, not a lost one.
  Future<String> send({
    required String senderId,
    required String recipientId,
    required String text,
    required String senderName,
    String? senderRole,
    String? route,
    String? studentId,
  }) async {
    final chatId = await MessagingRepository.instance.ensureThread(
      senderId,
      recipientId,
      studentId: studentId,
    );
    await MessagingRepository.instance.sendMessage(
      chatId: chatId,
      senderId: senderId,
      recipientId: recipientId,
      text: text,
      senderRole: senderRole,
    );

    try {
      await PushSender.instance.notifyOne(
        recipientId,
        UserNotification(
          id: '',
          type: NotificationType.chat,
          title: senderName.trim().isEmpty ? 'New message' : senderName.trim(),
          // A preview, not the whole essay — a lock screen truncates
          // anyway, and the thread is one tap away.
          body: text.length > 140 ? '${text.substring(0, 139)}…' : text,
          data: {'chatId': chatId, 'route': ?route},
        ),
      );
    } catch (e) {
      debugPrint('ChatService: alert for $chatId failed — $e');
    }

    return chatId;
  }
}
