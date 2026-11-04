import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/driver_data_service.dart' show kWeekdayKeys;
import '../../app/push_sender.dart';
import '../../app/session_service.dart';
import '../../data/user_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/glass_card.dart';

/// Every child's requested weekly timings, in one place, with an answer.
///
/// Families could already save the times they wanted, and nothing ever
/// carried them to the driver: the times sat on the child's record, the
/// family read their own wish back as though it were an arrangement, and
/// the driver — the one person who has to make it work across four rounds —
/// never knew to look. This is the other half.
class DriverTimetablesScreen extends StatefulWidget {
  const DriverTimetablesScreen({super.key});

  @override
  State<DriverTimetablesScreen> createState() => _DriverTimetablesScreenState();
}

class _DriverTimetablesScreenState extends State<DriverTimetablesScreen> {
  final _session = SessionService.instance;

  /// The child currently being written, so one card spins rather than the
  /// whole list freezing.
  String? _busyId;

  /// Waiting on an answer first, then everybody else — the point of the
  /// screen is the ones that need the driver.
  List<Student> get _roster {
    final merged = <String, Student>{
      for (final s in _session.roster.value) s.id: s,
      for (final s in _session.routeStudents.value) s.id: s,
    };
    final list = merged.values.toList();
    list.sort((a, b) {
      final ap = a.scheduleRequestStatus == ScheduleRequestStatus.pending;
      final bp = b.scheduleRequestStatus == ScheduleRequestStatus.pending;
      if (ap != bp) return ap ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  @override
  void initState() {
    super.initState();
    _session.roster.addListener(_rebuild);
    _session.routeStudents.addListener(_rebuild);
  }

  @override
  void dispose() {
    _session.roster.removeListener(_rebuild);
    _session.routeStudents.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _answer(
    Student student, {
    required bool accept,
    String? note,
  }) async {
    setState(() => _busyId = student.id);
    try {
      await UserRepository.instance.updateStudent(student.id, {
        'scheduleRequestStatus': accept
            ? ScheduleRequestStatus.accepted.name
            : ScheduleRequestStatus.rejected.name,
        'scheduleRequestNote': note,
      });

      final recipient = student.parentId.trim().isEmpty
          ? student.id
          : student.parentId.trim();
      final driverName = _session.driver.value?.name.trim() ?? '';
      await PushSender.instance.notifyOne(
        recipient,
        UserNotification(
          id: '',
          type: NotificationType.rideRequestAnswered,
          title: accept ? 'Timings agreed' : 'Timings not possible',
          body: accept
              ? '${driverName.isEmpty ? 'Your driver' : driverName} has '
                    'agreed to the times you asked for ${student.name}.'
              : (note == null || note.trim().isEmpty
                    ? '${driverName.isEmpty ? 'Your driver' : driverName} '
                          'cannot manage those times. Open the schedule to '
                          'try others.'
                    : '${driverName.isEmpty ? 'Your driver' : driverName}: '
                          '${note.trim()}'),
          data: {'studentId': student.id, 'route': '/parent/schedule'},
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? '${student.name}’s timings are agreed.'
                : '${student.name}’s family has been told.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save that. Check your connection.'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _decline(Student student) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: dCtx.cardBg,
        title: Text(
          'Cannot manage these times?',
          style: TextStyle(color: dCtx.textPrimary, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tell them what you can do instead — a decline with no reason '
              'leaves the family with nothing to change.',
              style: TextStyle(color: dCtx.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 2,
              style: TextStyle(color: dCtx.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'e.g. I am at your gate at 06:50',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, controller.text.trim()),
            child: const Text('Send', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    // The controller outlives the dialog's exit animation this way, which a
    // dispose immediately after the await does not.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (note == null) return;
    await _answer(student, accept: false, note: note);
  }

  @override
  Widget build(BuildContext context) {
    final roster = _roster;
    final waiting = roster
        .where((s) => s.scheduleRequestStatus == ScheduleRequestStatus.pending)
        .length;

    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              _Header(waiting: waiting, onBack: () => context.pop()),
              Expanded(
                child: roster.isEmpty
                    ? _Empty()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        itemCount: roster.length,
                        itemBuilder: (_, i) {
                          final student = roster[i];
                          return _TimetableCard(
                            student: student,
                            busy: _busyId == student.id,
                            onAccept: () =>
                                _answer(student, accept: true),
                            onDecline: () => _decline(student),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int waiting;
  final VoidCallback onBack;

  const _Header({required this.waiting, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.driverCyan.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Icon(Icons.arrow_back, color: context.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Family timings',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  waiting == 0
                      ? 'Nothing waiting on you'
                      : '$waiting waiting on your answer',
                  style: TextStyle(
                    color: waiting == 0
                        ? context.textSecondary
                        : AppTheme.warningLight,
                    fontSize: 12,
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

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗓️', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 14),
            Text(
              'Nobody on your roster yet',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Once you accept a seat request, that family’s weekly '
              'timings appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimetableCard extends StatelessWidget {
  final Student student;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _TimetableCard({
    required this.student,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  (Color, String) get _statusChip => switch (student.scheduleRequestStatus) {
    ScheduleRequestStatus.pending => (AppTheme.warning, 'Waiting on you'),
    ScheduleRequestStatus.accepted => (AppTheme.success, 'Agreed'),
    ScheduleRequestStatus.rejected => (AppTheme.error, 'You declined'),
    ScheduleRequestStatus.none => (AppTheme.info, 'Your usual times'),
  };

  @override
  Widget build(BuildContext context) {
    final (chipColor, chipText) = _statusChip;
    final schedule = student.requestedSchedule;
    final pending =
        student.scheduleRequestStatus == ScheduleRequestStatus.pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        enableBlur: false,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarImage(
                  localFile: null,
                  photoUrl: student.photoUrl,
                  size: 40,
                  borderRadius: BorderRadius.circular(20),
                  fallback: riderGlyph(student.instituteType, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name.isEmpty ? 'Unnamed' : student.name,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        [
                          if (student.grade.isNotEmpty) student.grade,
                          if (student.school.isNotEmpty) student.school,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(label: chipText, color: chipColor),
              ],
            ),
            const SizedBox(height: 14),
            if (schedule.isEmpty)
              Text(
                'This family has not asked for particular times — your '
                'round’s own timings apply.',
                style: TextStyle(color: context.textTertiary, fontSize: 12),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < kWeekdayKeys.length; i++)
                    _DayRow(
                      label: _dayLabels[i],
                      times: schedule[kWeekdayKeys[i]],
                    ),
                ],
              ),
            if (student.scheduleRequestStatus ==
                    ScheduleRequestStatus.rejected &&
                (student.scheduleRequestNote ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'You said: ${student.scheduleRequestNote}',
                style: TextStyle(color: context.textTertiary, fontSize: 12),
              ),
            ],
            if (pending) ...[
              const SizedBox(height: 14),
              if (busy)
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _Btn(
                        label: 'Cannot do these',
                        color: AppTheme.error,
                        filled: false,
                        onTap: onDecline,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Btn(
                        label: 'I can do these',
                        color: AppTheme.success,
                        filled: true,
                        onTap: onAccept,
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final String label;
  final Map<String, String>? times;

  const _DayRow({required this.label, required this.times});

  @override
  Widget build(BuildContext context) {
    final morning = times?['morningPickup'] ?? '';
    final evening = times?['eveningDropoff'] ?? '';
    final nothing = morning.isEmpty && evening.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              label,
              style: TextStyle(
                color: context.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              nothing
                  ? 'No preference'
                  : [
                      if (morning.isNotEmpty) 'Pick up $morning',
                      if (evening.isNotEmpty) 'Home by $evening',
                    ].join('  ·  '),
              style: TextStyle(
                color: nothing ? context.textTertiary : context.textPrimary,
                fontSize: 12,
                fontWeight: nothing ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _Btn({
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: filled
              ? null
              : Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: filled ? Colors.white : color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
