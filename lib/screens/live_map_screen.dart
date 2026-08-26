import 'package:flutter/material.dart';

import '../app/tracking_service.dart';
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

  const LiveMapScreen({
    super.key,
    this.accentColor = AppTheme.parentPurple,
    this.highlightedStopName,
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
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  // Parent/student tracking screens deliberately never call
                  // `TrackingService.start(...)` any more — reconstructing a
                  // driver's full route client-side would mean querying (and
                  // displaying) every other family's pickup point, which
                  // `firestore.rules` rightly refuses and this app should
                  // not attempt to work around. So for those two roles this
                  // screen currently has nothing to show until a real
                  // cross-device position feed exists — this is a known
                  // gap, not a bug.
                  'A live map appears here once your driver has started the '
                  "route and there's a position to show.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondary),
                ),
              ),
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
