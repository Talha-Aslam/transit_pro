import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';
import 'package:go_router/go_router.dart';

import '../../app/driver_data_service.dart'
    show formatTimeOfDay, parseTimeOfDay;
import '../../app/parent_data_service.dart';
import '../../app/push_sender.dart';
import '../../app/session_service.dart';
import '../../app/weekly_times.dart';
import '../../data/user_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

const _kWeekdays = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
];

const _kWeekdayLabels = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

/// What a family records for each day, as keys of
/// `Student.requestedSchedule[day]`: when the institute starts and ends, and
/// the pickup and drop-off they would like from the van.
const _kTimes = [
  (WeeklyTimes.schoolStart, 'School starts', TimeOfDay(hour: 8, minute: 0)),
  (WeeklyTimes.schoolEnd, 'School ends', TimeOfDay(hour: 14, minute: 0)),
  (WeeklyTimes.pickup, 'Morning Pickup', TimeOfDay(hour: 7, minute: 15)),
  (WeeklyTimes.dropoff, 'Evening Dropoff', TimeOfDay(hour: 15, minute: 15)),
];

/// Lets a family record their child's Monday–Saturday timings — when the
/// institute starts and ends, and the pickup/drop-off they would like —
/// on `Student.requestedSchedule`. Shared by parents (for the selected
/// child) and students (for themselves).
///
/// Distinct from the read-only "Schedule" tab (`ParentSchedule`), which shows
/// the assigned driver's real, shared `DriverTimingSlots`: that time is the
/// same for every family on the route and isn't something a single parent
/// should be able to change for everyone else riding that bus. This screen's
/// times are a per-child preference the family keeps for their own
/// reference, saved straight onto that child's own `students/{id}` document.
class EditWeeklyScheduleScreen extends StatefulWidget {
  const EditWeeklyScheduleScreen({super.key});

  @override
  State<EditWeeklyScheduleScreen> createState() =>
      _EditWeeklyScheduleScreenState();
}

class _EditWeeklyScheduleScreenState extends State<EditWeeklyScheduleScreen> {
  /// Day → time key → time.
  final Map<String, Map<String, TimeOfDay?>> _times = {};
  String _driverId = '';

  bool _loading = true;
  bool _saving = false;
  String? _studentId;
  String _childName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // A student edits their own week; a parent, the child they have selected.
    final self = SessionService.instance.student.value;
    final child = self == null
        ? ParentDataService.instance.selectedChild
        : null;
    final id = self?.id ?? child?.id ?? '';
    if (id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    _studentId = id;
    _childName = self == null ? (child?.name ?? '') : '';

    final student = await UserRepository.instance.fetchStudent(id);
    _driverId = student?.driverId ?? '';
    final saved = student?.requestedSchedule ?? {};
    for (final day in _kWeekdays) {
      final times = saved[day];
      _times[day] = {
        for (final t in _kTimes) t.$1: parseTimeOfDay(times?[t.$1]),
      };
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickTime(String day, String key, TimeOfDay fallback) async {
    final current = _times[day]?[key] ?? fallback;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    setState(() => (_times[day] ??= {})[key] = picked);
  }

  /// Tells the driver there is something waiting for them.
  ///
  /// Best-effort: the request is already saved and shows on the driver's
  /// timetable screen either way, so a failed alert is a late answer rather
  /// than a lost one.
  Future<void> _askDriver(String studentId) async {
    try {
      final driverId = _driverId;
      if (driverId.isEmpty) return;
      final name = _childName.isNotEmpty
          ? _childName
          : SessionService.instance.student.value?.name;
      await PushSender.instance.notifyOne(
        driverId,
        UserNotification(
          id: '',
          type: NotificationType.rideRequest,
          title: 'New timings requested',
          body:
              '${name ?? 'A family'} has asked for different '
              'pickup or drop-off times. Tap to answer.',
          data: {'studentId': studentId, 'route': '/driver/timetables'},
        ),
      );
    } catch (e) {
      debugPrint('schedule request alert failed: $e');
    }
  }

  Future<void> _save() async {
    final studentId = _studentId;
    if (studentId == null) return;

    setState(() => _saving = true);
    try {
      // Every day's times as one nested map in a single Firestore update.
      final requestedSchedule = <String, Map<String, String>>{
        for (final day in _kWeekdays)
          day: {
            for (final t in _kTimes)
              if (_times[day]?[t.$1] != null)
                t.$1: formatTimeOfDay(_times[day]![t.$1]!),
          },
      };
      await UserRepository.instance.updateStudent(studentId, {
        'requestedSchedule': requestedSchedule,
        // Saved times are a request, not an arrangement: a driver running
        // four rounds cannot absorb a new 07:15 pickup because one parent
        // typed it. Re-saving reopens the question, which is right — the
        // driver agreed to the old times, not these.
        'scheduleRequestStatus': ScheduleRequestStatus.pending.name,
        'scheduleRequestNote': null,
      });
      await _askDriver(studentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sent to your driver for approval.')),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _studentId == null
                    ? Center(
                        child: Text(
                          'No student selected.',
                          style: TextStyle(color: context.textSecondary),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        children: [
                          for (var i = 0; i < _kWeekdays.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _DayCard(
                                label: _kWeekdayLabels[i],
                                times: _times[_kWeekdays[i]] ?? const {},
                                onTap: (key, fallback) =>
                                    _pickTime(_kWeekdays[i], key, fallback),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _studentId == null || _loading
          ? null
          : SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.parentPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Weekly Schedule',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
          Expanded(
            child: Text(
              _childName.isEmpty
                  ? 'Weekly Schedule'
                  : "$_childName's Weekly Schedule",
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

class _DayCard extends StatelessWidget {
  final String label;
  final Map<String, TimeOfDay?> times;
  final void Function(String key, TimeOfDay fallback) onTap;

  const _DayCard({
    required this.label,
    required this.times,
    required this.onTap,
  });

  Widget _tile((String, String, TimeOfDay) t) => Expanded(
    child: _TimeTile(
      label: t.$2,
      time: times[t.$1],
      onTap: () => onTap(t.$1, t.$3),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      enableBlur: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _tile(_kTimes[0]),
              const SizedBox(width: 10),
              _tile(_kTimes[1]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _tile(_kTimes[2]),
              const SizedBox(width: 10),
              _tile(_kTimes[3]),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
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
              time != null ? formatTimeOfDay(time!) : 'Not set',
              style: TextStyle(
                color: time != null
                    ? context.textPrimary
                    : context.textTertiary,
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
