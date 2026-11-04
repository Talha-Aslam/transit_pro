import 'package:transit_core/transit_core.dart';

/// `incidents/{incidentId}` — SOS events raised from the driver's phone.
///
/// The driver dashboard's SOS button alerted the families and stopped
/// there: nothing was recorded, so an admin reviewing the week had no way
/// to know an emergency had been raised, and the driver's own safety score
/// had nothing to be computed from. This is the record.
class IncidentRepository {
  IncidentRepository._();
  static final IncidentRepository instance = IncidentRepository._();

  /// Files an incident and returns its id.
  Future<String> raise(Incident incident) async {
    final ref = await Db.incidents.add(incident);
    await ref.update({'createdAt': Db.now});
    return ref.id;
  }

  /// Every incident filed against [driverId], newest first.
  ///
  /// Deliberately unfiltered by resolution: a resolved emergency still
  /// happened, and a safety score that forgets it the moment an admin
  /// closes the ticket would be worth nothing.
  Stream<List<Incident>> watchForDriver(String driverId, {int limit = 200}) =>
      Db.incidents
          .where('driverId', isEqualTo: driverId)
          .limit(limit)
          .snapshots()
          .docsList;
}
