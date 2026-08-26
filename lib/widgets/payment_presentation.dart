import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';

import '../app/language_provider.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

/// One place that decides how a [Payment] looks.
///
/// The three fee screens each grew their own `_amountToInt` / `_sumByStatus` /
/// `_formatRs` — byte-identical in two of them — plus their own `_PaymentData`
/// row model. Worse, all three parsed money back out of strings like
/// `'Rs.2,500'` with a regex, which is exactly what storing integer paisa was
/// meant to end. Everything money-shaped now goes through here.

// ── Formatting ──────────────────────────────────────────────────────────────

/// `250000` → `Rs.2,500`.
///
/// Rounds to whole rupees for display: the pilot quotes fees in round hundreds,
/// and a trailing `.00` on every row is noise. The paisa are still in the
/// document — this is presentation only, and nothing ever parses it back.
String paisaToDisplay(int paisa) {
  final rupees = (paisa / 100).round().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < rupees.length; i++) {
    if (i > 0 && (rupees.length - i) % 3 == 0) buf.write(',');
    buf.write(rupees[i]);
  }
  return '${paisa < 0 ? '-' : ''}Rs.$buf';
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// `2026-08` → `August 2026`. Falls back to the raw key rather than guessing, so
/// a malformed value shows as itself instead of silently reading as January.
String monthLabel(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length < 2) return monthKey;
  final year = parts[0];
  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return monthKey;
  return '${_monthNames[month - 1]} $year';
}

/// `15 Nov`.
String dayLabel(DateTime? date) {
  if (date == null) return '—';
  return '${date.day} ${_monthNames[date.month - 1].substring(0, 3)}';
}

/// The date line under a payment's month, which means different things per state.
///
/// A paid row wants "when did the money arrive"; an unpaid row wants "when is it
/// due". Both were crammed into one overloaded `date` string in the mock data,
/// and keeping that shape here — but deriving it — is what lets the existing row
/// layout stay unchanged.
String paymentDateLine(Payment p) {
  if (p.status == PaymentStatus.paid) {
    final when = p.confirmedAt ?? p.paidAt;
    return when == null ? 'Paid' : 'Paid ${dayLabel(when)}';
  }
  if (p.status == PaymentStatus.refunded) {
    return 'Refunded ${dayLabel(p.confirmedAt ?? p.paidAt)}';
  }
  // A slip attached but not yet confirmed is its own state, and the most
  // reassuring thing a parent can be told — it says "we have it, wait" rather
  // than leaving them looking at "Pending" and wondering if the upload worked.
  if (p.paidAt != null) return 'Awaiting confirmation';
  return p.dueDate == null ? 'No due date' : 'Due ${dayLabel(p.dueDate)}';
}

Color paymentStatusColor(PaymentStatus status) => switch (status) {
      PaymentStatus.paid => AppTheme.success,
      PaymentStatus.pending => AppTheme.warning,
      PaymentStatus.overdue => AppTheme.error,
      // `refunded` had no colour anywhere before — the driver screen's switch
      // fell through to its default cyan and the fee screens had no case at all.
      PaymentStatus.refunded => AppTheme.info,
    };

String paymentStatusEmoji(PaymentStatus status) => switch (status) {
      PaymentStatus.paid => '✅',
      PaymentStatus.pending => '⏳',
      PaymentStatus.overdue => '⚠️',
      PaymentStatus.refunded => '↩️',
    };

/// Localised status label, falling back to the enum's own English.
///
/// The old code called `AppStrings.t(record.status.toLowerCase())` on a raw
/// string, which silently produced a missing-key label the moment a status
/// existed without a translation. This keeps the lookup but names the keys
/// explicitly so an untranslated `refunded` degrades to "Refunded" rather than to
/// the key itself.
String paymentStatusLabel(PaymentStatus status) {
  final key = status.name;
  final translated = AppStrings.t(key);
  if (translated.isNotEmpty && translated != key) return translated;
  return switch (status) {
    PaymentStatus.paid => 'Paid',
    PaymentStatus.pending => 'Pending',
    PaymentStatus.overdue => 'Overdue',
    PaymentStatus.refunded => 'Refunded',
  };
}

// ── Aggregation ─────────────────────────────────────────────────────────────

/// Money split by state, in paisa.
class PaymentTotals {
  final int paid;
  final int pending;
  final int overdue;
  final int refunded;

