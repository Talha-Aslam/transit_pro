import 'dart:async';

import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/driver_data_service.dart';
import '../../app/language_provider.dart';
import '../../app/notification_service.dart';
import '../../app/session_service.dart';
import '../../data/trip_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

// Bulk alert option model (top-level)
class _BulkAlertOption {
  final String id;
  final String label;
  final String icon;
  final String type;
  final Color color;
  final String titleTemplate;
  final String bodyTemplate;

  const _BulkAlertOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.type,
    required this.color,
    required this.titleTemplate,
    required this.bodyTemplate,
  });
}

final List<_BulkAlertOption> _bulkOptions = [
  _BulkAlertOption(
    id: 'emergency',
    label: 'Emergency',
    icon: '🚨',
    type: 'alert',
    color: AppTheme.error,
    titleTemplate: '{{name}} emergency',
    bodyTemplate:
        'Urgent update regarding {{name}}. Please contact the driver immediately.',
  ),
  _BulkAlertOption(
    id: 'custom',
    label: 'Custom message',
    icon: '✉️',
    type: 'info',
    color: AppTheme.driverCyan,
    titleTemplate: '{{name}} update',
    bodyTemplate: '{{message}}',
  ),
];

class DriverAttendance extends StatefulWidget {
  const DriverAttendance({super.key});

  @override
  State<DriverAttendance> createState() => _DriverAttendanceState();
}

/// `🎓` for a college or university rider, `🧒` for a school child — mirrors
/// the convention already used on the booked-students roster.
String _avatarFor(Student student) {
  final type = student.instituteType.toLowerCase();
  if (type.contains('university') || type.contains('college')) return '🎓';
  return '🧒';
}

class _DriverAttendanceState extends State<DriverAttendance> {
  final _notifSvc = NotificationService.instance;
  final _session = SessionService.instance;

  String _search = '';
  String _filter = 'all';

  /// Everything the roster is derived from, merged into one listenable —
  /// same reasoning as `driver_booked_students_screen.dart`: the roster and
  /// route-student notifiers publish by assignment rather than calling
  /// `notifyListeners`, so they have to be listened to directly.
  late final Listenable _rosterListenable;

