import 'package:transit_core/transit_core.dart';

import 'db.dart';

/// Buses and routes. Mostly read-only from the mobile app — the admin app owns
/// the writes.
class FleetRepository {
  FleetRepository._();
  static final FleetRepository instance = FleetRepository._();

  // ── Routes ────────────────────────────────────────────────────────────────

  Stream<BusRoute?> watchRoute(String routeId) =>
      Db.routes.doc(routeId).snapshots().map((s) => s.data());

  Future<BusRoute?> fetchRoute(String routeId) async {
    final snap = await Db.routes.doc(routeId).get();
    return snap.data();
  }

  Stream<List<BusRoute>> watchActiveRoutes() =>
      Db.routes.where('isActive', isEqualTo: true).snapshots().docsList;

  /// The route this driver is assigned to. Returns null while unassigned,
  /// which the driver UI should surface rather than crash on.
  Future<BusRoute?> fetchRouteForDriver(String driverId) async {
    final snap =
        await Db.routes.where('driverId', isEqualTo: driverId).limit(1).get();
    return snap.docs.isEmpty ? null : snap.docs.first.data();
  }

  Stream<BusRoute?> watchRouteForDriver(String driverId) => Db.routes
      .where('driverId', isEqualTo: driverId)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : s.docs.first.data());

  Future<String> createRoute(BusRoute route) async {
    final ref = await Db.routes.add(route);
    await ref.update({'createdAt': Db.now, 'updatedAt': Db.now});
    return ref.id;
  }

  Future<void> updateRoute(String routeId, Map<String, dynamic> fields) =>
      Db.fs
          .collection('routes')
          .doc(routeId)
          .update({...fields, 'updatedAt': Db.now});

  /// Replaces the whole embedded stop list. Stops are embedded rather than kept
  /// in their own collection because they are always read with the route.
  Future<void> replaceStops(String routeId, List<RouteStop> stops) =>
      updateRoute(routeId, {'stops': stops.map((s) => s.toMap()).toList()});

  // ── Buses ─────────────────────────────────────────────────────────────────

  Stream<Bus?> watchBus(String busId) =>
      Db.buses.doc(busId).snapshots().map((s) => s.data());

  Future<Bus?> fetchBus(String busId) async {
    final snap = await Db.buses.doc(busId).get();
    return snap.data();
  }

  Stream<List<Bus>> watchAllBuses() => Db.buses.snapshots().docsList;

  Future<String> createBus(Bus bus) async {
    final ref = await Db.buses.add(bus);
    await ref.update({'createdAt': Db.now, 'updatedAt': Db.now});
    return ref.id;
  }

  Future<void> updateBus(String busId, Map<String, dynamic> fields) =>
      Db.fs.collection('buses').doc(busId).update({...fields, 'updatedAt': Db.now});
}
