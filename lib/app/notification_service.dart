import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:transit_core/transit_core.dart';

import 'geofence_service.dart';
import 'language_provider.dart';

/// Called when the user taps a notification while the app is terminated.
/// Must be a top-level function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
void _onNotificationTapBackground(NotificationResponse response) {
  // The OS will relaunch the app; normal routing takes over.
}

/// Notification item for in-app display.
class AppNotification {
  final int id;
  final String type;
  final String icon;
  final String title;
  final String message;
  final String time;
  final String date;
  final Color color;
  bool read;

  /// The `notifications/{uid}/items/{docId}` id this came from, or null for a
  /// device-local notification (a geofence alert raised by this phone).
  ///
  /// Marking read has to reach Firestore for a remote item, or it comes back
  /// unread on the next snapshot. A local item has nowhere to write to, so the
  /// nullability is the distinction the read handlers key on.
  final String? docId;

  /// Deep-link payload from the sender, e.g. `{'route': '/driver/ride-requests'}`.
  final Map<String, dynamic> data;

  AppNotification({
    required this.id,
    required this.type,
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    required this.date,
    required this.color,
    this.read = false,
    this.docId,
    this.data = const {},
  });

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    type: type,
    icon: icon,
    title: title,
    message: message,
    time: time,
    date: date,
    color: color,
    read: read ?? this.read,
    docId: docId,
    data: data,
  );
}

