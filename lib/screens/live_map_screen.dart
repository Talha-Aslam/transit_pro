import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';

import '../app/live_bus_service.dart';
import '../map/live_bus_map_view.dart';
import '../theme/app_theme.dart';

/// A family's live map, full screen and interactive.
///
/// Owns none of the tracking: it is a bigger window onto whatever
/// [LiveBusService] is already following for the Track tab that opened it.
/// The driver's own full-screen round is `DriverTripMapScreen`.
class LiveMapScreen extends StatefulWidget {
  final Color accentColor;

  /// Kept for the routes that still pass it; the family map marks this
  /// child's stop from the trip itself.
  final String? highlightedStopName;

  /// The watching child's own two points. Supplied by the parent/student
  /// tracking tabs so the family map can show "your stop" and the school
  /// alongside the bus.
  final GeoCoord? pickup;
  final GeoCoord? destination;

  const LiveMapScreen({
    super.key,
    this.accentColor = AppTheme.parentPurple,
    this.highlightedStopName,
    this.pickup,
    this.destination,
  });

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  /// Same Follow/Free camera toggle as `driver_route.dart`'s live map card —
  /// mirrored here rather than shared, since that file is owned by another
  /// engineer for a different phase of this plan.
  bool _followCamera = true;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    // A family's device has no `TrackingService` route of its own — only the
    // driver's does. What it does have, once the driver taps Start Route, is
    // the bus's own position feed. `LiveBusService.isFollowing` is true for
    // exactly as long as a trip is running on the other phone.
    final followingBus = LiveBusService.instance.isFollowing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Map'),
        backgroundColor: context.cardBgElevated,
        foregroundColor: context.textPrimary,
        elevation: 0,
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: followingBus,
        builder: (_, following, _) {
          if (!following) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'The map comes alive when your driver starts the '
                  'route.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondary),
                ),
              ),
            );
          }
          return Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) => LiveBusMapView(
                    height: constraints.maxHeight,
                    pickup: widget.pickup,
                    destination: widget.destination,
                    accent: accent,
                    followBus: _followCamera,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: SafeArea(
                  child: _FollowToggle(
                    accent: accent,
                    following: _followCamera,
                    onTap: () => setState(() => _followCamera = !_followCamera),
                  ),
                ),
              ),
              // "Following, but no ping yet" is its own state: the
              // round has started and the first position is seconds
              // away, which is different from no round at all.
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  child: ValueListenableBuilder<LiveLocation?>(
                    valueListenable: LiveBusService.instance.position,
                    builder: (_, ping, _) => ping != null
                        ? const SizedBox.shrink()
                        : _WaitingBanner(accent: accent),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shown over the family map between "the driver started the round" and
/// "the first position arrived" — a few seconds on a good connection, and
/// otherwise a state the viewer deserves an explanation for.
class _WaitingBanner extends StatelessWidget {
  final Color accent;
  const _WaitingBanner({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.surfaceBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Route started — waiting for the bus to report its position.',
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors the Follow/Free pill in `driver_route.dart` — same look, same
/// behavior, duplicated here rather than extracted since that file cannot
/// be touched to share a common widget.
class _FollowToggle extends StatelessWidget {
  final Color accent;
  final bool following;
  final VoidCallback onTap;

  const _FollowToggle({
    required this.accent,
    required this.following,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: following
              ? accent.withValues(alpha: 0.2)
              : const Color(0x10FFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: following ? accent : const Color(0x20FFFFFF),
          ),
        ),
        child: Text(
          following ? '📍 Follow' : '🗺 Free',
          style: TextStyle(
            color: following ? accent : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
