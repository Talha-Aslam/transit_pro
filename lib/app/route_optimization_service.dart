import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:transit_core/transit_core.dart';

import '../map/geo_utils.dart';

/// A place the van has to visit, before it has a position in the order.
class PlanStop {
  final String id;
  final GeoCoord location;
  const PlanStop(this.id, this.location);
}

/// One driven leg of a planned route.
class PlannedLeg {
  final int meters;
  final int seconds;
  final List<GeoCoord> points;

  const PlannedLeg({
    required this.meters,
    required this.seconds,
    required this.points,
  });
}

/// The answer to "in what order, and along which roads".
///
/// `legs[i]` ends at `order[i]`. When the plan had a fixed destination
/// there is one more leg than stops, ending there; when it did not (a drop
/// run with no depot) the last stop in [order] *is* where the van ends.
class RoutePlanResult {
  final List<String> order;
  final List<PlannedLeg> legs;
  final GeoCoord? destination;

  /// True when Google could not be asked and this is a nearest-neighbour
  /// guess drawn with straight lines.
  final bool approximate;

  /// One sentence for the driver when [approximate] is true.
  final String? warning;

  const RoutePlanResult({
    required this.order,
    required this.legs,
    this.destination,
    this.approximate = false,
    this.warning,
  });

  int get totalMeters => legs.fold(0, (sum, l) => sum + l.meters);
  int get totalSeconds => legs.fold(0, (sum, l) => sum + l.seconds);
}

/// Plans a round. Behind an interface so the Google *Route Optimization*
/// API (many vehicles, time windows) can replace the Routes API later
/// without the trip controller or any screen noticing.
abstract class RouteOptimizer {
  /// [optimize] false keeps [stops] in the order given and only fetches the
  /// roads — what a mid-trip refresh wants, since reordering the stop the
  /// driver is already heading for would turn them around on the spot.
  ///
  /// [destination] null means "end at whichever stop is best".
  Future<RoutePlanResult> plan({
    required GeoCoord origin,
    GeoCoord? destination,
    required List<PlanStop> stops,
    bool optimize = true,
  });

  /// Routes API requests made so far — a running count the controller logs
  /// and the tests hold to a budget.
  int get callCount;
}

/// Thrown when the transport cannot be used at all (not deployed, not
/// configured), as opposed to a request that failed.
class RoutesUnavailable implements Exception {
  final String reason;
  const RoutesUnavailable(this.reason);
  @override
  String toString() => 'RoutesUnavailable: $reason';
}

class RoutesFailed implements Exception {
  final int status;
  final String message;
  const RoutesFailed(this.status, this.message);
  @override
  String toString() => 'RoutesFailed($status): $message';
}

/// How a `computeRoutes` request reaches Google.
abstract class RoutesTransport {
  Future<Map<String, dynamic>> compute(Map<String, dynamic> body);
}

/// The one field mask the app ever sends. Fixed, so the backend proxy can
/// enforce exactly this and nothing more expensive.
const routesFieldMask =
    'routes.optimizedIntermediateWaypointIndex,'
    'routes.polyline.encodedPolyline,'
    'routes.legs.distanceMeters,'
    'routes.legs.duration,'
    'routes.legs.polyline.encodedPolyline,'
    'routes.distanceMeters,'
    'routes.duration';

/// Through the backend: `POST {pushWorkerUrl}/routes`, signed in.
///
/// The Worker holds a server key that never ships in the app, checks the
/// caller is a signed-in driver, and pins the field mask. A Worker that has
/// not been redeployed answers 404, and one with no key configured answers
/// 501 — both mean "use the other transport", not "the route failed".
class WorkerRoutesTransport implements RoutesTransport {
  final String baseUrl;
  WorkerRoutesTransport(this.baseUrl);

