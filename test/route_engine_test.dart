import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_pro/app/location_fix.dart';
import 'package:transit_pro/app/route_optimization_service.dart';
import 'package:transit_pro/map/geo_utils.dart';

/// Answers like Google: given the request body, returns one route whose
/// legs are straight lines, reordering intermediates south-to-north when
/// asked to optimise — a stand-in that is deterministic and checkable.
class FakeTransport implements RoutesTransport {
  final bodies = <Map<String, dynamic>>[];
  Object? failWith;

  @override
  Future<Map<String, dynamic>> compute(Map<String, dynamic> body) async {
    bodies.add(body);
    if (failWith != null) throw failWith!;
    GeoCoord at(Map<String, dynamic> w) {
      final ll = (w['location'] as Map)['latLng'] as Map;
      return GeoCoord(ll['latitude'] as double, ll['longitude'] as double);
    }

    final origin = at(body['origin'] as Map<String, dynamic>);
    final dest = at(body['destination'] as Map<String, dynamic>);
    final mids = [
      for (final w in (body['intermediates'] as List? ?? const []))
        at(w as Map<String, dynamic>),
    ];
    var order = [for (var i = 0; i < mids.length; i++) i];
    if (body['optimizeWaypointOrder'] == true) {
      order.sort((a, b) => mids[a].lat.compareTo(mids[b].lat));
    }
    final path = [origin, for (final i in order) mids[i], dest];
    return {
      'routes': [
        {
          if (body['optimizeWaypointOrder'] == true)
            'optimizedIntermediateWaypointIndex': order,
          'legs': [
            for (var i = 0; i + 1 < path.length; i++)
              {
                'distanceMeters': GeoUtils.distance(
                  path[i],
                  path[i + 1],
                ).round(),
                'duration':
                    '${(GeoUtils.distance(path[i], path[i + 1]) / 8).round()}s',
                'polyline': {
                  'encodedPolyline': GeoUtils.encodePolyline([
                    path[i],
                    path[i + 1],
                  ]),
                },
              },
          ],
        },
      ],
    };
  }
}

