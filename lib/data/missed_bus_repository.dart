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
  Stream<MissedBusRequest?> watchActiveForStudent(String studentId) =>
      Db.missedBusRequests
          .where('studentId', isEqualTo: studentId)
          .where('status', whereIn: [
            MissedBusStatus.searching.name,
            MissedBusStatus.accepted.name,
          ])
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

  /// A driver claims the request. Assignment details come from the accepting
  /// driver's own record — the prototype overwrote them with a hardcoded bus.
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
