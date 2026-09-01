import 'dart:async';

import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';
import '../../app/attendance_service.dart';
import '../../app/driver_data_service.dart';
import '../../app/language_provider.dart';
import '../../app/parent_data_service.dart';
import '../../app/session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ParentSchedule extends StatefulWidget {
  final VoidCallback onBack;
  const ParentSchedule({super.key, required this.onBack});

  @override
  State<ParentSchedule> createState() => _ParentScheduleState();
}

class _ParentScheduleState extends State<ParentSchedule> {
  // Derived from the real current weekday (0=Mon..4=Fri) instead of a
  // hardcoded "Wednesday". Weekends clamp to Friday since `_weekDays` only
  // covers the school week.
  int _selectedDay = _todayIndex();

  static int _todayIndex() {
    final idx = DateTime.now().weekday - 1; // 1=Mon..7=Sun -> 0=Mon..6=Sun
    return idx.clamp(0, _weekDays.length - 1);
  }

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  /// Per-day attendance choice, keyed by child id then by date (normalized to
  /// midnight via [_dateOnly] so a `DateTime.now()` with a nonzero time of
  /// day never fails to match the same day's entry). Nesting by child id
  /// keeps the child switcher above from leaking one child's choices onto
  /// another's — same reason the old tomorrow-only version keyed by child id.
  /// A missing entry for a date means "no notice sent" and defaults to
  /// attending, the common case, rather than an ambiguous unset state.
  final Map<String, Map<DateTime, bool>> _attendanceByChildAndDate = {};

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<DateTime, bool> _attendanceFor(ChildInfo child) =>
      _attendanceByChildAndDate.putIfAbsent(child.id, () => {});

  /// Whether [child] is marked attending on [date] — `true` (attending) when
  /// no notice has been sent for that date yet.
  bool _isAttending(ChildInfo? child, DateTime date) {
    if (child == null) return true;
    return _attendanceFor(child)[_dateOnly(date)] ?? true;
  }

  /// Id of the child whose attendance is mid-submit, so only that card's
  /// controls disable/show a spinner -- not every child's, and not the rest
  /// of the screen.
  String? _submittingAttendanceFor;

  /// Flips [child]'s attendance for [date] and submits immediately -- a
  /// single deliberate tap, not something that needs debouncing.
  void _onAttendanceToggle(ChildInfo child, DateTime date, bool attending) {
    setState(() => _attendanceFor(child)[_dateOnly(date)] = attending);
    unawaited(_submitAttendance(child, date: date, attending: attending));
  }

  /// Sends the parent's attendance choice for [date] to the driver via
  /// [AttendanceService] and shows a confirmation once it lands.
  Future<void> _submitAttendance(
    ChildInfo child, {
    required DateTime date,
    required bool attending,
  }) async {
    setState(() => _submittingAttendanceFor = child.id);
    try {
      await AttendanceService.instance.updateAttendance(
        studentId: child.id,
        date: date,
        isAttending: attending,
      );
      if (!mounted) return;
      final name = child.name.isEmpty ? 'Your child' : child.name;
      final dayLabel = _dateOnly(date) == _dateOnly(DateTime.now())
          ? 'today'
          : 'on ${_fullWeekDays[date.weekday - 1]}';
      final message = attending
          ? 'Driver notified: $name is attending $dayLabel.'
          : 'Driver notified: $name will be absent $dayLabel.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    } finally {
      if (mounted) setState(() => _submittingAttendanceFor = null);
    }
  }

  void _onLangChanged() => setState(() {});

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  static const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  static const _fullWeekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  /// Full Mon–Fri dates of the *current* week -- the single source of truth
  /// [_dates] (day-of-month for the header row) and the day-selector's
  /// absence dots both read from, so the two can never disagree about which
  /// calendar day column `i` represents.
  List<DateTime> get _weekDates {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return List.generate(5, (i) => monday.add(Duration(days: i)));
  }

