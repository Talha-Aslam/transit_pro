import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
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

/// Place search and geocoding over HTTP, backed by Google Maps Platform.
///
/// Routing is not here any more: planning a round, and every route a map
/// draws, goes through `RouteOptimizationService`, which calls the Routes
/// API from the backend and caches the answer on the trip.
///
/// Uses **Places API (New)** (`places.googleapis.com`) — POST+JSON with the
/// key in an `X-Goog-Api-Key` header and an explicit `X-Goog-FieldMask` —
/// since Google no longer lets new projects enable the classic Places API.
/// Geocoding is unchanged; it has no "new" variant.
///
/// Returns empty / null when no key is configured or a call fails — never
/// throws into the caller.
class RouteService {
  RouteService._();
  static final RouteService instance = RouteService._();

  /// Defaults to [AppConfig.googleMapsApiKey]. Overridable for tests.
  String? accessToken = AppConfig.googleMapsApiKey.isNotEmpty
      ? AppConfig.googleMapsApiKey
      : null;

  bool get _hasToken => accessToken != null && accessToken!.isNotEmpty;

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
      final places = retrieved.whereType<GeocodeResult>().toList();

      // Nearest first. `locationBias` above only nudges Google's own
      // ranking, which still put a campus three cities away at the top for
      // a family typing the name of the one down their street. Once every
      // candidate has a coordinate, the order is ours to decide.
      if (near != null) {
        places.sort((a, b) {
          final da = Geolocator.distanceBetween(
            near.lat,
            near.lng,
            a.coord.lat,
            a.coord.lng,
          );
          final db = Geolocator.distanceBetween(
            near.lat,
            near.lng,
            b.coord.lat,
            b.coord.lng,
          );
          return da.compareTo(db);
        });
      }
      return places;
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

  /// A loose ~0.2° (~20km) box around [center]. Geocoding's `bounds` only
  /// *biases* results (unlike Places' `locationBias`, which can restrict),
  /// so this doesn't need to be precise.
  String _looseBounds(GeoCoord center) {
    const delta = 0.2;
    return '${center.lat - delta},${center.lng - delta}'
        '|${center.lat + delta},${center.lng + delta}';
  }
}
