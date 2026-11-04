import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart' hide StopStatus;
import 'package:transit_pro/app/driver_performance.dart';
import 'package:transit_pro/app/tracking_service.dart';
import 'package:transit_pro/models/route_data.dart';

/// A short straight route through Lahore: roughly 1 km of polyline with a
/// stop at each end.
RouteData _route() {
  const a = GeoCoord(31.5204, 74.3587);
  const b = GeoCoord(31.5294, 74.3587); // ~1 km due north
  return RouteData(
    id: 'r1',
    name: 'Morning round',
    busNumber: 'LHR-1',
    driverName: 'Test driver',
    stops: [
      StopData(name: 'Home', location: a, scheduledTime: '07:00 AM'),
      StopData(
        name: 'School',
        location: b,
        scheduledTime: '07:30 AM',
        status: StopStatus.destination,
      ),
    ],
    polylinePoints: const [
      a,
      GeoCoord(31.5234, 74.3587),
      GeoCoord(31.5264, 74.3587),
      b,
    ],
  );
}

void main() {
  final tracking = TrackingService.instance;

  tearDown(tracking.stop);

  group('live figures', () {
    test('nothing is running: every figure reads empty, not a seed value', () {
      // The seeds used to be `etaMinutes = 8` and `speed = 35`, which is
      // where a parent's "8 min to school" came from before any driver had
      // started anything.
      tracking.stop();
      expect(tracking.etaMinutes.value, 0);
      expect(tracking.speed.value, 0);
      expect(tracking.avgSpeed.value, 0);
      expect(tracking.distanceMeters.value, isNull);
      expect(tracking.distanceLabel, isNull);
    });

    test('starting a route measures the whole route up front', () async {
      await tracking.start(_route(), preferLive: false);
      final metres = tracking.distanceMeters.value;
      expect(metres, isNotNull);
      // ~1 km of polyline; generous bounds, this is checking it measured
      // the route rather than guessing.
      expect(metres, greaterThan(800));
      expect(metres, lessThan(1200));
    });

    test('a Routes API duration becomes the ETA', () async {
      await tracking.start(_route(), preferLive: false);
      tracking.applyRouteEstimate(meters: 4200, seconds: 600);
      expect(tracking.etaMinutes.value, 10);
      expect(tracking.distanceLabel, '4.2 km');
    });

    test('with no API figure the ETA comes from distance and speed', () async {
      await tracking.start(_route(), preferLive: false);
      // No `applyRouteEstimate`, so this falls through to metres ÷ speed.
      // The simulation has not ticked yet, so it uses the 22 km/h default:
      // 1 km at 22 km/h is just under three minutes.
      final eta = tracking.etaMinutes.value;
      expect(eta, greaterThan(0));
      expect(eta, lessThan(10));
    });

    test('ending a route clears the figures it produced', () async {
      await tracking.start(_route(), preferLive: false);
      tracking.applyRouteEstimate(meters: 4200, seconds: 600);
      expect(tracking.etaMinutes.value, 10);

      tracking.stop();
      expect(tracking.route, isNull);
      expect(tracking.etaMinutes.value, 0);
      expect(tracking.distanceMeters.value, isNull);
      expect(tracking.avgSpeed.value, 0);
    });

    test('an estimate for a trip that is not running is ignored', () {
      tracking.stop();
      tracking.applyRouteEstimate(meters: 4200, seconds: 600);
      expect(tracking.etaMinutes.value, 0);
      expect(tracking.distanceMeters.value, isNull);
    });

    test('liveRevision moves when a figure does', () async {
      await tracking.start(_route(), preferLive: false);
      final before = tracking.liveRevision.value;
      tracking.applyRouteEstimate(meters: 3000, seconds: 420);
      expect(tracking.liveRevision.value, greaterThan(before));
    });
  });

  group('distance formatting', () {
    test('under a kilometre reads in metres', () {
      expect(TrackingService.formatDistance(850), '850 m');
    });
    test('over a kilometre reads in kilometres, one decimal', () {
      expect(TrackingService.formatDistance(4249), '4.2 km');
    });
    test('null stays null, so the card can show a dash', () {
      expect(TrackingService.formatDistance(null), isNull);
    });
  });

  group('performance scores', () {
    Trip trip(TripStatus status, {bool? onTime}) => Trip(
      id: 't',
      routeId: 'r',
      driverId: 'd',
      busId: 'b',
      dateKey: '2026-11-01',
      status: status,
      onTime: onTime,
    );

    DriverRating rating(double value) => DriverRating(
      id: 'x',
      driverId: 'd',
      raterId: 'p',
      rating: value,
      weekKey: '2026-W44',
    );

    test('a driver with no history scores nothing at all', () {
      final s = computeDriverScores(
        trips: const [],
        ratings: const [],
        incidents: const [],
      );
      expect(s.satisfaction, isNull);
      expect(s.compliance, isNull);
      expect(s.safety, isNull);
      expect(s.onTime, isNull);
      // The number the big circle shows. 96 was hardcoded here.
      expect(s.overall, isNull);
      expect(s.label, 'No data available');
    });

    test('satisfaction is the families\' own average, not a constant', () {
      final s = computeDriverScores(
        trips: [trip(TripStatus.completed, onTime: true)],
        ratings: [rating(4), rating(5)],
        incidents: const [],
      );
      expect(s.satisfaction, closeTo(0.9, 0.0001));
    });

    test('an abandoned round costs route compliance', () {
      final s = computeDriverScores(
        trips: [
          trip(TripStatus.completed, onTime: true),
          trip(TripStatus.completed, onTime: false),
          trip(TripStatus.cancelled),
        ],
        ratings: const [],
        incidents: const [],
      );
      expect(s.compliance, closeTo(2 / 3, 0.0001));
      expect(s.onTime, closeTo(0.5, 0.0001));
    });

    test('an SOS costs the safe-driving score', () {
      final trips = [
        trip(TripStatus.completed, onTime: true),
        trip(TripStatus.completed, onTime: true),
      ];
      final clean = computeDriverScores(
        trips: trips,
        ratings: const [],
        incidents: const [],
      );
      expect(clean.safety, 1.0);

      final afterSos = computeDriverScores(
        trips: trips,
        ratings: const [],
        incidents: [
          Incident(id: 'i', severity: IncidentSeverity.high, title: 'SOS'),
        ],
      );
      expect(afterSos.safety, closeTo(0.5, 0.0001));
    });

    test('the overall score averages only the parts that exist', () {
      // On-time and compliance only — no ratings, no incidents possible
      // without trips to compare against is not the case here, so safety
      // counts too.
      final s = computeDriverScores(
        trips: [trip(TripStatus.completed, onTime: true)],
        ratings: const [],
        incidents: const [],
      );
      // compliance 1.0, safety 1.0, onTime 1.0, satisfaction absent.
      expect(s.overall, 100);
      expect(s.label, 'Excellent performance');
    });

    test('a weak record gets a label that says so', () {
      final s = computeDriverScores(
        trips: [
          trip(TripStatus.completed, onTime: false),
          trip(TripStatus.cancelled),
        ],
        ratings: [rating(2)],
        incidents: const [],
      );
      expect(s.overall, lessThan(60));
      expect(s.label, 'Needs attention');
    });
  });
}
