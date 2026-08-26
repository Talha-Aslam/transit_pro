import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/language_provider.dart';
import '../../app/session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/payment_presentation.dart';

/// What the driver has actually been paid, straight off `payments`.
///
/// Previously six hardcoded `_PaymentRecord`s whose money was a string
/// (`'Rs.2,500'`) that the summary cards parsed back out with a regex. Now every
/// figure comes from the live `Payment` documents this driver is allowed to read,
/// and every format/colour/total decision goes through
/// `widgets/payment_presentation.dart` so the three fee screens agree.
class DriverPaymentHistoryScreen extends StatefulWidget {
  const DriverPaymentHistoryScreen({super.key});

  @override
  State<DriverPaymentHistoryScreen> createState() =>
      _DriverPaymentHistoryScreenState();
}

class _DriverPaymentHistoryScreenState
    extends State<DriverPaymentHistoryScreen> {
  String _filter = 'All';

  /// The chip keys, built once. The old code rebuilt two four-element `filters`
  /// and `labels` lists *inside* `itemBuilder`, so a horizontal scroll
  /// reallocated eight strings per visible chip per frame.
  static final List<String> _filterKeys = paymentFilters.keys.toList();

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

  /// Every student this driver can name, keyed by id.
  ///
  /// Two sources because a driver can have passengers from either: [roster] is
  /// whoever's ride request they accepted, [routeStudents] is whoever an admin
  /// put on their route. Roster wins on a collision — it is the direct
  /// relationship. Both are already in memory, so resolving a payment to a
  /// student costs no extra reads.
  Map<String, Student> _studentsById(
    List<Student> roster,
    List<Student> routeStudents,
  ) {
    final map = <String, Student>{};
    for (final s in routeStudents) {
      map[s.id] = s;
    }
    for (final s in roster) {
      map[s.id] = s;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionService.instance;

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                // Session state drives loading/error; roster and routeStudents
                // resolve the names on each row; payments is the list itself.
                child: ValueListenableBuilder<SessionState>(
                  valueListenable: session.state,
                  builder: (context, state, _) =>
                      ValueListenableBuilder<List<Student>>(
                    valueListenable: session.roster,
                    builder: (context, roster, _) =>
                        ValueListenableBuilder<List<Student>>(
                      valueListenable: session.routeStudents,
                      builder: (context, routeStudents, _) =>
                          ValueListenableBuilder<List<Payment>>(
                        valueListenable: session.payments,
                        builder: (context, payments, _) => _buildBody(
                          state: state,
                          payments: payments,
                          students: _studentsById(roster, routeStudents),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required SessionState state,
    required List<Payment> payments,
    required Map<String, Student> students,
  }) {
    final totals = PaymentTotals.of(payments);
    final visible = applyPaymentFilter(payments, paymentFilters[_filter]);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildOverview(totals),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFilters(),
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
          _buildRecords(
            state: state,
            all: payments,
            visible: visible,
            students: students,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFooter(totals),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
    );
  }

  Widget _buildOverview(PaymentTotals totals) {
    return GlassCard(
      gradient: LinearGradient(
        colors: [
          AppTheme.driverCyan.withValues(alpha: 0.18),
          AppTheme.driverTeal.withValues(alpha: 0.12),
        ],
      ),
      borderColor: AppTheme.driverCyan.withValues(alpha: 0.35),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      'Who paid how much and when',
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
                  value: paisaToDisplay(totals.paid),
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  label: AppStrings.t('pending'),
                  value: paisaToDisplay(totals.pending),
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  label: AppStrings.t('overdue'),
                  value: paisaToDisplay(totals.overdue),
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filterKeys.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filterKeys[index];
          final selected = _filter == filter;
          return GestureDetector(
            onTap: () => setState(() => _filter = filter),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                gradient: selected ? AppTheme.driverGradient : null,
                color: selected ? null : context.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: selected
                    ? null
                    : Border.all(color: context.cardBgElevated),
              ),
              child: Text(
                AppStrings.t(filter.toLowerCase()),
                style: TextStyle(
                  color: selected ? Colors.white : context.textSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecords({
    required SessionState state,
    required List<Payment> all,
    required List<Payment> visible,
    required Map<String, Student> students,
  }) {
    // Until an admin issues fees the collection is genuinely empty, so say that
    // rather than implying something failed.
    const nothingYet =
        'No payments yet. Fees appear here once they are issued for students '
        'on your rounds.';

    if (all.isEmpty && state == SessionState.loading) {
      return const PaymentListState(
        loading: true,
        emptyMessage: nothingYet,
        accent: AppTheme.driverCyan,
      );
    }
    if (all.isEmpty && state == SessionState.error) {
      return PaymentListState(
        error: SessionService.instance.lastError ?? 'unknown',
        emptyMessage: nothingYet,
        accent: AppTheme.driverCyan,
      );
    }
    if (visible.isEmpty) {
      return PaymentListState(
        emptyMessage: all.isEmpty
            ? nothingYet
            : 'No payment records found for this filter.',
        accent: AppTheme.driverCyan,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final payment in visible) _buildRow(payment, students),
        ],
      ),
    );
  }

  Widget _buildRow(Payment payment, Map<String, Student> students) {
    final student = students[payment.studentId];

    // The row leads with the *student's* name, not the payer's. The mock showed
    // a parent name ('Ayesha Khan'), which a driver cannot obtain: firestore
    // rules restrict `users/{uid}` reads to the owner or an admin, so a driver
    // reading the parent behind `payment.parentId` is permission-denied by
    // design. The student, however, is already on this driver's roster/route,
    // so their name is free. Showing the student is both readable and the more
    // useful identifier for a driver scanning their own rounds.
    if (student == null) {
      // Paid up, then left the roster — we no longer have a name to show, but
      // the money still belongs in the driver's history.
      return PaymentRow(
        payment: payment,
        title: monthLabel(payment.monthKey),
        subtitle: 'Former student',
      );
    }

    return PaymentRow(
      payment: payment,
      title: student.name,
      subtitle: monthLabel(payment.monthKey),
    );
  }

  Widget _buildFooter(PaymentTotals totals) {
    return GlassCard(
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
                'All payment history',
                style: TextStyle(color: context.textTertiary, fontSize: 12),
              ),
            ],
          ),
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.driverGradient.createShader(bounds),
            child: Text(
              paisaToDisplay(totals.billed),
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
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
