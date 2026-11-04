import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:transit_core/transit_core.dart';

/// One forward-geocoding search result: a human label plus the point it
/// resolves to.
///
/// [name] and [placeFormatted] are optional, populated only by
/// [RouteService.searchPlaces] (Places returns a structured display name
/// plus a formatted address; the plain [RouteService.forwardGeocode] does
/// not) — every existing call site only ever used [label], so both stay
/// optional.
class GeocodeResult {
  final String label;
  final GeoCoord coord;
  final String? name;
  final String? placeFormatted;
  const GeocodeResult({
    required this.label,
    required this.coord,
    this.name,
    this.placeFormatted,
  });
}

/// Directions/geocoding over HTTP, backed by Google Maps Platform.
///
/// Deliberately uses the **current-generation** products, not the legacy
/// ones: Google no longer lets new projects enable the old Directions API
/// or classic Places API, so this targets **Routes API**
/// (`routes.googleapis.com`) and **Places API (New)**
/// (`places.googleapis.com`). Both are POST+JSON with the key in an
/// `X-Goog-Api-Key` header and an explicit `X-Goog-FieldMask` naming the
/// response fields, rather than the old query-string GET style. Geocoding
/// is unchanged — it has no "new" variant.
///
/// Falls back to straight-line interpolation / null when no key is
/// configured or a call fails — never throws into the caller.
class RouteService {
  RouteService._();
  static final RouteService instance = RouteService._();

  /// Defaults to [AppConfig.googleMapsApiKey]. Overridable for tests.
  String? accessToken = AppConfig.googleMapsApiKey.isNotEmpty
      ? AppConfig.googleMapsApiKey
      : null;

  bool get _hasToken => accessToken != null && accessToken!.isNotEmpty;

  static const _computeRoutesUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  static const _geocodeUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';
  static const _autocompleteUrl =
      'https://places.googleapis.com/v1/places:autocomplete';
  static const _placeDetailsBaseUrl = 'https://places.googleapis.com/v1/places';

  /// A fresh Places Autocomplete session token. Call once when a search
  /// session starts (first keystroke, or the field gaining focus) and reuse
  /// the same string for every autocomplete/details call in that session —
  /// Google bills Autocomplete per session, keyed on this `sessionToken`.
  /// Not a RFC-4122 UUID (this repo has no `uuid` dependency) — just random
  /// hex, which satisfies Places' "URL-safe, at most 36 chars" rule and has
  /// enough entropy that two sessions never collide in practice.
  static String newSessionToken() {
    final rand = Random();
    return List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
  }