void main() {
  group('GeoUtils', () {
    test('encodes and decodes Google polylines losslessly to 1e-5', () {
      const pts = [
        GeoCoord(31.52040, 74.35870),
        GeoCoord(31.52311, 74.35202),
        GeoCoord(31.48150, 74.30300),
      ];
      final back = GeoUtils.decodePolyline(GeoUtils.encodePolyline(pts));
      expect(back, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(back[i].lat, closeTo(pts[i].lat, 1e-5));
        expect(back[i].lng, closeTo(pts[i].lng, 1e-5));
      }
      // Google's own documented example.
      final g = GeoUtils.decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(g.first.lat, closeTo(38.5, 1e-5));
      expect(g.last.lng, closeTo(-126.453, 1e-5));
    });

    test('projects a point onto the nearest segment', () {
      const line = [GeoCoord(31.5000, 74.3000), GeoCoord(31.5000, 74.3100)];
      // ~55 m north of the middle of an east-west segment.
      final p = GeoUtils.project(const GeoCoord(31.5005, 74.3050), line)!;
      expect(p.segment, 0);
      expect(p.offsetMeters, closeTo(55, 3));
      expect(p.alongMeters, closeTo(GeoUtils.length(line) / 2, 5));
      expect(GeoUtils.ahead(line, p).first.lat, closeTo(31.5, 1e-9));
      expect(GeoUtils.behind(line, p), hasLength(2));
    });

    test('turns the short way round', () {
      expect(GeoUtils.lerpAngle(350, 10, 0.5), closeTo(0, 1e-9));
      expect(GeoUtils.lerpAngle(10, 350, 0.5), closeTo(0, 1e-9));
    });
  });

  group('Routes API request', () {
    test('asks for exactly what the brief asks for', () {
      final body = GoogleRouteOptimizer.requestBody(
        origin: const GeoCoord(31.47, 74.27),
        destination: const GeoCoord(31.48, 74.30),
        stops: const [
          PlanStop('a', GeoCoord(31.475, 74.28)),
          PlanStop('b', GeoCoord(31.472, 74.274)),
        ],
        optimize: true,
      );
      expect(body['travelMode'], 'DRIVE');
      expect(body['routingPreference'], 'TRAFFIC_AWARE');
      expect(body['optimizeWaypointOrder'], isTrue);
      final first = (body['intermediates'] as List).first as Map;
      expect(first['vehicleStopover'], isTrue);
      expect(first['sideOfRoad'], isTrue);
      expect(routesFieldMask, contains('optimizedIntermediateWaypointIndex'));
      expect(routesFieldMask, contains('routes.legs.polyline.encodedPolyline'));
    });

    test("Google's reordering becomes the stop order", () {
      final r = GoogleRouteOptimizer.parseResponse(
        {
          'routes': [
            {
              'optimizedIntermediateWaypointIndex': [1, 0],
              'legs': [
                {'distanceMeters': 100, 'duration': '20s'},
                {'distanceMeters': 200, 'duration': '40s'},
                {'distanceMeters': 300, 'duration': '60s'},
              ],
            },
          ],
        },
        origin: const GeoCoord(0, 0),
        destination: const GeoCoord(0, 0.003),
        stops: const [
          PlanStop('A', GeoCoord(0, 0.002)),
          PlanStop('B', GeoCoord(0, 0.001)),
        ],
      );
      expect(r.order, ['B', 'A']);
      expect(r.legs.map((l) => l.seconds), [20, 40, 60]);
      expect(r.totalMeters, 600);
    });
  });

  group('GoogleRouteOptimizer', () {
    late FakeTransport transport;
    late GoogleRouteOptimizer optimizer;
    setUp(() {
      transport = FakeTransport();
      optimizer = GoogleRouteOptimizer(transport);
    });

    test('more than 25 stops are split, every stop kept once', () async {
      final stops = [
        for (var i = 0; i < 30; i++)
          PlanStop('s$i', GeoCoord(31.40 + i * 0.002, 74.30)),
      ];
      final r = await optimizer.plan(
        origin: const GeoCoord(31.39, 74.30),
        destination: const GeoCoord(31.50, 74.30),
        stops: stops,
      );
      expect(transport.bodies.length, 2);
      for (final b in transport.bodies) {
        expect((b['intermediates'] as List).length, lessThanOrEqualTo(25));
      }
      expect(r.order.toSet(), {for (final s in stops) s.id});
      expect(r.order, hasLength(30));
      expect(r.legs, hasLength(31));
      expect(r.approximate, isFalse);
    });

    test('a drop run with no depot ends at the best home', () async {
      final r = await optimizer.plan(
        origin: const GeoCoord(31.40, 74.30),
        stops: const [
          PlanStop('far', GeoCoord(31.46, 74.30)),
          PlanStop('near', GeoCoord(31.41, 74.30)),
          PlanStop('mid', GeoCoord(31.43, 74.30)),
        ],
      );
      // Few enough to try each as the end: one request per candidate.
      expect(transport.bodies.length, 3);
      expect(r.order, ['near', 'mid', 'far']);
      expect(r.legs, hasLength(3), reason: 'no separate destination leg');
    });

    test('past five homes it ends at the farthest, in one request', () async {
      final stops = [
        for (var i = 0; i < 7; i++)
          PlanStop('h$i', GeoCoord(31.40 + (i + 1) * 0.01, 74.30)),
      ];
      final r = await optimizer.plan(
        origin: const GeoCoord(31.40, 74.30),
        stops: stops,
      );
      expect(transport.bodies.length, 1);
      expect(r.order.last, 'h6');
    });

    test('Google failing still gives a drivable plan, labelled', () async {
      transport.failWith = const RoutesFailed(429, 'quota');
      final r = await optimizer.plan(
        origin: const GeoCoord(31.40, 74.30),
        destination: const GeoCoord(31.50, 74.30),
        stops: const [
          PlanStop('b', GeoCoord(31.45, 74.30)),
          PlanStop('a', GeoCoord(31.41, 74.30)),
        ],
      );
      expect(r.approximate, isTrue);
      expect(r.warning, isNotNull);
      expect(r.order, ['a', 'b'], reason: 'nearest first');
      expect(r.legs, hasLength(3));
    });

    test('a refresh keeps the order the driver is already following', () async {
      final r = await optimizer.plan(
        origin: const GeoCoord(31.40, 74.30),
        destination: const GeoCoord(31.50, 74.30),
        stops: const [
          PlanStop('b', GeoCoord(31.45, 74.30)),
          PlanStop('a', GeoCoord(31.41, 74.30)),
        ],
        optimize: false,
      );
      expect(
        transport.bodies.single.containsKey('optimizeWaypointOrder'),
        isFalse,
      );
      expect(r.order, ['b', 'a']);
    });
  });

  group('FallbackRoutesTransport', () {
    test('an undeployed backend falls back, and is not asked again', () async {
      final backend = FakeTransport()
        ..failWith = const RoutesUnavailable('404');
      final direct = FakeTransport();
      final t = FallbackRoutesTransport(backend, direct);
      final body = GoogleRouteOptimizer.requestBody(
        origin: const GeoCoord(0, 0),
        destination: const GeoCoord(0, 0.01),
        stops: const [],
        optimize: false,
      );
      await t.compute(body);
      await t.compute(body);
      expect(backend.bodies, hasLength(1));
      expect(direct.bodies, hasLength(2));
    });
  });

  group('FixFilter', () {
    final t0 = DateTime(2026, 11, 9, 7);
    LocationFix fix(double lat, int sec, {double acc = 10}) => LocationFix(
      coord: GeoCoord(lat, 74.30),
      at: t0.add(Duration(seconds: sec)),
      accuracy: acc,
    );

    test('drops fixes worse than 50 m', () {
      final f = FixFilter();
      expect(f.accept(fix(31.4, 0, acc: 80), GeoUtils.distance), isFalse);
      expect(f.accept(fix(31.4, 4, acc: 12), GeoUtils.distance), isTrue);
    });

    test('drops a jump faster than 150 km/h', () {
      final f = FixFilter();
      expect(f.accept(fix(31.4000, 0), GeoUtils.distance), isTrue);
      // ~1.1 km in 4 s is ~1000 km/h.
      expect(f.accept(fix(31.4100, 4), GeoUtils.distance), isFalse);
      // ~44 m in 4 s is ~40 km/h.
      expect(f.accept(fix(31.4004, 4), GeoUtils.distance), isTrue);
    });

    test('a bad reference fix cannot lock tracking out', () {
      final f = FixFilter();
      f.accept(fix(31.4000, 0), GeoUtils.distance);
      var accepted = false;
      for (var i = 1; i <= 6 && !accepted; i++) {
        accepted = f.accept(fix(31.5000, i), GeoUtils.distance);
      }
      expect(accepted, isTrue);
    });

    test('three vague fixes in a row is reported as a weak signal', () {
      final f = FixFilter();
      for (var i = 0; i < 3; i++) {
        f.accept(fix(31.4, i, acc: 90), GeoUtils.distance);
      }
      expect(f.weakSignal, isTrue);
    });
  });

  group('wiring', () {
    String read(String p) => File(p).readAsStringSync();

    test('tracking runs as a foreground service, and survives the screen', () {
      final src = read('lib/app/tracking_service.dart');
      expect(src, contains('ForegroundNotificationConfig('));
      expect(src, contains('allowBackgroundLocationUpdates: true'));
      expect(src, contains('intervalDuration: const Duration(seconds: 4)'));
      expect(
        read('ios/Runner/Info.plist'),
        contains('<string>location</string>'),
      );
    });

    test('the demo-route background service is gone for good', () {
      expect(read('lib/main.dart').contains('MockRouteBuilder'), isFalse);
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest.contains('android:name=".BootReceiver"'), isFalse);
      expect(manifest.contains('android:name=".BusTrackingService"'), isFalse);
      expect(manifest.contains('RECEIVE_BOOT_COMPLETED'), isFalse);
    });

    test('nothing calls the Routes API per GPS fix', () {
      // The trip controller is the only planner, and only on events.
      final tracking = read('lib/app/tracking_service.dart');
      expect(tracking.contains('computeRoutes'), isFalse);
      expect(tracking.contains('RouteOptimizer'), isFalse);
      final route = read('lib/screens/driver/driver_route.dart');
      expect(
        route.contains('Timer.periodic'),
        isFalse,
        reason: 'the 8-second Routes poll is gone',
      );
    });

    test('accuracy is allowed through the live-location rules', () {
      expect(read('database.rules.json'), contains('"accuracy"'));
    });

    test('the backend proxy pins the field mask and checks the role', () {
      final worker = read('push_worker/src/index.js');
      expect(worker, contains("url.pathname === '/routes'"));
      expect(worker, contains("stringField(user, 'role') !== 'driver'"));
      expect(worker, contains('ROUTES_FIELD_MASK'));
      expect(worker, contains('MAX_INTERMEDIATES = 25'));
    });

    test("family screens only ever watch their own child's round", () {
      for (final p in [
        'lib/screens/parent/parent_dashboard.dart',
        'lib/screens/parent/parent_tracking.dart',
        'lib/screens/student/student_dashboard.dart',
        'lib/screens/student/student_tracking.dart',
      ]) {
        final src = read(p);
        expect(src, contains('watchActiveTripForStudent('), reason: p);
        expect(src, isNot(contains('watchActiveTripForDriver(')), reason: p);
      }
      final status = read('lib/app/child_status_service.dart');
      expect(status, contains('running.carries(child.id)'));
      expect(read('lib/app/trip_controller.dart'), contains('riderIds:'));
    });
  });
}