  @override
  Future<Map<String, dynamic>> compute(Map<String, dynamic> body) async {
    if (baseUrl.isEmpty) throw const RoutesUnavailable('no worker url');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const RoutesUnavailable('not signed in');
    final token = await user.getIdToken();
    final response = await http
        .post(
          Uri.parse('$baseUrl/routes'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode({'request': body}),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode == 404 || response.statusCode == 501) {
      throw RoutesUnavailable('worker answered ${response.statusCode}');
    }
    if (response.statusCode != 200) {
      throw RoutesFailed(response.statusCode, response.body);
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }
}

/// Straight to Google with the app's own key. The fallback while the
/// Worker's server key is not configured.
class DirectRoutesTransport implements RoutesTransport {
  final String apiKey;
  DirectRoutesTransport(this.apiKey);

  @override
  Future<Map<String, dynamic>> compute(Map<String, dynamic> body) async {
    if (apiKey.isEmpty) throw const RoutesUnavailable('no key');
    final response = await http
        .post(
          Uri.parse(
            'https://routes.googleapis.com/directions/v2:computeRoutes',
          ),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask': routesFieldMask,
          },
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw RoutesFailed(response.statusCode, response.body);
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }
}

/// Tries [primary]; when it says it is unavailable, uses [secondary] and
/// stops asking [primary] for [retryAfter], so an undeployed endpoint costs
/// one failed request per ten minutes rather than one per route.
class FallbackRoutesTransport implements RoutesTransport {
  final RoutesTransport primary;
  final RoutesTransport secondary;
  final Duration retryAfter;
  DateTime? _primaryDownUntil;

  FallbackRoutesTransport(
    this.primary,
    this.secondary, {
    this.retryAfter = const Duration(minutes: 10),
  });

  @override
  Future<Map<String, dynamic>> compute(Map<String, dynamic> body) async {
    final downUntil = _primaryDownUntil;
    if (downUntil == null || DateTime.now().isAfter(downUntil)) {
      try {
        return await primary.compute(body);
      } on RoutesUnavailable catch (e) {
        debugPrint('routes: primary unavailable ($e), using fallback');
        _primaryDownUntil = DateTime.now().add(retryAfter);
      }
    }
    return secondary.compute(body);
  }
}

/// [RouteOptimizer] over the Google Routes API v2 `computeRoutes`.
class GoogleRouteOptimizer implements RouteOptimizer {
  final RoutesTransport transport;

  GoogleRouteOptimizer(this.transport);

  /// The app-wide instance: backend first, the app's key as the fallback.
  static final RouteOptimizer instance = GoogleRouteOptimizer(
    FallbackRoutesTransport(
      WorkerRoutesTransport(AppConfig.pushWorkerUrl),
      DirectRoutesTransport(AppConfig.googleMapsApiKey),
    ),
  );

  /// Google's ceiling on intermediates for one request.
  static const maxIntermediates = 25;

  /// With this few stops and no fixed end, each one is tried as the end and
  /// the quickest kept. Past it, the farthest from the start is used: the
  /// try-every-one approach costs one request per stop.
  static const tryEveryEndUpTo = 5;

  int _calls = 0;

  @override
  int get callCount => _calls;

  @override
  Future<RoutePlanResult> plan({
    required GeoCoord origin,
    GeoCoord? destination,
    required List<PlanStop> stops,
    bool optimize = true,
  }) async {
    if (stops.isEmpty && destination == null) {
      return const RoutePlanResult(order: [], legs: []);
    }
    try {
      if (destination != null) {
        return await _planTo(origin, destination, stops, optimize);
      }
      return await _planOpenEnded(origin, stops, optimize);
    } catch (e) {
      debugPrint('routes: falling back to straight lines — $e');
      return fallbackPlan(
        origin: origin,
        destination: destination,
        stops: stops,
        keepOrder: !optimize,
      );
    }
  }

  /// No fixed end: the drop run with no depot. One of the stops becomes the
  /// destination.
  Future<RoutePlanResult> _planOpenEnded(
    GeoCoord origin,
    List<PlanStop> stops,
    bool optimize,
  ) async {
    if (stops.length == 1 || !optimize) {
      final end = stops.last;
      final rest = stops.sublist(0, stops.length - 1);
      return _endingAt(
        await _planTo(origin, end.location, rest, optimize),
        end,
      );
    }

    final candidates = stops.length <= tryEveryEndUpTo
        ? stops
        : [_farthest(origin, stops)];
    RoutePlanResult? best;
    PlanStop? bestEnd;
    for (final end in candidates) {
      final rest = [
        for (final s in stops)
          if (s.id != end.id) s,
      ];
      final r = await _planTo(origin, end.location, rest, true);
      if (best == null || r.totalSeconds < best.totalSeconds) {
        best = r;
        bestEnd = end;
      }
    }
    return _endingAt(best!, bestEnd!);
  }

  /// Folds the chosen end stop back into the order, so the caller sees one
  /// stop list with no separate destination.
  RoutePlanResult _endingAt(RoutePlanResult r, PlanStop end) => RoutePlanResult(
    order: [...r.order, end.id],
    legs: r.legs,
    approximate: r.approximate,
    warning: r.warning,
  );

  Future<RoutePlanResult> _planTo(
    GeoCoord origin,
    GeoCoord destination,
    List<PlanStop> stops,
    bool optimize,
  ) async {
    if (stops.length <= maxIntermediates) {
      return _request(origin, destination, stops, optimize);
    }

    // Too many for one request. Walk them nearest-first and cut the walk
    // into runs of at most 25; each run is optimised on its own and hands
    // its last stop to the next as the start. Not globally optimal, but each
    // run is, and neighbouring stops stay in the same run.
    final walk = optimize ? nearestNeighbourOrder(origin, stops) : stops;
    final order = <String>[];
    final legs = <PlannedLeg>[];
    var from = origin;
    for (var i = 0; i < walk.length; i += maxIntermediates) {
      final end = (i + maxIntermediates).clamp(0, walk.length);
      final chunk = walk.sublist(i, end);
      if (end >= walk.length) {
        final r = await _request(from, destination, chunk, optimize);
        order.addAll(r.order);
        legs.addAll(r.legs);
      } else {
        final last = chunk.last;
        final r = await _request(
          from,
          last.location,
          chunk.sublist(0, chunk.length - 1),
          optimize,
        );
        order
          ..addAll(r.order)
          ..add(last.id);
        legs.addAll(r.legs);
        from = last.location;
      }
    }
    return RoutePlanResult(order: order, legs: legs, destination: destination);
  }

  Future<RoutePlanResult> _request(
    GeoCoord origin,
    GeoCoord destination,
    List<PlanStop> stops,
    bool optimize,
  ) async {
    _calls++;
    final data = await transport.compute(
      requestBody(
        origin: origin,
        destination: destination,
        stops: stops,
        optimize: optimize,
      ),
    );
    return parseResponse(
      data,
      origin: origin,
      destination: destination,
      stops: stops,
    );
  }

  /// The `computeRoutes` body. Public for the tests.
  static Map<String, dynamic> requestBody({
    required GeoCoord origin,
    required GeoCoord destination,
    required List<PlanStop> stops,
    required bool optimize,
  }) {
    Map<String, dynamic> point(GeoCoord c, {bool stopover = false}) => {
      'location': {
        'latLng': {'latitude': c.lat, 'longitude': c.lng},
      },
      // Stop on the kerb the child is waiting on, rather than routing the
      // van to the middle of the road opposite.
      if (stopover) 'vehicleStopover': true,
      if (stopover) 'sideOfRoad': true,
    };

    return {
      'origin': point(origin),
      'destination': point(destination, stopover: true),
      if (stops.isNotEmpty)
        'intermediates': [
          for (final s in stops) point(s.location, stopover: true),
        ],
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE',
      if (optimize && stops.length > 1) 'optimizeWaypointOrder': true,
      'polylineEncoding': 'ENCODED_POLYLINE',
    };
  }

  /// Turns a `computeRoutes` response into a plan. Public for the tests.
  static RoutePlanResult parseResponse(
    Map<String, dynamic> data, {
    required GeoCoord origin,
    required GeoCoord destination,
    required List<PlanStop> stops,
  }) {
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      throw const RoutesFailed(200, 'no route found');
    }
    final route = routes.first as Map<String, dynamic>;

    // `optimizedIntermediateWaypointIndex[i]` is the original index of the
    // stop Google put i-th. Absent, or [-1] for an unoptimised request,
    // means it kept the given order.
    final raw = route['optimizedIntermediateWaypointIndex'] as List?;
    var indexes = [for (var i = 0; i < stops.length; i++) i];
    if (raw != null && raw.length == stops.length) {
      final parsed = raw.map((e) => (e as num).toInt()).toList();
      final sane =
          parsed.toSet().length == stops.length &&
          parsed.every((i) => i >= 0 && i < stops.length);
      if (sane) indexes = parsed;
    }
    final ordered = [for (final i in indexes) stops[i]];

    final rawLegs = (route['legs'] as List?) ?? const [];
    final legs = <PlannedLeg>[];
    for (var i = 0; i < ordered.length + 1; i++) {
      final from = i == 0 ? origin : ordered[i - 1].location;
      final to = i < ordered.length ? ordered[i].location : destination;
      if (i >= rawLegs.length) {
        legs.add(_straightLeg(from, to));
        continue;
      }
      final leg = rawLegs[i] as Map<String, dynamic>;
      final encoded =
          (leg['polyline'] as Map<String, dynamic>?)?['encodedPolyline']
              as String?;
      final straight = GeoUtils.distance(from, to);
      legs.add(
        PlannedLeg(
          meters:
              (leg['distanceMeters'] as num?)?.toInt() ??
              (straight * 1.35).round(),
          seconds:
              parseDuration(leg['duration'] as String?) ??
              _estimateSeconds(straight),
          points: encoded == null || encoded.isEmpty
              ? [from, to]
              : GeoUtils.decodePolyline(encoded),
        ),
      );
    }
    return RoutePlanResult(
      order: [for (final s in ordered) s.id],
      legs: legs,
      destination: destination,
    );
  }

  /// `"165s"` → 165.
  static int? parseDuration(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll('s', ''))?.round();
  }

