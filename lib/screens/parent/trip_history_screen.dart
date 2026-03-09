import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  int _filterIndex = 0;

  List<String> get _filters => [
    AppStrings.t('all_filter'),
    AppStrings.t('morning_filter'),
    AppStrings.t('afternoon'),
    AppStrings.t('this_week'),
  ];

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

  final _trips = const [
    _Trip(
      date: 'Mon, Mar 3 2026',
      type: 'Morning Pickup',
      from: 'Oak Street Stop',
      to: 'Lincoln Elementary',
      time: '07:15 AM',
      duration: '28 min',
      status: 'On Time',
      statusOk: true,
    ),
    _Trip(
      date: 'Mon, Mar 3 2026',
      type: 'Afternoon Drop-off',
      from: 'Lincoln Elementary',
      to: 'Oak Street Stop',
      time: '03:30 PM',
      duration: '31 min',
      status: 'On Time',
      statusOk: true,
    ),
    _Trip(
      date: 'Tue, Mar 4 2026',
      type: 'Morning Pickup',
      from: 'Oak Street Stop',
      to: 'Lincoln Elementary',
      time: '07:20 AM',
      duration: '30 min',
      status: '5 min late',
      statusOk: false,
    ),
    _Trip(
      date: 'Tue, Mar 4 2026',
      type: 'Afternoon Drop-off',
      from: 'Lincoln Elementary',
      to: 'Oak Street Stop',
      time: '03:30 PM',
      duration: '29 min',
      status: 'On Time',
      statusOk: true,
    ),
    _Trip(
      date: 'Wed, Mar 5 2026',
      type: 'Morning Pickup',
      from: 'Oak Street Stop',
      to: 'Lincoln Elementary',
      time: '07:14 AM',
      duration: '27 min',
      status: '1 min early',
      statusOk: true,
    ),
    _Trip(
      date: 'Wed, Mar 5 2026',
      type: 'Afternoon Drop-off',
      from: 'Lincoln Elementary',
      to: 'Oak Street Stop',
      time: '03:30 PM',
      duration: '32 min',
      status: 'On Time',
      statusOk: true,
    ),
    _Trip(
      date: 'Thu, Mar 6 2026',
      type: 'Morning Pickup',
      from: 'Oak Street Stop',
      to: 'Lincoln Elementary',
      time: '07:18 AM',
      duration: '29 min',
      status: 'On Time',
      statusOk: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final onTime = _trips.where((t) => t.statusOk).length;
    final late = _trips.length - onTime;

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.parentPurple.withOpacity(0.2),
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
                    Text(
                      AppStrings.t('trip_history_title'),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.parentPurple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.parentPurple.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '${_trips.length} ${AppStrings.t('trips_lbl')}',
                        style: TextStyle(
                          color: AppTheme.parentPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Stats row
                      Row(
                        children: [
                          Expanded(
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 12,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${_trips.length}',
                                    style: TextStyle(
                                      color: AppTheme.parentPurple,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppStrings.t('total_trips'),
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 12,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$onTime',
                                    style: const TextStyle(
                                      color: AppTheme.success,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppStrings.t('on_time'),
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 12,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$late',
                                    style: const TextStyle(
                                      color: AppTheme.warning,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppStrings.t('delayed'),
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Filter chips
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _filters.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final selected = i == _filterIndex;
                            return GestureDetector(
                              onTap: () => setState(() => _filterIndex = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  gradient: selected
                                      ? AppTheme.parentGradient
                                      : null,
                                  color: selected
                                      ? null
                                      : context.cardBgElevated,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected
                                        ? Colors.transparent
                                        : context.surfaceBorder,
                                  ),
                                ),
                                child: Text(
                                  _filters[i],
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : context.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Trip list
                      GlassCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            ..._trips.asMap().entries.map((e) {
                              final t = e.value;
                              final isLast = e.key == _trips.length - 1;
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  border: isLast
                                      ? null
                                      : Border(
                                          bottom: BorderSide(
                                            color: context.surfaceBorder,
                                          ),
                                        ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color:
                                            (t.statusOk
                                                    ? AppTheme.success
                                                    : AppTheme.warning)
                                                .withOpacity(0.13),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              (t.statusOk
                                                      ? AppTheme.success
                                                      : AppTheme.warning)
                                                  .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          t.type.contains('Pickup')
                                              ? '🚌'
                                              : '🏫',
                                          style: const TextStyle(fontSize: 18),
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
                                                  t.type,
                                                  style: TextStyle(
                                                    color: context.textPrimary,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      (t.statusOk
                                                              ? AppTheme.success
                                                              : AppTheme
                                                                    .warning)
                                                          .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  t.status,
                                                  style: TextStyle(
                                                    color: t.statusOk
                                                        ? AppTheme.success
                                                        : AppTheme.warning,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${t.from}  →  ${t.to}',
                                            style: TextStyle(
                                              color: context.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Text(
                                                t.date,
                                                style: TextStyle(
                                                  color: context.textTertiary,
                                                  fontSize: 10,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${t.time}  ·  ${t.duration}',
                                                style: TextStyle(
                                                  color: context.textTertiary,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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
}

class _Trip {
  final String date, type, from, to, time, duration, status;
  final bool statusOk;

  const _Trip({
    required this.date,
    required this.type,
    required this.from,
    required this.to,
    required this.time,
    required this.duration,
    required this.status,
    required this.statusOk,
  });
}