  /// Day-of-month for Mon–Fri of the *current* week, so the day selector
  /// stays in step with the header's date range below instead of always
  /// showing a fixed "Feb 23–27".
  List<int> get _dates => _weekDates.map((d) => d.day).toList();

  /// True when [date] is marked "Not Attending" for [child] -- so the week's
  /// day-selector dots can turn red for exactly the days the parent marked
  /// absent, reading straight from [_attendanceByChildAndDate]. This is the
  /// whole mechanism -- no separate calendar state to keep in sync, the day
  /// selector just asks this method per date.
  bool _isAbsentOn(ChildInfo? child, DateTime date) =>
      !_isAttending(child, date);

  /// The selected child's assigned driver, resolved the same way
  /// `ParentDashboard._timingSlotsFor` does: `child.driver` is the driver's
  /// uid (set by `ParentDataService._rebuild`), and `SessionService
  /// .driverFor` looks it up in the cache `SessionService._resolveReferences`
  /// fills in. Null before that resolution lands or when no driver is
  /// assigned yet.
  Driver? _driverFor(ChildInfo? child) {
    if (child == null || child.driver.isEmpty) return null;
    return SessionService.instance.driverFor(child.driver);
  }

  /// Real pickup/drop-off times for [driver], or null when no driver has
  /// been resolved yet — the caller shows a placeholder instead of a
  /// fabricated time.
  DriverTimingSlots? _timingSlotsFor(Driver? driver) {
    if (driver == null) return null;
    return DriverTimingSlots.fromMap(driver.timingSlots);
  }

  /// Builds the Mon–Fri schedule from the assigned driver's real data.
  ///
  /// `DriverTimingSlots` only stores one set of times, not one per weekday,
  /// so every day shares the same real pickup/drop-off time — what differs
  /// per day is the 'done'/'today'/'upcoming' status (derived from the real
  /// current date instead of a hardcoded 'Wednesday') and whether the driver
  /// actually runs that weekday at all, per `DriverSchedule.runsOn` (empty
  /// `weekdays` on every schedule means "every day").
  List<_DaySchedule> _buildSchedule(Driver? driver, DriverTimingSlots? slots) {
    final todayWeekday = DateTime.now().weekday; // 1=Mon..7=Sun
    final pickup = slots == null
        ? '—'
        : formatTimeOfDay(slots.morningPickupFromHome);
    final dropoff = slots == null
        ? '—'
        : formatTimeOfDay(slots.afternoonDropoffAtHome);
    final schedules = driver?.schedules ?? const [];

    return List.generate(5, (i) {
      final weekday = i + 1; // Mon=1..Fri=5
      final runsThisDay =
          schedules.isEmpty || schedules.any((s) => s.runsOn(weekday));
      final status = weekday == todayWeekday
          ? 'today'
          : weekday < todayWeekday
          ? 'done'
          : 'upcoming';
      return _DaySchedule(
        day: _weekDays[i],
        pickup: pickup,
        dropoff: dropoff,
        status: status,
        note: (driver != null && !runsThisDay) ? 'No pickup this day' : '',
      );
    });
  }

