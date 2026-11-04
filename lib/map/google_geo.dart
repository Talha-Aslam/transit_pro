import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit_core/transit_core.dart';

/// The one conversion point between this app's coordinate type ([GeoCoord])
/// and google_maps_flutter's ([LatLng]).
///
/// Both are (lat, lng)-ordered, so unlike the Mapbox setup this replaces,
/// there's no ordering trap to guard against here. Still kept as a single,
/// dedicated conversion point — same reason as before: `GeoCoord` lives in
/// `transit_core`, which must not depend on `google_maps_flutter`.
extension GeoCoordGoogle on GeoCoord {
  LatLng get latLng => LatLng(lat, lng);
}

extension LatLngGeo on LatLng {
  GeoCoord get geoCoord => GeoCoord(latitude, longitude);
}
