import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:transit_core/transit_core.dart';
import '../models/route_data.dart';

/// Geofence alert type.
enum GeofenceEvent { approaching, arrived, departed }

/// A geofence alert payload.
class GeofenceAlert {
  final StopData stop;
  final GeofenceEvent event;
  final double distance;
  final DateTime timestamp;

  const GeofenceAlert({
    required this.stop,
    required this.event,
    required this.distance,
    required this.timestamp,
  });
}

/// Monitors bus position against route stops and fires proximity alerts.
///
/// Thresholds:
/// - **approaching** : within 500 m
/// - **arrived**     : within 100 m
/// - **departed**    : moved beyond 200 m after being arrived
class GeofenceService {
  GeofenceService._();
  static final GeofenceService instance = GeofenceService._();

  final alerts = ValueNotifier<List<GeofenceAlert>>([]);

  final _firedApproaching = <String>{};
  final _firedArrived = <String>{};
  final _firedDeparted = <String>{};

  /// Check bus position against all stops and emit alerts.
  void evaluate(GeoCoord busPos, List<StopData> stops) {
    for (final stop in stops) {
      final dist = Geolocator.distanceBetween(
        busPos.lat,
        busPos.lng,
        stop.location.lat,
        stop.location.lng,
      );

      final key = stop.name;

      // Approaching (500 m)
      if (dist <= 500 && !_firedApproaching.contains(key)) {
        _firedApproaching.add(key);
        _emit(
          GeofenceAlert(
            stop: stop,
            event: GeofenceEvent.approaching,
            distance: dist,
            timestamp: DateTime.now(),
          ),
        );
      }

      // Arrived (100 m)
      if (dist <= 100 && !_firedArrived.contains(key)) {
        _firedArrived.add(key);
        _emit(
          GeofenceAlert(
            stop: stop,
            event: GeofenceEvent.arrived,
            distance: dist,
            timestamp: DateTime.now(),
          ),
        );
      }

      // Departed (was arrived, now > 200 m)
      if (_firedArrived.contains(key) &&
          !_firedDeparted.contains(key) &&
          dist > 200) {
        _firedDeparted.add(key);
        _emit(
          GeofenceAlert(
            stop: stop,
            event: GeofenceEvent.departed,
            distance: dist,
            timestamp: DateTime.now(),
          ),
        );
      }
    }
  }

  void _emit(GeofenceAlert alert) {
    alerts.value = [...alerts.value, alert];
  }

  /// Reset all tracking state (e.g., when route restarts).
  void reset() {
    _firedApproaching.clear();
    _firedArrived.clear();
    _firedDeparted.clear();
    alerts.value = [];
  }
}
