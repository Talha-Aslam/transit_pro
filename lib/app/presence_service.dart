import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:transit_core/transit_core.dart';

import '../data/user_repository.dart';

/// Keeps `users/{uid}.isOnline` / `lastSeenAt` true to what the user is
/// doing, for the admin panel's online / offline tags and "last seen".
///
/// * Signed in with the app in front → online, re-stamped every minute.
/// * App sent to the background or closed → offline at once.
/// * Signed out → offline before the session ends.
/// * Killed by the OS (nothing can be written) → the heartbeat stops, and
///   readers treat a [lastSeenAt] older than [AppUser.presenceTimeout] as
///   offline (see [AppUser.isOnlineAt]).
///
/// For a driver it also flips `drivers/{id}.status` between online and
/// offline, never touching an approval state (pending / suspended) or a
/// running trip.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  static const heartbeat = Duration(minutes: 1);

  String? _uid;
  UserRole? _role;
  DriverStatus? Function()? _driverStatus;
  Timer? _beat;
  bool _observing = false;
  bool _foreground = true;

  /// Starts tracking [uid]. [driverStatus] reads the driver's current status
  /// so a trip or an approval state is never overwritten.
  void bind(
    String uid, {
    UserRole? role,
    DriverStatus? Function()? driverStatus,
  }) {
    final isNew = _uid != uid;
    _uid = uid;
    _role = role;
    _driverStatus = driverStatus;
    if (isNew) unawaited(_logAccess(uid, 'signIn'));
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    if (_foreground) _goOnline();
  }

  /// The role arrives after the user document; set it when it does.
  void updateRole(UserRole role, {DriverStatus? Function()? driverStatus}) {
    final changed = _role != role;
    _role = role;
    _driverStatus = driverStatus ?? _driverStatus;
    if (changed && _foreground && _uid != null) _writeDriver(online: true);
  }

  /// Marks the account offline and stops. Awaited by sign-out while the
  /// Firebase session is still valid, so the write is allowed.
  Future<void> unbind() async {
    final uid = _uid;
    _beat?.cancel();
    _beat = null;
    _uid = null;
    if (uid != null) {
      unawaited(_logAccess(uid, 'signOut'));
      await _write(
        uid,
        online: false,
      ).timeout(const Duration(seconds: 4), onTimeout: () {});
    }
    _role = null;
    _driverStatus = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        _goOnline();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (!_foreground) return;
        _foreground = false;
        _beat?.cancel();
        _beat = null;
        final uid = _uid;
        if (uid != null) unawaited(_write(uid, online: false));
      case AppLifecycleState.inactive:
        // A dialog, the notification shade, an incoming call — still open.
        break;
    }
  }

  /// One row per session start / sign-out in `users/{uid}/accessLog`, for
  /// the admin panel's "Access" history. Append-only by rule.
  Future<void> _logAccess(String uid, String event) async {
    try {
      await Db.fs.collection('users').doc(uid).collection('accessLog').add({
        'event': event,
        'platform': defaultTargetPlatform.name,
        'at': Db.now,
      });
    } catch (e) {
      debugPrint('presence: access log failed — $e');
    }
  }

  void _goOnline() {
    final uid = _uid;
    if (uid == null) return;
    unawaited(_write(uid, online: true));
    _beat?.cancel();
    _beat = Timer.periodic(heartbeat, (_) {
      final current = _uid;
      if (current != null && _foreground) {
        unawaited(_write(current, online: true, driverToo: false));
      }
    });
  }

  Future<void> _write(
    String uid, {
    required bool online,
    bool driverToo = true,
  }) async {
    try {
      await Db.fs.collection('users').doc(uid).update({
        'isOnline': online,
        'lastSeenAt': Db.now,
      });
    } catch (e) {
      debugPrint('presence: user write failed — $e');
    }
    if (driverToo) await _writeDriver(online: online, uid: uid);
  }

  Future<void> _writeDriver({required bool online, String? uid}) async {
    final id = uid ?? _uid;
    if (id == null || _role != UserRole.driver) return;
    final current = _driverStatus?.call();
    // Approval states are the admin's; a running trip says more than online.
    if (current == null ||
        current == DriverStatus.pendingVerification ||
        current == DriverStatus.suspended ||
        current == DriverStatus.onTrip) {
      return;
    }
    await UserRepository.instance.touchPresence(
      id,
      status: online ? DriverStatus.online : DriverStatus.offline,
    );
  }
}
