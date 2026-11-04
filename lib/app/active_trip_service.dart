import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import '../data/trip_repository.dart';

/// The one answer to "is this driver on a route right now?".
///
/// Every driver screen used to decide that for itself by asking
/// `TrackingService.instance.route != null`. That is a *device-local*
/// leftover: it is non-null whenever this phone happens to be holding a
/// built [RouteData], and null whenever it is not — so the profile tab
/// showed "Active - On Route" after a trip had already been ended from
/// another screen, and showed "Not Started" for a trip that was genuinely
/// running but had been started before the app was last killed.
///
/// `trips/{tripId}` with `status == inProgress` is the real answer: it is
/// written once, read by parents and students the same way, and survives
/// the app being closed. This streams it and hands every screen the same
/// notifier so they cannot disagree with each other.
class ActiveTripService extends ChangeNotifier {
  ActiveTripService._();
  static final ActiveTripService instance = ActiveTripService._();

  /// The trip this driver currently has open, or null when none is running.
  final trip = ValueNotifier<Trip?>(null);

  /// True while a real trip is in progress. This — not the presence of a
  /// local route object — is what the dashboard badge, the profile status
  /// chip and the route screen all key off.
  bool get isOnRoute => trip.value != null;

  String? _boundUid;
  StreamSubscription<Trip?>? _sub;

  /// Starts (or re-points) the watch. Idempotent per uid, so the session
  /// bootstrap can call it on every driver sign-in without stacking
  /// listeners.
  void bindToDriver(String uid) {
    if (_boundUid == uid && _sub != null) return;
    unbind();
    _boundUid = uid;
    _sub = TripRepository.instance.watchActiveTripForDriver(uid).listen(
      (t) {
        if (t?.id == trip.value?.id && t?.status == trip.value?.status) return;
        trip.value = t;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('ActiveTripService: trip stream failed — $e');
        // Deliberately leaves the last known value alone. A dropped stream
        // is not evidence the trip ended, and flipping the badge to "not
        // started" mid-route would be worse than a stale one.
      },
    );
  }

  /// Called on sign-out. A trip belongs to one account; leaving it would
  /// show the previous driver's round to whoever signs in next.
  void unbind() {
    _sub?.cancel();
    _sub = null;
    _boundUid = null;
    if (trip.value != null) {
      trip.value = null;
      notifyListeners();
    }
  }
}
