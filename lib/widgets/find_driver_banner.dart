import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../app/session_service.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

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
              ? 'Driver assigned'
              : 'Riding with ${driver.name}';
          final round = driver?.scheduleById(subject.scheduleId);
          subtitle = round == null
              ? 'Tap to see other drivers serving ${subject.school}.'
              : '${round.directionLabel} ${round.timeRange} · '
                  'tap to change driver';
        } else if (request != null && request.isPending) {
          tint = AppTheme.warning;
          emoji = '⏳';
          title = 'Waiting on ${request.driverName}';
          subtitle = '${request.scheduleLabel} — tap to check or withdraw.';
        } else if (subject.school.trim().isEmpty) {
          tint = AppTheme.info;
          emoji = '🏫';
          title = 'Add ${subject.name}\'s school';
          subtitle = 'Driver search matches on the school they attend.';
        } else {
          tint = accent;
          emoji = '🔍';
          title = 'Find a driver for ${subject.name}';
          subtitle = 'See drivers who already run to ${subject.school}.';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => context.push(searchRoute),
            child: GlassCard(
              // Sits inside a scrolling dashboard body, so it repaints (and
              // would re-blur) on every scroll frame along with the rest.
              enableBlur: false,
              padding: const EdgeInsets.all(16),
              borderColor: tint.withValues(alpha: 0.35),
              gradient: LinearGradient(
                colors: [
                  tint.withValues(alpha: 0.14),
                  tint.withValues(alpha: 0.04),
                ],
              ),
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
                    child: Text(emoji, style: const TextStyle(fontSize: 21)),
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
                  Icon(Icons.chevron_right_rounded, color: context.textTertiary),
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
