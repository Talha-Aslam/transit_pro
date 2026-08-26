import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:transit_core/transit_core.dart';

/// The one conversion point between this app's coordinate type ([GeoCoord],
/// lat-first) and Mapbox's ([Position], **lng-first**).
///
/// This file is deliberately the *only* place in the repo allowed to contain
/// a `Position(` literal. Both constructors are positional and `double`, and
/// for every coordinate this app actually uses (Lahore: lat ~31, lng ~74) a
/// swapped pair is still a mathematically valid position — it throws
/// nothing, logs nothing, and silently puts the bus somewhere in Kazakhstan.
/// Writing the order exactly once, here, and reusing it everywhere else is
/// the only real defence against that.
extension GeoCoordMapbox on GeoCoord {
  Point get point => Point(coordinates: Position(lng, lat)); // lng FIRST
}

extension GeoCoordListMapbox on List<GeoCoord> {
  LineString get lineString => LineString(
        coordinates: [for (final c in this) Position(c.lng, c.lat)],
      );
}

extension PositionGeo on Position {
  GeoCoord get geoCoord => GeoCoord(lat.toDouble(), lng.toDouble()); // lat FIRST
}