/// Singleton that manages both local push notifications and in-app history.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// What the three notification screens render. Always the merge of
  /// [_remote] and [_local] — never assigned from anywhere else, so a Firestore
  /// snapshot cannot wipe out a geofence alert this device just raised.
  final history = ValueNotifier<List<AppNotification>>([]);
  int _nextId = 100;

  bool _initialised = false;

  /// Firestore inbox items — written by whoever wanted to reach this user (a
  /// driver answering a request, a parent sending one).
  List<AppNotification> _remote = const [];

  /// Notifications raised by this device only: geofence crossings, local
  /// reminders. They have no Firestore document behind them, so they live here
  /// and are lost on restart — which is correct, they describe a moment that has
  /// passed.
  List<AppNotification> _local = const [];

  StreamSubscription<List<UserNotification>>? _inboxSub;
  String? _boundUid;

  /// Doc ids already seen on this stream, so a reconnect or an unrelated field
  /// update on an existing item never re-fires its banner.
  Set<String> _seenRemoteIds = {};

  /// True until the first snapshot for the current bind has been processed.
  /// Without this, every notification already sitting in the inbox at sign-in
  /// would re-play as a fresh system banner.
  bool _isFirstSnapshot = true;

  /// Initialise the notification plugin. Safe to call multiple times.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapBackground,
    );
  }

  // ── Firestore inbox ───────────────────────────────────────────────────────

  /// Starts streaming `notifications/{uid}/items` into [history].
  ///
  /// ## Why this is the notification mechanism, and not FCM
  ///
  /// Reaching another user's device with a *push* needs a trusted sender — a
  /// Cloud Function, or a server holding the FCM server key. Shipping that key in
  /// the client would give every installed APK the ability to push to any user,
  /// so it cannot live here. This project has no server component, so the inbox
  /// document is the real cross-device path available today: it is written by the
  /// sender, it arrives on this stream within a second, it survives being
  /// dismissed, and it is exactly the payload a Cloud Function would later
  /// forward. When one is added it should trigger on writes to this collection
  /// rather than reimplementing the triggers.
  ///
  /// Safe to call repeatedly. Called from `main.dart`'s session bootstrap and
  /// again on sign-in, so it must be idempotent per uid.
  void bindToUser(String uid) {
    if (_boundUid == uid && _inboxSub != null) return;
    unbind();
    _boundUid = uid;
    _isFirstSnapshot = true;
    _inboxSub = MessagingRepository.instance
        .watchNotifications(uid)
        .listen(
          (items) {
            final incoming = items.map(_fromFirestore).toList();

            // Anything with a docId we haven't seen on this stream yet just
            // arrived from another device (a driver's alert, a ride-request
            // reply, a route event) — that is exactly the case with no on-screen
            // owner to raise a banner itself, so this stream does it instead.
            // Skipped on the first snapshot after bind: that one is the existing
            // inbox catching up, not new arrivals.
            if (!_isFirstSnapshot) {
              for (final n in incoming) {
                if (n.docId != null &&
                    !_seenRemoteIds.contains(n.docId) &&
                    !n.read) {
                  unawaited(_pushSystemNotification(n));
                }
              }
            }
            _isFirstSnapshot = false;
            _seenRemoteIds = {
              for (final n in incoming)
                if (n.docId != null) n.docId!,
            };

            _remote = incoming;
            _publish();
          },
          onError: (Object e) {
            debugPrint('NotificationService: inbox stream failed — $e');
            // Leave whatever is already on screen. An unreadable inbox is not worth
            // blanking the list the user is reading, and the stream retries itself.
          },
        );
  }

  /// Called on sign-out. Drops both lists: notifications are per-account, and
  /// leaving them would show one family's alerts to the next person to sign in on
  /// a shared phone.
  void unbind() {
    _inboxSub?.cancel();
    _inboxSub = null;
    _boundUid = null;
    _remote = const [];
    _local = const [];
    _seenRemoteIds = {};
    _isFirstSnapshot = true;
    _publish();
  }

  /// Raises a system-tray banner (sound + vibration, per [Importance.high])
  /// for an item that already has a Firestore document behind it. Distinct
  /// from [show]: this never touches [_local] or [_remote] — the item is
  /// already in the stream that fed [_publish], so adding it again would
  /// duplicate it in the list.
  Future<void> _pushSystemNotification(AppNotification n) async {
    const androidDetails = AndroidNotificationDetails(
      'transit_pro_channel',
      'Transit Pro',
      channelDescription: 'Bus tracking notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    // Plugin notification ids are 32-bit; a docId's hashCode can exceed that
    // range, so fold it down rather than truncating silently.
    final notifId = n.docId.hashCode & 0x7fffffff;
    await _plugin.show(notifId, n.title, n.message, details);
  }

  /// Newest first across both sources.
  void _publish() {
    history.value = [..._remote, ..._local]
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  AppNotification _fromFirestore(UserNotification n) {
    final (icon, color) = _appearanceFor(n.type);
    final created = n.createdAt;
    return AppNotification(
      // Sort key as well as plugin id. Using the creation time in milliseconds
      // makes the merge in [_publish] order correctly against locally-raised
      // notifications without either source knowing about the other. A document
      // whose server timestamp has not landed yet sorts newest, which is right —
      // it is the one that just arrived.
      id:
          created?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
      type: _uiTypeFor(n.type),
      icon: icon,
      title: n.title,
      message: n.body,
      time: _timeLabel(created),
      date: _dateLabel(created),
      color: color,
      read: n.read,
      docId: n.id,
      data: n.data,
    );
  }

  /// Maps the domain type onto the three buckets the notification screens filter
  /// by. Anything unrecognised reads as `info` rather than being hidden.
  static String _uiTypeFor(NotificationType type) => switch (type) {
    NotificationType.emergency ||
    NotificationType.missedBus ||
    NotificationType.absent ||
    NotificationType.delay => 'alert',
    NotificationType.boarded ||
    NotificationType.busArrived ||
    NotificationType.routeCompleted ||
    NotificationType.pickupAssigned ||
    NotificationType.payment => 'success',
    _ => 'info',
  };

  static (String, Color) _appearanceFor(NotificationType type) =>
      switch (type) {
        NotificationType.emergency => ('🚨', Color(0xFFEF4444)),
        NotificationType.missedBus => ('🚌', Color(0xFFEF4444)),
        NotificationType.absent => ('⚠️', Color(0xFFF59E0B)),
        NotificationType.delay => ('⏰', Color(0xFFF59E0B)),
        NotificationType.boarded => ('✅', Color(0xFF10B981)),
        NotificationType.busArrived => ('🏫', Color(0xFF10B981)),
        NotificationType.busApproaching => ('🔔', Color(0xFFF59E0B)),
        NotificationType.busDeparted => ('🚌', Color(0xFF3B82F6)),
        NotificationType.routeStarted => ('📍', Color(0xFF3B82F6)),
        NotificationType.routeCompleted => ('🌇', Color(0xFF10B981)),
        NotificationType.pickupAssigned => ('🧑‍✈️', Color(0xFF10B981)),
        NotificationType.rideRequest => ('📬', Color(0xFFF59E0B)),
        NotificationType.rideRequestAnswered => ('📨', Color(0xFF3B82F6)),
        NotificationType.payment => ('💳', Color(0xFF10B981)),
        NotificationType.document => ('📜', Color(0xFF8B5CF6)),
        NotificationType.chat => ('💬', Color(0xFF3B82F6)),
        NotificationType.system => ('🔔', Color(0xFF3B82F6)),
        NotificationType.adminMessage => ('🛡️', Color(0xFF8B5CF6)),
      };

  static String _timeLabel(DateTime? when) {
    if (when == null) return 'Just now';
    final hour12 = when.hour % 12 == 0 ? 12 : when.hour % 12;
    final minute = when.minute.toString().padLeft(2, '0');
    return '$hour12:$minute ${when.hour < 12 ? 'AM' : 'PM'}';
  }

  static String _dateLabel(DateTime? when) {
    if (when == null) return 'Today';
    final now = DateTime.now();
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(when.year, when.month, when.day)).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[when.weekday - 1]}, '
        '${months[when.month - 1]} ${when.day}';
  }

  /// Show a local push notification and add to in-app history.
  Future<void> show({
    required String title,
    required String body,
    String type = 'info',
    String icon = '🔔',
    Color color = Colors.blue,
  }) async {
    final id = _nextId++;

    // Push notification
    const androidDetails = AndroidNotificationDetails(
      'transit_pro_channel',
      'Transit Pro',
      channelDescription: 'Bus tracking notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);

    // In-app history
    final now = TimeOfDay.now();
    final timeStr =
        '${now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';

    final notif = AppNotification(
      // Millisecond timestamp, not the plugin's `id`, so this sorts correctly
      // against Firestore items in [_publish] — those key off `createdAt`.
      id: DateTime.now().millisecondsSinceEpoch,
      type: type,
      icon: icon,
      title: title,
      message: body,
      time: timeStr,
      date: 'Today',
      color: color,
    );

    _local = [notif, ..._local];
    _publish();
  }

  /// Convert a geofence alert into a notification.
  Future<void> fromGeofence(GeofenceAlert alert) async {
    String title;
    String body;
    String icon;
    Color color;

    switch (alert.event) {
      case GeofenceEvent.approaching:
        final mins = ((alert.distance / 50).round()).toString();
        title = AppStrings.t(
          'geofence_approaching_title',
        ).replaceAll('{stop}', alert.stop.name);
        body = AppStrings.t(
          'geofence_approaching_body',
        ).replaceAll('{stop}', alert.stop.name).replaceAll('{mins}', mins);
        icon = '🔔';
        color = const Color(0xFFF59E0B);
        break;
      case GeofenceEvent.arrived:
        title = AppStrings.t(
          'geofence_arrived_title',
        ).replaceAll('{stop}', alert.stop.name);
        body = AppStrings.t(
          'geofence_arrived_body',
        ).replaceAll('{stop}', alert.stop.name);
        icon = '✅';
        color = const Color(0xFF10B981);
        break;
      case GeofenceEvent.departed:
        title = AppStrings.t(
          'geofence_departed_title',
        ).replaceAll('{stop}', alert.stop.name);
        body = AppStrings.t(
          'geofence_departed_body',
        ).replaceAll('{stop}', alert.stop.name);
        icon = '🚌';
        color = const Color(0xFF3B82F6);
        break;
    }

    await show(
      title: title,
      body: body,
      type: alert.event == GeofenceEvent.approaching ? 'alert' : 'info',
      icon: icon,
      color: color,
    );
  }

  /// Marks everything read, in Firestore as well as on screen.
  ///
  /// The optimistic local update stays — the badge should clear on tap, not a
  /// round trip later — but without the Firestore write every remote item comes
  /// straight back unread on the next snapshot, which is what made the old
  /// in-memory-only version look broken as soon as real data arrived.
  Future<void> markAllRead() async {
    _remote = _remote.map((n) => n.copyWith(read: true)).toList();
    _local = _local.map((n) => n.copyWith(read: true)).toList();
    _publish();

    final uid = _boundUid;
    if (uid == null) return;
    try {
      await MessagingRepository.instance.markAllRead(uid);
    } catch (e) {
      debugPrint('NotificationService: markAllRead failed — $e');
    }
  }

  /// Marks one item read. A no-op for a device-local notification, which has no
  /// document to update.
  Future<void> markRead(AppNotification notification) async {
    final uid = _boundUid;
    final docId = notification.docId;
    if (uid == null || docId == null) return;
    try {
      await MessagingRepository.instance.markRead(uid, docId);
    } catch (e) {
      debugPrint('NotificationService: markRead failed — $e');
    }
  }

  int get unreadCount => history.value.where((n) => !n.read).length;
}
