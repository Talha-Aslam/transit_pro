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
/// [RouteService.searchPlaces] (the Search Box API returns a structured
/// name + formatted address; the plain [RouteService.forwardGeocode] does
/// not) — every existing call site only ever used [label], so both stay
/// optional rather than forcing every construction site to supply them.
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

/// Directions/geocoding over HTTP, backed by Mapbox's Directions v5 and
/// Geocoding v6 REST APIs.
///
/// Falls back to straight-line interpolation / null when no token is
/// configured or a call fails — never throws into the caller.
class RouteService {
  RouteService._();
  static final RouteService instance = RouteService._();

  /// Defaults to [AppConfig.mapboxAccessToken]. Overridable for tests.
  String? accessToken = AppConfig.mapboxAccessToken.isNotEmpty
      ? AppConfig.mapboxAccessToken
      : null;

  bool get _hasToken => accessToken != null && accessToken!.isNotEmpty;

  static const _directionsUrl =
      'https://api.mapbox.com/directions/v5/mapbox/driving';
  static const _reverseGeocodeUrl =
      'https://api.mapbox.com/search/geocode/v6/reverse';
  static const _forwardGeocodeUrl =
      'https://api.mapbox.com/search/geocode/v6/forward';
  static const _searchSuggestUrl =
      'https://api.mapbox.com/search/searchbox/v1/suggest';
  static const _searchRetrieveBaseUrl =
      'https://api.mapbox.com/search/searchbox/v1/retrieve';

  /// A fresh Search Box API session token. Call once when a search session
  /// starts (first keystroke, or the search field gaining focus) and reuse
  /// the same string for every `/suggest` and `/retrieve` call in that
  /// session — Mapbox bills the Search Box API per session, keyed on this
  /// value. Not a RFC-4122 UUID (this repo doesn't depend on the `uuid`
  /// package) — just random hex with enough entropy that two sessions never
  /// collide in practice, which is all Mapbox actually requires.
  static String newSessionToken() {
    final rand = Random();
    return List.generate(
      32,
      (_) => rand.nextInt(16).toRadixString(16),
    ).join();
  }