  static PlanStop _farthest(GeoCoord origin, List<PlanStop> stops) {
    var best = stops.first;
    var bestD = -1.0;
    for (final s in stops) {
      final d = GeoUtils.distance(origin, s.location);
      if (d > bestD) {
        bestD = d;
        best = s;
      }
    }
    return best;
  }

  /// Greedy: always the closest stop not yet visited.
  static List<PlanStop> nearestNeighbourOrder(
    GeoCoord origin,
    List<PlanStop> stops,
  ) {
    final left = List.of(stops);
    final out = <PlanStop>[];
    var here = origin;
    while (left.isNotEmpty) {
      var bestIndex = 0;
      var bestD = double.infinity;
      for (var i = 0; i < left.length; i++) {
        final d = GeoUtils.distance(here, left[i].location);
        if (d < bestD) {
          bestD = d;
          bestIndex = i;
        }
      }
      final next = left.removeAt(bestIndex);
      out.add(next);
      here = next.location;
    }
    return out;
  }

  /// City driving, with a factor for roads not being straight lines.
  static int _estimateSeconds(double straightMeters) =>
      ((straightMeters * 1.35) / (22 / 3.6)).round();

  static PlannedLeg _straightLeg(GeoCoord from, GeoCoord to) {
    final d = GeoUtils.distance(from, to);
    return PlannedLeg(
      meters: (d * 1.35).round(),
      seconds: _estimateSeconds(d),
      points: [from, to],
    );
  }

  /// What the round looks like when Google cannot be asked: nearest stop
  /// first, straight lines, a guessed speed. Enough to keep a round running
  /// with no signal — and labelled, so nobody mistakes it for a road route.
  static RoutePlanResult fallbackPlan({
    required GeoCoord origin,
    GeoCoord? destination,
    required List<PlanStop> stops,
    bool keepOrder = false,
  }) {
    final ordered = keepOrder ? stops : nearestNeighbourOrder(origin, stops);
    final legs = <PlannedLeg>[];
    var from = origin;
    for (final s in ordered) {
      legs.add(_straightLeg(from, s.location));
      from = s.location;
    }
    if (destination != null) legs.add(_straightLeg(from, destination));
    return RoutePlanResult(
      order: [for (final s in ordered) s.id],
      legs: legs,
      destination: destination,
      approximate: true,
      warning:
          'Could not reach Google Maps — showing the nearest stop first '
          'with straight lines. Road directions return when the signal does.',
    );
  }
}