  /// Fetch polyline points between [origin] and [destination], optionally
  /// via [waypoints].
  ///
  /// [optimize] is a documented no-op: this always visits waypoints in the
  /// order given. (Routes API *can* reorder them via
  /// `optimizeWaypointOrder`, but that changes which stop comes next on a
  /// live route, so it stays off deliberately.)
  Future<List<GeoCoord>> fetchRoute({
    required GeoCoord origin,
    required GeoCoord destination,
    List<GeoCoord> waypoints = const [],
    bool optimize = true,
  }) async {
    final straightLine = [origin, ...waypoints, destination];
    if (!_hasToken) return straightLine;

    try {
      final response = await _computeRoutes(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        fieldMask: 'routes.polyline.encodedPolyline',
      );
      if (response.statusCode != 200) {
        debugPrint(
          'RouteService: routes ${response.statusCode} — ${response.body}',
        );
        return straightLine;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return straightLine;

      final polyline =
          (routes.first as Map<String, dynamic>)['polyline']
              as Map<String, dynamic>?;
      final encoded = polyline?['encodedPolyline'] as String?;
      if (encoded == null) return straightLine;

      // Precision-5 encoded polyline — matches flutter_polyline_points'
      // hardcoded 1e5 decode divisor, which is what ENCODED_POLYLINE means.
      final decoded = PolylinePoints().decodePolyline(encoded);
      return decoded.map((p) => GeoCoord(p.latitude, p.longitude)).toList();
    } catch (e) {
      debugPrint('RouteService error: $e');
      return straightLine;
    }
  }

  /// Fetch the driving distance and duration between two points.
  ///
  /// Returns the formatted strings the UI prints *and* the raw figures
  /// behind them. `TrackingService.applyRouteEstimate` needs the numbers:
  /// a '12 min' string cannot be aged by the thirty seconds that have
  /// passed since it was fetched, which is what makes the on-screen ETA
  /// tick down smoothly between refreshes.
  Future<
    ({String distance, String duration, double meters, int seconds})?
  >
  fetchDistanceDuration({
    required GeoCoord origin,
    required GeoCoord destination,
  }) async {
    if (!_hasToken) return null;

    try {
      final response = await _computeRoutes(
        origin: origin,
        destination: destination,
        fieldMask: 'routes.distanceMeters,routes.duration',
      );
      if (response.statusCode != 200) {
        debugPrint(
          'RouteService: routes ${response.statusCode} — ${response.body}',
        );
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      // Routes API already totals these across every leg, unlike the legacy
      // Directions API which reported them per leg.
      final meters = (route['distanceMeters'] as num?)?.toDouble();
      final seconds = _parseDuration(route['duration'] as String?);
      if (meters == null || seconds == null) return null;

      return (
        distance: _formatDistance(meters),
        duration: _formatDuration(seconds),
        meters: meters,
        seconds: seconds,
      );
    } catch (e) {
      debugPrint('RouteService distance error: $e');
      return null;
    }
  }

  /// Turns free-text (e.g. "Gulberg, Lahore") into a short list of candidate
  /// places via the Geocoding API. [near] biases results loosely (via
  /// `bounds`) — Geocoding has no hard proximity filter the way Places'
  /// `locationBias` does. Returns an empty list with no key, a blank query,
  /// or a failed/empty lookup — never throws.
  Future<List<GeocodeResult>> forwardGeocode(
    String query, {
    GeoCoord? near,
    int limit = 5,
  }) async {
    final trimmed = query.trim();
    if (!_hasToken || trimmed.isEmpty) return [];

    try {
      final uri = Uri.parse(_geocodeUrl).replace(
        queryParameters: {
          'address': trimmed,
          'key': accessToken!,
          'region': 'pk',
          'language': 'en',
          if (near != null) 'bounds': _looseBounds(near),
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        debugPrint(
          'RouteService: forward geocode ${response.statusCode} — ${response.body}',
        );
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return [];
      final results = (data['results'] as List?) ?? [];

      final out = <GeocodeResult>[];
      for (final r in results.take(limit)) {
        final result = r as Map<String, dynamic>;
        final location =
            (result['geometry'] as Map<String, dynamic>?)?['location']
                as Map<String, dynamic>?;
        final lat = (location?['lat'] as num?)?.toDouble();
        final lng = (location?['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        out.add(
          GeocodeResult(
            label: result['formatted_address'] as String? ?? trimmed,
            coord: GeoCoord(lat, lng),
          ),
        );
      }
      return out;
    } catch (e) {
      debugPrint('RouteService forward geocode error: $e');
      return [];
    }
  }

  /// POI/landmark search via Places API (New) — Autocomplete then Place
  /// Details. This is the product that actually indexes brands,
  /// universities, malls etc; Geocoding (used by [forwardGeocode]) is an
  /// *address* index and has no idea what "University of Lahore" is, which
  /// is why such a query used to collapse down to just the city.
  ///
  /// Autocomplete predictions carry no coordinates, so each needs a separate
  /// Place Details call. Since callers want a [GeoCoord] immediately, this
  /// resolves every prediction in parallel before returning, so the existing
  /// `List<GeocodeResult>` call sites need no restructuring.
  ///
  /// [sessionToken] must be the same string across every autocomplete and
  /// details call in one search session (see [newSessionToken]) — billing is
  /// per session, keyed on it.
  ///
  /// [poiCategory] is a comma-separated list of **Google place types** (e.g.
  /// `'school,primary_school,secondary_school,university'`), sent as
  /// `includedPrimaryTypes`. Places API (New) supports this natively — the
  /// legacy API did not, so category narrowing that was lost in the Mapbox
  /// → Google move is available again here. Google caps it at 5 types, so
  /// anything beyond the first 5 is dropped.
  Future<List<GeocodeResult>> searchPlaces(
    String query, {
    required String sessionToken,
    GeoCoord? near,
    int limit = 8,
    String? poiCategory,
  }) async {
    final trimmed = query.trim();
    if (!_hasToken || trimmed.isEmpty) return [];

    final types = (poiCategory ?? '')
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(5)
        .toList();

    try {
      final response = await http.post(
        Uri.parse(_autocompleteUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': accessToken!,
        },
        body: json.encode({
          'input': trimmed,
          'sessionToken': sessionToken,
          'languageCode': 'en',
          'includedRegionCodes': ['pk'],
          if (types.isNotEmpty) 'includedPrimaryTypes': types,
          if (near != null)
            'locationBias': {
              'circle': {
                'center': {'latitude': near.lat, 'longitude': near.lng},
                'radius': 50000.0,
              },
            },
        }),
      );
      if (response.statusCode != 200) {
        debugPrint(
          'RouteService: autocomplete ${response.statusCode} — ${response.body}',
        );
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final suggestions = (data['suggestions'] as List?) ?? [];
      if (suggestions.isEmpty) return [];

      // A suggestion is either a placePrediction or a queryPrediction; only
      // the former resolves to a real point, so the latter is skipped.
      final predictions = suggestions
          .map(
            (s) =>
                (s as Map<String, dynamic>)['placePrediction']
                    as Map<String, dynamic>?,
          )
          .whereType<Map<String, dynamic>>()
          .take(limit)
          .toList();
      if (predictions.isEmpty) return [];

      final retrieved = await Future.wait(
        predictions.map((p) => _placeDetails(p, sessionToken)),
      );
      return retrieved.whereType<GeocodeResult>().toList();
    } catch (e) {
      debugPrint('RouteService search places error: $e');
      return [];
    }
  }

  /// Resolves one autocomplete prediction to coordinates via Place Details.
  /// Returns null on any failure — caught here (not left to propagate) so
  /// one bad prediction in [searchPlaces]'s `Future.wait` never drops the
  /// rest.
  Future<GeocodeResult?> _placeDetails(
    Map<String, dynamic> prediction,
    String sessionToken,
  ) async {
    final placeId = prediction['placeId'] as String?;
    if (placeId == null || !_hasToken) return null;

    try {
      final uri = Uri.parse('$_placeDetailsBaseUrl/$placeId').replace(
        queryParameters: {'sessionToken': sessionToken, 'languageCode': 'en'},
      );
      final response = await http.get(
        uri,
        headers: {
          'X-Goog-Api-Key': accessToken!,
          'X-Goog-FieldMask': 'id,displayName,formattedAddress,location',
        },
      );
      if (response.statusCode != 200) {
        debugPrint(
          'RouteService: place details ${response.statusCode} — ${response.body}',
        );
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final location = data['location'] as Map<String, dynamic>?;
      final lat = (location?['latitude'] as num?)?.toDouble();
      final lng = (location?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      final name =
          (data['displayName'] as Map<String, dynamic>?)?['text'] as String?;
      final formattedAddress = data['formattedAddress'] as String?;
      final secondaryText =
          ((prediction['structuredFormat']
                      as Map<String, dynamic>?)?['secondaryText']
                  as Map<String, dynamic>?)?['text']
              as String?;
      final predictionText =
          (prediction['text'] as Map<String, dynamic>?)?['text'] as String?;

      return GeocodeResult(
        label: name ?? formattedAddress ?? predictionText ?? placeId,
        coord: GeoCoord(lat, lng),
        name: name,
        placeFormatted: formattedAddress ?? secondaryText,
      );
    } catch (e) {
      debugPrint('RouteService place details error: $e');
      return null;
    }
  }

  /// Turns coordinates into a human-readable address, e.g. `31.5204, 74.3587`
  /// → `"Model Town, Lahore, Punjab, Pakistan"`. Returns null with no key,
  /// on a failed lookup, or when Google has no address for the point (open
  /// water, unmapped area) — callers fall back to raw coordinates.
  Future<String?> reverseGeocode(GeoCoord point) async {
    if (!_hasToken) return null;

    try {
      final uri = Uri.parse(_geocodeUrl).replace(
        queryParameters: {
          'latlng': '${point.lat},${point.lng}',
          'key': accessToken!,
          'language': 'en',
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        debugPrint(
          'RouteService: reverse geocode ${response.statusCode} — ${response.body}',
        );
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return null;

      return (results.first as Map<String, dynamic>)['formatted_address']
          as String?;
    } catch (e) {
      debugPrint('RouteService geocode error: $e');
      return null;
    }
  }

  /// One Routes API `computeRoutes` call. [fieldMask] is mandatory for this
  /// API — it refuses a request without one, and the fields named here are
  /// the only ones that come back (and the only ones billed for).
  Future<http.Response> _computeRoutes({
    required GeoCoord origin,
    required GeoCoord destination,
    List<GeoCoord> waypoints = const [],
    required String fieldMask,
  }) {
    Map<String, dynamic> waypoint(GeoCoord c) => {
      'location': {
        'latLng': {'latitude': c.lat, 'longitude': c.lng},
      },
    };

    return http.post(
      Uri.parse(_computeRoutesUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': accessToken!,
        'X-Goog-FieldMask': fieldMask,
      },
      body: json.encode({
        'origin': waypoint(origin),
        'destination': waypoint(destination),
        if (waypoints.isNotEmpty)
          'intermediates': waypoints.map(waypoint).toList(),
        'travelMode': 'DRIVE',
        'polylineEncoding': 'ENCODED_POLYLINE',
      }),
    );
  }

  /// Routes API reports duration as a protobuf duration string — `"165s"`.
  int? _parseDuration(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final seconds = double.tryParse(raw.replaceAll('s', ''));
    return seconds?.round();
  }

  /// A loose ~0.2° (~20km) box around [center]. Geocoding's `bounds` only
  /// *biases* results (unlike Places' `locationBias`, which can restrict),
  /// so this doesn't need to be precise.
  String _looseBounds(GeoCoord center) {
    const delta = 0.2;
    return '${center.lat - delta},${center.lng - delta}'
        '|${center.lat + delta},${center.lng + delta}';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '$hours hr' : '$hours hr $remainder min';
  }
}
