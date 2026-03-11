import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Status of a stop along a route.
enum StopStatus { completed, current, upcoming, destination }

/// A single stop on a bus route.
class StopData {
  final String name;
  final LatLng location;
  final String scheduledTime;
  final int studentCount;
  final String? note;
  StopStatus status;

  StopData({
    required this.name,
    required this.location,
    required this.scheduledTime,
    this.studentCount = 0,
    this.note,
    this.status = StopStatus.upcoming,
  });
}

/// Full route definition with all stops and metadata.
class RouteData {
  final String id;
  final String name;
  final String busNumber;
  final String driverName;
  final List<StopData> stops;
  final List<LatLng> polylinePoints;

  const RouteData({
    required this.id,
    required this.name,
    required this.busNumber,
    required this.driverName,
    required this.stops,
    this.polylinePoints = const [],
  });

  int get completedStops =>
      stops.where((s) => s.status == StopStatus.completed).length;

  StopData? get currentStop =>
      stops.where((s) => s.status == StopStatus.current).firstOrNull;

  StopData? get nextStop =>
      stops.where((s) => s.status == StopStatus.upcoming).firstOrNull;
}

/// Holds all mock data for a single simulated route in Lahore.
class MockRouteBuilder {
  static RouteData buildMorningRoute() {
    final stops = [
      StopData(
        name: 'Bus Depot',
        location: const LatLng(31.5204, 74.3587),
        scheduledTime: '06:55 AM',
        studentCount: 0,
        note: 'Departure point',
        status: StopStatus.completed,
      ),
      StopData(
        name: 'Oak Street',
        location: const LatLng(31.5230, 74.3520),
        scheduledTime: '07:15 AM',
        studentCount: 3,
        note: '3 students picked up',
        status: StopStatus.completed,
      ),
      StopData(
        name: 'Maple Avenue',
        location: const LatLng(31.5265, 74.3460),
        scheduledTime: '07:22 AM',
        studentCount: 3,
        note: '3 students picked up',
        status: StopStatus.completed,
      ),
      StopData(
        name: 'Pine Road',
        location: const LatLng(31.5300, 74.3410),
        scheduledTime: '07:30 AM',
        studentCount: 2,
        note: 'Approaching',
        status: StopStatus.current,
      ),
      StopData(
        name: 'Cedar Blvd',
        location: const LatLng(31.5340, 74.3350),
        scheduledTime: '07:37 AM',
        studentCount: 4,
        note: '4 students waiting',
        status: StopStatus.upcoming,
      ),
      StopData(
        name: 'Lincoln Elementary',
        location: const LatLng(31.5380, 74.3290),
        scheduledTime: '07:45 AM',
        studentCount: 0,
        note: 'Drop-off point',
        status: StopStatus.destination,
      ),
    ];

    return RouteData(
      id: 'route_a',
      name: 'Route A · Morning Run',
      busNumber: 'Bus #42',
      driverName: 'Mike Johnson',
      stops: stops,
      polylinePoints: _morningWaypoints,
    );
  }

  /// 82 waypoints that follow a realistic Lahore street grid:
  ///   Depot → north → west (Oak St) → north → west (Maple) →
  ///   north → west (Pine Rd) → north → west (Cedar Blvd) →
  ///   north → west → school.
  /// Street-aligned segments give proper turning corners.
  static const _morningWaypoints = [
    // ── Segment A: North from depot ──────────────────────────────────────
    LatLng(31.5204, 74.3587),
    LatLng(31.5208, 74.3586),
    LatLng(31.5212, 74.3585),
    LatLng(31.5216, 74.3584),
    LatLng(31.5220, 74.3583),
    LatLng(31.5225, 74.3582),
    LatLng(31.5230, 74.3581),
    // ── Corner: turning west ─────────────────────────────────────────────
    LatLng(31.5231, 74.3572),
    LatLng(31.5231, 74.3562),
    LatLng(31.5231, 74.3552),
    LatLng(31.5231, 74.3542),
    LatLng(31.5231, 74.3532),
    LatLng(31.5230, 74.3520), // ★ Oak Street stop
    // ── Segment C: North from Oak latitude ───────────────────────────────
    LatLng(31.5235, 74.3520),
    LatLng(31.5240, 74.3520),
    LatLng(31.5245, 74.3520),
    LatLng(31.5250, 74.3520),
    LatLng(31.5255, 74.3520),
    LatLng(31.5260, 74.3520),
    LatLng(31.5265, 74.3520),
    // ── Corner: turning west ─────────────────────────────────────────────
    LatLng(31.5265, 74.3512),
    LatLng(31.5265, 74.3503),
    LatLng(31.5265, 74.3494),
    LatLng(31.5265, 74.3485),
    LatLng(31.5265, 74.3475),
    LatLng(31.5265, 74.3466),
    LatLng(31.5265, 74.3460), // ★ Maple Avenue stop
    // ── Segment E: North from Maple latitude ─────────────────────────────
    LatLng(31.5270, 74.3460),
    LatLng(31.5275, 74.3460),
    LatLng(31.5280, 74.3460),
    LatLng(31.5285, 74.3460),
    LatLng(31.5290, 74.3460),
    LatLng(31.5295, 74.3460),
    LatLng(31.5300, 74.3460),
    // ── Corner: turning west ─────────────────────────────────────────────
    LatLng(31.5300, 74.3452),
    LatLng(31.5300, 74.3444),
    LatLng(31.5300, 74.3436),
    LatLng(31.5300, 74.3428),
    LatLng(31.5300, 74.3419),
    LatLng(31.5300, 74.3410), // ★ Pine Road stop
    // ── Segment G: North from Pine latitude ──────────────────────────────
    LatLng(31.5305, 74.3410),
    LatLng(31.5310, 74.3410),
    LatLng(31.5315, 74.3410),
    LatLng(31.5320, 74.3410),
    LatLng(31.5325, 74.3410),
    LatLng(31.5330, 74.3410),
    LatLng(31.5335, 74.3410),
    LatLng(31.5340, 74.3410),
    // ── Corner: turning west ─────────────────────────────────────────────
    LatLng(31.5340, 74.3402),
    LatLng(31.5340, 74.3394),
    LatLng(31.5340, 74.3386),
    LatLng(31.5340, 74.3378),
    LatLng(31.5340, 74.3370),
    LatLng(31.5340, 74.3362),
    LatLng(31.5340, 74.3354),
    LatLng(31.5340, 74.3350), // ★ Cedar Blvd stop
    // ── Segment I: North from Cedar latitude ─────────────────────────────
    LatLng(31.5345, 74.3350),
    LatLng(31.5350, 74.3350),
    LatLng(31.5355, 74.3350),
    LatLng(31.5360, 74.3350),
    LatLng(31.5365, 74.3350),
    LatLng(31.5370, 74.3350),
    LatLng(31.5375, 74.3350),
    LatLng(31.5380, 74.3350),
    // ── Final corner: turning west to school ─────────────────────────────
    LatLng(31.5380, 74.3343),
    LatLng(31.5380, 74.3335),
    LatLng(31.5380, 74.3327),
    LatLng(31.5380, 74.3319),
    LatLng(31.5380, 74.3311),
    LatLng(31.5380, 74.3303),
    LatLng(31.5380, 74.3295),
    LatLng(31.5380, 74.3290), // ★ Lincoln Elementary
  ];
}
