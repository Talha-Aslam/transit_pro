// Guards the single highest-risk line in the Mapbox migration: GeoCoord is
// (lat, lng), Mapbox's Position is (lng, lat). Both positional, both double.
// For every coordinate this app uses (Lahore, lat ~31 / lng ~74) a swapped
// pair is a *valid* position — it would throw nothing and silently put the
// bus in Kazakhstan. This is the only defence against that regressing.
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_pro/map/mapbox_geo.dart';

void main() {
  group('GeoCoord <-> Mapbox Position', () {
    const lahore = GeoCoord(31.5204, 74.3587);

    test('.point puts longitude first, latitude second', () {
      final point = lahore.point;
      expect(point.coordinates.lng, 74.3587);
      expect(point.coordinates.lat, 31.5204);
    });

    test('point -> geoCoord round-trips to the original value', () {
      final roundTripped = lahore.point.coordinates.geoCoord;
      expect(roundTripped, lahore);
    });

    test('a naive (lat, lng) Position construction is NOT what .point does',
        () {
      // Sanity check the trap is real: constructing Position the "obvious"
      // (lat-first) way for this same coordinate is a different point.
      final wrongWay = Position(lahore.lat, lahore.lng); // lng param = lat!
      expect(wrongWay.lng, isNot(lahore.lng));
    });

    test('list -> lineString preserves lat/lng order across every point',
        () {
      const points = [
        GeoCoord(31.5204, 74.3587),
        GeoCoord(31.5380, 74.3290),
        GeoCoord(-31.5, -74.5), // negative hemisphere, still must round-trip
      ];

      final line = points.lineString;
      expect(line.coordinates.length, points.length);
      for (var i = 0; i < points.length; i++) {
        expect(line.coordinates[i].lng, points[i].lng);
        expect(line.coordinates[i].lat, points[i].lat);
        expect(line.coordinates[i].geoCoord, points[i]);
      }
    });
  });
}
