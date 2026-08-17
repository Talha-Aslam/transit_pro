import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:transit_core/transit_core.dart';

import 'db.dart';

/// Notification inbox and one-to-one chat.
///
/// Replaces the three canned "echo bot" chat screens with a real Firestore
/// thread — roughly a day's work and the messages actually reach the other
/// person's phone.
class MessagingRepository {
  MessagingRepository._();
  static final MessagingRepository instance = MessagingRepository._();

  // ── Notifications ─────────────────────────────────────────────────────────

  Stream<List<UserNotification>> watchNotifications(String uid, {int limit = 100}) =>
      Db.notifications(uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .docsList;

  Stream<int> watchUnreadCount(String uid) => Db.notifications(uid)
      .where('read', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);

  /// Writes an in-app notification. Cross-device *push* is FCM's job — this is
  /// the inbox record that survives the notification being dismissed.
  Future<void> push(String uid, UserNotification notification) async {
    final ref = await Db.notifications(uid).add(notification);
    await ref.update({'createdAt': Db.now});
  }

  /// Fans one notification out to several recipients in a single commit —
  /// e.g. alerting every parent on a route that the bus is delayed.
  Future<void> pushToMany(
    List<String> uids,
    UserNotification notification,
  ) async {
    final batch = Db.fs.batch();
    for (final uid in uids) {
      final ref =
          Db.fs.collection('notifications').doc(uid).collection('items').doc();
      batch.set(ref, {...notification.toMap(), 'createdAt': Db.now});
    }
    await batch.commit();
  }

  Future<void> markRead(String uid, String notificationId) => Db.fs
      .collection('notifications')
      .doc(uid)
      .collection('items')
      .doc(notificationId)
      .update({'read': true});

  Future<void> markAllRead(String uid) async {
    final snap = await Db.notifications(uid).where('read', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;
    final batch = Db.fs.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  /// Returns the thread id, creating the thread on first message.
  ///
  /// The id is derived from the two uids, so the same pair always lands on the
  /// same thread without a lookup query.
  Future<String> ensureThread(String uidA, String uidB) async {
    final chatId = ChatThread.idFor(uidA, uidB);
    final doc = Db.chats.doc(chatId);
    if (!(await doc.get()).exists) {
      await Db.fs.collection('chats').doc(chatId).set({
        'participants': [uidA, uidB]..sort(),
        'lastMessage': '',
        'unreadCounts': {uidA: 0, uidB: 0},
        'updatedAt': Db.now,
      });
    }
    return chatId;
  }

  Stream<List<ChatMessage>> watchMessages(String chatId, {int limit = 200}) =>
      Db.messages(chatId)
          .orderBy('sentAt', descending: false)
          .limit(limit)
          .snapshots()
          .docsList;

  Stream<List<ChatThread>> watchThreadsFor(String uid) => Db.chats
      .where('participants', arrayContains: uid)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .docsList;

  /// Appends a message and updates the thread summary in one commit, so the
  /// list preview can never disagree with the thread contents.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String recipientId,
    required String text,
    String? imageUrl,
  }) async {
    final batch = Db.fs.batch();

    final msgRef =
        Db.fs.collection('chats').doc(chatId).collection('messages').doc();
    batch.set(msgRef, {
      'senderId': senderId,
      'text': text,
      'imageUrl': ?imageUrl,
      'readBy': [senderId],
      'sentAt': Db.now,
    });

    batch.set(
      Db.fs.collection('chats').doc(chatId),
      {
        'lastMessage': text,
        'lastSenderId': senderId,
        'updatedAt': Db.now,
        'unreadCounts': {recipientId: FieldValue.increment(1)},
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> markThreadRead(String chatId, String uid) => Db.fs
      .collection('chats')
      .doc(chatId)
      .set({'unreadCounts': {uid: 0}}, SetOptions(merge: true));
}
