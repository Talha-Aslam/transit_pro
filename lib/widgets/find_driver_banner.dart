import 'package:flutter/material.dart';
import '../app/language_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../app/session_service.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';
import 'app_glyph.dart';

/// Dashboard card that reports where the family stands on transport, and leads to
/// driver search.
///
/// Shared by the parent and student dashboards — the two roles do the identical
/// thing here (book a seat for a student), so a per-role copy would be two places
/// to fix the same wording.
///
/// The card is stateful in content rather than being a plain button because
/// "find a driver" is only the right label some of the time. A family waiting on
/// a reply needs to see that they are waiting; a family already booked needs the
/// driver's name, not an invitation to start over. Rendering one fixed label is
/// how a parent ends up sending a second request to a driver who has not answered
/// the first.
class FindDriverBanner extends StatelessWidget {
  /// Role accent — parents reach this purple, students amber.
  final Color accent;

  /// Where "find a driver" leads. Differs per role only in the URL.
  final String searchRoute;

  const FindDriverBanner({
    super.key,
    required this.accent,
    required this.searchRoute,
  });

  @override
  Widget build(BuildContext context) {
    final session = SessionService.instance;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        // A parent looks at the child they have selected; a student is their own
        // subject.
        final subject = session.student.value ?? session.selectedChild;
        if (subject == null) return const SizedBox.shrink();

        final request = _requestFor(session, subject);
        final driver = session.driverFor(subject.driverId);

        final String emoji;
        final String title;
        final String subtitle;
        final Color tint;

        if (subject.hasDriver) {
          tint = AppTheme.success;
          emoji = '🧑‍✈️';
          title = driver == null
              ? AppStrings.t('driver_assigned')
              : '${AppStrings.t('riding_with')} ${driver.name}';
          final round = driver?.scheduleById(subject.scheduleId);
          subtitle = round == null
              ? '${AppStrings.t('tap_other_drivers')} ${subject.school}.'
              : '${round.timeRange} · '
                    '${AppStrings.t('tap_change_driver')}';
        } else if (request != null && request.isPending) {
          tint = AppTheme.warning;
          emoji = '⏳';
          title = '${AppStrings.t('waiting_on')} ${request.driverName}';
          subtitle =
              '${request.scheduleLabel} — '
              '${AppStrings.t('tap_check_withdraw')}.';
        } else if (subject.school.trim().isEmpty) {
          tint = AppTheme.info;
          emoji = '🏫';
          title = '${AppStrings.t('add_school_for')} ${subject.name}';
          subtitle = AppStrings.t('driver_search_matches');
        } else {
          tint = accent;
          emoji = '🔍';
          title = '${AppStrings.t('find_driver_for')} ${subject.name}';
          subtitle =
              '${AppStrings.t('see_drivers_running_to')} '
              '${subject.school}.';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => context.push(searchRoute),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              accent: tint,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: AppGlyph(emoji, size: 21, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The newest request for this student, whichever driver it is with.
  ///
  /// Unlike [SessionService.requestFor] this does not need a driver id — the
  /// banner's question is "is this child waiting on anyone?", not "are they
  /// waiting on a specific person".
  static RideRequest? _requestFor(SessionService session, Student subject) {
    for (final r in session.rideRequests.value) {
      if (r.studentId == subject.id && r.isPending) return r;
    }
    return null;
  }
}
