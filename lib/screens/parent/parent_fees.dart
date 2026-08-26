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
  /// Which chip is active — a key into [paymentFilters], not a status string, so
  /// the label stays translatable while the filtering stays typed.
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
    final session = SessionService.instance;

    // Three things decide what belongs on this screen: the ledger itself, the
    // child list, and which child is selected. Listening to only the first
    // would leave last child's figures on screen after a switch.
    return ValueListenableBuilder<List<Payment>>(
      valueListenable: session.payments,
      builder: (context, allPayments, _) => ListenableBuilder(
        listenable: Listenable.merge([
          session.children,
          session.selectedChildIndex,
        ]),
        builder: (context, _) {
          final child = session.selectedChild;

          // Scope to the selected child. A parent's `payments` stream spans
          // every child on the account, so an unscoped list shows one child's
          // bill under the other child's name — which is worse than showing
          // nothing, because the parent can act on it and pay the wrong month
          // for the wrong kid. With no child on file there is nothing to scope
          // to, so the whole ledger is the honest answer.
          final payments = child == null
              ? allPayments
              : session.paymentsForStudent(child.id);

          return _buildFees(context, payments);
        },
      ),
    );
  }

  Widget _buildFees(BuildContext context, List<Payment> payments) {
    // Every figure on this screen comes out of here — no string money anywhere.
    final totals = PaymentTotals.of(payments);
    final due = nextDuePayment(payments);
    final filtered = applyPaymentFilter(payments, paymentFilters[_filter]);
    final dueDate = due?.dueDate;

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
                  AppStrings.t('my_fees'),
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.t('fee_details'),
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Balance card ──────────────────────────────
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
                        child: Center(
                          child: Image.asset(
                            'assets/images/utilities/dollar.png',
                            width: 44,
                            height: 44,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.t('outstanding_balance'),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              // pending + overdue: an overdue month is still
                              // owed, and dropping it here would shrink the
                              // balance exactly when it matters most.
                              paisaToDisplay(totals.outstanding),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Only shown when something is actually due — an invented
                      // date next to a zero balance reads as a real demand.
                      if (due != null && dueDate != null)
                        StatusBadge(
                          label: 'Due: ${dayLabel(dueDate)}',
                          color: paymentStatusColor(due.status),
                        ),
                    ],
                  ),
                  // Always shown, whether or not a bill is currently due — the
                  // parent must always be able to reach the payment-method
                  // picker (to see how they'll pay once a fee is issued), not
                  // only when there happens to be one open right now. With
                  // nothing due the screen still opens, just with no amount to
                  // act on — see `PaymentMethodScreen._hasBill`.
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () => context.push(
                      '/parent/payment',
                      extra: {
                        'amount': due == null ? '' : paisaToDisplay(due.amountPaisa),
                        'month': due == null ? '' : monthLabel(due.monthKey),
                        // The downstream screens only read `amount` and
                        // `month` and ignore anything else, so carrying the
                        // document id costs nothing now and is what lets a
                        // later change write back to the right payment
                        // instead of matching on a formatted month string.
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
                          due == null
                              ? 'Payment Methods'
                              : AppStrings.t('pay_now'),
                          style: const TextStyle(
                            color: Colors.white,
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

          // ── Summary stats ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatPill(
                  icon: 'assets/images/utilities/check.png',
                  label: AppStrings.t('paid'),
                  value: paisaToDisplay(totals.paid),
                  color: AppTheme.success,
                ),
                const SizedBox(width: 10),
                _StatPill(
                  icon: 'assets/images/utilities/pending.png',
                  label: AppStrings.t('pending'),
                  value: paisaToDisplay(totals.pending),
                  color: AppTheme.warning,
                ),
                const SizedBox(width: 10),
                _StatPill(
                  icon: 'assets/images/utilities/total.png',
                  label: AppStrings.t('total'),
                  value: paisaToDisplay(totals.billed),
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
                // Chip keys are the shared filter names; the labels keep coming
                // from the same AppStrings keys as before ('all', 'paid', …).
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
          if (payments.isEmpty)
            PaymentListState(
              loading: SessionService.instance.isLoading,
              emptyMessage:
                  'No fee records yet. These appear once your child\'s '
                  'transport fee is issued.',
              accent: AppTheme.studentAmber,
            )
          else if (filtered.isEmpty)
            PaymentListState(
              emptyMessage: 'No payments under this filter.',
              accent: AppTheme.studentAmber,
            )
          else
            ...filtered.map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PaymentRow(payment: p),
              ),
            ),
          const SizedBox(height: 16),

          // ── Total paid fee ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              enableBlur: false,
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t('total'),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.t('paid'),
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppTheme.studentGradient.createShader(b),
                    child: Text(
                      // "Total paid" — settled money only, which is what this
                      // figure always meant.
                      paisaToDisplay(totals.paid),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ─────────────────────────────────────────────────────────────

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
            Image.asset(icon, width: 28, height: 28),
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
