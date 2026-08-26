import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:transit_core/transit_core.dart';

import '../models/route_data.dart';
import 'mapbox_geo.dart';

/// Owns the imperative Mapbox annotation lifecycle for one route map.
///
/// Google Maps is declarative — pass a new `Set<Marker>` and the widget
/// diffs it for you. Mapbox is imperative: await a manager, then
/// create/update/delete on it. The bus position ticks every 150 ms, so this
/// class exists specifically to avoid thrashing the platform channel:
///
/// - The 6 stop pins are created exactly once and only ever touched again on
///   an actual status change (driven by [TrackingService.stopStatusRevision],
///   not by position ticks).
/// - The bus is one [PointAnnotation] held and `update()`-ed in place, never
///   recreated.
/// - Bus updates are latest-wins: if a platform call is still in flight when
///   the next tick arrives, the new position is queued and the in-flight
///   call's completion immediately fires the queued one — never more than
///   one in-flight call, and no tick is ever silently lost, just coalesced.
/// - Every `await` boundary re-checks [_disposed] — `TrackingService`,
///   layouts and this controller are all torn down and rebuilt every time a
///   user leaves and re-enters the Track tab, and Android can re-fire
///   `onMapCreated` after platform-view recreation, so a stale in-flight
///   setup must never write to a map that's already gone.
class RouteMapController {
  MapboxMap? _map;
  PointAnnotationManager? _stopsMgr;
  PointAnnotationManager? _busMgr;
  PolylineAnnotationManager? _routeMgr;
  PolylineAnnotationManager? _progressMgr;

  final Map<String, PointAnnotation> _stopAnnotations = {};
  PointAnnotation? _busAnnotation;
  PolylineAnnotation? _progressAnnotation;

  bool _disposed = false;
  bool _attached = false;

  // Latest-wins bus-update coalescing.
  GeoCoord? _pendingBusPos;
  double? _pendingBearing;
  int? _pendingProgressIdx;
  bool _busUpdateInFlight = false;
  int _progressTick = 0;

  bool get isAttached => _attached;

  /// Called from `MapWidget.onMapCreated`. Safe to call more than once —
  /// Android can recreate the platform view (hot reload, config change)
  /// without the Flutter widget rebuilding, which would otherwise leave two
  /// live sets of managers writing to the same map.
  Future<void> attach(MapboxMap map) async {
    if (_attached) await _teardownManagers();
    if (_disposed) return;
    _map = map;

    await map.compass.updateSettings(CompassSettings(enabled: false));
    if (_disposed) return;
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    if (_disposed) return;

    // Z-order follows creation order: route line at the bottom, bus on top.
    _routeMgr = await map.annotations.createPolylineAnnotationManager();
    if (_disposed) return _cleanupOrphan(_routeMgr);
    _progressMgr = await map.annotations.createPolylineAnnotationManager();
    if (_disposed) return _cleanupOrphan(_progressMgr);
    _stopsMgr = await map.annotations.createPointAnnotationManager();
    if (_disposed) return _cleanupOrphan(_stopsMgr);
    _busMgr = await map.annotations.createPointAnnotationManager();
    if (_disposed) return _cleanupOrphan(_busMgr);

    await _routeMgr!.setLineDasharray([5.0, 2.5]);
    if (_disposed) return;
    // Mapbox collision-hides overlapping symbols by default — with 6 stops
    // spanning ~2km inside a 220px map at zoom ~12.5, that would silently
    // drop pins rather than error, so this is not optional.
    await _stopsMgr!.setIconAllowOverlap(true);
    if (_disposed) return;
    await _busMgr!.setIconAllowOverlap(true);
    if (_disposed) return;
    await _busMgr!.setIconRotationAlignment(IconRotationAlignment.MAP);

    _attached = true;
  }

  /// Draws the (dashed) full route line. Call once per route; static for the
  /// lifetime of a route, so this never needs an `update()`.
  Future<void> setRoute(List<GeoCoord> points, Color routeColor) async {
    if (_disposed || _routeMgr == null || points.length < 2) return;
    await _routeMgr!.create(
      PolylineAnnotationOptions(
        geometry: points.lineString,
        lineColor: routeColor.toARGB32(),
        lineWidth: 4,
        lineOpacity: 1,
      ),
    );
  }

  /// Creates the static stop pins in one call. [colorFor] resolves a stop to
  /// its pin colour/icon — callers pre-rasterise and register these via
  /// [MapIcons] before calling this.
  Future<void> setStops(
    List<StopData> stops,
    Future<Uint8List> Function(StopData stop) imageFor,
  ) async {
    if (_disposed || _stopsMgr == null || stops.isEmpty) return;

    final images = await Future.wait(stops.map(imageFor));
    if (_disposed) return;

    final options = [
      for (var i = 0; i < stops.length; i++)
        PointAnnotationOptions(
          geometry: stops[i].location.point,
          image: images[i],
          iconAnchor: IconAnchor.BOTTOM,
        ),
    ];

    final created = await _stopsMgr!.createMulti(options);
    if (_disposed) return;

    for (var i = 0; i < stops.length; i++) {
      final ann = created[i];
      if (ann != null) _stopAnnotations[stops[i].name] = ann;
    }
  }