  /// Fetch polyline points between [origin] and [destination], optionally
  /// via [waypoints].
  ///
  /// [optimize] is a documented no-op: Mapbox's Directions API always
  /// visits waypoints in the order given — reordering them is a separate
  /// product, the Optimization API, not requested here.
  Future<List<GeoCoord>> fetchRoute({
    required GeoCoord origin,
    required GeoCoord destination,
    List<GeoCoord> waypoints = const [],
    bool optimize = true,
  }) async {
    final straightLine = [origin, ...waypoints, destination];
    if (!_hasToken) return straightLine;

    try {
      final response = await _directions(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
      );
      if (response.statusCode != 200) {
        debugPrint(
          'RouteService: directions ${response.statusCode} — ${response.body}',
        );
        return straightLine;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return straightLine;

      final encoded = (routes.first as Map<String, dynamic>)['geometry']
          as String?;
      if (encoded == null) return straightLine;

      final decoded = PolylinePoints().decodePolyline(encoded);
      return decoded
          .map((p) => GeoCoord(p.latitude, p.longitude))
          .toList();
    } catch (e) {
      debugPrint('RouteService error: $e');
      return straightLine;
    }
  }

  /// Fetch distance & duration text between two points.
  Future<({String distance, String duration})?> fetchDistanceDuration({
    required GeoCoord origin,
    required GeoCoord destination,
  }) async {
    if (!_hasToken) return null;

    try {
      final response = await _directions(
        origin: origin,
        destination: destination,
        overviewFull: false,
      );
      if (response.statusCode != 200) {
        debugPrint(
          'RouteService: directions ${response.statusCode} — ${response.body}',
        );
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final meters = (route['distance'] as num?)?.toDouble();
      final seconds = (route['duration'] as num?)?.toDouble();
      if (meters == null || seconds == null) return null;

      return (
        distance: _formatDistance(meters),
        duration: _formatDuration(seconds.round()),
      );
    } catch (e) {
      debugPrint('RouteService distance error: $e');
      return null;
    }
  }

  /// Turns free-text (e.g. "Gulberg, Lahore") into a short list of candidate
  /// places. [near] biases results toward that point (Mapbox's `proximity`)
  /// so "Gulberg" resolves to the one the user is actually looking at rather
  /// than an unrelated city. Returns an empty list with no token, a blank
  /// query, or a failed/empty lookup — never throws.
  Future<List<GeocodeResult>> forwardGeocode(
    String query, {
    GeoCoord? near,
    int limit = 5,
  }) async {
    final trimmed = query.trim();
    if (!_hasToken || trimmed.isEmpty) return [];

    try {
      final uri = Uri.parse(_forwardGeocodeUrl).replace(
        queryParameters: {
          'q': trimmed,
          'limit': limit.toString(),
          'access_token': accessToken!,
          'country': 'pk',
          'language': 'en',
          if (near != null) 'proximity': '${near.lng},${near.lat}',
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
      final features = data['features'] as List?;
      if (features == null) return [];

      final results = <GeocodeResult>[];
      for (final feature in features) {
        final properties =
            (feature as Map<String, dynamic>)['properties']
                as Map<String, dynamic>?;
        final coords = properties?['coordinates'] as Map<String, dynamic>?;
        final lat = (coords?['latitude'] as num?)?.toDouble();
        final lng = (coords?['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final label = _granularAddress(properties) ??
            properties?['full_address'] as String? ??
            properties?['name'] as String? ??
            trimmed;
        results.add(GeocodeResult(label: label, coord: GeoCoord(lat, lng)));
      }
      return results;
    } catch (e) {
      debugPrint('RouteService forward geocode error: $e');
      return [];
    }
  }

  /// POI/landmark search via Mapbox's Search Box API — the product that
  /// actually indexes brands, universities, malls etc. Geocoding v6 (used by
  /// [forwardGeocode]) is an *address* index and has no idea what
  /// "University of Lahore" is, which is why it used to collapse a query
  /// like that down to just the city.
  ///
  /// The Search Box API is a two-step suggest→retrieve flow: `/suggest`
  /// returns candidate names but no coordinates, and each one needs a
  /// separate `/retrieve/{mapbox_id}` call to get a point. Since callers
  /// here want a [GeoCoord] immediately (same as [forwardGeocode]), this
  /// eagerly retrieves every suggestion in parallel before returning, so the
  /// existing `List<GeocodeResult>` call site in `map_picker_screen.dart`
  /// needs no restructuring.
  ///
  /// [sessionToken] must be the same string across every suggest/retrieve
  /// call in one user search session (see [newSessionToken]) — the Search
  /// Box API is billed per session, keyed on this value. Returns an empty
  /// list with no token, a blank query, or a failed/empty lookup — never
  /// throws.
  Future<List<GeocodeResult>> searchPlaces(
    String query, {
    required String sessionToken,
    GeoCoord? near,
    int limit = 8,
  }) async {
    final trimmed = query.trim();
    if (!_hasToken || trimmed.isEmpty) return [];

    try {
      final uri = Uri.parse(_searchSuggestUrl).replace(
        queryParameters: {
          'q': trimmed,
          'session_token': sessionToken,
          'access_token': accessToken!,
          'language': 'en',
          'country': 'pk',
          'limit': limit.toString(),
          if (near != null) 'proximity': '${near.lng},${near.lat}',
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        debugPrint(
          'RouteService: search suggest ${response.statusCode} — ${response.body}',
        );
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final suggestions = data['suggestions'] as List?;
      if (suggestions == null || suggestions.isEmpty) return [];

      final retrieved = await Future.wait(
        suggestions.map(
          (s) => _retrievePlace(s as Map<String, dynamic>, sessionToken),
        ),
      );
      return retrieved.whereType<GeocodeResult>().toList();
    } catch (e) {
      debugPrint('RouteService search places error: $e');
      return [];
    }
  }

  /// Resolves one `/suggest` suggestion to coordinates via `/retrieve`.
  /// Returns null on any failure — caught here (not left to propagate) so
  /// one bad suggestion in [searchPlaces]'s `Future.wait` never drops the
  /// rest.
  Future<GeocodeResult?> _retrievePlace(
    Map<String, dynamic> suggestion,
    String sessionToken,
  ) async {
    final mapboxId = suggestion['mapbox_id'] as String?;
    if (mapboxId == null || !_hasToken) return null;

    try {
      final uri = Uri.parse('$_searchRetrieveBaseUrl/$mapboxId').replace(
        queryParameters: {
          'session_token': sessionToken,
          'access_token': accessToken!,
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        debugPrint(
          'RouteService: search retrieve ${response.statusCode} — ${response.body}',
        );
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List?;
      if (features == null || features.isEmpty) return null;

      final feature = features.first as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'] as List?;
      if (coords == null || coords.length < 2) return null;
      final lng = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      final properties = feature['properties'] as Map<String, dynamic>?;
      final name =
          properties?['name'] as String? ?? suggestion['name'] as String?;
      final placeFormatted =
          properties?['place_formatted'] as String? ??
          suggestion['place_formatted'] as String?;
      final fullAddress = properties?['full_address'] as String?;

      final label =
          name ??
          fullAddress ??
          placeFormatted ??
          suggestion['name'] as String? ??
          mapboxId;

      return GeocodeResult(
        label: label,
        coord: GeoCoord(lat, lng),
        name: name,
        placeFormatted: placeFormatted ?? fullAddress,
      );
    } catch (e) {
      debugPrint('RouteService retrieve place error: $e');
      return null;
    }
  }

  /// Builds a progressively-graceful address from Mapbox v6's structured
  /// `properties` — `[house number + street], [locality], [place]` — rather
  /// than the single flattened `full_address` string this used to return.
  /// Falls back to whatever level of detail is actually present: a rural
  /// point with no `street` still gets its `place`/`region`, rather than
  /// nothing. Returns null when none of the structured fields are present,
  /// so the caller can fall back to `full_address`/`name`.
  String? _granularAddress(Map<String, dynamic>? properties) {
    if (properties == null) return null;
    final parts = <String>[];

    final addressNumber = properties['address_number'] as String?;
    final street = properties['street'] as String?;
    if (street != null && street.isNotEmpty) {
      parts.add(
        addressNumber != null && addressNumber.isNotEmpty
            ? '$addressNumber $street'
            : street,
      );
    }

    final context = properties['context'] as Map<String, dynamic>?;
    String? contextName(String key) =>
        (context?[key] as Map<String, dynamic>?)?['name'] as String?;
    final locality = contextName('locality');
    final place = contextName('place');
    final region = contextName('region');

    if (locality != null && locality.isNotEmpty && locality != place) {
      parts.add(locality);
    }
    if (place != null && place.isNotEmpty) {
      parts.add(place);
    }
    if (parts.isEmpty && region != null && region.isNotEmpty) {
      parts.add(region);
    }

    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Turns coordinates into a human-readable address, e.g. `31.5204, 74.3587`
  /// → `"Model Town, Lahore, Pakistan"`. Returns null with no token
  /// configured, on a failed lookup, or when Mapbox has no address for the
  /// point (open water, unmapped area) — callers should fall back to raw
  /// coordinates.
  Future<String?> reverseGeocode(GeoCoord point) async {
    if (!_hasToken) return null;

    try {
      final uri = Uri.parse(_reverseGeocodeUrl).replace(
        queryParameters: {
          'longitude': point.lng.toString(),
          'latitude': point.lat.toString(),
          'access_token': accessToken!,
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
      final features = data['features'] as List?;
      if (features == null || features.isEmpty) return null;

      final properties =
          (features.first as Map<String, dynamic>)['properties']
              as Map<String, dynamic>?;
      return _granularAddress(properties) ??
          properties?['full_address'] as String? ??
          properties?['name'] as String?;
    } catch (e) {
      debugPrint('RouteService geocode error: $e');
      return null;
    }
  }

  Future<http.Response> _directions({
    required GeoCoord origin,
    required GeoCoord destination,
    List<GeoCoord> waypoints = const [],
    bool overviewFull = true,
  }) {
    final coords = [origin, ...waypoints, destination]
        .map((c) => '${c.lng},${c.lat}')
        .join(';');

    final uri = Uri.parse('$_directionsUrl/$coords').replace(
      queryParameters: {
        // Precision-5 polyline — matches flutter_polyline_points'
        // hardcoded 1e5 decode divisor. Mapbox's higher-precision
        // 'polyline6' would silently decode to the wrong coordinates with
        // this decoder, since nothing here validates precision at runtime.
        'geometries': 'polyline',
        'overview': overviewFull ? 'full' : 'simplified',
        'access_token': accessToken!,
      },
    );

    return http.get(uri);
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
