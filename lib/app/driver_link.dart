import 'package:transit_core/transit_core.dart';

/// Whether [s] is carried by anyone: a driver accepted them, or an admin put
/// them on a route.
///
/// A bus id with neither is a leftover — seats released before releasing
/// cleared the bus too — and must not keep a removed driver on the family's
/// screens.
bool isLinkedToDriver(Student s) =>
    (s.driverId ?? '').isNotEmpty || (s.routeId ?? '').isNotEmpty;

/// Who drives [s]: the driver who accepted them, or — for a child an admin
/// put on a route — that route's bus driver. Empty when nobody does.
String driverIdOf(Student s, Bus? bus) {
  final own = s.driverId ?? '';
  if (own.isNotEmpty) return own;
  if ((s.routeId ?? '').isNotEmpty) return bus?.driverId ?? '';
  return '';
}
