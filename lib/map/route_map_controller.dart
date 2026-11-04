import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_core/transit_core.dart';

import '../models/route_data.dart';
import 'google_geo.dart';

/// Owns the declarative marker/polyline state for one route map.
///
/// google_maps_flutter is declarative — hand it a new `Set<Marker>`/
/// `Set<Polyline>` and the plugin diffs it against the last one, sending
/// only what actually changed across the platform channel. This class
/// assembles those sets without rebuilding more than necessary, since the
/// bus position ticks every 150 ms:
///
/// - The 6 stop markers are built once and only rebuilt on an actual status
///   change (driven by [TrackingService.stopStatusRevision], not by position
///   ticks).
/// - The bus is one `Marker` replaced in place each tick — a `Marker` with
///   the same `markerId` is treated as an update, not an add+remove.
/// - Bus updates are latest-wins: if a publish is still in flight when the
///   next tick arrives, the new position overwrites the pending one, so a
///   burst coalesces instead of queuing.
/// - Every update re-checks [_disposed] — `TrackingService`, layouts and
///   this controller are all torn down and rebuilt whenever the user leaves
///   and re-enters the Track tab.
class RouteMapController {
  GoogleMapController? _map;
  bool _disposed = false;
  bool _attached = false;

  final ValueNotifier<Set<Marker>> markers = ValueNotifier(const {});
  final ValueNotifier<Set<Polyline>> polylines = ValueNotifier(const {});

  final Map<String, Marker> _stopMarkers = {};
  Marker? _busMarker;
  Polyline? _routeLine;
  Polyline? _progressLine;

  // Latest-wins bus-update coalescing.
  GeoCoord? _pendingBusPos;
  double? _pendingBearing;
  int? _pendingProgressIdx;
  bool _busUpdateInFlight = false;
  int _progressTick = 0;

  bool get isAttached => _attached;

  /// Called from `GoogleMap.onMapCreated`. Safe to call more than once —
  /// Android can recreate the platform view (hot reload, config change)
  /// without the Flutter widget rebuilding.
  void attach(GoogleMapController map) {
    if (_disposed) return;
    _map = map;
    _attached = true;
  }

  /// Draws the dashed full route line. Call once per route; static for the
  /// lifetime of a route, so it never needs updating after this.
  void setRoute(List<GeoCoord> points, Color routeColor) {
    if (_disposed || points.length < 2) return;
    _routeLine = Polyline(
      polylineId: const PolylineId('route'),
      points: [for (final p in points) p.latLng],
      color: routeColor,
      width: 4,
      patterns: [PatternItem.dash(20), PatternItem.gap(10)],
    );
    _publishPolylines();
  }

