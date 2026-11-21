/// Compares what was read off a payment screenshot with the bill it is
/// meant to pay and the driver who should have received it.
///
/// Pure Dart; produces the [SlipCheck] stored on the payment.
library;

import 'package:transit_core/transit_core.dart';

import 'slip_parser.dart';
import 'text_utils.dart';

/// Who should have been paid, and how much, and when.
class SlipExpectation {
  final int amountPaisa;

  /// First day the bill covers; for a payment sent without a bill, the
  /// first of the month it is for.
  final DateTime? periodStart;

  /// Names the money may arrive under: the driver's own name, the bank
  /// account title, each wallet's name.
  final List<String> payeeNames;

  /// The driver's account and wallet numbers, as entered.
  final List<String> payeeAccounts;

  const SlipExpectation({
    required this.amountPaisa,
    this.periodStart,
    this.payeeNames = const [],
    this.payeeAccounts = const [],
  });

  /// From the driver's profile and payout details.
  factory SlipExpectation.forDriver({
    required int amountPaisa,
    DateTime? periodStart,
    required String driverName,
    PayoutDetails payout = const PayoutDetails(),
  }) => SlipExpectation(
    amountPaisa: amountPaisa,
    periodStart: periodStart,
    payeeNames: [
      driverName,
      payout.accountTitle,
      for (final w in payout.wallets) w.name,
    ].where((n) => n.trim().isNotEmpty).toList(),
    payeeAccounts: [
      payout.accountNumber,
      for (final w in payout.wallets) w.number,
    ].where((n) => n.trim().isNotEmpty).toList(),
  );
}

/// How far before the bill's start a payment may be dated (paying a few
/// days early is normal) and how far after now (clock skew, time zones).
const slipEarlyGrace = Duration(days: 3);
const slipFutureGrace = Duration(days: 1);

/// Whether the money went to the expected payee. Null when the receiver was
/// not read at all.
bool? receiverMatches(SlipReading r, SlipExpectation e) {
  final hasName = (r.receiverName ?? '').trim().isNotEmpty;
  final hasAccount = (r.receiverAccountLast4 ?? '').isNotEmpty;
  if (!hasName && !hasAccount) return null;
  if (hasAccount) {
    for (final acc in e.payeeAccounts) {
      if (last4Digits(acc) == r.receiverAccountLast4) return true;
    }
  }
  if (hasName && e.payeeNames.any((n) => namesMatch(n, r.receiverName))) {
    return true;
  }
  // Only an account number was read and the driver listed none: nothing to
  // compare it with.
  if (!hasName && e.payeeAccounts.isEmpty) return null;
  return false;
}

/// The check for [r] against [e]. [duplicate]: the transaction id is
/// already registered against a different payment.
SlipCheck evaluateSlip(
  SlipReading r,
  SlipExpectation e, {
  bool duplicate = false,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final issues = <String>[];
  if (r.isEmpty) {
    issues.add(SlipCheck.unreadable);
  } else {
    if (r.amountPaisa == null) {
      issues.add(SlipCheck.amountUnreadable);
    } else if (r.amountPaisa != e.amountPaisa) {
      issues.add(SlipCheck.amountMismatch);
    }
    switch (receiverMatches(r, e)) {
      case null:
        issues.add(SlipCheck.receiverUnreadable);
      case false:
        issues.add(SlipCheck.receiverMismatch);
      case true:
        break;
    }
    final paid = r.paidAt;
    if (paid != null) {
      final earliest = e.periodStart?.subtract(slipEarlyGrace);
      final latest = at.add(slipFutureGrace);
      if ((earliest != null && paid.isBefore(earliest)) ||
          paid.isAfter(latest)) {
        issues.add(SlipCheck.dateOutOfRange);
      }
    }
    if (duplicate) issues.add(SlipCheck.duplicateTransaction);
    if (r.successful == false) issues.add(SlipCheck.notSuccessful);
  }
  return SlipCheck(
    provider: r.provider,
    amountPaisa: r.amountPaisa,
    expectedAmountPaisa: e.amountPaisa,
    transactionId: r.transactionId == null
        ? null
        : '${r.transactionId}${r.transactionIdTruncated ? '…' : ''}',
    paidAt: r.paidAt,
    receiverName: r.receiverName,
    receiverAccountLast4: r.receiverAccountLast4,
    senderName: r.senderName,
    engine: r.engine,
    issues: issues,
    checkedAt: at,
  );
}
