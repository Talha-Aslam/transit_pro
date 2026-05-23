import 'package:flutter/material.dart';
import '../../app/notification_service.dart';
import '../../app/language_provider.dart';
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
  final VoidCallback onBack;
  const DriverAttendance({super.key, required this.onBack});

  @override
  State<DriverAttendance> createState() => _DriverAttendanceState();
}

class _DriverAttendanceState extends State<DriverAttendance> {
  final _notifSvc = NotificationService.instance;
  late List<_Student> _students;
  String _search = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _students = List.from(_initialStudents);
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  void _toggleStatus(int id) {
    setState(() {
      final i = _students.indexWhere((s) => s.id == id);
      final next = _students[i].status == 'boarded' ? 'absent' : 'boarded';
      _students[i] = _students[i].copyWith(status: next);
    });
  }

  Future<void> _showBulkAlertOptions() async {
    final presentStudents = _students
        .where((s) => s.status == 'boarded')
        .toList();
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
    final presentStudents = _students
        .where((s) => s.status == 'boarded')
        .toList();
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

  int get _boarded => _students.where((s) => s.status == 'boarded').length;
  int get _absent => _students.where((s) => s.status == 'absent').length;

  List<_Student> get _filtered => _students.where((s) {
    final matchSearch =
        s.name.toLowerCase().contains(_search.toLowerCase()) ||
        s.stop.toLowerCase().contains(_search.toLowerCase());
    final matchFilter = _filter == 'all' || s.status == _filter;
    return matchSearch && matchFilter;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final stops = _filtered.map((s) => s.stop).toSet().toList();

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
                GestureDetector(onTap: widget.onBack, child: _backBtn(context)),
                const SizedBox(width: 12),
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
                    Text(
                      'Morning Run · Bus #42',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Summary row ───────────────────────────────────────────
                Row(
                  children: [
                    _SummaryCard(
                      icon: '✅',
                      label: AppStrings.t('boarded'),
                      value: _boarded,
                      color: AppTheme.success,
                    ),
                    const SizedBox(width: 10),
                    const SizedBox(width: 10),
                    _SummaryCard(
                      icon: '\u274c',
                      label: AppStrings.t('absent'),
                      value: _absent,
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
                            '$_boarded/${_students.length} ${AppStrings.t('students').toLowerCase()}',
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
                          value: _boarded / _students.length,
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
                      _filterBtn('all', 'All (${_students.length})'),
                      _filterBtn('boarded', '✅ $_boarded'),
                      _filterBtn('absent', '❌ $_absent'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Student list grouped by stop ──────────────────────────
                if (_filtered.isEmpty)
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
                  ...stops.map((stop) {
                    final stopStudents = _filtered
                        .where((s) => s.stop == stop)
                        .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text(
                                '📍 $stop',
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
                        ...stopStudents.map(
                          (student) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _StudentCard(
                              student: student,
                              onToggle: () => _toggleStatus(student.id),
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
  final _Student student;
  final VoidCallback onToggle;
  const _StudentCard({required this.student, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig[student.status]!;
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
              child: Text(student.avatar, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${student.grade} · ${student.parentPhone}',
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

Widget _backBtn(BuildContext context) => Container(
  width: 38,
  height: 38,
  decoration: BoxDecoration(
    color: context.cardBgElevated,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: context.inputBorder),
  ),
  child: Center(
    child: Text(
      '←',
      style: TextStyle(color: context.textPrimary, fontSize: 16),
    ),
  ),
);

class _StatusConfig {
  final Color color;
  final String icon, label;
  const _StatusConfig({
    required this.color,
    required this.icon,
    required this.label,
  });
}

const _statusConfig = {
  'boarded': _StatusConfig(
    color: AppTheme.success,
    icon: '✅',
    label: 'Boarded',
  ),
  'absent': _StatusConfig(color: AppTheme.error, icon: '❌', label: 'Absent'),
};

class _Student {
  final int id;
  final String name, grade, stop, status, avatar, parentPhone;
  const _Student({
    required this.id,
    required this.name,
    required this.grade,
    required this.stop,
    required this.status,
    required this.avatar,
    required this.parentPhone,
  });
  _Student copyWith({String? status}) => _Student(
    id: id,
    name: name,
    grade: grade,
    stop: stop,
    status: status ?? this.status,
    avatar: avatar,
    parentPhone: parentPhone,
  );
}

const _initialStudents = [
  _Student(
    id: 1,
    name: 'Emma Johnson',
    grade: 'Grade 5',
    stop: 'Oak Street',
    status: 'boarded',
    avatar: '👧',
    parentPhone: '+1 555-0101',
  ),
  _Student(
    id: 2,
    name: 'Liam Williams',
    grade: 'Grade 3',
    stop: 'Oak Street',
    status: 'boarded',
    avatar: '👦',
    parentPhone: '+1 555-0102',
  ),
  _Student(
    id: 3,
    name: 'Olivia Davis',
    grade: 'Grade 4',
    stop: 'Maple Avenue',
    status: 'boarded',
    avatar: '👧',
    parentPhone: '+1 555-0103',
  ),
  _Student(
    id: 4,
    name: 'Noah Brown',
    grade: 'Grade 6',
    stop: 'Maple Avenue',
    status: 'boarded',
    avatar: '👦',
    parentPhone: '+1 555-0104',
  ),
  _Student(
    id: 5,
    name: 'Ava Martinez',
    grade: 'Grade 2',
    stop: 'Pine Road',
    status: 'boarded',
    avatar: '👧',
    parentPhone: '+1 555-0105',
  ),
  _Student(
    id: 6,
    name: 'William Wilson',
    grade: 'Grade 5',
    stop: 'Pine Road',
    status: 'boarded',
    avatar: '👦',
    parentPhone: '+1 555-0106',
  ),
  _Student(
    id: 7,
    name: 'Sophia Anderson',
    grade: 'Grade 3',
    stop: 'Cedar Blvd',
    status: 'absent',
    avatar: '👧',
    parentPhone: '+1 555-0107',
  ),
  _Student(
    id: 8,
    name: 'James Taylor',
    grade: 'Grade 4',
    stop: 'Cedar Blvd',
    status: 'absent',
    avatar: '👦',
    parentPhone: '+1 555-0108',
  ),
  _Student(
    id: 9,
    name: 'Isabella Thomas',
    grade: 'Grade 6',
    stop: 'Cedar Blvd',
    status: 'absent',
    avatar: '👧',
    parentPhone: '+1 555-0109',
  ),
  _Student(
    id: 10,
    name: 'Benjamin Jackson',
    grade: 'Grade 2',
    stop: 'Cedar Blvd',
    status: 'absent',
    avatar: '👦',
    parentPhone: '+1 555-0110',
  ),
  _Student(
    id: 11,
    name: 'Mia White',
    grade: 'Grade 5',
    stop: 'Oak Street',
    status: 'boarded',
    avatar: '👧',
    parentPhone: '+1 555-0111',
  ),
  _Student(
    id: 12,
    name: 'Lucas Harris',
    grade: 'Grade 3',
    stop: 'Maple Avenue',
    status: 'boarded',
    avatar: '👦',
    parentPhone: '+1 555-0112',
  ),
  _Student(
    id: 13,
    name: 'Ali Khan',
    grade: 'Undergraduate',
    stop: 'University of Lahore',
    status: 'boarded',
    avatar: '🎓',
    parentPhone: '+92 300 7001001',
  ),
  _Student(
    id: 14,
    name: 'Zara Ahmed',
    grade: 'Undergraduate',
    stop: 'LUMS',
    status: 'absent',
    avatar: '🎓',
    parentPhone: '+92 300 7001002',
  ),
];
