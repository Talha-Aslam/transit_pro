import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
// `route_data.dart`'s StopData/RouteData have their own StopStatus enum,
// distinct from transit_core's — hide the latter rather than prefix every
// reference in this file.
import 'package:transit_core/transit_core.dart' hide StopStatus;
import 'geofence_service.dart';
import 'location_permissions.dart';
import '../models/route_data.dart';

/// Singleton service that drives bus position along a route.
///
/// In **simulated** mode (default) it interpolates through waypoints.
/// In **live** mode it reads real GPS from the device.
class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  // ── Public state ──────────────────────────────────────────────────────────
  final busPosition = ValueNotifier<GeoCoord>(const GeoCoord(31.5204, 74.3587));
  final busHeading = ValueNotifier<double>(0);
  final speed = ValueNotifier<int>(35);
  final etaMinutes = ValueNotifier<int>(8);
  final isLive = ValueNotifier<bool>(false);
  final isSimulating = ValueNotifier<bool>(false);

  /// Bumped only when a stop's [StopStatus] actually transitions — never on
  /// every 150 ms tick. The map layer listens to this (not the 6.7 Hz
  /// position ticks) to know when to touch the 6 static stop annotations,
  /// which only need redrawing a handful of times per route, not 6.7×/sec.
  final stopStatusRevision = ValueNotifier<int>(0);

  /// Helper to check if any form of tracking is active.
  ValueNotifier<bool> get isMoving => isSimulating;

  RouteData? _route;

  /// Null until a real trip is running. This used to fall back to
  /// [MockRouteBuilder.buildMorningRoute] the instant anything asked for a
  /// route, which is why a brand-new account's Track tab could show a full
  /// "Route Progress" timeline and a moving bus before any driver had ever
  /// started anything — every screen that reads this must now handle null as
  /// "no ride is happening right now", not fall back to a placeholder route
  /// of its own.
  RouteData? get route => _route;

  /// Expose the current waypoint index so the route screen can build
  /// the "completed" polyline segment accurately.
  int get waypointIndex => _waypointIndex;

  Timer? _simTimer;
  StreamSubscription<Position>? _gpsSub;
  int _waypointIndex = 0;
  final _rand = Random();
  // Whether the service is currently paused (off-screen).
  bool _paused = false;
  // Remembers whether simulation was running before pause.
  bool _wasSimulating = false;
  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Initialise with a route and start simulated tracking.
  void start(RouteData route) {
    _route = route;
    _waypointIndex = 0;
    if (route.polylinePoints.isNotEmpty) {
      busPosition.value = route.polylinePoints.first;
    }
    _startSimulation();
  }

  /// Call from widget dispose, or when a real trip actually ends.
  ///
  /// Clears [_route] (not just the timers) so [route] goes back to null —
  /// otherwise a screen that reads it after the ride ends would keep showing
  /// the last trip's stops and polyline forever, which is exactly the kind
  /// of stale-mock-data bug this null contract exists to prevent.
  void stop() {
    _simTimer?.cancel();
    _simTimer = null;
    _gpsSub?.cancel();
    _gpsSub = null;
    isSimulating.value = false;
    isLive.value = false;
    _paused = false;
    _route = null;
    _waypointIndex = 0;
  }

  /// Freeze all position updates without losing route progress.
  /// Call when the map/route screen goes off-screen.
  void pause() {
    if (_paused) return;
    _paused = true;
    _wasSimulating = isSimulating.value;
    _simTimer?.cancel();
    _simTimer = null;
    isSimulating.value = false;
    // Pause the GPS stream so the OS location provider is also throttled.
    if (_gpsSub != null && !(_gpsSub?.isPaused ?? true)) {
      _gpsSub?.pause();
    }
  }

  /// Resume from exactly where pause() left off.
  void resume() {
    if (!_paused) return;
    _paused = false;
    if (isLive.value) {
      // Resume the GPS stream.
      if (_gpsSub != null && (_gpsSub?.isPaused ?? false)) {
        _gpsSub?.resume();
      }
    } else if (_wasSimulating) {
      _startSimulation();
    }
  }

  /// Toggle between simulated and real GPS.
  Future<void> toggleLive() async {
    if (isLive.value) {
      _gpsSub?.cancel();
      _gpsSub = null;
      isLive.value = false;
      _startSimulation();
    } else {
      _simTimer?.cancel();
      _simTimer = null;
      isSimulating.value = false;

      final ok = await ensureLocationPermission();
      if (!ok) return;

      isLive.value = true;
      _gpsSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((pos) {
            busPosition.value = GeoCoord(pos.latitude, pos.longitude);
            busHeading.value = pos.heading;
            speed.value = pos.speed.round().clamp(0, 120);
          });
    }
  }

  // ── Simulation ────────────────────────────────────────────────────────────

  void _startSimulation() {
    final r = _route;
    if (r == null) return;
    isSimulating.value = true;
    final pts = r.polylinePoints;
    if (pts.isEmpty) return;

    _simTimer?.cancel();
    // 150 ms ticks → smooth 6–7 fps movement across ~82 waypoints
    _simTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (_route == null) {
        _simTimer?.cancel();
        _simTimer = null;
        return;
      }
      if (_waypointIndex >= pts.length - 1) {
        _waypointIndex = 0; // loop
        _resetStopStatuses();
        GeofenceService.instance.reset();
        // Deliberately does not bump the student's ride count any more. This
        // is the *simulation* looping, not a journey; counting it inflated the
        // dashboard with rides that never happened. Ride stats are derived
        // from real attendance records in StudentDataService.
      }

      _waypointIndex++;
      final prev = pts[_waypointIndex - 1];
      final next = pts[_waypointIndex];

      busPosition.value = next;
      busHeading.value = _bearing(prev, next);
      speed.value = 30 + _rand.nextInt(15);

      _updateStopStatuses(next);
      _updateEta();
    });
  }

  void _updateStopStatuses(GeoCoord busPos) {
    final r = _route;
    if (r == null) return;
    var changed = false;
    for (final stop in r.stops) {
      final dist = _distanceBetween(busPos, stop.location);
      if (dist < 150 && stop.status == StopStatus.upcoming) {
        stop.status = StopStatus.current;
        changed = true;
      } else if (dist < 150 && stop.status == StopStatus.current) {
        // already current, keep it
      } else if (stop.status == StopStatus.current && dist > 200) {
        stop.status = StopStatus.completed;
        changed = true;
      }
    }
    if (changed) stopStatusRevision.value++;
  }

  void _resetStopStatuses() {
    final r = _route;
    if (r == null) return;
    for (int i = 0; i < r.stops.length; i++) {
      final s = r.stops[i];
      if (i < 3) {
        s.status = StopStatus.completed;
      } else if (i == 3) {
        s.status = StopStatus.current;
      } else if (i == r.stops.length - 1) {
        s.status = StopStatus.destination;
      } else {
        s.status = StopStatus.upcoming;
      }
    }
    stopStatusRevision.value++;
  }

  void _updateEta() {
    final r = _route;
    if (r == null) return;
    final pts = r.polylinePoints;
    if (pts.isEmpty) return;
    final remaining = pts.length - _waypointIndex;
    final totalEta = (remaining / pts.length * 15).round().clamp(1, 15);
    etaMinutes.value = totalEta;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double _distanceBetween(GeoCoord a, GeoCoord b) {
    return Geolocator.distanceBetween(a.lat, a.lng, b.lat, b.lng);
  }

  double _bearing(GeoCoord from, GeoCoord to) {
    final dLon = _toRad(to.lng - from.lng);
    final lat1 = _toRad(from.lat);
    final lat2 = _toRad(to.lat);
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  double _toRad(double deg) => deg * pi / 180;

  /// Advance to the next stop manually (for driver "Mark Stop Done").
  void markCurrentStopDone() {
    final r = _route;
    if (r == null) return;
    final current = r.currentStop;
    if (current != null) {
      current.status = StopStatus.completed;
      final next = r.nextStop;
      if (next != null) {
        next.status = StopStatus.current;
      }
      stopStatusRevision.value++;
    }
  }
}
