import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/language_provider.dart';
import '../../models/parent_trip_history_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  int _filterIndex = 1;
  DateTime? _selectedCalendarDate;

  List<String> get _filters => ['Today', 'Week', 'Month', 'Year'];

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

  List<_Trip> get _trips => buildParentTripHistoryEntries(DateTime.now())
      .where((entry) => entry.completed)
      .map(
        (entry) => _Trip(
          date: entry.date,
          type: AppStrings.t(entry.typeKey),
          from: entry.from,
          to: entry.to,
          time: entry.time,
          status: AppStrings.t(entry.statusKey),
          statusOk: entry.statusOk,
          isMorning: entry.isMorning,
        ),
      )
      .toList();

  List<_Trip> get _filteredTrips {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);

    final selectedTrips = _selectedCalendarDate != null
        ? _trips
              .where(
                (t) => _isSameDay(
                  t.date,
                  DateUtils.dateOnly(_selectedCalendarDate!),
                ),
              )
              .toList()
        : switch (_filterIndex) {
            0 => _trips.where((t) => _isSameDay(t.date, today)).toList(),
            1 => _trips.where((t) => _isInCurrentWeek(t.date, today)).toList(),
            2 =>
              _trips
                  .where(
                    (t) =>
                        t.date.year == today.year &&
                        t.date.month == today.month,
                  )
                  .toList(),
            3 => _trips.where((t) => t.date.year == today.year).toList(),
            _ => _trips,
          };

    selectedTrips.sort((a, b) => b.date.compareTo(a.date));
    return selectedTrips;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isInCurrentWeek(DateTime value, DateTime today) {
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    final valueDay = DateUtils.dateOnly(value);
    return !valueDay.isBefore(startOfWeek) && valueDay.isBefore(endOfWeek);
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day} ${date.year}';
  }

  Future<void> _pickCalendarDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedCalendarDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() => _selectedCalendarDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final filteredTrips = _filteredTrips;
    final onTime = filteredTrips.where((t) => t.statusOk).length;
    final late = filteredTrips.length - onTime;

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
                      AppTheme.parentPurple.withValues(alpha: 0.2),
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
                        color: AppTheme.parentPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.parentPurple.withValues(alpha: 0.3),
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
                                    '${filteredTrips.length}',
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
                        child: Row(
                          children: [
                            Expanded(
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _filters.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, i) {
                                  final selected =
                                      i == _filterIndex &&
                                      _selectedCalendarDate == null;
                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      _filterIndex = i;
                                      _selectedCalendarDate = null;
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
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
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _pickCalendarDate,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: context.cardBgElevated,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: context.surfaceBorder,
                                  ),
                                ),
                                child: Icon(
                                  Icons.calendar_month_rounded,
                                  color: context.textSecondary,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedCalendarDate != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Showing ${_formatDate(_selectedCalendarDate!)}',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCalendarDate = null),
                              child: Text(
                                'Clear',
                                style: TextStyle(
                                  color: AppTheme.parentPurple,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Trip list
                      GlassCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            if (filteredTrips.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(18),
                                child: Text(
                                  'No trips found for this range.',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ...filteredTrips.asMap().entries.map((e) {
                              final t = e.value;
                              final isLast = e.key == filteredTrips.length - 1;
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
                                                .withValues(alpha: 0.13),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              (t.statusOk
                                                      ? AppTheme.success
                                                      : AppTheme.warning)
                                                  .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          t.isMorning ? '🚌' : '🏫',
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
                                                          .withValues(alpha: 0.15),
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
                                            '${t.from}  ${AppStrings.t('trip_to_arrow')}  ${t.to}',
                                            style: TextStyle(
                                              color: context.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Text(
                                                _formatDate(t.date),
                                                style: TextStyle(
                                                  color: context.textTertiary,
                                                  fontSize: 10,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                t.time,
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
  final DateTime date;
  final String type, from, to, time, status;
  final bool statusOk;
  final bool isMorning;

  const _Trip({
    required this.date,
    required this.type,
    required this.from,
    required this.to,
    required this.time,
    required this.status,
    required this.statusOk,
    required this.isMorning,
  });
}
