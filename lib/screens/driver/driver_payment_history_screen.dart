import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DriverPaymentHistoryScreen extends StatefulWidget {
  const DriverPaymentHistoryScreen({super.key});

  @override
  State<DriverPaymentHistoryScreen> createState() =>
      _DriverPaymentHistoryScreenState();
}

class _DriverPaymentHistoryScreenState
    extends State<DriverPaymentHistoryScreen> {
  String _filter = 'All';

  static final List<_PaymentRecord> _records = [
    _PaymentRecord(
      'November 2024',
      'Rs.2,500',
      'Paid',
      '15 Nov',
      'Monthly fee',
    ),
    _PaymentRecord('October 2024', 'Rs.2,500', 'Paid', '14 Oct', 'Monthly fee'),
    _PaymentRecord(
      'September 2024',
      'Rs.2,500',
      'Paid',
      '12 Sep',
      'Monthly fee',
    ),
    _PaymentRecord('August 2024', 'Rs.2,500', 'Paid', '10 Aug', 'Monthly fee'),
    _PaymentRecord(
      'December 2024',
      'Rs.2,500',
      'Pending',
      'Due: 15 Dec',
      'Awaiting confirmation',
    ),
    _PaymentRecord(
      'July 2024',
      'Rs.2,500',
      'Overdue',
      'Due: 28 Jul',
      'Needs follow-up',
    ),
  ];

  List<_PaymentRecord> get _filteredRecords {
    if (_filter == 'All') return _records;
    return _records.where((record) => record.status == _filter).toList();
  }

  int _amountToInt(String amount) {
    final digits = amount.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  int _sumByStatus(String status) {
    return _records
        .where((record) => record.status == status)
        .fold(0, (sum, record) => sum + _amountToInt(record.amount));
  }

  String _formatRs(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buffer.write(s[i]);
      final remaining = s.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) buffer.write(',');
    }
    return 'Rs.${buffer.toString()}';
  }

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
    final paidTotal = _sumByStatus('Paid');
    final pendingTotal = _sumByStatus('Pending');
    final overdueTotal = _sumByStatus('Overdue');
    final total = paidTotal + pendingTotal + overdueTotal;
    final records = _filteredRecords;

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.driverCyan.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: context.cardBgElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.inputBorder),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.arrow_back,
                            color: context.textPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppStrings.t('payment_history'),
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GlassCard(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.driverCyan.withValues(alpha: 0.18),
                              AppTheme.driverTeal.withValues(alpha: 0.12),
                            ],
                          ),
                          borderColor: AppTheme.driverCyan.withValues(
                            alpha: 0.35,
                          ),
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.driverGradient,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.receipt_long_rounded,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Payment Overview',
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Monthly fee collection status',
                                          style: TextStyle(
                                            color: context.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _SummaryCard(
                                      label: AppStrings.t('paid'),
                                      value: _formatRs(paidTotal),
                                      color: AppTheme.success,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _SummaryCard(
                                      label: AppStrings.t('pending'),
                                      value: _formatRs(pendingTotal),
                                      color: AppTheme.warning,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _SummaryCard(
                                      label: AppStrings.t('overdue'),
                                      value: _formatRs(overdueTotal),
                                      color: AppTheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: 4,
                            separatorBuilder: (_, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final items = [
                                AppStrings.t('all'),
                                AppStrings.t('paid'),
                                AppStrings.t('pending'),
                                AppStrings.t('overdue'),
                              ];
                              final filter = [
                                'All',
                                'Paid',
                                'Pending',
                                'Overdue',
                              ][index];
                              final selected = _filter == filter;
                              return GestureDetector(
                                onTap: () => setState(() => _filter = filter),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: selected
                                        ? AppTheme.driverGradient
                                        : null,
                                    color: selected ? null : context.cardBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: selected
                                        ? null
                                        : Border.all(
                                            color: context.cardBgElevated,
                                          ),
                                  ),
                                  child: Text(
                                    items[index],
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : context.textSecondary,
                                      fontSize: 12,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
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
                      if (records.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Text(
                            'No payment records found for this filter.',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        ...records.map(
                          (record) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _statusColor(
                                        record.status,
                                      ).withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        record.status == 'Paid'
                                            ? '✅'
                                            : record.status == 'Pending'
                                            ? '⏳'
                                            : '⚠️',
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                record.title,
                                                style: TextStyle(
                                                  color: context.textPrimary,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _statusColor(
                                                  record.status,
                                                ).withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                AppStrings.t(
                                                  record.status.toLowerCase(),
                                                ),
                                                style: TextStyle(
                                                  color: _statusColor(
                                                    record.status,
                                                  ),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          record.note,
                                          style: TextStyle(
                                            color: context.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              record.date,
                                              style: TextStyle(
                                                color: context.textTertiary,
                                                fontSize: 11,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              record.amount,
                                              style: TextStyle(
                                                color: context.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GlassCard(
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppStrings.t('payment_history'),
                                    style: TextStyle(
                                      color: context.textTertiary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              ShaderMask(
                                shaderCallback: (bounds) => AppTheme
                                    .driverGradient
                                    .createShader(bounds),
                                child: Text(
                                  _formatRs(total),
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
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':
        return AppTheme.success;
      case 'Pending':
        return AppTheme.warning;
      case 'Overdue':
        return AppTheme.error;
      default:
        return AppTheme.driverCyan;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRecord {
  final String title;
  final String amount;
  final String status;
  final String date;
  final String note;

  const _PaymentRecord(
    this.title,
    this.amount,
    this.status,
    this.date,
    this.note,
  );
}
