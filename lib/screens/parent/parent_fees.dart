import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../app/language_provider.dart';

class StudentFees extends StatefulWidget {
  const StudentFees({super.key});
  @override
  State<StudentFees> createState() => _StudentFeesState();
}

class _StudentFeesState extends State<StudentFees> {
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
                  AppTheme.studentAmber.withOpacity(0.15),
                  AppTheme.studentOrange.withOpacity(0.06),
                ],
              ),
              borderColor: AppTheme.studentAmber.withOpacity(0.25),
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
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            ShaderMask(
                              shaderCallback: (b) =>
                                  AppTheme.studentGradient.createShader(b),
                              child: Text(
                                'Rs.2,500',
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
                      StatusBadge(
                        label: 'Due: Dec 15',
                        color: AppTheme.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Pay now button
                  GestureDetector(
                    onTap: () => context.push(
                      '/parent/payment',
                      extra: {'amount': 'Rs.2,500', 'month': 'December 2024'},
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppTheme.studentGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.studentAmber.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          AppStrings.t('pay_now'),
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
                  value: 'Rs.22,500',
                  color: AppTheme.success,
                ),
                const SizedBox(width: 10),
                _StatPill(
                  icon: 'assets/images/utilities/pending.png',
                  label: AppStrings.t('pending'),
                  value: 'Rs.2,500',
                  color: AppTheme.warning,
                ),
                const SizedBox(width: 10),
                _StatPill(
                  icon: 'assets/images/utilities/total.png',
                  label: AppStrings.t('total'),
                  value: 'Rs.25,000',
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
              children:
                  {
                    'All': AppStrings.t('all'),
                    'Paid': AppStrings.t('paid'),
                    'Pending': AppStrings.t('pending'),
                    'Overdue': AppStrings.t('overdue'),
                  }.entries.map((e) {
                    final f = e.key;
                    final label = e.value;
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
          ..._buildPayments(),
          const SizedBox(height: 16),

          // ── Fee breakdown ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.t('fee_breakdown'),
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _BreakdownRow(
                    label: AppStrings.t('transport_fee'),
                    amount: 'Rs.18,000',
                  ),
                  _BreakdownRow(
                    label: AppStrings.t('maintenance_levy'),
                    amount: 'Rs.3,000',
                  ),
                  _BreakdownRow(
                    label: AppStrings.t('insurance'),
                    amount: 'Rs.2,000',
                  ),
                  _BreakdownRow(
                    label: AppStrings.t('id_card_fee'),
                    amount: 'Rs.500',
                  ),
                  _BreakdownRow(
                    label: AppStrings.t('gps_tracking'),
                    amount: 'Rs.1,500',
                  ),
                  const Divider(color: Colors.white12, height: 20),
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
                          'Rs.25,000',
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
      ),
    );
  }

  List<Widget> _buildPayments() {
    final payments = [
      _PaymentData(
        'November 2024',
        'Rs.2,500',
        'Paid',
        '15 Nov',
        AppTheme.success,
      ),
      _PaymentData(
        'October 2024',
        'Rs.2,500',
        'Paid',
        '14 Oct',
        AppTheme.success,
      ),
      _PaymentData(
        'September 2024',
        'Rs.2,500',
        'Paid',
        '12 Sep',
        AppTheme.success,
      ),
      _PaymentData(
        'August 2024',
        'Rs.2,500',
        'Paid',
        '10 Aug',
        AppTheme.success,
      ),
      _PaymentData(
        'December 2024',
        'Rs.2,500',
        'Pending',
        'Due: 15 Dec',
        AppTheme.warning,
      ),
    ];

    final filtered = _filter == 'All'
        ? payments
        : payments.where((p) => p.status == _filter).toList();

    return filtered
        .map(
          (p) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: GlassCard(
              gradient: LinearGradient(
                colors: [p.color.withOpacity(0.06), p.color.withOpacity(0.02)],
              ),
              borderColor: p.color.withOpacity(0.12),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: p.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        p.status == 'Paid' ? '✅' : '⏳',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.month,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          p.date,
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        p.amount,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      StatusBadge(label: p.status, color: p.color),
                    ],
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();
  }
}

// ── Models & Widgets ────────────────────────────────────────────────────

class _PaymentData {
  final String month, amount, status, date;
  final Color color;
  _PaymentData(this.month, this.amount, this.status, this.date, this.color);
}

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

class _BreakdownRow extends StatelessWidget {
  final String label, amount;
  const _BreakdownRow({required this.label, required this.amount});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          Text(
            amount,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