  /// `HH:mm` (24h) → `07:15 AM`, matching `RouteStop.scheduledTime`'s stored
  /// form. Unparseable input (blank for a stop nobody has timed yet) shows as
  /// '—' rather than a bogus time.
  static String _formatHHmm(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return '—';
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return '—';
    final period = h < 12 ? 'AM' : 'PM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  static const _months = [
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

  /// e.g. "Feb 23–27, 2026" for the current week's Mon–Fri, computed instead
  /// of hardcoded.
  String _weekRangeLabel() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final friday = monday.add(const Duration(days: 4));
    final startLabel = '${_months[monday.month - 1]} ${monday.day}';
    final endLabel = monday.month == friday.month
        ? '${friday.day}'
        : '${_months[friday.month - 1]} ${friday.day}';
    return '$startLabel–$endLabel, ${friday.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ChildInfo>>(
      valueListenable: ParentDataService.instance.children,
      builder: (context, children, _) {
        return ValueListenableBuilder<int>(
          valueListenable: ParentDataService.instance.selectedChildIndex,
          builder: (context, selIdx, _) {
            final safeIdx = children.isEmpty
                ? 0
                : selIdx.clamp(0, children.length - 1);
            final child = children.isEmpty ? null : children[safeIdx];
            // Same "no bus assigned yet" signal `student_dashboard.dart` and
            // `parent_dashboard.dart` already gate on, rather than trusting
            // a driver-less default schedule.
            final hasBus =
                child != null &&
                (child.busNumber.isNotEmpty || child.route.isNotEmpty);
            final driver = _driverFor(child);
            final slots = _timingSlotsFor(driver);
            final schedule = _buildSchedule(driver, slots);
            final selectedIndex = _selectedDay.clamp(0, schedule.length - 1);
            final sel = schedule[selectedIndex];

            Color statusColor;
            String statusLabel;
            switch (sel.status) {
              case 'done':
                statusColor = AppTheme.success;
                statusLabel = AppStrings.t('completed_check');
                break;
              case 'today':
                statusColor = AppTheme.purple;
                statusLabel = AppStrings.t('active');
                break;
              default:
                statusColor = context.textTertiary;
                statusLabel = AppStrings.t('upcoming_clock');
            }

            // The real stop name this child boards at, resolved through the
            // admin-assigned route (`SessionService.stopNameFor`) — empty
            // when no admin route exists yet, rather than a fabricated
            // street name.
            final stopLabel = child != null && child.stop.isNotEmpty
                ? child.stop
                : AppStrings.t('your_stop');

            return _buildBody(
              context,
              children: children,
              selectedChildIndex: safeIdx,
              child: child,
              schedule: schedule,
              sel: sel,
              hasBus: hasBus,
              statusColor: statusColor,
              statusLabel: statusLabel,
              stopLabel: stopLabel,
              myStopId: SessionService.instance.selectedChild?.stopId,
            );
          },
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required List<ChildInfo> children,
    required int selectedChildIndex,
    required ChildInfo? child,
    required List<_DaySchedule> schedule,
    required _DaySchedule sel,
    required bool hasBus,
    required Color statusColor,
    required String statusLabel,
    required String stopLabel,
    required String? myStopId,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t('schedule'),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _weekRangeLabel(),
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // ── Child switcher (only when >1 child) ───────────────────
                // Same pattern `parent_dashboard.dart` already uses — without
                // this, a parent with more than one child could only ever
                // see whichever child was last selected elsewhere, with no
                // way to switch from this screen.
                if (children.length > 1) ...[
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: children.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final selected = i == selectedChildIndex;
                        return GestureDetector(
                          onTap: () =>
                              ParentDataService.instance.selectChild(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? AppTheme.parentGradient
                                  : null,
                              color: selected ? null : context.cardBgElevated,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? Colors.transparent
                                    : context.surfaceBorder,
                              ),
                            ),
                            child: Text(
                              children[i].name.isEmpty
                                  ? 'Child ${i + 1}'
                                  : children[i].name.split(' ').first,
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
                  const SizedBox(height: 12),
                ],
                // ── Day selector ─────────────────────────────────────────
                GlassCard(
                  enableBlur: false,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: List.generate(5, (i) {
                      final isSelected = _selectedDay == i;
                      final isToday = schedule[i].status == 'today';
                      // Bonus-task link: the absent-days dot color reads
                      // straight from the same `_tomorrowGoing`/
                      // `_absenceDays` state the attendance card below
                      // writes -- see `_isAbsentOn` -- so marking a
                      // multi-day absence there immediately turns the
                      // matching dates' dots red here, no separate
                      // calendar state to keep in sync.
                      final isAbsent = _isAbsentOn(child, _weekDates[i]);
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedDay = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.parentPurple.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.parentPurple.withValues(
                                        alpha: 0.5,
                                      )
                                    : Colors.transparent,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _weekDays[i],
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: isToday
                                        ? AppTheme.mainGradient
                                        : null,
                                    color: isToday
                                        ? null
                                        : isSelected
                                        ? context.cardBgElevated
                                        : context.cardBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${_dates[i]}',
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isAbsent
                                        ? AppTheme.error
                                        : schedule[i].status == 'done'
                                        ? AppTheme.success
                                        : schedule[i].status == 'today'
                                        ? AppTheme.purple
                                        : context.surfaceBorder,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Day detail ───────────────────────────────────────────
                GlassCard(
                  enableBlur: false,
                  gradient: sel.status == 'today'
                      ? LinearGradient(
                          colors: [
                            AppTheme.parentPurple.withValues(alpha: 0.12),
                            AppTheme.info.withValues(alpha: 0.06),
                          ],
                        )
                      : null,
                  borderColor: sel.status == 'today'
                      ? AppTheme.parentPurple.withValues(alpha: 0.25)
                      : null,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_fullWeekDays[_selectedDay]} Schedule',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (sel.note.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '⚡ ${sel.note}',
                                  style: const TextStyle(
                                    color: AppTheme.parentAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // Hidden for a new account / a day with no real
                          // driver schedule behind it (`!hasBus`) -- `sel
                          // .status` is derived purely from today's date
                          // (see `_buildSchedule`), so without this guard a
                          // brand-new family with no driver assigned yet
                          // would still see "Completed" on every day before
                          // today, describing a pickup that never happened.
                          if (hasBus)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!hasBus)
                        Text(
                          "Your driver hasn't set a schedule yet.",
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 13,
                          ),
                        )
                      else
                        Row(
                          children: [
                            _TimeCard(
                              emoji:
                                  'assets/images/schedule/waiting_for_bus_transparent.png',
                              label: AppStrings.t('morning_pickup'),
                              time: sel.pickup,
                              sub: stopLabel,
                            ),
                            const SizedBox(width: 12),
                            _TimeCard(
                              emoji:
                                  'assets/images/schedule/drop_off_transparent.png',
                              label: AppStrings.t('evening_drop'),
                              time: sel.dropoff,
                              sub: stopLabel,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Route timetable ───────────────────────────────────────
                // Real stops from the child's admin-assigned `BusRoute`
                // (`SessionService.route`, resolved from `selectedChild
                // .routeId`) rather than a fixed 5-street mock — absent
                // entirely for a pilot family with no admin route yet, per
                // this screen's own `hasBus` honesty rule above.
                ValueListenableBuilder<BusRoute?>(
                  valueListenable: SessionService.instance.route,
                  builder: (context, route, _) {
                    final stops = route?.orderedStops ?? const <RouteStop>[];
                    if (stops.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        GlassCard(
                          enableBlur: false,
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                route!.name.isNotEmpty
                                    ? '${route.name} — ${AppStrings.t('route_a_timetable')}'
                                    : AppStrings.t('route_a_timetable'),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      AppStrings.t('stop'),
                                      style: TextStyle(
                                        color: context.textTertiary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Center(
                                      child: Text(
                                        '🕐 TIME',
                                        style: TextStyle(
                                          color: context.textTertiary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...List.generate(stops.length, (i) {
                                final stop = stops[i];
                                final isDestination = i == stops.length - 1;
                                final isMine =
                                    myStopId != null &&
                                    myStopId.isNotEmpty &&
                                    stop.id == myStopId;
                                final highlighted = isDestination || isMine;
                                final tint = isDestination
                                    ? AppTheme.warning
                                    : AppTheme.parentPurple;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: highlighted
                                        ? tint.withValues(alpha: 0.08)
                                        : context.cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: highlighted
                                          ? tint.withValues(alpha: 0.2)
                                          : context.surfaceBorder,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text(
                                              isDestination
                                                  ? '🏫'
                                                  : isMine
                                                  ? '📍'
                                                  : '⭕',
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                isMine && !isDestination
                                                    ? '${stop.name} ($stopLabel)'
                                                    : stop.name,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: highlighted
                                                      ? tint
                                                      : context.textPrimary,
                                                  fontSize: 12,
                                                  fontWeight: highlighted
                                                      ? FontWeight.w700
                                                      : FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Center(
                                          child: Text(
                                            _formatHHmm(stop.scheduledTime),
                                            style: const TextStyle(
                                              color: AppTheme.successLight,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),

                // ── Attendance for the selected date ────────────────────────
                // Replaces the old "Upcoming Holidays" block. Only shown
                // once a driver is actually linked (`hasBus`) -- with no
                // driver assigned there is nobody to notify.
                if (hasBus && child != null)
                  _AttendanceToggleCard(
                    childName: child.name.isEmpty ? 'your child' : child.name,
                    date: _weekDates[_selectedDay],
                    dayLabel: _fullWeekDays[_selectedDay],
                    isToday: sel.status == 'today',
                    attending: _isAttending(child, _weekDates[_selectedDay]),
                    submitting: _submittingAttendanceFor == child.id,
                    onToggle: (attending) => _onAttendanceToggle(
                      child,
                      _weekDates[_selectedDay],
                      attending,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final String emoji, label, time, sub;
  const _TimeCard({
    required this.emoji,
    required this.label,
    required this.time,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBgElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              emoji,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: TextStyle(color: context.textTertiary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySchedule {
  final String day, pickup, dropoff, status, note;
  const _DaySchedule({
    required this.day,
    required this.pickup,
    required this.dropoff,
    required this.status,
    required this.note,
  });
}

/// Attendance toggle for whichever date is selected in the day selector
/// above -- not just tomorrow. Defaults green/"Attending"; tapping it flips
/// to red/"Not Attending" and calls [onToggle], which the screen wires to
/// [AttendanceService] via `_submitAttendance`.
///
/// Neumorphic rather than `GlassCard` (glassmorphic, like the rest of this
/// screen) per this task's own styling ask -- built the same two-opposing-
/// `BoxShadow` way `student_schedule.dart`'s `_DayScheduleCard` already
/// does, since that's the one neumorphic recipe already established in this
/// app rather than inventing a second one.
class _AttendanceToggleCard extends StatelessWidget {
  final String childName;
  final DateTime date;
  final String dayLabel;
  final bool isToday;
  final bool attending;
  final bool submitting;
  final ValueChanged<bool> onToggle;

  const _AttendanceToggleCard({
    required this.childName,
    required this.date,
    required this.dayLabel,
    required this.isToday,
    required this.attending,
    required this.submitting,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = attending ? AppTheme.success : AppTheme.error;
    final dark = context.isDark;
    return GestureDetector(
      onTap: submitting ? null : () => onToggle(!attending),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: dark
                  ? Colors.black.withValues(alpha: 0.45)
                  : const Color(0xFFA9B4C0).withValues(alpha: 0.35),
              offset: const Offset(5, 5),
              blurRadius: 12,
            ),
            BoxShadow(
              color: dark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white.withValues(alpha: 0.9),
              offset: const Offset(-5, -5),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: submitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    : Icon(
                        attending
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: color,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppStrings.t('attendance_label')} — $childName, '
                    '${isToday ? 'Today' : dayLabel}',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    attending
                        ? AppStrings.t('attending')
                        : AppStrings.t('not_attending'),
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: attending,
              activeTrackColor: AppTheme.success,
              onChanged: submitting ? null : onToggle,
            ),
          ],
        ),
      ),
    );
  }
}
