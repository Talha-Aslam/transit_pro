import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';

import '../app/live_bus_service.dart';
import '../app/tracking_service.dart';
import '../map/live_bus_map_view.dart';
import '../map/route_map_view.dart';
import '../theme/app_theme.dart';

/// Fullscreen, genuinely interactive view onto whatever [TrackingService]
/// session is already running.
///
/// This screen owns none of the tracking lifecycle — it never calls
/// `TrackingService.instance.start(...)` or `.stop()`. It is opened from a
/// tab (parent/student tracking) that already started the simulation, and
/// closing this screen (the back button) leaves that session running
/// exactly as it was — this is just a bigger, pannable/zoomable window onto
/// the same [RouteMapView] those tabs already render at 220px with
/// `interactive: false`.
class LiveMapScreen extends StatefulWidget {
  final Color accentColor;

  /// Highlights one stop regardless of its status — the parent/student
  /// "this is your stop" marker. Passed straight through to [RouteMapView].
  final String? highlightedStopName;

  /// The watching child's own two points. Supplied by the parent/student
  /// tracking tabs so the family map can show "your stop" and the school
  /// alongside the bus. Null on the driver's own screen, which renders the
  /// whole round from [TrackingService] instead.
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
  final _tracking = TrackingService.instance;

  /// Same Follow/Free camera toggle as `driver_route.dart`'s live map card —
  /// mirrored here rather than shared, since that file is owned by another
  /// engineer for a different phase of this plan.
  bool _followCamera = true;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    // `TrackingService.route` is null until a real trip is running (nobody
    // has called `.start(...)` yet, or the driver ended the trip) — this
    // screen is only ever a *view* onto that state, so a null/empty route
    // here just means "nothing to show right now", not an error.
    final route = _tracking.route;
    final hasRoute = route != null && route.polylinePoints.isNotEmpty;

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
      body: hasRoute
          ? Stack(
              children: [
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) => RouteMapView(
                      height: constraints.maxHeight,
                      highlightedStopName: widget.highlightedStopName,
                      routeColor: accent,
                      upcomingStopColor: accent,
                      followBus: _followCamera,
                      interactive: true,
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
                      onTap: () =>
                          setState(() => _followCamera = !_followCamera),
                    ),
                  ),
                ),
              ],
            )
          // A family device: no local route, but the bus publishes its own
          // position. This used to be the dead end that told the parent to
          // wait for a feed that already existed but nothing consumed.
          : ValueListenableBuilder<bool>(
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
                          onTap: () =>
                              setState(() => _followCamera = !_followCamera),
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
