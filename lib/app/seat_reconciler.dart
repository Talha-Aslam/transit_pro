import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import '../data/user_repository.dart';
import 'session_service.dart';

/// Keeps a driver's stored seat counts honest.
///
/// `DriverSchedule.bookedSeats` lives on the driver document, and only the
/// driver may write it. That is right for accepting — the count has to move
/// inside the same transaction that answers the request, or two parents race
/// for the last seat and both win. It is wrong for a family *leaving*: a
/// parent may withdraw from a round at any time, and they cannot touch the
/// driver's document to give the seat back.
///
/// So the family's withdrawal is recorded where they do have authority — the
/// ride request goes `cancelled`, the child is unlinked — and this puts the
/// driver's own count back in step the next time their app is running. The
/// accepted requests are the ground truth; `bookedSeats` is a cache of them
/// that exists so a transaction has a single field to guard.
///
/// ## The race this has to avoid
///
/// `RideRequestRepository.accept` increments `bookedSeats` inside its
/// transaction. The ride-request stream learns about the new `accepted`
/// status a moment later. In that gap the stored count is one *ahead* of
/// what the requests say — and a reconciler that wrote immediately would
/// undo the booking it had just watched succeed. Hence the delay and the
/// re-check: a mismatch has to still be there after things have settled
/// before anything is written.
class SeatReconciler {
  SeatReconciler._();
  static final SeatReconciler instance = SeatReconciler._();

  /// Long enough for a Firestore write on this device to come back through
  /// the stream, short enough that a driver glancing at their seat count
  /// after a parent leaves sees the right number.
  static const _settleDelay = Duration(seconds: 8);

  Timer? _timer;
  bool _bound = false;
  bool _writing = false;

  void bindToDriver() {
    if (_bound) return;
    _bound = true;
    SessionService.instance.driver.addListener(_schedule);
    SessionService.instance.rideRequests.addListener(_schedule);
    _schedule();
  }

  void unbind() {
    if (!_bound) return;
    _bound = false;
    SessionService.instance.driver.removeListener(_schedule);
    SessionService.instance.rideRequests.removeListener(_schedule);
    _timer?.cancel();
    _timer = null;
  }

  void _schedule() {
    _timer?.cancel();
    if (_mismatch() == null) return;
    _timer = Timer(_settleDelay, _apply);
  }

  /// The schedules as they should be, or null when they already agree.
  List<DriverSchedule>? _mismatch() {
    final driver = SessionService.instance.driver.value;
    if (driver == null || driver.schedules.isEmpty) return null;

    final accepted = <String, int>{};
    for (final r in SessionService.instance.rideRequests.value) {
      if (!r.isAccepted) continue;
      accepted[r.scheduleId] = (accepted[r.scheduleId] ?? 0) + 1;
    }

    var changed = false;
    final corrected = <DriverSchedule>[];
    for (final s in driver.schedules) {
      final real = accepted[s.id] ?? 0;
      if (real != s.bookedSeats) changed = true;
      corrected.add(s.copyWith(bookedSeats: real));
    }
    return changed ? corrected : null;
  }

  Future<void> _apply() async {
    if (_writing) return;
    // Re-read rather than trusting what the timer was started for: the
    // request stream has had eight seconds to catch up, and most of the time
    // it has, leaving nothing to do.
    final corrected = _mismatch();
    final driverId = SessionService.instance.uid;
    if (corrected == null || driverId == null) return;

    _writing = true;
    try {
      await UserRepository.instance.replaceSchedules(driverId, corrected);
      debugPrint('SeatReconciler: seat counts corrected for $driverId');
    } catch (e) {
      // Best-effort. A failure leaves the stored count too high, which turns
      // families away from a round that has room — bad, but not as bad as
      // overselling it, and the next session tries again.
      debugPrint('SeatReconciler: could not correct seat counts — $e');
    } finally {
      _writing = false;
    }
  }
}
