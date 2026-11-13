import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/child_status_service.dart';
import '../../app/language_provider.dart';
import '../../app/round_display.dart';
import '../../app/session_service.dart';
import '../../app/weekly_times.dart';
import '../../data/trip_repository.dart';
import '../../data/user_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

/// A student's week, built the way the parent's Schedule tab is: their own
/// timings (when the institute starts and ends, and the pickup/drop-off they
/// asked the driver for), the round they are booked on, what actually
/// happened on each day so far, and a way to say "not riding" for a day.
///
/// Everything here is live off the student's own record and their
/// attendance. The old screen kept its own timetable in memory and offered a
/// QR check-out nothing ever read.
class StudentSchedule extends StatefulWidget {
  const StudentSchedule({super.key});
  @override
  State<StudentSchedule> createState() => _StudentScheduleState();
}

class _StudentScheduleState extends State<StudentSchedule> {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  int _selectedDay = (DateTime.now().weekday - 1).clamp(0, 5);
  StreamSubscription<List<AttendanceRecord>>? _historySub;
  Map<String, AttendanceStatus> _history = const {};
  bool _savingAbsence = false;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onChanged);
    SessionService.instance.addListener(_onChanged);
    final id = SessionService.instance.uid;
    if (id != null) {
      _historySub = TripRepository.instance.watchAttendanceHistory(id).listen((
        records,
      ) {
        if (!mounted) return;
        setState(() {
          _history = {
            for (final r in records)
              if (r.dateKey.isNotEmpty)
                // A day with a ride counts as ridden whichever leg is newer.
                r.dateKey: _history[r.dateKey] == AttendanceStatus.droppedOff
                    ? AttendanceStatus.droppedOff
                    : r.status,
          };
        });
      }, onError: (Object e) => debugPrint('schedule history: $e'));
    }
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onChanged);
    SessionService.instance.removeListener(_onChanged);
    _historySub?.cancel();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Monday of the week on screen; on a Sunday, the week about to start.
  DateTime get _monday {
    final today = DateUtils.dateOnly(DateTime.now());
    return today.weekday == DateTime.sunday
        ? today.add(const Duration(days: 1))
        : today.subtract(Duration(days: today.weekday - 1));
  }

  DateTime _dateOf(int index) => _monday.add(Duration(days: index));

  Future<void> _setRiding(Student me, DateTime date, bool riding) async {
    setState(() => _savingAbsence = true);
    final key = Trip.dateKeyFor(date);
    final today = ChildStatusService.todayKey();
    // Days already gone are dropped: nothing reads an old absence.
    final kept = <String>{
      for (final d in me.absentDates)
        if (d.compareTo(today) >= 0) d,
    };
    riding ? kept.remove(key) : kept.add(key);
    try {
      await UserRepository.instance.updateStudent(me.id, {
        'absentDates': kept.toList()..sort(),
      });
    } catch (e) {
      debugPrint('marking absence failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save. Check your connection.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingAbsence = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = SessionService.instance.student.value;
    final driver = SessionService.instance.driverFor(me?.driverId);
    final round = driver?.scheduleById(me?.scheduleId);
    final date = _dateOf(_selectedDay);
    final times = me == null ? const WeeklyTimes() : WeeklyTimes.on(me, date);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.t('my_schedule'),
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.t('pickup_dropoff_timings'),
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          if (me != null &&
              me.scheduleRequestStatus != ScheduleRequestStatus.none) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _RequestStatus(student: me),
            ),
          ],
          const SizedBox(height: 16),

          // ── Day selector ────────────────────────────────────────────
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _days.length,
              itemBuilder: (_, i) {
                final selected = i == _selectedDay;
                final d = _dateOf(i);
                final mark = _history[Trip.dateKeyFor(d)];
                final dot = switch (mark) {
                  AttendanceStatus.boarded ||
                  AttendanceStatus.droppedOff => AppTheme.success,
                  AttendanceStatus.absent => AppTheme.error,
                  _ => null,
                };
                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = i),
                  child: Container(
                    width: 54,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.studentAmber
                          : context.cardBgElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? AppTheme.studentAmber
                            : context.inputBorder,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _days[i],
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : context.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : context.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (dot != null)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: selected ? Colors.white : dot,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── The day ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              enableBlur: false,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My timings',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Time(label: 'School starts', hhmm: times.schoolStartAt),
                      const SizedBox(width: 10),
                      _Time(label: 'School ends', hhmm: times.schoolEndAt),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Time(label: 'Pickup asked', hhmm: times.pickupAt),
                      const SizedBox(width: 10),
                      _Time(label: 'Drop-off asked', hhmm: times.dropoffAt),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/student/weekly-schedule'),
                      icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                      label: const Text('Edit weekly timings'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.studentAmber,
                        side: const BorderSide(color: AppTheme.studentAmber),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── The round ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              enableBlur: false,
              padding: const EdgeInsets.all(16),
              child: round == null
                  ? Text(
                      driver == null
                          ? 'No driver yet. Find one from the Home screen.'
                          : 'Your driver has not put you on a round yet.',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          round.label.isEmpty ? 'Your round' : round.label,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${driver!.name} · ${roundSummary(round)}',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        // This student's own times on the round, from where
                        // they fall in its order of stops.
                        if (driver.expectedTimes[me?.id ?? '']
                            case final t?) ...[
                          const SizedBox(height: 8),
                          Text(
                            [
                              if (clock12(t.pickup).isNotEmpty)
                                'Expected pickup ${clock12(t.pickup)}',
                              if (clock12(t.dropoff).isNotEmpty)
                                'drop-off ${clock12(t.dropoff)}',
                            ].join(' · '),
                            style: const TextStyle(
                              color: AppTheme.studentAmber,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (!round.runsOn(date.weekday)) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'No pickup this day',
                            style: TextStyle(
                              color: AppTheme.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Riding that day? ────────────────────────────────────────
          if (me != null && !date.isBefore(DateUtils.dateOnly(DateTime.now())))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassCard(
                enableBlur: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.studentAmber,
                  title: Text(
                    'Riding on ${_days[_selectedDay]} ${date.day}',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Turn off and your driver skips your stop that day.',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: !me.isAbsentOn(Trip.dateKeyFor(date)),
                  onChanged: _savingAbsence
                      ? null
                      : (riding) => _setRiding(me, date, riding),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Time extends StatelessWidget {
  final String label;
  final String hhmm;
  const _Time({required this.label, required this.hhmm});

  @override
  Widget build(BuildContext context) {
    final shown = clock12(hhmm);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.cardBgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.inputBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: context.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              shown.isEmpty ? 'Not set' : shown,
              style: TextStyle(
                color: shown.isEmpty
                    ? context.textTertiary
                    : context.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the timings this student asked for stand with their driver.
class _RequestStatus extends StatelessWidget {
  final Student student;
  const _RequestStatus({required this.student});

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (student.scheduleRequestStatus) {
      ScheduleRequestStatus.accepted => (
        AppStrings.t('schedule_accepted'),
        AppTheme.success,
      ),
      ScheduleRequestStatus.rejected => (
        AppStrings.t('schedule_rejected'),
        AppTheme.error,
      ),
      _ => (AppStrings.t('schedule_pending'), AppTheme.warning),
    };
    final note = student.scheduleRequestNote?.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        note.isEmpty ? text : '$text — $note',
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