  /// The trip **Start Route** creates. Attendance is a subcollection of a
  /// trip, so there is nothing to mark until one is in progress.
  Trip? _activeTrip;
  String? _tripSubUid;
  StreamSubscription<Trip?>? _tripSub;
  StreamSubscription<List<AttendanceRecord>>? _attendanceSub;
  Map<String, AttendanceStatus> _attendanceByStudent = const {};

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _rosterListenable = Listenable.merge([
      _session,
      _session.driver,
      _session.roster,
      _session.routeStudents,
    ]);
    _rosterListenable.addListener(_onLangChanged);
    _ensureTripSubscription();
  }

  void _onLangChanged() {
    if (!mounted) return;
    setState(() {});
    _ensureTripSubscription();
  }

  /// (Re)subscribes to the driver's active trip whenever the signed-in uid
  /// changes — including the very first time it becomes available, since the
  /// session may still be loading when `initState` runs.
  void _ensureTripSubscription() {
    final uid = _session.uid;
    if (uid == _tripSubUid) return;
    _tripSubUid = uid;
    _tripSub?.cancel();
    _tripSub = null;
    if (uid == null) {
      _onActiveTrip(null);
      return;
    }
    _tripSub =
        TripRepository.instance.watchActiveTripForDriver(uid).listen(_onActiveTrip);
  }

  void _onActiveTrip(Trip? trip) {
    _attendanceSub?.cancel();
    _attendanceSub = null;
    if (!mounted) {
      _activeTrip = trip;
      return;
    }
    setState(() {
      _activeTrip = trip;
      _attendanceByStudent = const {};
    });
    if (trip != null) {
      _attendanceSub =
          TripRepository.instance.watchAttendance(trip.id).listen((records) {
        if (!mounted) return;
        setState(() {
          _attendanceByStudent = {
            for (final r in records) r.studentId: r.status,
          };
        });
      });
    }
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _rosterListenable.removeListener(_onLangChanged);
    _tripSub?.cancel();
    _attendanceSub?.cancel();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  /// The two roster sources, merged and de-duplicated by student id — the same
  /// rule `driver_booked_students_screen.dart` uses: the direct roster (an
  /// accepted ride request) wins over an admin-assigned route student.
  List<Student> get _roster {
    final merged = <String, Student>{};
    for (final s in _session.roster.value) {
      merged[s.id] = s;
    }
    for (final s in _session.routeStudents.value) {
      merged.putIfAbsent(s.id, () => s);
    }
    final list = merged.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// A student with no attendance row yet reads as not-yet-boarded — the
  /// two-state boarded/absent toggle this screen has always shown, now backed
  /// by the real three-state `AttendanceStatus` a trip actually stores.
  bool _isBoarded(Student s) =>
      _attendanceByStudent[s.id] == AttendanceStatus.boarded;

  /// The round a student rides, for grouping — there is no free-text "stop
  /// name" on the real student record, so this groups by the driver's round
  /// instead, exactly what the booked-students roster already does.
  String _groupLabelFor(Student s) {
    final id = s.scheduleId;
    if (id == null || id.isEmpty) return 'Unassigned round';
    final round = _session.driver.value?.scheduleById(id);
    return (round == null || round.label.isEmpty) ? 'Unassigned round' : round.label;
  }

  Future<void> _toggleStatus(Student student) async {
    final trip = _activeTrip;
    if (trip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start your route to record attendance.'),
        ),
      );
      return;
    }
    final next =
        _isBoarded(student) ? AttendanceStatus.absent : AttendanceStatus.boarded;
    // Optimistic: the live `watchAttendance` stream confirms within a frame or
    // two, and a tap should not visibly wait on a round trip first.
    setState(() {
      _attendanceByStudent = {..._attendanceByStudent, student.id: next};
    });
    try {
      await TripRepository.instance.markAttendance(
        tripId: trip.id,
        studentId: student.id,
        status: next,
        markedBy: _session.uid ?? '',
      );
    } catch (e) {
      debugPrint('markAttendance failed: $e');
    }
  }

  Future<void> _showBulkAlertOptions() async {
    final presentStudents = _roster.where(_isBoarded).toList();
    if (presentStudents.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No present students to alert.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.8,
          builder: (context, sc) {
            return Container(
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Choose alert to send',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._bulkOptions.map(
                    (opt) => ListTile(
                      leading: Text(
                        opt.icon,
                        style: const TextStyle(fontSize: 20),
                      ),
                      title: Text(
                        opt.label,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        opt.id == 'custom'
                            ? 'Send a custom message to parents'
                            : 'Send an emergency alert to parents',
                        style: TextStyle(color: context.textSecondary),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        if (opt.id == 'custom') {
                          final msg = await _askCustomMessage();
                          if (msg == null || msg.trim().isEmpty) return;
                          await _sendAlertsToPresentOf(opt, customMessage: msg);
                        } else {
                          await _sendAlertsToPresentOf(opt);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _askCustomMessage() async {
    String? result;
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: const Text('Custom message'),
        content: TextField(
          controller: ctrl,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Type the message to send',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              result = ctrl.text.trim();
              Navigator.pop(dCtx);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _sendAlertsToPresentOf(
    _BulkAlertOption opt, {
    String? customMessage,
  }) async {
    final presentStudents = _roster.where(_isBoarded).toList();
    if (presentStudents.isEmpty) return;

    for (final student in presentStudents) {
      final title = opt.titleTemplate
          .replaceAll('{{name}}', student.name)
          .replaceAll('{{message}}', customMessage ?? '');
      final body = opt.bodyTemplate
          .replaceAll('{{name}}', student.name)
          .replaceAll('{{message}}', customMessage ?? '');
      await _notifSvc.show(
        title: '${opt.icon} $title',
        body: body,
        type: opt.type,
        icon: opt.icon,
        color: opt.color,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${opt.label}" alerts sent for ${presentStudents.length} students.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Computed once per build rather than re-derived (and re-filtered) on
    // every access — the roster merge and the boarded/absent counts used to
    // be separate getters called several times each, redoing the same work on
    // every keystroke in the search box.
    final roster = _roster;
    final query = _search.trim().toLowerCase();

    var boardedCount = 0;
    for (final s in roster) {
      if (_isBoarded(s)) boardedCount++;
    }
    final absentCount = roster.length - boardedCount;

    final filtered = roster.where((s) {
      final matchSearch = query.isEmpty ||
          s.name.toLowerCase().contains(query) ||
          s.grade.toLowerCase().contains(query) ||
          s.school.toLowerCase().contains(query);
      final boarded = _isBoarded(s);
      final matchFilter = switch (_filter) {
        'boarded' => boarded,
        'absent' => !boarded,
        _ => true,
      };
      return matchSearch && matchFilter;
    }).toList();

    // Grouped by round in a single pass, rather than re-filtering the full
    // list once per group as the old per-stop rendering did.
    final grouped = <String, List<Student>>{};
    for (final s in filtered) {
      grouped.putIfAbsent(_groupLabelFor(s), () => []).add(s);
    }

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
                  AppTheme.driverCyan.withValues(alpha: 0.2),
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
                      AppStrings.t('student_attendance'),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    ValueListenableBuilder<DriverInfo>(
                      valueListenable: DriverDataService.instance.driverInfo,
                      builder: (_, info, _) {
                        final assignment = [info.busNumber, info.route]
                            .where((s) => s.isNotEmpty)
                            .join(' · ');
                        return Text(
                          assignment.isEmpty
                              ? 'No vehicle assigned yet'
                              : assignment,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Summary row ───────────────────────────────────────────
                Row(
                  children: [
                    _SummaryCard(
                      icon: '✅',
                      label: AppStrings.t('boarded'),
                      value: boardedCount,
                      color: AppTheme.success,
                    ),
                    const SizedBox(width: 10),
                    const SizedBox(width: 10),
                    _SummaryCard(
                      icon: '❌',
                      label: AppStrings.t('absent'),
                      value: absentCount,
                      color: AppTheme.error,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Progress bar ──────────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppStrings.t('boarding_progress'),
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '$boardedCount/${roster.length} ${AppStrings.t('students').toLowerCase()}',
                            style: const TextStyle(
                              color: AppTheme.driverAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: roster.isEmpty
                              ? 0
                              : boardedCount / roster.length,
                          backgroundColor: context.cardBgElevated,
                          valueColor: const AlwaysStoppedAnimation(
                            AppTheme.success,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (_activeTrip == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppTheme.warning,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No route in progress. Start your route to '
                              'record and save attendance.',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _showBulkAlertOptions,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.success.withValues(alpha: 0.2),
                            AppTheme.driverCyan.withValues(alpha: 0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppTheme.success.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: AppTheme.success,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Send alerts to present students',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Notify all boarded students and their parents',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: context.textTertiary,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Search ────────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.inputBorder),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 14, right: 10),
                        child: Image.asset(
                          'assets/images/utilities/search.png',
                          width: 18,
                          height: 18,
                          cacheWidth: 36,
                          cacheHeight: 36,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: AppStrings.t('search_student'),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintStyle: TextStyle(color: context.textHint),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Filter tabs ───────────────────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterBtn('all', 'All (${roster.length})'),
                      _filterBtn('boarded', '✅ $boardedCount'),
                      _filterBtn('absent', '❌ $absentCount'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Student list grouped by round ──────────────────────────
                if (roster.isEmpty && _session.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.driverCyan,
                      ),
                    ),
                  )
                else if (filtered.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Text('🔍', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text(
                            'No students found',
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...grouped.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text(
                                '🚌 ${entry.key}',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: context.cardBgElevated,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...entry.value.map(
                          (student) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _StudentCard(
                              student: student,
                              boarded: _isBoarded(student),
                              onToggle: () => _toggleStatus(student),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBtn(String key, String label) {
    final active = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.driverCyan.withValues(alpha: 0.15)
                : context.cardBgElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? AppTheme.driverCyan.withValues(alpha: 0.5)
                  : context.surfaceBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppTheme.driverAccent : context.textSecondary,
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String icon, label;
  final int value;
  final Color color;
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Student student;
  final bool boarded;
  final VoidCallback onToggle;
  const _StudentCard({
    required this.student,
    required this.boarded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = boarded
        ? const _StatusConfig(color: AppTheme.success, icon: '✅', label: 'Boarded')
        : const _StatusConfig(color: AppTheme.error, icon: '❌', label: 'Absent');
    return GlassCard(
      enableBlur: false,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.cardBgElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(_avatarFor(student), style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name.isEmpty ? 'Unnamed student' : student.name,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (student.grade.isNotEmpty) student.grade,
                    if (student.school.isNotEmpty) student.school,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cfg.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cfg.color.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${cfg.icon} ${cfg.label}',
                style: TextStyle(
                  color: cfg.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusConfig {
  final Color color;
  final String icon, label;
  const _StatusConfig({
    required this.color,
    required this.icon,
    required this.label,
  });
}
