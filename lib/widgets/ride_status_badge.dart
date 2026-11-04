import 'package:flutter/material.dart';

import '../app/child_status_service.dart';
import '../app/language_provider.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

/// The one badge that says where a child is.
///
/// Every screen that shows a child used to decide this for itself, and the
/// parent dashboard decided it from whether the child had a driver at
/// all — so the badge read "On the Bus" at nine at night, on a Sunday, and
/// for a child whose driver had ended the route an hour earlier. The colour
/// and the wording both come from [ChildStatusService] now, so two screens
/// cannot disagree about the same child.
class RideStatusBadge extends StatelessWidget {
  final String studentId;

  const RideStatusBadge({super.key, required this.studentId});

  static Color colorFor(BuildContext context, RideStage stage) =>
      switch (stage) {
        RideStage.unassigned => context.textTertiary,
        RideStage.absent => context.textTertiary,
        RideStage.scheduled => AppTheme.info,
        RideStage.onTheBus => AppTheme.success,
        RideStage.reached => AppTheme.purple,
      };

  /// The badge text for [status], with the institute's name substituted in.
  static String labelFor(ChildRideStatus status) {
    final text = AppStrings.t(status.labelKey);
    final place = status.place;
    return place == null ? text : text.replaceAll('{place}', place);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, ChildRideStatus>>(
      valueListenable: ChildStatusService.instance.statuses,
      builder: (context, map, _) {
        final status = map[studentId] ?? ChildRideStatus.unknown;
        return StatusBadge(
          label: labelFor(status),
          color: colorFor(context, status.stage),
        );
      },
    );
  }
}
