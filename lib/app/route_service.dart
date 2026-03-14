import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;

/// Service for fetching optimised routes from Google Directions API.
///
/// Falls back to straight-line interpolation when no API key is configured.
class RouteService {
  RouteService._();
  static final RouteService instance = RouteService._();

  /// Set this to your Google Maps API key to enable real directions.
  String? apiKey;

  /// Fetch polyline points between [origin] and [destination],
  /// optionally via [waypoints] with optimisation.
  Future<List<LatLng>> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    bool optimize = true,
  }) async {
    if (apiKey == null || apiKey!.isEmpty || apiKey == 'YOUR_API_KEY') {
      // Fallback: connect points with straight lines
      return [origin, ...waypoints, destination];
    }

    try {
      final waypointStr = waypoints.isNotEmpty
          ? '&waypoints=${optimize ? "optimize:true|" : ""}${waypoints.map((w) => '${w.latitude},${w.longitude}').join('|')}'
          : '';

      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '$waypointStr'
        '&key=$apiKey',
      );

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return [origin, ...waypoints, destination];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') {
        return [origin, ...waypoints, destination];
      }

      final routes = data['routes'] as List;
      if (routes.isEmpty) return [origin, ...waypoints, destination];

      final overviewPolyline =
          routes[0]['overview_polyline']['points'] as String;
      final polylinePoints = PolylinePoints();
      final decoded = polylinePoints.decodePolyline(overviewPolyline);

      return decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();
    } catch (e) {
      debugPrint('RouteService error: $e');
      return [origin, ...waypoints, destination];
    }
  }

  /// Fetch distance & duration text between two points.
  Future<({String distance, String duration})?> fetchDistanceDuration({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (apiKey == null || apiKey!.isEmpty || apiKey == 'YOUR_API_KEY') {
      return null;
    }

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&key=$apiKey',
      );

      final response = await http.get(uri);
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final leg = data['routes'][0]['legs'][0];
      return (
        distance: leg['distance']['text'] as String,
        duration: leg['duration']['text'] as String,
      );
    } catch (e) {
      debugPrint('RouteService distance error: $e');
      return null;
    }
  }
}
