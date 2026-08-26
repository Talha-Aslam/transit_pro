import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/language_provider.dart';
import '../../app/session_service.dart';
import '../../app/student_data_service.dart';
import '../../data/trip_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class StudentTripHistoryScreen extends StatefulWidget {
  const StudentTripHistoryScreen({super.key});

  @override
  State<StudentTripHistoryScreen> createState() =>
      _StudentTripHistoryScreenState();
}

class _StudentTripHistoryScreenState extends State<StudentTripHistoryScreen> {
  static const _weekdayAbbrev = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const _monthAbbrev = [
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

  int _filterIndex = 1;
  DateTime? _selectedCalendarDate;
  late Future<List<_Trip>> _tripsFuture;

  List<String> get _filters => [
    AppStrings.t('all_lbl'),
    AppStrings.t('today'),
    AppStrings.t('week_lbl'),
    AppStrings.t('month_lbl'),
    AppStrings.t('year_lbl'),
  ];

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _tripsFuture = _loadTrips();
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  /// This student's own trip history, built from real attendance records
  /// instead of the invented `buildParentTripHistoryEntries` list every
  /// student used to see identically.
  ///
  /// A record still [AttendanceStatus.pending] belongs in neither the
  /// "present" nor "absent" section below, so it's dropped. Each record's
  /// parent [Trip] is fetched (deduplicated, in parallel) for its real
  /// on-time verdict and start time — capped at 50 records for one student,
  /// so this stays cheap.
  Future<List<_Trip>> _loadTrips() async {
    final studentId = SessionService.instance.uid;
    if (studentId == null || studentId.isEmpty) return const [];

    List<AttendanceRecord> records;
    try {
      records =
          await TripRepository.instance.fetchAttendanceForStudent(studentId);
    } catch (_) {
      return const [];
    }

    final resolved =
        records.where((r) => r.status != AttendanceStatus.pending).toList();
    if (resolved.isEmpty) return const [];

    final tripIds =
        resolved.map((r) => r.tripId).where((id) => id.isNotEmpty).toSet();
    final trips = <String, Trip>{};
    if (tripIds.isNotEmpty) {
      final fetched = await Future.wait(
        tripIds.map((id) async {
          try {
            return await TripRepository.instance.watchTrip(id).first;
          } catch (_) {
            return null;
          }
        }),
      );
      for (final t in fetched) {
        if (t != null) trips[t.id] = t;
      }
    }

    final info = StudentDataService.instance.studentInfo.value;
    final stop = info.stop.isNotEmpty ? info.stop : AppStrings.t('pickup');
    final school =
        info.school.isNotEmpty ? info.school : AppStrings.t('at_school');

    return resolved.map((r) {
      final trip = trips[r.tripId];
      final isMorning = trip?.type != TripType.afternoon;
      final date = trip?.startedAt ??
          r.markedAt ??
          DateTime.tryParse(r.dateKey) ??
          DateTime.now();

      final String status;
      final bool statusOk;
      final onTime = trip?.onTime;
      if (onTime == true) {
        status = AppStrings.t('trip_status_on_time');
        statusOk = true;
      } else if (onTime == false) {
        final mins = trip?.delayMinutes;
        status = mins != null ? '$mins min late' : 'Delayed';
        statusOk = false;
      } else {
        // Trip closed with no recorded verdict (or still in progress) —
        // "Completed" rather than fabricating a late/on-time claim.
        status = 'Completed';
        statusOk = true;
      }

      return _Trip(
        date: date,
        type: AppStrings.t(
          isMorning ? 'trip_type_morning_pickup' : 'trip_type_afternoon_dropoff',
        ),
        from: isMorning ? stop : school,
        to: isMorning ? school : stop,
        time: _formatTime(date),
        status: status,
        statusOk: statusOk,
        attendancePresent: r.status == AttendanceStatus.boarded,
        isMorning: isMorning,
      );
    }).toList();
  }

  String _formatTime(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Filters an already-computed [trips] list — takes the list rather than
  /// calling the [_trips] getter itself, so a single build only rebuilds the
  /// (currently mock) trip list once instead of once per branch below.
  List<_Trip> _filterTrips(List<_Trip> trips) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);

    final selectedTrips = _selectedCalendarDate != null
        ? trips
              .where(
                (t) => _isSameDay(
                  t.date,
                  DateUtils.dateOnly(_selectedCalendarDate!),
                ),
              )
              .toList()
        : switch (_filterIndex) {
            0 => List<_Trip>.of(trips),
            1 => trips.where((t) => _isSameDay(t.date, today)).toList(),
            2 => trips.where((t) => _isInCurrentWeek(t.date, today)).toList(),
            3 =>
              trips
                  .where(
                    (t) =>
                        t.date.year == today.year &&
                        t.date.month == today.month,
                  )
                  .toList(),
            4 => trips.where((t) => t.date.year == today.year).toList(),
            _ => List<_Trip>.of(trips),
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
    return '${_weekdayAbbrev[date.weekday - 1]}, '
        '${_monthAbbrev[date.month - 1]} ${date.day} ${date.year}';
  }

  Future<void> _pickCalendarDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedCalendarDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.studentAmber),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() => _selectedCalendarDate = picked);
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required int count,
    required Color accent,
  }) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 22,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTripRow({
    required BuildContext context,
    required _Trip t,
    required bool isLast,
    required bool showStatus,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: context.surfaceBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (t.attendancePresent ? AppTheme.success : AppTheme.error)
                  .withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (t.attendancePresent ? AppTheme.success : AppTheme.error)
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (t.attendancePresent
                                    ? AppTheme.success
                                    : AppTheme.error)
                                .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t.attendancePresent
                            ? AppStrings.t('present_lbl')
                            : AppStrings.t('absent'),
                        style: TextStyle(
                          color: t.attendancePresent
                              ? AppTheme.success
                              : AppTheme.error,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (showStatus) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (t.statusOk ? AppTheme.success : AppTheme.warning)
                                  .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
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
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${t.from}  ${AppStrings.t('trip_to_arrow')}  ${t.to}',
                  style: TextStyle(color: context.textSecondary, fontSize: 11),
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
  }

  Widget _buildHeader({required int tripCount}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.studentAmber.withValues(alpha: 0.2),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.studentAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.studentAmber.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '$tripCount ${AppStrings.t('trips_lbl')}',
              style: TextStyle(
                color: AppTheme.studentAmber,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: FutureBuilder<List<_Trip>>(
            future: _tripsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Column(
                  children: [
                    _buildHeader(tripCount: 0),
                    Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.studentAmber,
                        ),
                      ),
                    ),
                  ],
                );
              }

              final trips = snapshot.data ?? const <_Trip>[];
              final filteredTrips = _filterTrips(trips);
              final presentTrips = filteredTrips
                  .where((t) => t.attendancePresent)
                  .toList();
              final absentTrips = filteredTrips
                  .where((t) => !t.attendancePresent)
                  .toList();
              final onTime = presentTrips.where((t) => t.statusOk).length;
              final late = presentTrips.length - onTime;
              final present = presentTrips.length;
              final absent = absentTrips.length;

              return Column(
                children: [
                  _buildHeader(tripCount: trips.length),
                  Expanded(
                    child: trips.isEmpty
                        ? _EmptyState(
                            message:
                                'No trips yet. Trip history will appear here '
                                'once you start riding.',
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: GlassCard(
                                        // One of 3 stat tiles side by side — a
                                        // repeated-item row, not a one-off card.
                                        enableBlur: false,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                          horizontal: 12,
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              '${filteredTrips.length}',
                                              style: TextStyle(
                                                color: AppTheme.studentAmber,
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
                                        enableBlur: false,
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
                                        enableBlur: false,
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
                                SizedBox(
                                  height: 36,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _filters.length,
                                          separatorBuilder: (_, index) =>
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
                                                      ? AppTheme.studentGradient
                                                      : null,
                                                  color: selected
                                                      ? null
                                                      : context.cardBgElevated,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
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
                                            borderRadius:
                                                BorderRadius.circular(12),
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
                                          '${AppStrings.t('showing_date')} ${_formatDate(_selectedCalendarDate!)}',
                                          style: TextStyle(
                                            color: context.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(
                                          () => _selectedCalendarDate = null,
                                        ),
                                        child: Text(
                                          AppStrings.t('clear_lbl'),
                                          style: TextStyle(
                                            color: AppTheme.studentAmber,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 14),
                                GlassCard(
                                  // Holds a variable-length, unbounded list of
                                  // trip rows and dominates the scrollable
                                  // body along with the absent-trips card
                                  // below — not a small, static accent card.
                                  enableBlur: false,
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          14,
                                          12,
                                          14,
                                          8,
                                        ),
                                        child: _buildSectionHeader(
                                          context: context,
                                          title: AppStrings.t('present_trips'),
                                          count: present,
                                          accent: AppTheme.success,
                                        ),
                                      ),
                                      if (presentTrips.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            0,
                                            14,
                                            14,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              AppStrings.t('no_present_trips'),
                                              style: TextStyle(
                                                color: context.textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: presentTrips.length,
                                          itemBuilder: (context, i) {
                                            final t = presentTrips[i];
                                            final isLast =
                                                i == presentTrips.length - 1;
                                            return KeyedSubtree(
                                              key: ValueKey(
                                                'present-${t.date.millisecondsSinceEpoch}-${t.type}-${t.time}',
                                              ),
                                              child: _buildTripRow(
                                                context: context,
                                                t: t,
                                                isLast: isLast,
                                                showStatus: true,
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                GlassCard(
                                  enableBlur: false,
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          14,
                                          12,
                                          14,
                                          8,
                                        ),
                                        child: _buildSectionHeader(
                                          context: context,
                                          title: AppStrings.t('absent_trips'),
                                          count: absent,
                                          accent: AppTheme.error,
                                        ),
                                      ),
                                      if (absentTrips.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            0,
                                            14,
                                            14,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              AppStrings.t('no_absent_trips'),
                                              style: TextStyle(
                                                color: context.textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: absentTrips.length,
                                          itemBuilder: (context, i) {
                                            final t = absentTrips[i];
                                            final isLast =
                                                i == absentTrips.length - 1;
                                            return KeyedSubtree(
                                              key: ValueKey(
                                                'absent-${t.date.millisecondsSinceEpoch}-${t.type}-${t.time}',
                                              ),
                                              child: _buildTripRow(
                                                context: context,
                                                t: t,
                                                isLast: isLast,
                                                showStatus: false,
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Honest empty state for a student with no trip history at all yet — shown
/// instead of zeroed-out stat cards and empty sections, which used to look
/// like a loading glitch rather than "nothing has happened yet".
class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textTertiary, fontSize: 13),
        ),
      ),
    );
  }
}

class _Trip {
  final DateTime date;
  final String type, from, to, time, status;
  final bool statusOk;
  final bool attendancePresent;
  final bool isMorning;

  const _Trip({
    required this.date,
    required this.type,
    required this.from,
    required this.to,
    required this.time,
    required this.status,
    required this.statusOk,
    required this.attendancePresent,
    required this.isMorning,
  });
}
