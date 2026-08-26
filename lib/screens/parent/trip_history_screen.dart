import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/language_provider.dart';
import '../../app/parent_data_service.dart';
import '../../data/trip_repository.dart';
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
  late Future<List<_Trip>> _tripsFuture;

  List<String> get _filters => ['Today', 'Week', 'Month', 'Year'];

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

  /// Family-wide (every child, same scope as the old mock list) trip history,
  /// built from real attendance records instead of the invented
  /// `buildParentTripHistoryEntries` list.
  ///
  /// A record still [AttendanceStatus.pending] (trip not yet resolved for
  /// this child) belongs in neither the "present" nor "absent" section this
  /// screen renders, so it's dropped rather than shown as a guess. Each
  /// record's parent [Trip] is fetched (deduplicated, in parallel) for its
  /// on-time verdict and start time — the same trade-off as the dashboard's
  /// stat tiles, acceptable here because a family's own trip list is capped
  /// at 50 records per child.
  Future<List<_Trip>> _loadTrips() async {
    final children = ParentDataService.instance.children.value;
    final childIds = children.map((c) => c.id).where((id) => id.isNotEmpty).toList();
    if (childIds.isEmpty) return const [];
    final childrenById = {for (final c in children) c.id: c};

    final allRecords = <AttendanceRecord>[];
    for (final id in childIds) {
      try {
        allRecords.addAll(
          await TripRepository.instance.fetchAttendanceForStudent(id),
        );
      } catch (_) {
        // Leave this child's contribution empty rather than fail the whole
        // family's history over one unreadable child.
      }
    }

    final resolved =
        allRecords.where((r) => r.status != AttendanceStatus.pending).toList();
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

    return resolved.map((r) {
      final trip = trips[r.tripId];
      final isMorning = trip?.type != TripType.afternoon;
      final date = trip?.startedAt ??
          r.markedAt ??
          DateTime.tryParse(r.dateKey) ??
          DateTime.now();
      final child = childrenById[r.studentId];
      final stop = (child != null && child.stop.isNotEmpty)
          ? child.stop
          : AppStrings.t('pickup');
      final school = (child != null && child.school.isNotEmpty)
          ? child.school
          : AppStrings.t('at_school');

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

  List<_Trip> _computeFilteredTrips(List<_Trip> trips) {
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
            0 => trips.where((t) => _isSameDay(t.date, today)).toList(),
            1 => trips.where((t) => _isInCurrentWeek(t.date, today)).toList(),
            2 =>
              trips
                  .where(
                    (t) =>
                        t.date.year == today.year &&
                        t.date.month == today.month,
                  )
                  .toList(),
            3 => trips.where((t) => t.date.year == today.year).toList(),
            _ => trips,
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
                        t.attendancePresent ? 'Present' : 'Absent',
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.parentPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.parentPurple.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '$tripCount ${AppStrings.t('trips_lbl')}',
              style: TextStyle(
                color: AppTheme.parentPurple,
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
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.parentPurple,
                        ),
                      ),
                    ),
                  ],
                );
              }

              final trips = snapshot.data ?? const <_Trip>[];
              final filteredTrips = _computeFilteredTrips(trips);
              final presentTrips = filteredTrips
                  .where((t) => t.attendancePresent)
                  .toList();
              final absentTrips = filteredTrips
                  .where((t) => !t.attendancePresent)
                  .toList();
              final onTime = presentTrips.where((t) => t.statusOk).length;
              final late = presentTrips.length - onTime;
              final present = filteredTrips.where((t) => t.attendancePresent).length;
              final absent = filteredTrips.length - present;

              return Column(
                children: [
                  _buildHeader(tripCount: trips.length),
                  Expanded(
                    child: trips.isEmpty
                        ? const _EmptyState(
                            message:
                                'No trips yet. Trip history will appear here '
                                'once your child starts riding.',
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                // Stats row
                                Row(
                                  children: [
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

                                // Filter chips
                                SizedBox(
                                  height: 36,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _filters.length,
                                          separatorBuilder: (_, _) =>
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
                                          'Showing ${_formatDate(_selectedCalendarDate!)}',
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

                                // Present section
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
                                          title: 'Present Trips',
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
                                              'No present trips found for this range.',
                                              style: TextStyle(
                                                color: context.textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        ...presentTrips.asMap().entries.map((
                                          e,
                                        ) {
                                          final t = e.value;
                                          final isLast =
                                              e.key == presentTrips.length - 1;
                                          return _buildTripRow(
                                            context: context,
                                            t: t,
                                            isLast: isLast,
                                            showStatus: true,
                                          );
                                        }),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Absent section
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
                                          title: 'Absent Trips',
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
                                              'No absent trips found for this range.',
                                              style: TextStyle(
                                                color: context.textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        ...absentTrips.asMap().entries.map((
                                          e,
                                        ) {
                                          final t = e.value;
                                          final isLast =
                                              e.key == absentTrips.length - 1;
                                          return _buildTripRow(
                                            context: context,
                                            t: t,
                                            isLast: isLast,
                                            showStatus: false,
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
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Honest empty state for a family with no trip history at all yet — shown
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
