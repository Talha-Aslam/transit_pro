import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../data/user_repository.dart';

/// Registers this device for push notifications: requests OS permission,
/// then saves the token onto `users/{uid}.fcmTokens` via
/// `UserRepository.addFcmToken` — which already existed but had no caller
/// until now, since nothing in the app ever ran `FirebaseMessaging`.
///
/// This is only the *device* half of the push pipeline. Nothing in this
/// project sends an actual push yet — see `NotificationService.bindToUser`'s
/// doc comment: doing that needs a trusted sender (a Cloud Function or a
/// server holding the FCM key), which this project doesn't have. Wiring up
/// token collection now means real tokens are sitting in Firestore, ready
/// for when that Cloud Function exists, instead of the two being built in
/// the wrong order — a function with no tokens to send to would have
/// nothing to prove it works.
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

  /// Removes this device's token on sign-out, so a shared or reinstalled
  /// phone doesn't keep receiving push for an account no longer signed in
  /// on it. Mirrors `NotificationService.unbind()`'s reasoning.
  Future<void> unregisterForUser(String uid) async {
    await _refreshSub?.cancel();
    _refreshSub = null;
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
