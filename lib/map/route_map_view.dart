import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
// `route_data.dart`'s StopStatus is distinct from transit_core's own enum of
// the same name — hide the latter rather than prefix every reference here.
import 'package:transit_core/transit_core.dart' hide StopStatus;

import '../app/tracking_service.dart';
import '../models/route_data.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'mapbox_geo.dart';
import 'map_icons.dart';
import 'map_style.dart';
import 'route_map_controller.dart';

/// Shared live-tracking map: the 6 stop pins, the dashed route line, the
/// "completed" progress line, and the moving bus. Replaces the near-identical
/// `GoogleMap` block that used to live in each of the three tracking screens.
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
  /// and a pan-capturing native view would fight the page scroll (a latent
  /// bug the old Google Maps screens had too). The driver map opts in: its
  /// explicit Follow/Free toggle implies the user is meant to be able to pan
  /// once they switch to Free.
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
    unawaited(_controller.dispose());
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
    // Calling `updateProgress` here too, on every 150ms tick, used to push a
    // full ~80-point polyline across the platform channel on every single
    // tick, completely bypassing that throttle.
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
    unawaited(_controller.updateStopIcons(
      route.stops,
      (stop) => MapIcons.pin(_colorFor(stop), dpr),
    ));
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

  Future<void> _onMapCreated(MapboxMap map) async {
    await _controller.attach(map);
    if (!mounted) return;

    // Null until a real trip is running (see `TrackingService.route`) — the
    // map still renders, just with nothing to draw on it yet.
    final route = _tracking.route;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    if (route != null) {
      await _controller.setRoute(route.polylinePoints, widget.routeColor);
      if (!mounted) return;

      // Static for the lifetime of this route — set once here so the
      // throttled per-tick redraw in `_onBusTick`/`_drainBusUpdates` doesn't
      // need these passed on every tick.
      _controller.setProgressStyle(route.polylinePoints, widget.progressColor);

      await _controller.setStops(
        route.stops,
        (stop) => MapIcons.pin(_colorFor(stop), dpr),
      );
      if (!mounted) return;

      final busImage = await MapIcons.bus(dpr);
      if (!mounted) return;
      await _controller.setBus(
        _tracking.busPosition.value,
        _tracking.busHeading.value,
        busImage,
      );
      if (!mounted) return;

      if (_tracking.waypointIndex > 0) {
        await _controller.updateProgress(
          _tracking.waypointIndex,
          route.polylinePoints,
          widget.progressColor,
        );
      }
    }

    await map.gestures.updateSettings(
      GesturesSettings(
        scrollEnabled: widget.interactive,
        pitchEnabled: widget.interactive,
        rotateEnabled: widget.interactive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (!AppConfig.hasMapboxToken) {
      // Constructing a MapWidget with no token doesn't just fail to render —
      // it throws MapboxConfigurationException out of the native platform
      // view constructor, which Flutter does not catch. This must be checked
      // *before* building MapWidget, not inside onMapCreated (which never
      // gets the chance to run).
      content = ColoredBox(
        color: Colors.black.withValues(alpha: 0.85),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Map unavailable — no Mapbox access token configured.',
              style: TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else {
      final start = _tracking.busPosition.value;
      final isDark = ThemeProvider.instance.isDark;
      content = MapWidget(
        // A theme toggle needs a full style reload; `loadStyleURI` on a live
        // map wouldn't bring the annotation managers back on its own, so this
        // key forces the platform view to be destroyed and recreated instead
        // — annotations rebuild from scratch via onMapCreated, same as any
        // other tab remount.
        key: ValueKey('route-map-$isDark'),
        // Lighter Android platform-view hosting mode than the library
        // default (Virtual Display) — this is the heaviest of the four
        // modes `MapWidget` offers, per its own doc comments.
        androidHostingMode: AndroidPlatformViewHostingMode.TLHC_HC,
        styleUri: MapStyle.forBrightness(isDark),
        cameraOptions: CameraOptions(center: start.point, zoom: 12.5),
        onMapCreated: _onMapCreated,
      );
    }

    final map = SizedBox(height: widget.height, child: content);
    return widget.borderRadius == null
        ? map
        : ClipRRect(borderRadius: widget.borderRadius!, child: map);
  }
}
