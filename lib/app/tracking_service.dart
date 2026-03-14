import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_data.dart';

/// Singleton service that drives bus position along a route.
///
/// In **simulated** mode (default) it interpolates through waypoints.
/// In **live** mode it reads real GPS from the device.
class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  // ── Public state ──────────────────────────────────────────────────────────
  final busPosition = ValueNotifier<LatLng>(const LatLng(31.5204, 74.3587));
  final busHeading = ValueNotifier<double>(0);
  final speed = ValueNotifier<int>(35);
  final etaMinutes = ValueNotifier<int>(8);
  final isLive = ValueNotifier<bool>(false);
  final isSimulating = ValueNotifier<bool>(false);

  late RouteData _route;
  RouteData get route => _route;

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

  /// Call from widget dispose.
  void stop() {
    _simTimer?.cancel();
    _simTimer = null;
    _gpsSub?.cancel();
    _gpsSub = null;
    isSimulating.value = false;
    isLive.value = false;
    _paused = false;
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

      final ok = await _ensureLocationPermission();
      if (!ok) return;

      isLive.value = true;
      _gpsSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((pos) {
            busPosition.value = LatLng(pos.latitude, pos.longitude);
            busHeading.value = pos.heading;
            speed.value = pos.speed.round().clamp(0, 120);
          });
    }
  }

  // ── Simulation ────────────────────────────────────────────────────────────

  void _startSimulation() {
    isSimulating.value = true;
    final pts = _route.polylinePoints;
    if (pts.isEmpty) return;

    _simTimer?.cancel();
    // 150 ms ticks → smooth 6–7 fps movement across ~82 waypoints
    _simTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (_waypointIndex >= pts.length - 1) {
        _waypointIndex = 0; // loop
        _resetStopStatuses();
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

  void _updateStopStatuses(LatLng busPos) {
    for (final stop in _route.stops) {
      final dist = _distanceBetween(busPos, stop.location);
      if (dist < 150 && stop.status == StopStatus.upcoming) {
        stop.status = StopStatus.current;
      } else if (dist < 150 && stop.status == StopStatus.current) {
        // already current, keep it
      } else if (stop.status == StopStatus.current && dist > 200) {
        stop.status = StopStatus.completed;
      }
    }
  }

  void _resetStopStatuses() {
    for (int i = 0; i < _route.stops.length; i++) {
      final s = _route.stops[i];
      if (i < 3) {
        s.status = StopStatus.completed;
      } else if (i == 3) {
        s.status = StopStatus.current;
      } else if (i == _route.stops.length - 1) {
        s.status = StopStatus.destination;
      } else {
        s.status = StopStatus.upcoming;
      }
    }
  }

  void _updateEta() {
    final pts = _route.polylinePoints;
    final remaining = pts.length - _waypointIndex;
    final totalEta = (remaining / pts.length * 15).round().clamp(1, 15);
    etaMinutes.value = totalEta;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double _distanceBetween(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  double _bearing(LatLng from, LatLng to) {
    final dLon = _toRad(to.longitude - from.longitude);
    final lat1 = _toRad(from.latitude);
    final lat2 = _toRad(to.latitude);
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  double _toRad(double deg) => deg * pi / 180;

  Future<bool> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return false;
    }
    if (perm == LocationPermission.deniedForever) return false;
    return true;
  }

  /// Advance to the next stop manually (for driver "Mark Stop Done").
  void markCurrentStopDone() {
    final current = _route.currentStop;
    if (current != null) {
      current.status = StopStatus.completed;
      final next = _route.nextStop;
      if (next != null) {
        next.status = StopStatus.current;
      }
    }
  }
}
