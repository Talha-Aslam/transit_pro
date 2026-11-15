import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:transit_core/transit_core.dart';

import '../data/user_repository.dart';
import 'notification_service.dart';
import 'router.dart';
import 'session_service.dart';

/// Registers this device for push notifications: requests OS permission,
/// then saves the token onto `users/{uid}.fcmTokens` via
/// `UserRepository.addFcmToken` — which already existed but had no caller
/// until now, since nothing in the app ever ran `FirebaseMessaging`.
///
/// The sending half is the Cloudflare Worker in `push_worker/` — see its
/// README. It holds the service account key that a client APK must never
/// contain, reads the notification back out of Firestore, and sends it to
/// the tokens collected here.
///
/// This class also listens for pushes that land while the app is running,
/// which is what stops the same alert appearing twice: the Firestore inbox
/// stream raises its own banner for anything new, and without telling it
/// what FCM has already shown, a backgrounded app announces every
/// notification once per path.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  String? _boundUid;
  String? _registeredToken;
  StreamSubscription<String>? _refreshSub;

  /// Requests notification permission and saves this device's token.
  ///
  /// Called from `SessionService.start()` — the same single hook point
  /// `NotificationService.bindToUser` already uses, and for the same
  /// reason its doc comment gives: one call site that every sign-in path
  /// goes through, rather than one per `AuthService` method that a new
  /// path could forget.
  ///
  /// Best-effort and never throws: a denied permission, an unsupported
  /// platform, or a token fetch failure must not block sign-in — the app
  /// is fully usable without push, the same way it's fully usable without
  /// Cloudinary configured (see `CloudinaryService.isConfigured`).
  Future<void> registerForUser(String uid) async {
    if (_boundUid == uid && _registeredToken != null) return;
    _boundUid = uid;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push notifications: permission denied by the user.');
        return;
      }

      final token = await messaging.getToken();
      if (token == null) {
        debugPrint('Push notifications: getToken() returned null.');
        return;
      }

      _registeredToken = token;
      await UserRepository.instance.addFcmToken(uid, token);

      _listenForForegroundMessages();
      _listenForTaps();

      // Tokens rotate (reinstall, token expiry, app data cleared) — without
      // this, a device would silently stop receiving push after a rotation
      // with no error anywhere to explain why.
      await _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh.listen((newToken) async {
        _registeredToken = newToken;
        try {
          await UserRepository.instance.addFcmToken(uid, newToken);
        } catch (e) {
          debugPrint('Push notifications: token refresh save failed — $e');
        }
      });
    } catch (e) {
      debugPrint('Push notifications: registration failed — $e');
    }
  }

  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<RemoteMessage>? _tapSub;
  bool _initialTapHandled = false;

  /// A tapped push opens the screen it is about, not just the app.
  ///
  /// Covers both a tap while the app was in the background
  /// ([FirebaseMessaging.onMessageOpenedApp]) and a tap that launched it from
  /// closed ([FirebaseMessaging.getInitialMessage], once per process).
  void _listenForTaps() {
    _tapSub?.cancel();
    _tapSub = FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => unawaited(_openFromPush(m)),
      onError: (Object e) => debugPrint('Push notifications: onOpened — $e'),
    );
    if (_initialTapHandled) return;
    _initialTapHandled = true;
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) unawaited(_openFromPush(m));
    });
  }

  Future<void> _openFromPush(RemoteMessage message) async {
    final uid = _boundUid;
    final docId = message.data['docId'] as String?;
    final type = message.data['type'] as String?;
    var route = message.data['route'] as String?;

    // The push carries only the inbox id; the deep link is on the inbox item.
    if ((route == null || route.isEmpty) &&
        uid != null &&
        docId != null &&
        docId.isNotEmpty) {
      try {
        final item = (await Db.notifications(uid).doc(docId).get()).data();
        final r = item?.data['route'];
        if (r is String) route = r;
      } catch (e) {
        debugPrint('Push notifications: reading tapped item failed — $e');
      }
    }
    if (uid != null && docId != null && docId.isNotEmpty) {
      unawaited(
        MessagingRepository.instance.markRead(uid, docId).catchError((_) {}),
      );
    }

    final role = SessionService.instance.user.value?.role.name;
    if ((route == null || route.isEmpty) && type == 'chat' && role != null) {
      route = switch (role) {
        'driver' => '/driver/messages',
        'student' => '/student/driver-chat',
        _ => '/parent/driver-chat',
      };
    }
    if (route == null || !route.startsWith('/')) return;
    // Never follow a link into another role's screens.
    if (role != null && !route.startsWith('/$role')) return;

    final target = route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        appRouter.push(target);
      } catch (e) {
        debugPrint('Push notifications: opening $target failed — $e');
      }
    });
  }

  /// Notes every push that arrives while the app is alive.
  ///
  /// Android does not display an FCM `notification` payload itself while
  /// the app is in the foreground, so the inbox stream's banner is the one
  /// the user sees and nothing is suppressed. Backgrounded, the system tray
  /// shows it *and* the still-live Firestore listener would raise a second
  /// — which is the duplicate this prevents.
  void _listenForForegroundMessages() {
    _messageSub?.cancel();
    _messageSub = FirebaseMessaging.onMessage.listen((message) {
      NotificationService.instance.showForegroundPush(
        docId: message.data['docId'] as String?,
        title: message.notification?.title ?? 'Transit Pro',
        body: message.notification?.body ?? '',
        type: message.data['type'] as String?,
      );
    }, onError: (Object e) => debugPrint('Push notifications: onMessage — $e'));
  }

  /// Removes this device's token on sign-out, so a shared or reinstalled
  /// phone doesn't keep receiving push for an account no longer signed in
  /// on it. Mirrors `NotificationService.unbind()`'s reasoning.
  Future<void> unregisterForUser(String uid) async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    await _messageSub?.cancel();
    _messageSub = null;
    await _tapSub?.cancel();
    _tapSub = null;
    final token = _registeredToken;
    _boundUid = null;
    _registeredToken = null;
    if (token == null) return;
    try {
      await UserRepository.instance.removeFcmToken(uid, token);
    } catch (e) {
      debugPrint('Push notifications: unregister failed — $e');
    }
  }
}
