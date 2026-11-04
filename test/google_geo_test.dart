import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_pro/map/google_geo.dart';

void main() {
  group('GeoCoord <-> LatLng', () {
    const lahore = GeoCoord(31.5204, 74.3587);

    test('.latLng keeps latitude and longitude in the same order', () {
      final latLng = lahore.latLng;
      expect(latLng.latitude, 31.5204);
      expect(latLng.longitude, 74.3587);
    });

    test('latLng -> geoCoord round-trips to the original value', () {
      expect(lahore.latLng.geoCoord, lahore);
    });

    test('round-trips the negative hemisphere too', () {
      const point = GeoCoord(-31.5, -74.5);
      expect(point.latLng.geoCoord, point);
    });
  });
}
