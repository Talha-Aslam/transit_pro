import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
// `route_data.dart`'s StopData/RouteData have their own StopStatus enum,
// distinct from transit_core's — hide the latter rather than prefix every
// reference in this file.
import 'package:transit_core/transit_core.dart' hide StopStatus;
import '../data/live_location_repository.dart';
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

  /// Instantaneous ground speed in km/h, straight off the GPS fix.
  final speed = ValueNotifier<int>(0);

  /// Rolling average over the last [_speedWindow] fixes — what the "Avg
  /// speed" read-out shows, and what the ETA is computed against. The
  /// instantaneous value swings between 0 (stopped at a light) and 60
  /// several times a minute, which made both of those jump around for no
  /// reason the driver could see.
  final avgSpeed = ValueNotifier<int>(0);

  /// Minutes to the end of the route. Zero means "nothing is running" —
  /// this used to be seeded to 8, which is why a parent saw "8 min to
  /// school" before any driver had started anything.
  final etaMinutes = ValueNotifier<int>(0);

  /// Metres still to drive along the route, or null before the first fix.
  final distanceMeters = ValueNotifier<double?>(null);

  final isLive = ValueNotifier<bool>(false);
  final isSimulating = ValueNotifier<bool>(false);

  /// True while this device is publishing its position for parents to watch.
  final isBroadcasting = ValueNotifier<bool>(false);

  /// Bumped only when a stop's [StopStatus] actually transitions — never on
  /// every 150 ms tick. The map layer listens to this (not the 6.7 Hz
  /// position ticks) to know when to touch the 6 static stop annotations,
  /// which only need redrawing a handful of times per route, not 6.7×/sec.
  final stopStatusRevision = ValueNotifier<int>(0);

  /// Bumped whenever *any* live figure a dashboard shows has moved: stop
  /// progress, ETA, distance or average speed. One listenable a summary
  /// card can watch, instead of picking whichever notifier happened to tick
  /// often enough — which is how the dashboard ended up listening to
  /// [etaMinutes] alone and freezing its progress bar on a real trip, where
  /// that value changes only every minute or so.
  final liveRevision = ValueNotifier<int>(0);

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

  /// Formatted remaining distance, e.g. `3.4 km` / `850 m`, or null when
  /// there is nothing to measure yet.
  String? get distanceLabel => formatDistance(distanceMeters.value);

  Timer? _simTimer;
  StreamSubscription<Position>? _gpsSub;
  Timer? _publishTimer;
  String? _broadcastBusId;
  String? _broadcastDriverId;
  String? _broadcastTripId;
  int _waypointIndex = 0;
  final _rand = Random();
  // Whether the service is currently paused (off-screen).
  bool _paused = false;
  // Remembers whether simulation was running before pause.
  bool _wasSimulating = false;

  // ── Live figures ──────────────────────────────────────────────────────────

  /// How many recent fixes the rolling average spans. Six fixes at the
  /// default distance filter is roughly the last minute of driving — long
  /// enough to ride out a red light, short enough to react to the van
  /// actually slowing down.
  static const int _speedWindow = 6;
  final List<int> _recentSpeeds = [];

  /// `_cumulative[i]` is the distance in metres from polyline point `i` to
  /// the end of the route. Built once per route rather than re-summed on
  /// every fix.
  List<double> _cumulative = const [];

  /// How far along [_cumulative] the bus has been matched. Kept so the
  /// match only ever moves forward: a route that doubles back past an
  /// earlier street would otherwise snap the remaining distance back up by
  /// a kilometre each time the bus passed it.
  int _progressIndex = 0;

  /// The last duration Google's Routes API gave for the drive still ahead,
  /// and when it arrived. Road-aware — it knows about the one-way system
  /// and the traffic the straight-line estimate never will. Treated as
  /// authoritative while it is fresh, and carried forward between refreshes
  /// by subtracting elapsed time.
  int? _apiEtaSeconds;
  DateTime? _apiEtaAt;

  /// Beyond this the API figure is too old to extrapolate from and the
  /// geometric estimate takes over. The route screen refreshes every 8 s,
  /// so reaching this means the network has been gone for a while.
  static const Duration _apiEtaMaxAge = Duration(minutes: 2);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Initialise with a route and start tracking it.
  ///
  /// Real GPS is the default now. A driver who taps **Start Route** is on the
  /// road, so interpolating a fake bus along the polyline — what this used to
  /// do unconditionally — showed every parent a vehicle that was not where
  /// the van actually was. Simulation is still the fallback for when the
  /// device refuses to give a fix (permission denied, location services off,
  /// emulator), and still what the on-screen toggle switches back to.
  ///
  /// Returns true when real GPS took over, false when it fell back to the
  /// simulation, so the caller can say so.
  Future<bool> start(RouteData route, {bool preferLive = true}) async {
    _route = route;
    _waypointIndex = 0;
    _progressIndex = 0;
    _recentSpeeds.clear();
    _apiEtaSeconds = null;
    _apiEtaAt = null;
    _buildCumulativeDistances(route);
    if (route.polylinePoints.isNotEmpty) {
      busPosition.value = route.polylinePoints.first;
    }
    // Show the whole route's length straight away rather than a dash until
    // the first GPS fix lands, which on a cold start can be 20 seconds.
    distanceMeters.value = _cumulative.isEmpty ? null : _cumulative.first;
    _updateEta();
    if (preferLive && await _startLive()) return true;
    _startSimulation();
    return false;
  }

  /// Call from widget dispose, or when a real trip actually ends.
  ///
  /// Clears [_route] (not just the timers) so [route] goes back to null —
  /// otherwise a screen that reads it after the ride ends would keep showing
  /// the last trip's stops and polyline forever, which is exactly the kind
  /// of stale-mock-data bug this null contract exists to prevent.
  void stop() {
    stopBroadcast();
    _simTimer?.cancel();
    _simTimer = null;
    _gpsSub?.cancel();
    _gpsSub = null;
    isSimulating.value = false;
    isLive.value = false;
    _paused = false;
    _route = null;
    _waypointIndex = 0;
    _progressIndex = 0;
    _cumulative = const [];
    _recentSpeeds.clear();
    _apiEtaSeconds = null;
    _apiEtaAt = null;
    // Every live figure describes a trip that is over. Leaving the last
    // ones on screen is how "8 min to school" outlived the ride that
    // produced it.
    speed.value = 0;
    avgSpeed.value = 0;
    etaMinutes.value = 0;
    distanceMeters.value = null;
    liveRevision.value++;
  }

  /// [stop], for a caller that is inside `State.dispose()`.
  ///
  /// [stop] writes to half a dozen notifiers, and other screens are
  /// listening to them — the dashboard's live cards watch [liveRevision].
  /// Flutter locks the element tree while it is tearing a widget down, and
  /// marking another mounted builder as needing build during that throws
  /// *"setState() or markNeedsBuild() called when widget tree was locked"*.
  /// Leaving the Route tab with no trip running did exactly that.
  ///
  /// A microtask runs once the frame's synchronous work has finished and the
  /// tree is unlocked again. Nothing observable changes: the trip being torn
  /// down is already over, and the screen that asked is already gone.
  ///
  /// [stop] itself stays synchronous — `_endRoute` needs the figures cleared
  /// the moment the driver taps the button, and a test needs to read them on
  /// the next line.
  void stopAfterFrame() {
    scheduleMicrotask(stop);
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
      await _startLive();
    }
  }

  /// Subscribes to the device's real position. Returns false (leaving
  /// [isLive] false) when the fix can't be had — denied permission, location
  /// services switched off — so the caller decides what to do instead.
  Future<bool> _startLive() async {
    final ok = await ensureLocationPermission();
    if (!ok) return false;

    _simTimer?.cancel();
    _simTimer = null;
    isSimulating.value = false;
    isLive.value = true;

    await _gpsSub?.cancel();
    _gpsSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: AppConfig.locationDistanceFilterMeters,
          ),
        ).listen((pos) {
          final here = GeoCoord(pos.latitude, pos.longitude);
          busPosition.value = here;
          // `Position.heading` is -1 when the device can't determine a
          // course (stationary, or no compass fix) — keep the last known
          // bearing rather than snapping the bus marker to due north.
          if (pos.heading >= 0) busHeading.value = pos.heading;
          // Geolocator reports metres per second. This was assigned straight
          // into a field rendered as "km/h", so a van doing 50 km/h showed
          // as 14 — and published that number to every parent's screen.
          _recordSpeed((pos.speed * 3.6).round().clamp(0, 200));

          // Stop progress, distance and ETA used to advance only while the
          // *simulation* ticked, so on a real trip every stop stayed
          // "upcoming" and the ETA stayed on its seed value from the first
          // metre to the last.
          _updateProgress(here);
          _updateStopStatuses(here);
          _updateEta();
        });
    return true;
  }

  /// Records an instantaneous speed and republishes the rolling average.
  void _recordSpeed(int kmh) {
    speed.value = kmh;
    _recentSpeeds.add(kmh);
    if (_recentSpeeds.length > _speedWindow) _recentSpeeds.removeAt(0);
    final sum = _recentSpeeds.fold<int>(0, (a, b) => a + b);
    avgSpeed.value = (sum / _recentSpeeds.length).round();
  }

  // ── Broadcast (driver → parents, over RTDB) ──────────────────────────────

  /// Publishes [busPosition] to `liveLocations/{busId}` every
  /// [AppConfig.locationPublishInterval] until [stopBroadcast].
  ///
  /// Lives here, next to the position itself, so the route screen and the
  /// dashboard's sharing toggle drive one timer between them instead of two
  /// writing the same node on separate schedules.
  Future<void> startBroadcast({
    required String busId,
    required String driverId,
    String? tripId,
  }) async {
    if (_broadcastBusId == busId && _publishTimer != null) return;
    await stopBroadcast();

    _broadcastBusId = busId;
    _broadcastDriverId = driverId;
    _broadcastTripId = tripId;
    isBroadcasting.value = true;

    // Server-side cleanup, so a killed app doesn't leave a ghost bus parked
    // on every parent's map.
    await LiveLocationRepository.instance.armDisconnectCleanup(busId);
    await _publishOnce();
    _publishTimer = Timer.periodic(
      AppConfig.locationPublishInterval,
      (_) => _publishOnce(),
    );
  }

  Future<void> stopBroadcast() async {
    _publishTimer?.cancel();
    _publishTimer = null;
    final busId = _broadcastBusId;
    _broadcastBusId = null;
    _broadcastDriverId = null;
    _broadcastTripId = null;
    isBroadcasting.value = false;
    if (busId == null) return;
    await LiveLocationRepository.instance.clear(busId);
    await LiveLocationRepository.instance.cancelDisconnectCleanup(busId);
  }

  Future<void> _publishOnce() async {
    final busId = _broadcastBusId;
    final driverId = _broadcastDriverId;
    if (busId == null || driverId == null) return;
    final p = busPosition.value;
    try {
      await LiveLocationRepository.instance.publish(
        LiveLocation(
          busId: busId,
          lat: p.lat,
          lng: p.lng,
          heading: busHeading.value,
          speedKmh: speed.value.toDouble(),
          tripId: _broadcastTripId,
          driverId: driverId,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (_) {
      // One dropped ping is not worth tearing the trip down for — the next
      // tick is 5 seconds away, and `LiveLocation.isStale` already covers a
      // gap on the watching end.
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
        _progressIndex = 0;
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
      _recordSpeed(30 + _rand.nextInt(15));

      // The simulation knows exactly where it is on the polyline, so it
      // sets the progress index directly instead of re-deriving it by
      // proximity the way a real fix has to.
      _progressIndex = _waypointIndex;
      distanceMeters.value = _remainingFromIndex(_waypointIndex);
      _updateStopStatuses(next);
      _updateEta();
    });
  }

  // ── Progress along the route ─────────────────────────────────────────────

  /// Precomputes "metres from point i to the end" for every polyline point.
  void _buildCumulativeDistances(RouteData route) {
    final pts = route.polylinePoints;
    if (pts.length < 2) {
      _cumulative = pts.isEmpty ? const [] : <double>[0];
      return;
    }
    final out = List<double>.filled(pts.length, 0);
    for (int i = pts.length - 2; i >= 0; i--) {
      out[i] = out[i + 1] + _distanceBetween(pts[i], pts[i + 1]);
    }
    _cumulative = out;
  }

  double? _remainingFromIndex(int index) {
    if (_cumulative.isEmpty) return null;
    return _cumulative[index.clamp(0, _cumulative.length - 1)];
  }

  /// Matches a real GPS fix onto the route and updates [distanceMeters].
  ///
  /// Only ever moves forward, and only searches a window ahead of where the
  /// bus already was, so a route that passes the same junction twice does
  /// not teleport the remaining distance back to the start.
  void _updateProgress(GeoCoord here) {
    final pts = _route?.polylinePoints ?? const <GeoCoord>[];
    if (pts.isEmpty || _cumulative.isEmpty) return;

    // Generous enough to survive a lost signal through an underpass without
    // letting the match jump to a far-away part of the same road.
    const windowPoints = 40;
    final end = min(pts.length - 1, _progressIndex + windowPoints);

    var bestIndex = _progressIndex;
    var bestDistance = double.infinity;
    for (int i = _progressIndex; i <= end; i++) {
      final d = _distanceBetween(here, pts[i]);
      if (d < bestDistance) {
        bestDistance = d;
        bestIndex = i;
      }
    }

    // More than a kilometre from everything in the window means the van is
    // not on this stretch at all — a detour, or a long gap with no fix.
    // Re-match against the entire route rather than pinning the bus to
    // whichever window point happened to be least wrong.
    if (bestDistance > 1000) {
      for (int i = 0; i < pts.length; i++) {
        final d = _distanceBetween(here, pts[i]);
        if (d < bestDistance) {
          bestDistance = d;
          bestIndex = i;
        }
      }
    }

    _progressIndex = bestIndex;
    final along = _remainingFromIndex(bestIndex);
    if (along == null) return;
    // Off-route distance counts too: a van 300 m down the wrong street
    // still has those 300 m to drive back.
    distanceMeters.value = along + (bestDistance > 60 ? bestDistance : 0);
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
    if (changed) {
      stopStatusRevision.value++;
      liveRevision.value++;
    }
  }

  /// Back to "nothing visited yet" — first stop current, last the
  /// destination, everything between upcoming.
  ///
  /// This used to mark indices 0-2 completed and index 3 current no matter
  /// what, a leftover from the six-stop demo route: on a real round with
  /// four children it reported three of them already picked up before the
  /// van had moved.
  void _resetStopStatuses() {
    final r = _route;
    if (r == null) return;
    final last = r.stops.length - 1;
    for (int i = 0; i < r.stops.length; i++) {
      r.stops[i].status = i == last
          ? StopStatus.destination
          : (i == 0 ? StopStatus.current : StopStatus.upcoming);
    }
    stopStatusRevision.value++;
    liveRevision.value++;
  }

  /// Hands the service a road-aware distance and duration from the Routes
  /// API, as the route screen refreshes it.
  ///
  /// Preferred over the geometric estimate for as long as it stays fresh:
  /// Google knows the traffic and the one-way system, and dividing
  /// along-the-polyline metres by an average speed does not. [_updateEta]
  /// extrapolates from it between refreshes, so the minutes count down
  /// smoothly rather than holding still and then jumping.
  void applyRouteEstimate({required double meters, required int seconds}) {
    if (_route == null) return;
    if (meters.isFinite && meters >= 0) distanceMeters.value = meters;
    if (seconds > 0) {
      _apiEtaSeconds = seconds;
      _apiEtaAt = DateTime.now();
    }
    _updateEta();
  }

  void _updateEta() {
    final r = _route;
    if (r == null) {
      if (etaMinutes.value != 0) {
        etaMinutes.value = 0;
        liveRevision.value++;
      }
      return;
    }

    final next = _computeEtaMinutes();
    if (next != etaMinutes.value) etaMinutes.value = next;
    // Distance and average speed move on nearly every fix even when the
    // minute figure does not, and the cards showing them need the bump too.
    liveRevision.value++;
  }

  int _computeEtaMinutes() {
    // 1. A fresh Routes API duration, aged by however long ago it arrived.
    final apiSeconds = _apiEtaSeconds;
    final apiAt = _apiEtaAt;
    if (apiSeconds != null && apiAt != null) {
      final age = DateTime.now().difference(apiAt);
      if (age < _apiEtaMaxAge) {
        final left = apiSeconds - age.inSeconds;
        return (left / 60).ceil().clamp(0, 600);
      }
    }

    // 2. Otherwise: remaining metres ÷ a speed we actually believe.
    final metres = distanceMeters.value;
    if (metres == null) return 0;
    if (metres < 80) return 0;

    // A stopped van is not an infinite ETA — it is at a light, or loading a
    // child. The floor is a slow-city-traffic figure; the ceiling keeps one
    // bad GPS spike from reporting the school as thirty seconds away.
    final moving = _recentSpeeds.where((s) => s > 3).toList();
    final kmh = moving.isEmpty
        ? 22.0
        : (moving.fold<int>(0, (a, b) => a + b) / moving.length).clamp(
            8.0,
            70.0,
          );
    final minutes = (metres / 1000) / kmh * 60;
    return minutes.ceil().clamp(1, 600);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// `3.4 km` / `850 m`, or null for null. Top-level-ish so the widget tests
  /// and the route screen can both format the same way.
  static String? formatDistance(double? metres) {
    if (metres == null) return null;
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }

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
      liveRevision.value++;
    }
  }
}
