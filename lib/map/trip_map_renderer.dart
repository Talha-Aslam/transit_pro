import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_core/transit_core.dart';

import '../theme/app_theme.dart';
import 'google_geo.dart';

/// How a round is drawn, shared by the driver's map and the families'.
///
/// Pure: lines in, `Polyline`s out. Both maps hand it a fresh set on every
/// change and let google_maps_flutter diff it, which is the whole fix for
/// "the route does not show after Start": the old map drew its line once in
/// `onMapCreated` and never again, so any route that arrived a moment later
/// — or changed — was never drawn.
class TripMapRenderer {
  TripMapRenderer._();

  /// Grey for the road already driven, a thick outlined line for the road
  /// ahead, and a stronger one on top for the stretch to the next stop.
  static Set<Polyline> polylines({
    required List<GeoCoord> remaining,
    List<GeoCoord> currentLeg = const [],
    List<GeoCoord> travelled = const [],
    required Color color,
  }) {
    List<LatLng> pts(List<GeoCoord> line) => [for (final p in line) p.latLng];
    return {
      if (travelled.length >= 2)
        Polyline(
          polylineId: const PolylineId('travelled'),
          points: pts(travelled),
          color: Colors.grey.withValues(alpha: 0.7),
          width: 5,
          zIndex: 1,
          jointType: JointType.round,
        ),
      if (remaining.length >= 2) ...{
        Polyline(
          polylineId: const PolylineId('remaining-casing'),
          points: pts(remaining),
          color: Colors.black.withValues(alpha: 0.35),
          width: 11,
          zIndex: 2,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
        Polyline(
          polylineId: const PolylineId('remaining'),
          points: pts(remaining),
          color: Color.lerp(color, Colors.white, 0.35)!,
          width: 7,
          zIndex: 3,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      },
      if (currentLeg.length >= 2) ...{
        Polyline(
          polylineId: const PolylineId('leg-casing'),
          points: pts(currentLeg),
          color: Color.lerp(color, Colors.black, 0.45)!,
          width: 13,
          zIndex: 4,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
        Polyline(
          polylineId: const PolylineId('leg'),
          points: pts(currentLeg),
          color: color,
          width: 8,
          zIndex: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      },
    };
  }

  /// The colour of a stop's marker, which is also the colour of its row in
  /// the driver's list, so the two can be read against each other.
  static Color stopColor(TripStop stop) => switch (stop.status) {
    TripStopStatus.done => AppTheme.success,
    TripStopStatus.skipped => AppTheme.error,
    TripStopStatus.arriving => AppTheme.warning,
    TripStopStatus.pending =>
      stop.isInstitute ? AppTheme.parentPurple : AppTheme.info,
  };

  /// A camera box around every point given, or null for fewer than two.
  static LatLngBounds? boundsOf(Iterable<GeoCoord> points) {
    double? minLat, maxLat, minLng, maxLng;
    var n = 0;
    for (final p in points) {
      n++;
      minLat = minLat == null || p.lat < minLat ? p.lat : minLat;
      maxLat = maxLat == null || p.lat > maxLat ? p.lat : maxLat;
      minLng = minLng == null || p.lng < minLng ? p.lng : minLng;
      maxLng = maxLng == null || p.lng > maxLng ? p.lng : maxLng;
    }
    if (n < 2) return null;
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }
}
