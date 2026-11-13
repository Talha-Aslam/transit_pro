import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import '../data/payment_repository.dart';
import '../widgets/payment_presentation.dart' show paisaToDisplay, dayLabel;
import 'push_sender.dart';
import 'session_service.dart';

/// Monthly fees, kept on the driver's phone.
///
/// Every child whose fee was agreed is billed in 30-day periods counted from
/// the day the seat was accepted: each period's bill is issued as it begins
/// and falls due at its end. Five days before a bill is due the family is
/// reminded; once it is past due it is marked overdue and they are told.
/// Every one of those is a push, so it reaches a phone whose app is closed.
///
/// There is no server to run this on a timer, so the driver's app does it:
/// when it opens, whenever the roster changes, and every few hours while it
/// stays open. Bills have fixed ids, so running it twice issues nothing
/// twice.
class FeeBillingService {
  FeeBillingService._();
  static final FeeBillingService instance = FeeBillingService._();

  /// How long before a bill's due date the family is reminded.
  static const reminderLead = Duration(days: 5);

  static const _period = PaymentRepository.billingPeriod;
  static const _recheck = Duration(hours: 6);

  bool _bound = false;
  bool _running = false;
  Timer? _timer;
  Timer? _debounce;

  void bindToDriver() {
    if (_bound) return;
    _bound = true;
    SessionService.instance.roster.addListener(_onRoster);
    _timer = Timer.periodic(_recheck, (_) => unawaited(run()));
    _onRoster();
  }

  void unbind() {
    if (!_bound) return;
    _bound = false;
    SessionService.instance.roster.removeListener(_onRoster);
    _timer?.cancel();
    _debounce?.cancel();
  }

  void _onRoster() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 5), () => unawaited(run()));
  }

  /// Who pays for [s]: their parent, or the student themselves.
  static String payerOf(Student s) =>
      s.parentId.trim().isEmpty ? s.id : s.parentId.trim();

  /// The bill periods that have begun by [now] for a fee agreed at
  /// [startedAt]: 0 for the first 30 days, 1 for the next, and so on.
  static List<(int, DateTime)> periodsBegun(
    DateTime startedAt,
    DateTime now, {
    int max = 24,
  }) => [
    for (var k = 0; k < max; k++)
      if (!startedAt.add(_period * k).isAfter(now))
        (k, startedAt.add(_period * k)),
  ];

  Future<void> run() async {
    final uid = SessionService.instance.uid;
    if (uid == null || _running) return;
    _running = true;
    try {
      final bills = await PaymentRepository.instance.watchForDriver(uid).first;
      final have = {for (final b in bills) b.id};
      final now = DateTime.now();

      for (final s in SessionService.instance.roster.value) {
        final started = s.feeStartedAt;
        if (s.monthlyFeePaisa <= 0 || started == null) continue;
        for (final (k, periodStart) in periodsBegun(started, now)) {
          final id = PaymentRepository.billId(uid, s.id, k);
          if (have.contains(id)) continue;
          await PaymentRepository.instance.createBill(
            driverId: uid,
            studentId: s.id,
            payerId: payerOf(s),
            amountPaisa: s.monthlyFeePaisa,
            periodStart: periodStart,
            period: k,
          );
        }
      }

      for (final b in bills) {
        final due = b.dueDate;
        if (!b.isBill || !b.isOutstanding || due == null) continue;
        if (b.status == PaymentStatus.pending && due.isBefore(now)) {
          await PaymentRepository.instance.markOverdue(b.id);
          await _tell(b, overdue: true);
        } else if (b.reminderSentAt == null &&
            due.difference(now) <= reminderLead) {
          await _tell(b, overdue: false);
          await PaymentRepository.instance.markReminded(b.id);
        }
      }
    } catch (e) {
      debugPrint('fee billing failed: $e');
    } finally {
      _running = false;
    }
  }

  /// A reminder the driver sends themselves, from a bill.
  Future<void> remind(Payment bill) async {
    await _tell(bill, overdue: bill.status == PaymentStatus.overdue);
    await PaymentRepository.instance.markReminded(bill.id);
  }

  Future<void> _tell(Payment b, {required bool overdue}) async {
    final name = SessionService.instance.roster.value
        .where((s) => s.id == b.studentId)
        .map((s) => s.name)
        .firstOrNull;
    final who = name == null || name.isEmpty ? 'your child' : name;
    await PushSender.instance.notifyOne(
      b.parentId,
      UserNotification(
        id: '',
        type: NotificationType.payment,
        title: overdue ? 'Fee overdue' : 'Fee due soon',
        body: overdue
            ? 'The ${paisaToDisplay(b.amountPaisa)} transport fee for $who was '
                  'due on ${dayLabel(b.dueDate)}. Please pay it.'
            : 'The ${paisaToDisplay(b.amountPaisa)} transport fee for $who is '
                  'due on ${dayLabel(b.dueDate)}. Please pay it.',
        data: {'paymentId': b.id, 'studentId': b.studentId},
      ),
    );
  }
}
