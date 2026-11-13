import 'package:transit_core/transit_core.dart';

/// Raised when a second driver opens a request the first one already took.
///
/// A normal outcome of two drivers watching the same queue, not a fault —
/// which is why it carries a sentence written for the driver rather than a
/// Firestore code.
class RequestAlreadyTakenException implements Exception {
  final String message;
  const RequestAlreadyTakenException([
    this.message =
        'Another driver reached this one first. It has been taken off '
        'your queue.',
  ]);

  @override
  String toString() => message;
}

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
  Stream<MissedBusRequest?> watchActiveForStudent(String studentId) => Db
      .missedBusRequests
      .where('studentId', isEqualTo: studentId)
      .where(
        'status',
        whereIn: [
          MissedBusStatus.searching.name,
          MissedBusStatus.viewing.name,
          MissedBusStatus.bidOffered.name,
          MissedBusStatus.accepted.name,
          MissedBusStatus.declined.name,
          MissedBusStatus.noDrivers.name,
        ],
      )
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : s.docs.first.data());

  /// The driver's incoming queue — every request still searching for a bus.
  ///
  /// Deliberately still `searching` only, not `viewing`/`bidOffered` too: once
  /// a driver has opened a request it moves into that driver's own
  /// [watchMyActiveBid], not the shared queue every other driver also sees —
  /// otherwise a second driver could bid on a request someone else is already
  /// negotiating.
  Stream<List<MissedBusRequest>> watchOpenRequests() => Db.missedBusRequests
      .where('status', isEqualTo: MissedBusStatus.searching.name)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .docsList;

  /// The request this specific driver is currently viewing or has bid on —
  /// drives the driver's own "your offer is pending" UI, separate from the
  /// shared open queue above.
  Stream<MissedBusRequest?> watchMyActiveBid(String driverId) => Db
      .missedBusRequests
      .where('assignedDriverId', isEqualTo: driverId)
      .where(
        'status',
        whereIn: [
          MissedBusStatus.viewing.name,
          MissedBusStatus.bidOffered.name,
        ],
      )
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : s.docs.first.data());

  Future<String> raiseRequest(MissedBusRequest request) async {
    final ref = await Db.missedBusRequests.add(request);
    await ref.update({'createdAt': Db.now});
    return ref.id;
  }

  /// Step 1 of the bidding flow: a driver opens a request to look at it.
  /// Denormalises driver + bus identity onto the document immediately
  /// (rather than waiting until a fare is sent, or until final acceptance
  /// the way the old single-step flow did), so the requester's UI can show
  /// "X is viewing your request" and, once a bid follows, a driver profile
  /// card — with no second read needed.
  /// Claims the request for [driver], or refuses because somebody else got
  /// there first.
  ///
  /// A transaction, not an update. Two drivers watching the same queue both
  /// read "unclaimed" and both tapped; the rules cannot serialise that —
  /// each write is individually legal — so both succeeded, the second
  /// silently overwrote the first, and two drivers drove to the same child.
  /// Re-reading inside the transaction is what makes the second one lose.
  Future<void> markViewing({
    required String requestId,
    required Driver driver,
    required Bus bus,
  }) async {
    final ref = Db.fs.collection('missedBusRequests').doc(requestId);
    await Db.fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const RequestAlreadyTakenException(
          'That request is no longer open.',
        );
      }
      final data = snap.data() ?? const <String, dynamic>{};
      final holder = data['assignedDriverId'] as String?;
      if (holder != null && holder.isNotEmpty && holder != driver.id) {
        throw const RequestAlreadyTakenException();
      }
      final status = asEnum(
        data['status'],
        MissedBusStatus.values,
        MissedBusStatus.searching,
      );
      // Already answered, cancelled or resolved: opening it now would
      // reopen a closed conversation on the requester's screen.
      if (status != MissedBusStatus.searching &&
          status != MissedBusStatus.viewing &&
          status != MissedBusStatus.bidOffered) {
        throw const RequestAlreadyTakenException(
          'That request has already been resolved.',
        );
      }

      tx.update(ref, {
        'status': MissedBusStatus.viewing.name,
        'assignedDriverId': driver.id,
        'assignedDriverName': driver.name,
        'assignedDriverPhone': driver.phone,
        'assignedDriverPhotoUrl': ?driver.photoUrl,
        'assignedBusId': bus.id,
        'assignedBusNumber': bus.busNumber,
      });
    });
  }

  /// Step 2: the viewing driver proposes a fare. Only the driver already on
  /// `assignedDriverId` should ever reach this — enforced by
  /// firestore.rules, not just by this client skipping the UI for anyone
  /// else.
  Future<void> sendBid({required String requestId, required int farePaisa}) =>
      Db.fs.collection('missedBusRequests').doc(requestId).update({
        'status': MissedBusStatus.bidOffered.name,
        'farePaisa': farePaisa,
      });

  /// Step 3a: the requester accepts the pending bid. The driver, bus and
  /// fare are already on the document from the two steps above, so this
  /// only has to flip the status.
  Future<void> confirmOffer(String requestId) => Db.fs
      .collection('missedBusRequests')
      .doc(requestId)
      .update({'status': MissedBusStatus.accepted.name, 'resolvedAt': Db.now});

  /// Step 3b: the requester rejects the pending bid — or a driver withdraws
  /// one they already sent. Reopens the request for other drivers rather
  /// than ending it outright: only this one driver's offer was unacceptable,
  /// not the request itself.
  Future<void> rejectOffer(String requestId) =>
      Db.fs.collection('missedBusRequests').doc(requestId).update({
        'status': MissedBusStatus.searching.name,
        'assignedDriverId': null,
        'assignedDriverName': null,
        'assignedDriverPhone': null,
        'assignedDriverPhotoUrl': null,
        'assignedBusId': null,
        'assignedBusNumber': null,
        'farePaisa': null,
      });

  Future<void> declineRequest(String requestId) => Db.fs
      .collection('missedBusRequests')
      .doc(requestId)
      .update({'status': MissedBusStatus.declined.name, 'resolvedAt': Db.now});

  Future<void> cancelRequest(String requestId) => Db.fs
      .collection('missedBusRequests')
      .doc(requestId)
      .update({'status': MissedBusStatus.cancelled.name, 'resolvedAt': Db.now});

  /// Called when the search window expires with no driver having accepted.
  Future<void> markNoDriversAvailable(String requestId) => Db.fs
      .collection('missedBusRequests')
      .doc(requestId)
      .update({'status': MissedBusStatus.noDrivers.name, 'resolvedAt': Db.now});
}
