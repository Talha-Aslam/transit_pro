import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/navigation_launcher.dart';
import '../../app/tracking_service.dart';
import '../../app/trip_controller.dart';
import '../../map/trip_map_renderer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

/// `12 min`, `under a minute`, or a dash.
String formatEta(int? seconds) {
  if (seconds == null) return '—';
  if (seconds < 60) return 'under a minute';
  final m = (seconds / 60).round();
  if (m < 60) return '$m min';
  return '${m ~/ 60} hr ${m % 60} min';
}

/// `850 m`, `3.4 km`, or a dash.
String formatMeters(double? meters) =>
    TrackingService.formatDistance(meters) ?? '—';

/// Who is at a stop, as one line.
String stopNames(TripController c, TripStop s) {
  if (s.isInstitute) return c.instituteName(s);
  final names = c.ridersAt(s).map((r) => r.name).toList();
  return names.isEmpty ? 'Stop ${s.order}' : names.join(' & ');
}

/// Everything that is wrong right now, each in one sentence.
///
/// Network down, location switched off, permission taken away, a weak fix,
/// a route drawn without Google: each changes what the families see, so the
/// driver is told rather than left wondering why the map looks wrong.
class TripStatusBanners extends StatelessWidget {
  final TripController controller;
  const TripStatusBanners({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = TrackingService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller,
        t.isConnected,
        t.gpsEnabled,
        t.gpsError,
        t.weakSignal,
      ]),
      builder: (context, _) {
        final banners = <(IconData, Color, String)>[
          if (t.gpsError.value != null)
            (Icons.location_disabled, AppTheme.error, t.gpsError.value!),
          if (!t.gpsEnabled.value)
            (
              Icons.location_off,
              AppTheme.error,
              'Location is switched off. Families cannot see the van.',
            ),
          if (!t.isConnected.value)
            (
              Icons.cloud_off,
              AppTheme.warning,
              'No internet. Your position will be sent when you are back '
                  'online.',
            ),
          if (t.weakSignal.value)
            (
              Icons.gps_not_fixed,
              AppTheme.warning,
              'Weak GPS signal — the van may look still for a moment.',
            ),
          if (controller.isApproximate && controller.warning != null)
            (Icons.alt_route, AppTheme.warning, controller.warning!),
        ];
        if (banners.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (final (icon, color, text) in banners)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Where the van is going next: who, how far, how long, and a button that
/// hands just that stop to Google Maps.
class NextStopCard extends StatelessWidget {
  final TripController controller;
  final VoidCallback? onSkip;
  const NextStopCard({super.key, required this.controller, this.onSkip});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final next = c.nextStop;
    if (next == null) return const SizedBox.shrink();
    final color = TripMapRenderer.stopColor(next);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: color.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _OrderDot(
                label: next.isInstitute ? '🏁' : '${next.order}',
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      next.isInstitute
                          ? 'Next: ${stopNames(c, next)}'
                          : c.leg == TripLegKind.pickup
                          ? 'Next pickup'
                          : 'Next drop-off',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      stopNames(c, next),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Figure(
                icon: Icons.schedule,
                value: formatEta(c.secondsTo(next)),
                label: 'arrives in',
              ),
              const SizedBox(width: 10),
              _Figure(
                icon: Icons.straighten,
                value: formatMeters(c.metersTo(next)),
                label: 'by road',
              ),
              if (c.isPlanning) ...[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.driverCyan,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text(
                    'Navigate',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onPressed: () async {
                    final ok = await NavigationLauncher.navigateTo(
                      next.location,
                    );
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Google Maps could not be opened.'),
                        ),
                      );
                    }
                  },
                ),
              ),
              if (next.isChildStop && onSkip != null) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onSkip,
                  child: const Text('Skip stop'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// "Arriving at Ali's" — one row per child at the stop, each with the two
/// answers that leg allows.
class ArrivalCard extends StatelessWidget {
  final TripController controller;
  const ArrivalCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final prompt = c.arrival;
    if (prompt == null) return const SizedBox.shrink();
    // Where children get on — a morning gate, or the institute on the way
    // home — or a home where they get off.
    final boarding = c.isBoardingStop(prompt.stop);
    final atInstitute = prompt.stop.isInstitute;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: AppTheme.warning,
      borderWidth: prompt.suggested ? 2.5 : 1.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place, color: AppTheme.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Arriving at ${stopNames(c, prompt.stop)}',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (prompt.suggested) ...[
            const SizedBox(height: 4),
            Text(
              boarding
                  ? 'You have stopped here — mark who got on.'
                  : 'You have stopped here — mark who got off.',
              style: const TextStyle(color: AppTheme.warning, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          for (final r in prompt.riders)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.name,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _ActionButton(
                    label: boarding
                        ? (atInstitute ? 'Boarded' : 'Present')
                        : 'Dropped',
                    color: AppTheme.success,
                    onTap: () =>
                        boarding ? c.markPresent(r.id) : c.markDropped(r.id),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: boarding
                        ? (atInstitute ? 'Not here' : 'Absent')
                        : 'Not on van',
                    color: AppTheme.error,
                    onTap: () => c.markAbsent(r.id),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The morning leg is done: everyone is handed over at school.
class ArrivedCard extends StatelessWidget {
  final VoidCallback onEnd;
  final bool ending;
  const ArrivedCard({super.key, required this.onEnd, this.ending = false});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppTheme.success,
      child: Column(
        children: [
          const Text('🏫', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            'Arrived at school',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Every child on board has been marked as dropped off and their '
            'families told.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: 'End route',
            gradient: AppTheme.driverGradient,
            glowColor: AppTheme.driverCyan,
            isLoading: ending,
            onTap: onEnd,
          ),
        ],
      ),
    );
  }
}

/// Every stop in visiting order: number, who, ETA, distance and state.
class TripStopList extends StatelessWidget {
  final TripController controller;
  const TripStopList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stops',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final s in c.stops) _StopRow(controller: c, stop: s),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final TripController controller;
  final TripStop stop;
  const _StopRow({required this.controller, required this.stop});

  String get _state => switch (stop.status) {
    TripStopStatus.done =>
      stop.isInstitute
          ? 'Arrived'
          : controller.leg == TripLegKind.pickup
          ? 'Picked up'
          : 'Dropped',
    TripStopStatus.skipped => 'Absent',
    TripStopStatus.arriving => 'Arriving',
    TripStopStatus.pending => formatEta(controller.secondsTo(stop)),
  };

  @override
  Widget build(BuildContext context) {
    final color = TripMapRenderer.stopColor(stop);
    final isNext = controller.nextStop?.id == stop.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _OrderDot(
            label: stop.isInstitute ? '🏁' : '${stop.order}',
            color: color,
            small: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stopNames(controller, stop),
                  style: TextStyle(
                    color: stop.isOpen
                        ? context.textPrimary
                        : context.textTertiary,
                    fontSize: 13,
                    fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                if (stop.isOpen)
                  Text(
                    formatMeters(controller.metersTo(stop)),
                    style: TextStyle(color: context.textTertiary, fontSize: 11),
                  ),
              ],
            ),
          ),
          Text(
            _state,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Who is on the van right now.
class OnBoardList extends StatelessWidget {
  final TripController controller;
  const OnBoardList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final riders = controller.onBoard;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'On board',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${riders.length}',
                style: const TextStyle(
                  color: AppTheme.success,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (riders.isEmpty)
            Text(
              'Nobody yet.',
              style: TextStyle(color: context.textTertiary, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in riders)
                  Chip(
                    avatar: const Icon(
                      Icons.check_circle,
                      color: AppTheme.success,
                      size: 16,
                    ),
                    label: Text(r.name),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OrderDot extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;
  const _OrderDot({
    required this.label,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = small ? 28.0 : 38.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: small ? 12 : 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _Figure({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.driverAccent),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: context.textTertiary, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 42, minWidth: 84),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