  /// Re-images only the stops whose icon actually needs to change. Cheap and
  /// infrequent — called from [TrackingService.stopStatusRevision], not from
  /// the 150 ms position tick.
  Future<void> updateStopIcons(
    List<StopData> stops,
    Future<Uint8List> Function(StopData stop) imageFor,
  ) async {
    if (_disposed || _stopsMgr == null) return;
    for (final stop in stops) {
      final ann = _stopAnnotations[stop.name];
      if (ann == null) continue;
      ann.image = await imageFor(stop);
      if (_disposed) return;
      await _stopsMgr!.update(ann);
      if (_disposed) return;
    }
  }

  /// Creates the bus annotation. Call once, after [setStops].
  Future<void> setBus(GeoCoord position, double bearing, Uint8List image) async {
    if (_disposed || _busMgr == null) return;
    _busAnnotation = await _busMgr!.create(
      PointAnnotationOptions(
        geometry: position.point,
        image: image,
        iconRotate: bearing,
      ),
    );
  }

  /// Queues a bus position/heading update. Latest-wins: if a previous call
  /// is still in flight, this one simply overwrites the pending values and
  /// returns — the in-flight call picks up the latest state when it
  /// completes, so no separate timer or throttle is needed.
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

        final bus = _busAnnotation;
        if (bus != null) {
          bus.geometry = pos.point;
          bus.iconRotate = bearing;
          await _busMgr?.update(bus);
          if (_disposed) return;
        }

        // The progress line's payload can be up to ~80 points — redraw it
        // on a coarser cadence than the bus itself.
        _progressTick++;
        if (_progressTick % 3 == 0) {
          await _updateProgress(idx);
          if (_disposed) return;
        }
      }
    } finally {
      _busUpdateInFlight = false;
    }
  }

  /// Draws (or replaces) the "completed" solid line from the route start up
  /// to [upToIndex]. [routePoints] is the same list the bus walks.
  ///
  /// This bypasses [queueBusUpdate]'s throttle — only call it for a one-off
  /// redraw (e.g. the initial progress line on map creation). Per-tick
  /// progress redraws must go through [setProgressStyle] once up front plus
  /// the `progressIdx` already threaded through [queueBusUpdate], so they
  /// share the same coarse cadence as the bus marker instead of pushing a
  /// full polyline every 150 ms.
  Future<void> updateProgress(int upToIndex, List<GeoCoord> routePoints,
      Color progressColor) async {
    setProgressStyle(routePoints, progressColor);
    await _updateProgress(upToIndex);
  }

  /// Sets the route points/colour used by the throttled progress redraw
  /// inside [_drainBusUpdates], without triggering a redraw itself. Route
  /// points and colour are static for a route's lifetime — call this once
  /// (e.g. alongside [setRoute]) rather than on every bus-position tick.
  void setProgressStyle(List<GeoCoord> routePoints, Color progressColor) {
    _routePointsForProgress = routePoints;
    _progressColor = progressColor;
  }

  List<GeoCoord>? _routePointsForProgress;
  Color? _progressColor;

  Future<void> _updateProgress(int upToIndex) async {
    if (_disposed || _progressMgr == null) return;
    final points = _routePointsForProgress;
    final color = _progressColor;
    if (points == null || color == null || upToIndex <= 0) return;

    final segment = points.sublist(0, (upToIndex + 1).clamp(0, points.length));
    if (segment.length < 2) return;

    final existing = _progressAnnotation;
    if (existing == null) {
      _progressAnnotation = await _progressMgr!.create(
        PolylineAnnotationOptions(
          geometry: segment.lineString,
          lineColor: color.toARGB32(),
          lineWidth: 5,
        ),
      );
    } else {
      existing.geometry = segment.lineString;
      await _progressMgr!.update(existing);
    }
  }

  /// Camera follow, exact parity with the old `moveCamera` jump (not an
  /// animated `easeTo` — unverified whether repeated `easeTo` calls at this
  /// cadence cancel cleanly rather than queuing/fighting each other).
  Future<void> followCamera(GeoCoord center, double bearing,
      {double zoom = 14.5, double pitch = 30}) async {
    if (_disposed || _map == null) return;
    await _map!.setCamera(
      CameraOptions(center: center.point, zoom: zoom, bearing: bearing, pitch: pitch),
    );
  }

  Future<void> _cleanupOrphan(BaseAnnotationManager? manager) async {
    if (manager == null) return;
    try {
      await _map?.annotations.removeAnnotationManager(manager);
    } catch (_) {
      // The platform view may already be torn down — its native teardown
      // already reclaimed this manager, so a failure here is expected, not
      // an error to surface.
    }
  }

  Future<void> _teardownManagers() async {
    for (final mgr in [_routeMgr, _progressMgr, _stopsMgr, _busMgr]) {
      if (mgr == null) continue;
      try {
        await _map?.annotations.removeAnnotationManager(mgr);
      } catch (_) {
        // Same reasoning as _cleanupOrphan.
      }
    }
    _routeMgr = null;
    _progressMgr = null;
    _stopsMgr = null;
    _busMgr = null;
    _stopAnnotations.clear();
    _busAnnotation = null;
    _progressAnnotation = null;
    _attached = false;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _teardownManagers();
    _map = null;
  }
}
