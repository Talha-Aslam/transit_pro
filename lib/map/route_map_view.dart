import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// `route_data.dart`'s StopStatus is distinct from transit_core's own enum of
// the same name — hide the latter rather than prefix every reference here.
import 'package:transit_core/transit_core.dart' hide StopStatus;

import '../app/tracking_service.dart';
import '../models/route_data.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'google_geo.dart';
import 'map_icons.dart';
import 'map_style.dart';
import 'route_map_controller.dart';

/// Shared live-tracking map: the 6 stop pins, the dashed route line, the
/// "completed" progress line, and the moving bus.
///
/// This widget owns nothing about *when* the route runs — it only listens to
/// [TrackingService]'s notifiers and renders whatever they currently say.
class RouteMapView extends StatefulWidget {
  final double height;
  final BorderRadius? borderRadius;

  /// Highlights one stop in [AppTheme.studentAmber] regardless of its
  /// [StopStatus] — the parent/student "this is your stop" marker. Null on
  /// the driver screen, which has no single rider to highlight.
  final String? highlightedStopName;

  final Color routeColor;
  final Color progressColor;
  final Color upcomingStopColor;

  /// Driver screen only: camera follows the bus with bearing + pitch.
  final bool followBus;

  /// Whether pan/zoom/rotate gestures are enabled at all. Off by default —
  /// the two 220px parent/student maps sit inside a `SingleChildScrollView`,
  /// and a pan-capturing native view would fight the page scroll. The driver
  /// map opts in: its explicit Follow/Free toggle implies the user is meant
  /// to be able to pan once they switch to Free.
  final bool interactive;

  const RouteMapView({
    super.key,
    required this.height,
    this.borderRadius,
    this.highlightedStopName,
    this.routeColor = AppTheme.studentAmber,
    this.progressColor = AppTheme.success,
    this.upcomingStopColor = AppTheme.info,
    this.followBus = false,
    this.interactive = false,
  });

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  final _tracking = TrackingService.instance;
  final _controller = RouteMapController();

  @override
  void initState() {
    super.initState();
    _tracking.busPosition.addListener(_onBusTick);
    _tracking.stopStatusRevision.addListener(_onStopStatusChanged);
  }

  @override
  void didUpdateWidget(RouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightedStopName != widget.highlightedStopName &&
        _controller.isAttached) {
      _onStopStatusChanged();
    }
  }

  @override
  void dispose() {
    _tracking.busPosition.removeListener(_onBusTick);
    _tracking.stopStatusRevision.removeListener(_onStopStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onBusTick() {
    if (!_controller.isAttached) return;
    final pos = _tracking.busPosition.value;
    final bearing = _tracking.busHeading.value;
    final idx = _tracking.waypointIndex;
    // `queueBusUpdate`'s own throttled drain loop (see
    // `RouteMapController._drainBusUpdates`) redraws the progress line from
    // this `idx` on its coarser cadence — the route points/colour it needs
    // for that were set once in `_onMapCreated` via `setProgressStyle`.
    _controller.queueBusUpdate(pos, bearing, idx);
    if (widget.followBus) {
      unawaited(_controller.followCamera(pos, bearing));
    }
  }

  void _onStopStatusChanged() {
    if (!_controller.isAttached) return;
    // `TrackingService.route` is null until a real trip is running — no
    // stops to redraw yet.
    final route = _tracking.route;
    if (route == null) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    unawaited(
      _controller.updateStopIcons(
        route.stops,
        (stop) => MapIcons.pin(_colorFor(stop), dpr),
        dpr,
      ),
    );
  }

  Color _colorFor(StopData stop) {
    if (stop.name == widget.highlightedStopName) return AppTheme.studentAmber;
    return switch (stop.status) {
      StopStatus.completed => AppTheme.success,
      StopStatus.current => AppTheme.purple,
      StopStatus.upcoming => widget.upcomingStopColor,
      StopStatus.destination => AppTheme.warningLight,
    };
  }

  Future<void> _onMapCreated(GoogleMapController map) async {
    _controller.attach(map);
    if (!mounted) return;

    // Null until a real trip is running (see `TrackingService.route`) — the
    // map still renders, just with nothing drawn on it yet.
    final route = _tracking.route;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    if (route != null) {
      _controller.setRoute(route.polylinePoints, widget.routeColor);

      // Static for the lifetime of this route — set once here so the
      // throttled per-tick redraw doesn't need these passed every tick.
      _controller.setProgressStyle(route.polylinePoints, widget.progressColor);

      await _controller.setStops(
        route.stops,
        (stop) => MapIcons.pin(_colorFor(stop), dpr),
        dpr,
      );
      if (!mounted) return;

      final busImage = await MapIcons.bus(dpr);
      if (!mounted) return;
      _controller.setBus(
        _tracking.busPosition.value,
        _tracking.busHeading.value,
        busImage,
        dpr,
      );

      if (_tracking.waypointIndex > 0) {
        _controller.updateProgress(
          _tracking.waypointIndex,
          route.polylinePoints,
          widget.progressColor,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (!AppConfig.hasGoogleMapsKey) {
      // With no key the native view renders its own chrome but no tiles —
      // check before building it, same as the old token guard did.
      content = ColoredBox(
        color: Colors.black.withValues(alpha: 0.85),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Map unavailable — no Google Maps API key configured.',
              style: TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else {
      final start = _tracking.busPosition.value;
      final isDark = ThemeProvider.instance.isDark;
      content = AnimatedBuilder(
        animation: Listenable.merge([
          _controller.markers,
          _controller.polylines,
        ]),
        builder: (context, _) => GoogleMap(
          // A theme toggle needs a style reload; recreating the platform
          // view (what this key forces) is the lower-risk option, and
          // annotations rebuild from scratch via onMapCreated.
          key: ValueKey('route-map-$isDark'),
          initialCameraPosition: CameraPosition(
            target: start.latLng,
            zoom: 12.5,
          ),
          style: MapStyle.forBrightness(isDark),
          onMapCreated: _onMapCreated,
          markers: _controller.markers.value,
          polylines: _controller.polylines.value,
          compassEnabled: false,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          scrollGesturesEnabled: widget.interactive,
          zoomGesturesEnabled: widget.interactive,
          rotateGesturesEnabled: widget.interactive,
          tiltGesturesEnabled: widget.interactive,
        ),
      );
    }

    final map = SizedBox(height: widget.height, child: content);
    return widget.borderRadius == null
        ? map
        : ClipRRect(borderRadius: widget.borderRadius!, child: map);
  }
}
