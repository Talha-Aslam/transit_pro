import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import '../data/user_repository.dart';
import 'session_service.dart';

/// Puts a fee the family agreed *after* the seat was booked onto the
/// child's record, from the driver's phone.
///
/// The fee is negotiated on the ride request: the driver proposes, the
/// family accepts or rejects. Only the driver may write the fee onto the
/// student document (the family must never be able to set their own fee),
/// and billing already runs on the driver's phone — so the driver's app
/// applies an accepted fee here, the same way [SeatReconciler] applies seat
/// counts. [FeeBillingService] then bills the new amount from the next
/// period; a seat that had no fee yet starts its first period today.
class FeeAgreementSync {
  FeeAgreementSync._();
  static final FeeAgreementSync instance = FeeAgreementSync._();

  /// Lets a write made on this phone come back through the streams first.
  static const _settleDelay = Duration(seconds: 3);

  bool _bound = false;
  bool _writing = false;
  Timer? _timer;

  void bindToDriver() {
    if (_bound) return;
    _bound = true;
    SessionService.instance.rideRequests.addListener(_schedule);
    SessionService.instance.roster.addListener(_schedule);
    _schedule();
  }

  void unbind() {
    if (!_bound) return;
    _bound = false;
    SessionService.instance.rideRequests.removeListener(_schedule);
    SessionService.instance.roster.removeListener(_schedule);
    _timer?.cancel();
    _timer = null;
  }

  void _schedule() {
    _timer?.cancel();
    if (_pending().isEmpty) return;
    _timer = Timer(_settleDelay, () => unawaited(_apply()));
  }

  List<(Student, int)> _pending() {
    final uid = SessionService.instance.uid;
    if (uid == null) return const [];
    return pendingUpdates(
      driverId: uid,
      requests: SessionService.instance.rideRequests.value,
      roster: SessionService.instance.roster.value,
    );
  }

  /// Each rider on [driverId]'s roster whose booked seat carries an agreed
  /// fee that their record does not show yet, with that fee in paisa.
  @visibleForTesting
  static List<(Student, int)> pendingUpdates({
    required String driverId,
    required List<RideRequest> requests,
    required List<Student> roster,
  }) {
    final riders = {
      for (final s in roster)
        if (s.driverId == driverId) s.id: s,
    };
    return [
      for (final r in requests)
        if (r.driverId == driverId && r.isAccepted && r.hasAgreedFee)
          if (riders[r.studentId] case final s?)
            if (s.monthlyFeePaisa != r.feePaisa) (s, r.feePaisa),
    ];
  }

  Future<void> _apply() async {
    if (_writing) return;
    _writing = true;
    try {
      for (final (student, fee) in _pending()) {
        await UserRepository.instance.updateStudent(student.id, {
          'monthlyFeePaisa': fee,
          // A seat booked without a fee starts billing today; one whose fee
          // changed keeps its 30-day periods and bills the new amount from
          // the next one.
          if (student.feeStartedAt == null) 'feeStartedAt': Db.now,
        });
      }
    } catch (e) {
      debugPrint('fee agreement sync failed: $e');
    } finally {
      _writing = false;
    }
  }
}
