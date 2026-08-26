import 'package:transit_core/transit_core.dart';

import 'db.dart';

/// The missed-bus request lifecycle, now genuinely cross-device.
///
/// In the prototype this worked only because every role ran in one process
/// reading the same RAM. Backed by Firestore, a student raises a request on
/// their phone and it appears on the driver's phone for real.
class MissedBusRepository {
  MissedBusRepository._();
  static final MissedBusRepository instance = MissedBusRepository._();

  /// The requester's own active request — drives the 4-state UI
  /// (form → searching → accepted → no drivers).
  ///
  /// `declined`/`noDrivers` are included, not just `searching`/`accepted`:
  /// the requester needs to actually see the "no bus available" screen, not
  /// have it silently vanish back to the form the instant a driver declines.
  /// `cancelled` is excluded — that is the terminal state [cancelRequest]
  /// writes once the requester dismisses a resolved request, and is also
  /// what a fresh cancel should immediately revert to the empty form for.
  Stream<MissedBusRequest?> watchActiveForStudent(String studentId) =>
      Db.missedBusRequests
          .where('studentId', isEqualTo: studentId)
          .where('status', whereIn: [
            MissedBusStatus.searching.name,
            MissedBusStatus.accepted.name,
            MissedBusStatus.declined.name,
            MissedBusStatus.noDrivers.name,
          ])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots()
          .map((s) => s.docs.isEmpty ? null : s.docs.first.data());

  /// The driver's incoming queue — every request still searching for a bus.
  Stream<List<MissedBusRequest>> watchOpenRequests() => Db.missedBusRequests
      .where('status', isEqualTo: MissedBusStatus.searching.name)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .docsList;

  Future<String> raiseRequest(MissedBusRequest request) async {
    final ref = await Db.missedBusRequests.add(request);
    await ref.update({'createdAt': Db.now});
    return ref.id;
  }

  /// A driver claims the request. Assignment details, including the fare,
  /// come from the accepting driver's own record — the prototype overwrote
  /// them with a hardcoded bus. The fare is copied in now rather than read
  /// live later, so a driver changing their rate afterwards cannot alter
  /// what a requester was already told.
  Future<void> acceptRequest({
    required String requestId,
    required Driver driver,
    required Bus bus,
    int? etaMinutes,
  }) =>
      Db.fs.collection('missedBusRequests').doc(requestId).update({
        'status': MissedBusStatus.accepted.name,
        'assignedDriverId': driver.id,
        'assignedDriverName': driver.name,
        'assignedDriverPhone': driver.phone,
        'assignedBusId': bus.id,
        'assignedBusNumber': bus.busNumber,
        'etaMinutes': ?etaMinutes,
        'farePaisa': ?(driver.missedBusFarePaisa > 0 ? driver.missedBusFarePaisa : null),
        'resolvedAt': Db.now,
      });

  Future<void> declineRequest(String requestId) =>
      Db.fs.collection('missedBusRequests').doc(requestId).update({
        'status': MissedBusStatus.declined.name,
        'resolvedAt': Db.now,
      });

  Future<void> cancelRequest(String requestId) =>
      Db.fs.collection('missedBusRequests').doc(requestId).update({
        'status': MissedBusStatus.cancelled.name,
        'resolvedAt': Db.now,
      });

  /// Called when the search window expires with no driver having accepted.
  Future<void> markNoDriversAvailable(String requestId) =>
      Db.fs.collection('missedBusRequests').doc(requestId).update({
        'status': MissedBusStatus.noDrivers.name,
        'resolvedAt': Db.now,
      });
}
