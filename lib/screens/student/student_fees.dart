import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/language_provider.dart';
import '../../app/session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/payment_presentation.dart';

class StudentFees extends StatefulWidget {
  const StudentFees({super.key});
  @override
  State<StudentFees> createState() => _StudentFeesState();
}

class _StudentFeesState extends State<StudentFees> {
  /// Key into [paymentFilters] — 'All' | 'Paid' | 'Pending' | 'Overdue'.
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // Two listenables, for two different reasons. The payments notifier carries
    // the rows; the session itself carries whether we are still *waiting* for
    // them. Without the outer listener a student whose fee list is genuinely
    // empty would sit on the spinner forever, because loading → ready never
    // touches `payments` and so never rebuilds on its own.
    return ListenableBuilder(
      listenable: SessionService.instance,
      builder: (context, _) => ValueListenableBuilder<List<Payment>>(
        // For the student role `SessionService.payments` is already the
        // `watchForStudent(uid)` query, so these are this student's own bills —
        // no further scoping by studentId is needed here.
        valueListenable: SessionService.instance.payments,
        builder: (context, payments, _) => _buildBody(context, payments),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Payment> payments) {
    final totals = PaymentTotals.of(payments);
    final paidTotal = totals.paid;
    final pendingTotal = totals.pending;
    final totalFee = totals.billed;

    // `outstanding` is pending + overdue. The old code used `pendingTotal`
    // alone, so a month dropped out of the balance the instant it went overdue —
    // exactly when it most needs to be shown. `totals.overdue` therefore has no
    // pill of its own in this three-pill layout; it lives inside this figure.
    final outstandingFee = totals.outstanding;

    // Drives both the due badge and the Pay-now button: overdue first, then
    // earliest due date.
    final due = nextDuePayment(payments);

    final loading = payments.isEmpty && SessionService.instance.isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.t('my_fees_s'),
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.t('fee_details_s'),
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Balance card ──────────────────────────────
          //
          // Always shown, even for a brand-new account with no fee records
          // yet — this is the payment-method entry point, not just a "money
          // is owed" banner, so it must survive an empty `payments` list.
          // Only the button's label and the amount shown depend on whether
          // anything is actually due.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              enableBlur: false,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.studentAmber.withValues(alpha: 0.15),
                  AppTheme.studentOrange.withValues(alpha: 0.06),
                ],
              ),
              borderColor: AppTheme.studentAmber.withValues(alpha: 0.25),
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppTheme.studentGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text('💰', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.t('outstanding_balance_s'),
                              style: TextStyle(
                                // Was a translucent white, which is
                                // effectively invisible on the light theme's
                                // pale card. The theme extension picks the
                                // right ink for either mode.
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            ShaderMask(
                              shaderCallback: (b) =>
                                  AppTheme.studentGradient.createShader(b),
                              child: Text(
                                paisaToDisplay(outstandingFee),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Only when something is actually due — a fabricated
                      // "Due: Dec 15" used to show even with nothing owing.
                      if (due?.dueDate != null)
                        StatusBadge(
                          label: 'Due: ${dayLabel(due!.dueDate)}',
                          color: paymentStatusColor(due.status),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Pay now / Payment methods button — see the doc comment
                  // above for why this no longer depends on `due != null`.
                  GestureDetector(
                    onTap: () => context.push(
                      '/parent/payment',
                      // Same String-keyed contract PaymentMethodScreen
                      // already reads; `paymentId` rides along so the flow
                      // can settle this exact document. An empty amount is
                      // how `PaymentMethodScreen` knows nothing is due.
                      extra: <String, dynamic>{
                        'amount': due == null
                            ? ''
                            : paisaToDisplay(due.amountPaisa),
                        'month': due == null ? '' : monthLabel(due.monthKey),
                        if (due != null) 'paymentId': due.id,
                      },
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppTheme.studentGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.studentAmber.withValues(
                              alpha: 0.25,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          due == null ? 'Payment Methods' : AppStrings.t('pay_now'),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Nothing billed yet (or nothing read yet): the stat pills and the
          // filters would all be zeroes, so show one honest empty state
          // instead of a screenful of Rs.0 below the balance card.
          if (payments.isEmpty)
            PaymentListState(
              loading: loading,
              emptyMessage:
                  'No fee records yet. These appear once your transport fee is issued.',
              accent: AppTheme.studentAmber,
            )
          else ...[
            // ── Summary stats ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _StatPill(
                    icon: '✅',
                    label: AppStrings.t('paid'),
                    value: paisaToDisplay(paidTotal),
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 10),
                  _StatPill(
                    icon: '⏳',
                    label: AppStrings.t('pending'),
                    value: paisaToDisplay(pendingTotal),
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 10),
                  _StatPill(
                    icon: '📅',
                    label: AppStrings.t('total'),
                    value: paisaToDisplay(totalFee),
                    color: AppTheme.info,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Filter chips ──────────────────────────────
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: paymentFilters.keys.map((f) {
                  final label = AppStrings.t(f.toLowerCase());
                  final sel = f == _filter;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: sel ? AppTheme.studentGradient : null,
                        color: sel ? null : context.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: sel
                            ? null
                            : Border.all(color: context.cardBgElevated),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: sel ? Colors.white : context.textSecondary,
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // ── Payment history ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                AppStrings.t('payment_history'),
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _buildPayments(payments),
            const SizedBox(height: 16),

            // ── Fee breakdown ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.t('total'),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (b) =>
                              AppTheme.studentGradient.createShader(b),
                          child: Text(
                            paisaToDisplay(totalFee),
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPayments(List<Payment> payments) {
    final filtered = applyPaymentFilter(payments, paymentFilters[_filter]);

    if (filtered.isEmpty) {
      return PaymentListState(
        emptyMessage: 'No ${AppStrings.t(_filter.toLowerCase())} fees to show.',
        accent: AppTheme.studentAmber,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final p in filtered) PaymentRow(payment: p),
        ],
      ),
    );
  }
}

// ── Models & Widgets ────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String icon, label, value;
  final Color color;
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        enableBlur: false,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: context.textTertiary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
