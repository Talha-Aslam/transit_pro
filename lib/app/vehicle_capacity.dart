import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import '../data/fleet_repository.dart';

/// How many seats a driver's vehicle has, as a family should be told it.
///
/// The bus document's own capacity — the seat count the driver gave for
/// their vehicle — is the answer. The rounds are not: every round offers
/// seats on the same van, so adding them up described a 12-seater running
/// two rounds as a 24-seater. [Driver.vehicleSeats] (the largest round) is
/// only the stand-in for a driver whose bus has no capacity on record.
class VehicleCapacity {
  VehicleCapacity._();

  /// One read per bus for the app's life: a search list rebuilds often, and
  /// a vehicle's size does not change while a parent scrolls it.
  static final _cache = <String, Future<int?>>{};
  static final _known = <String, int>{};

  /// The best number available right now, without waiting: the bus's
  /// capacity once it has been read, the largest round until then. Used as
  /// a builder's initial value so a rebuild does not flicker back to the
  /// estimate.
  static int current(Driver driver) => driver.vehicleCapacity > 0
      ? driver.vehicleCapacity
      : _known[driver.busId ?? ''] ?? estimate(driver);

  /// The number to show before the bus document has been read.
  static int estimate(Driver driver) => driver.vehicleSeats;

  static Future<int> of(Driver driver) async {
    // The driver's own figure, set on My Service, is the answer when there
    // is one; the bus document is for drivers who have not set it yet.
    if (driver.vehicleCapacity > 0) return driver.vehicleCapacity;
    final busId = driver.busId ?? '';
    if (busId.isEmpty) return estimate(driver);
    final capacity = await _cache.putIfAbsent(busId, () async {
      try {
        return (await FleetRepository.instance.fetchBus(busId))?.capacity;
      } catch (e) {
        // Not cached as an answer: the next screen to ask tries again.
        debugPrint('bus $busId capacity unavailable: $e');
        _cache.remove(busId);
        return null;
      }
    });
    if (capacity == null || capacity <= 0) return estimate(driver);
    _known[busId] = capacity;
    return capacity;
  }
}