  /// Builds the static stop markers in one pass. [imageFor] resolves a stop
  /// to its pin bitmap — callers pre-rasterise these via [MapIcons].
  Future<void> setStops(
    List<StopData> stops,
    Future<Uint8List> Function(StopData stop) imageFor,
    double dpr,
  ) async {
    if (_disposed || stops.isEmpty) return;

    final images = await Future.wait(stops.map(imageFor));
    if (_disposed) return;

    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      _stopMarkers[stop.name] = Marker(
        markerId: MarkerId('stop-${stop.name}'),
        position: stop.location.latLng,
        icon: BitmapDescriptor.bytes(images[i], imagePixelRatio: dpr),
        anchor: const Offset(0.5, 1),
      );
    }
    _publishMarkers();
  }

  /// Re-images only the stops whose icon actually needs to change. Cheap and
  /// infrequent — driven by [TrackingService.stopStatusRevision], not by the
  /// 150 ms position tick.
  Future<void> updateStopIcons(
    List<StopData> stops,
    Future<Uint8List> Function(StopData stop) imageFor,
    double dpr,
  ) async {
    if (_disposed) return;
    var changed = false;
    for (final stop in stops) {
      final existing = _stopMarkers[stop.name];
      if (existing == null) continue;
      final image = await imageFor(stop);
      if (_disposed) return;
      _stopMarkers[stop.name] = existing.copyWith(
        iconParam: BitmapDescriptor.bytes(image, imagePixelRatio: dpr),
      );
      changed = true;
    }
    if (changed) _publishMarkers();
  }

  /// Creates the bus marker. Call once, after [setStops].
  void setBus(GeoCoord position, double bearing, Uint8List image, double dpr) {
    if (_disposed) return;
    _busMarker = Marker(
      markerId: const MarkerId('bus'),
      position: position.latLng,
      icon: BitmapDescriptor.bytes(image, imagePixelRatio: dpr),
      rotation: bearing,
      anchor: const Offset(0.5, 0.5),
    );
    _publishMarkers();
  }

  /// Queues a bus position/heading update. Latest-wins: if a previous
  /// publish is still draining, this just overwrites the pending values.
  void queueBusUpdate(GeoCoord pos, double bearing, int progressIdx) {
    _pendingBusPos = pos;
    _pendingBearing = bearing;
    _pendingProgressIdx = progressIdx;
    if (!_busUpdateInFlight) unawaited(_drainBusUpdates());
  }

  Future<void> _drainBusUpdates() async {
    _busUpdateInFlight = true;
    try {
      while (!_disposed && _pendingBusPos != null) {
        final pos = _pendingBusPos!;
        final bearing = _pendingBearing!;
        final idx = _pendingProgressIdx!;
        _pendingBusPos = null;
        _pendingBearing = null;
        _pendingProgressIdx = null;

        final bus = _busMarker;
        if (bus != null) {
          _busMarker = bus.copyWith(
            positionParam: pos.latLng,
            rotationParam: bearing,
          );
          _publishMarkers();
        }

        // The progress line can be up to ~80 points — redraw it on a coarser
        // cadence than the bus marker itself.
        _progressTick++;
        if (_progressTick % 3 == 0) _updateProgress(idx);

        // Yield so a burst of queued ticks doesn't starve the event loop.
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      _busUpdateInFlight = false;
    }
  }

  /// Draws (or replaces) the "completed" solid line from the route start up
  /// to [upToIndex]. [routePoints] is the same list the bus walks.
  ///
  /// Per-tick progress redraws go through [setProgressStyle] once up front
  /// plus the `progressIdx` already threaded through [queueBusUpdate], so
  /// they share the bus marker's coarse cadence instead of rebuilding a full
  /// polyline every 150 ms.
  void updateProgress(
    int upToIndex,
    List<GeoCoord> routePoints,
    Color progressColor,
  ) {
    setProgressStyle(routePoints, progressColor);
    _updateProgress(upToIndex);
  }

  /// Sets the route points/colour used by the throttled progress redraw
  /// inside [_drainBusUpdates], without triggering a redraw itself. Both are
  /// static for a route's lifetime — call once (alongside [setRoute]) rather
  /// than on every tick.
  void setProgressStyle(List<GeoCoord> routePoints, Color progressColor) {
    _routePointsForProgress = routePoints;
    _progressColor = progressColor;
  }

  List<GeoCoord>? _routePointsForProgress;
  Color? _progressColor;

  void _updateProgress(int upToIndex) {
    if (_disposed) return;
    final points = _routePointsForProgress;
    final color = _progressColor;
    if (points == null || color == null || upToIndex <= 0) return;

    final segment = points.sublist(0, (upToIndex + 1).clamp(0, points.length));
    if (segment.length < 2) return;

    _progressLine = Polyline(
      polylineId: const PolylineId('progress'),
      points: [for (final p in segment) p.latLng],
      color: color,
      width: 5,
    );
    _publishPolylines();
  }

  /// Camera follow — a jump, not an animated transition, matching the old
  /// behaviour (unverified whether repeated animated moves at this cadence
  /// cancel cleanly rather than queuing and fighting each other).
  Future<void> followCamera(
    GeoCoord center,
    double bearing, {
    double zoom = 14.5,
    double pitch = 30,
  }) async {
    if (_disposed || _map == null) return;
    await _map!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: center.latLng,
          zoom: zoom,
          bearing: bearing,
          tilt: pitch,
        ),
      ),
    );
  }

  void _publishMarkers() {
    if (_disposed) return;
    markers.value = {..._stopMarkers.values, ?_busMarker};
  }

  void _publishPolylines() {
    if (_disposed) return;
    polylines.value = {?_routeLine, ?_progressLine};
  }

  void dispose() {
    _disposed = true;
    _attached = false;
    _map = null;
    _stopMarkers.clear();
    _busMarker = null;
    _routeLine = null;
    _progressLine = null;
    markers.dispose();
    polylines.dispose();
  }
}
