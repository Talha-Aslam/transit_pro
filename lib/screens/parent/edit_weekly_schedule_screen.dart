import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/driver_data_service.dart' show formatTimeOfDay;
import '../../app/parent_data_service.dart';
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

const _kDefaultMorning = TimeOfDay(hour: 7, minute: 15);
const _kDefaultEvening = TimeOfDay(hour: 15, minute: 15);

/// Lets a parent record their own requested Monday–Saturday pickup/drop-off
/// times for one child — `Student.requestedSchedule`.
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
  final Map<String, TimeOfDay?> _morning = {};
  final Map<String, TimeOfDay?> _evening = {};

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
    final child = ParentDataService.instance.selectedChild;
    if (child == null || child.id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    _studentId = child.id;
    _childName = child.name;

    final student = await UserRepository.instance.fetchStudent(child.id);
    final saved = student?.requestedSchedule ?? {};
    for (final day in _kWeekdays) {
      final times = saved[day];
      _morning[day] = _parseTimeOfDay(times?['morningPickup']);
      _evening[day] = _parseTimeOfDay(times?['eveningDropoff']);
    }
    if (mounted) setState(() => _loading = false);
  }

  static TimeOfDay? _parseTimeOfDay(String? formatted) {
    if (formatted == null || formatted.isEmpty) return null;
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
    ).firstMatch(formatted.trim());
    if (match == null) return null;
    var hour = int.parse(match.group(1)!) % 12;
    if (match.group(3) == 'PM') hour += 12;
    return TimeOfDay(hour: hour, minute: int.parse(match.group(2)!));
  }

  Future<void> _pickTime(String day, {required bool morning}) async {
    final current =
        (morning ? _morning[day] : _evening[day]) ??
        (morning ? _kDefaultMorning : _kDefaultEvening);
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    setState(() {
      if (morning) {
        _morning[day] = picked;
      } else {
        _evening[day] = picked;
      }
    });
  }

  Future<void> _save() async {
    final studentId = _studentId;
    if (studentId == null) return;

    setState(() => _saving = true);
    try {
      // Batch-writes all 6 days x 2 times as one nested map in a single
      // Firestore update, rather than 12 separate field writes.
      final requestedSchedule = <String, Map<String, String>>{
        for (final day in _kWeekdays)
          day: {
            if (_morning[day] != null)
              'morningPickup': formatTimeOfDay(_morning[day]!),
            if (_evening[day] != null)
              'eveningDropoff': formatTimeOfDay(_evening[day]!),
          },
      };
      await UserRepository.instance.updateStudent(studentId, {
        'requestedSchedule': requestedSchedule,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Weekly schedule saved.')));
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
                          'No child selected.',
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
                                morning: _morning[_kWeekdays[i]],
                                evening: _evening[_kWeekdays[i]],
                                onTapMorning: () =>
                                    _pickTime(_kWeekdays[i], morning: true),
                                onTapEvening: () =>
                                    _pickTime(_kWeekdays[i], morning: false),
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
  final TimeOfDay? morning;
  final TimeOfDay? evening;
  final VoidCallback onTapMorning;
  final VoidCallback onTapEvening;

  const _DayCard({
    required this.label,
    required this.morning,
    required this.evening,
    required this.onTapMorning,
    required this.onTapEvening,
  });

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
              Expanded(
                child: _TimeTile(
                  label: 'Morning Pickup',
                  time: morning,
                  onTap: onTapMorning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeTile(
                  label: 'Evening Dropoff',
                  time: evening,
                  onTap: onTapEvening,
                ),
              ),
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