  const PaymentTotals({
    this.paid = 0,
    this.pending = 0,
    this.overdue = 0,
    this.refunded = 0,
  });

  /// Everything ever billed, refunds included — the "total" figure in the
  /// footer.
  int get billed => paid + pending + overdue + refunded;

  /// What the family still owes.
  ///
  /// Overdue is included. The old student screen set `outstanding = pending`
  /// only, so an overdue month vanished from the balance the moment it went
  /// overdue — the one point at which a family most needs to see it.
  int get outstanding => pending + overdue;

  static PaymentTotals of(List<Payment> payments) {
    var paid = 0, pending = 0, overdue = 0, refunded = 0;
    for (final p in payments) {
      switch (p.status) {
        case PaymentStatus.paid:
          paid += p.amountPaisa;
        case PaymentStatus.pending:
          pending += p.amountPaisa;
        case PaymentStatus.overdue:
          overdue += p.amountPaisa;
        case PaymentStatus.refunded:
          refunded += p.amountPaisa;
      }
    }
    return PaymentTotals(
      paid: paid,
      pending: pending,
      overdue: overdue,
      refunded: refunded,
    );
  }
}

/// The next thing the family owes, or null when they are square.
///
/// Overdue outranks pending, then earliest due date — which is the order a
/// family should pay in, and therefore the one the "Pay now" button should act
/// on.
Payment? nextDuePayment(List<Payment> payments) {
  final unpaid = payments
      .where((p) =>
          p.status == PaymentStatus.pending || p.status == PaymentStatus.overdue)
      .toList();
  if (unpaid.isEmpty) return null;

  unpaid.sort((a, b) {
    if (a.status != b.status) {
      return a.status == PaymentStatus.overdue ? -1 : 1;
    }
    final ad = a.dueDate;
    final bd = b.dueDate;
    if (ad == null && bd == null) return a.monthKey.compareTo(b.monthKey);
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  });
  return unpaid.first;
}

/// The filter chips every fee screen has, as a status or null for "All".
const paymentFilters = <String, PaymentStatus?>{
  'All': null,
  'Paid': PaymentStatus.paid,
  'Pending': PaymentStatus.pending,
  'Overdue': PaymentStatus.overdue,
};

List<Payment> applyPaymentFilter(List<Payment> payments, PaymentStatus? status) =>
    status == null
        ? payments
        : payments.where((p) => p.status == status).toList();

// ── Shared row ──────────────────────────────────────────────────────────────

/// One payment, laid out the way all three fee screens already drew it.
///
/// Same visual as the previous inline row so nothing about the screens looks
/// different — but built from a [Payment], and with [subtitle] as the one point
/// of variation: the family screens show the month, the driver screen shows who
/// it was for.
class PaymentRow extends StatelessWidget {
  final Payment payment;

  /// Overrides the headline. The driver's view leads with the student's name
  /// rather than the month, because a driver reads this list to find a person.
  final String? title;

  /// Extra line under the title — the driver's view puts the month here.
  final String? subtitle;

  final VoidCallback? onTap;

  const PaymentRow({
    super.key,
    required this.payment,
    this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = paymentStatusColor(payment.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        // One of these is built per payment in a scrollable list — a live
        // blur per row is the classic BackdropFilter-in-a-list jank source.
        enableBlur: false,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                paymentStatusEmoji(payment.status),
                style: const TextStyle(fontSize: 17),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? monthLabel(payment.monthKey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle == null
                        ? paymentDateLine(payment)
                        : '$subtitle · ${paymentDateLine(payment)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  paisaToDisplay(payment.amountPaisa),
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                StatusBadge(
                  label: paymentStatusLabel(payment.status),
                  color: color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── States ──────────────────────────────────────────────────────────────────

/// Loading / error / empty, which none of the fee screens had because none of
/// them were ever asynchronous. Adding Firestore adds all three.
class PaymentListState extends StatelessWidget {
  final Object? error;
  final bool loading;
  final String emptyMessage;
  final Color accent;

  const PaymentListState({
    super.key,
    this.error,
    this.loading = false,
    required this.emptyMessage,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(accent),
          ),
        ),
      );
    }

    final isError = error != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Text(
            isError ? '⚠️' : '🧾',
            style: const TextStyle(fontSize: 30),
          ),
          const SizedBox(height: 12),
          Text(
            isError
                ? 'Could not load payments. Check your connection.'
                : emptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
