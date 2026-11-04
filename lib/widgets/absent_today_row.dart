import 'package:flutter/material.dart';

import '../app/child_status_service.dart';
import '../app/language_provider.dart';
import '../app/parent_data_service.dart';
import '../theme/app_theme.dart';

/// "Not riding today?" — one tap, no approval step.
///
/// A family whose child is home with a fever has no way to say so today, so
/// the driver sets out expecting them, waits at the gate, and the family's
/// own dashboard still says the ride is on. The driver is told immediately
/// and their roster drops the child for the day; nobody has to approve it,
/// because nobody is better placed than the family to know.
class AbsentTodayRow extends StatefulWidget {
  final String studentId;
  final String childName;

  const AbsentTodayRow({
    super.key,
    required this.studentId,
    required this.childName,
  });

  @override
  State<AbsentTodayRow> createState() => _AbsentTodayRowState();
}

class _AbsentTodayRowState extends State<AbsentTodayRow> {
  bool _busy = false;

  Future<void> _set(bool absent) async {
    setState(() => _busy = true);
    try {
      await ParentDataService.instance.setAbsent(
        studentId: widget.studentId,
        dateKey: ChildStatusService.todayKey(),
        absent: absent,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.t(absent ? 'mark_absent_done' : 'mark_absent_undone'),
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, ChildRideStatus>>(
      valueListenable: ChildStatusService.instance.statuses,
      builder: (context, map, _) {
        final stage = map[widget.studentId]?.stage;
        // Nothing to offer before a driver exists, and nothing useful to
        // offer once the child is already aboard — the driver can see them.
        if (stage == null ||
            stage == RideStage.unassigned ||
            stage == RideStage.onTheBus) {
          return const SizedBox.shrink();
        }
        final isOff = stage == RideStage.absent;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: context.cardBgElevated.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.surfaceBorder),
            ),
            child: Row(
              children: [
                Text(
                  isOff ? '🏠' : '🤒',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t('mark_absent_title'),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.t('mark_absent_body'),
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (_busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  GestureDetector(
                    onTap: () => _set(!isOff),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isOff
                            ? AppTheme.success.withValues(alpha: 0.18)
                            : AppTheme.warning.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        AppStrings.t(
                          isOff ? 'mark_absent_undo' : 'mark_absent_action',
                        ),
                        style: TextStyle(
                          color: isOff ? AppTheme.success : AppTheme.warning,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
