import 'dart:math' as math;

import 'package:transit_core/transit_core.dart';

/// Where a point lands on a polyline.
class PolylineProjection {
  /// The segment the point was matched to: `line[segment]` →
  /// `line[segment + 1]`.
  final int segment;

  /// The nearest point on that segment.
  final GeoCoord point;

  /// Metres from the original point to [point] — how far off the line it is.
  final double offsetMeters;

  /// Metres along the line from its start to [point].
  final double alongMeters;

  const PolylineProjection({
    required this.segment,
    required this.point,
    required this.offsetMeters,
    required this.alongMeters,
  });
}

/// Geometry the map, the trip controller and the tests all share.
///
/// Pure Dart, no plugins: everything here has to run inside a unit test, and
/// the one distance function the rest of the app used before
/// (`Geolocator.distanceBetween`) needs a platform channel.
class GeoUtils {
  GeoUtils._();

  static const double _earthRadius = 6371000.0;

  static double _rad(double deg) => deg * math.pi / 180;

  /// Great-circle distance in metres.
  static double distance(GeoCoord a, GeoCoord b) {
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.lat)) *
            math.cos(_rad(b.lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * _earthRadius * math.asin(math.min(1, math.sqrt(h)));
  }

  /// Initial compass bearing from [a] to [b], 0–360, 0 = north.
  static double bearing(GeoCoord a, GeoCoord b) {
    final dLng = _rad(b.lng - a.lng);
    final y = math.sin(dLng) * math.cos(_rad(b.lat));
    final x =
        math.cos(_rad(a.lat)) * math.sin(_rad(b.lat)) -
        math.sin(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Total length of [line] in metres.
  static double length(List<GeoCoord> line) {
    var total = 0.0;
    for (var i = 0; i + 1 < line.length; i++) {
      total += distance(line[i], line[i + 1]);
    }
    return total;
  }

  static GeoCoord lerp(GeoCoord a, GeoCoord b, double t) =>
      GeoCoord(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);

  /// Interpolates a heading the short way round — 350° to 10° passes
  /// through north, not through south.
  static double lerpAngle(double a, double b, double t) {
    final delta = ((b - a + 540) % 360) - 180;
    return (a + delta * t + 360) % 360;
  }

  /// Nearest point on [line] to [p].
  ///
  /// Segments are flattened onto a local plane around [p]. At the few
  /// kilometres a school round covers that is accurate to centimetres, and
  /// it is what makes the projection a closed form instead of a search.
  ///
  /// [fromSegment] lets a caller that already knows roughly where the van is
  /// skip the part of the line behind it, so a route that doubles back past
  /// the same junction does not snap the van to its earlier pass.
  static PolylineProjection? project(
    GeoCoord p,
    List<GeoCoord> line, {
    int fromSegment = 0,
  }) {
    if (line.isEmpty) return null;
    if (line.length == 1) {
      return PolylineProjection(
        segment: 0,
        point: line.first,
        offsetMeters: distance(p, line.first),
        alongMeters: 0,
      );
    }

    final cosLat = math.cos(_rad(p.lat));
    double x(GeoCoord c) => _rad(c.lng - p.lng) * cosLat * _earthRadius;
    double y(GeoCoord c) => _rad(c.lat - p.lat) * _earthRadius;

    var along = 0.0;
    final start = fromSegment.clamp(0, line.length - 2);
    for (var i = 0; i < start; i++) {
      along += distance(line[i], line[i + 1]);
    }

    PolylineProjection? best;
    for (var i = start; i + 1 < line.length; i++) {
      final a = line[i];
      final b = line[i + 1];
      final ax = x(a), ay = y(a), bx = x(b), by = y(b);
      final dx = bx - ax, dy = by - ay;
      final lenSq = dx * dx + dy * dy;
      var t = lenSq == 0 ? 0.0 : -(ax * dx + ay * dy) / lenSq;
      t = t.clamp(0.0, 1.0);
      final px = ax + dx * t, py = ay + dy * t;
      final offset = math.sqrt(px * px + py * py);
      final segLen = distance(a, b);
      if (best == null || offset < best.offsetMeters) {
        best = PolylineProjection(
          segment: i,
          point: lerp(a, b, t),
          offsetMeters: offset,
          alongMeters: along + segLen * t,
        );
      }
      along += segLen;
    }
    return best;
  }

  /// The part of [line] still ahead of [at]: the projected point, then every
  /// vertex after it.
  static List<GeoCoord> ahead(List<GeoCoord> line, PolylineProjection at) {
    if (line.length < 2) return List.of(line);
    return [at.point, ...line.sublist(at.segment + 1)];
  }

  /// The part of [line] already driven: every vertex up to [at], then the
  /// projected point.
  static List<GeoCoord> behind(List<GeoCoord> line, PolylineProjection at) {
    if (line.length < 2) return const [];
    return [...line.sublist(0, at.segment + 1), at.point];
  }

  /// Decodes a Google encoded polyline (precision 5), the format the Routes
  /// API returns for `ENCODED_POLYLINE`.
  static List<GeoCoord> decodePolyline(String encoded) {
    final out = <GeoCoord>[];
    var index = 0, lat = 0, lng = 0;
    int next() {
      var result = 0, shift = 0, b = 0;
      do {
        if (index >= encoded.length) return 0;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    }

    while (index < encoded.length) {
      lat += next();
      lng += next();
      out.add(GeoCoord(lat / 1e5, lng / 1e5));
    }
    return out;
  }

  /// Encodes [points] the way [decodePolyline] reads them — used to store a
  /// straight-line fallback route in the same shape as a real one.
  static String encodePolyline(List<GeoCoord> points) {
    final buf = StringBuffer();
    var prevLat = 0, prevLng = 0;
    void put(int v) {
      var value = v < 0 ? ~(v << 1) : v << 1;
      while (value >= 0x20) {
        buf.writeCharCode((0x20 | (value & 0x1f)) + 63);
        value >>= 5;
      }
      buf.writeCharCode(value + 63);
    }

    for (final p in points) {
      final lat = (p.lat * 1e5).round();
      final lng = (p.lng * 1e5).round();
      put(lat - prevLat);
      put(lng - prevLng);
      prevLat = lat;
      prevLng = lng;
    }
    return buf.toString();
  }
}
