import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:transit_core/transit_core.dart';

import 'db.dart';

/// Raised when a request cannot proceed for a reason the user needs to read —
/// the round filled up, the request was already answered, the driver changed
/// their schedule. Distinct from a Firestore error: these are all normal
/// outcomes of two people using the app at once, not faults.
class RideRequestException implements Exception {
  final String message;
  const RideRequestException(this.message);

  @override
  String toString() => message;
}

/// The seat-booking lifecycle: a family asks, a driver answers, a seat moves.
///
/// ## Why the queries here have no `orderBy`
///
/// Every read is a single-field equality filter, which Firestore serves from its
/// automatic index — no `firestore.indexes.json` entry, no console round trip
/// when a new screen needs a new view. Adding `.orderBy('createdAt')` to
/// `driverId == X` would demand a composite index, and this collection holds a
/// handful of documents per user, so sorting in memory costs nothing. That
/// tradeoff is deliberate: composite indexes have to be created by hand for this
/// project (there is no CI deploy yet), and every one of them is a way for the
/// app to break in production while working in development.
class RideRequestRepository {
  RideRequestRepository._();
  static final RideRequestRepository instance = RideRequestRepository._();

  DocumentReference<Map<String, dynamic>> _rawRequest(String id) =>
      Db.fs.collection('ride_requests').doc(id);

  DocumentReference<Map<String, dynamic>> _rawDriver(String id) =>
      Db.fs.collection('drivers').doc(id);

  // ── Reads ─────────────────────────────────────────────────────────────────

  /// A driver's inbox: every request ever sent to them, newest first.
  ///
  /// Returns all statuses rather than just `pending` so the driver can see what
  /// they have already answered — and so accepting does not make the card vanish
  /// mid-tap, which reads as a crash.
  Stream<List<RideRequest>> watchForDriver(String driverId) => Db.rideRequests
      .where('driverId', isEqualTo: driverId)
      .snapshots()
      .docsList
      .map(_newestFirst);

  /// Everything one family has asked for, across all their children.
  Stream<List<RideRequest>> watchForRequester(String requesterId) =>
      Db.rideRequests
          .where('requesterId', isEqualTo: requesterId)
          .snapshots()
          .docsList
          .map(_newestFirst);

  Future<RideRequest?> fetch({
    required String driverId,
    required String studentId,
  }) async {
    final snap = await Db.rideRequests
        .doc(RideRequest.idFor(driverId: driverId, studentId: studentId))
        .get();
    return snap.data();
  }

  static List<RideRequest> _newestFirst(List<RideRequest> list) {
    final sorted = [...list];
    sorted.sort((a, b) {
      final ad = a.createdAt;
      final bd = b.createdAt;
      // A document whose server timestamp has not landed yet sorts first: it is
      // the one the user just created, and burying it at the bottom would look
      // like the write failed.
      if (ad == null && bd == null) return 0;
      if (ad == null) return -1;
      if (bd == null) return 1;
      return bd.compareTo(ad);
    });
    return sorted;
  }

  // ── Family side ───────────────────────────────────────────────────────────

  /// Sends, or re-sends, a request for one child to one driver's round.
  ///
  /// Overwrites any previous request for the same driver/student pair — the
  /// composite document id makes that automatic, which is what stops a driver's
  /// inbox filling with repeat taps and lets a family re-ask after a decline
  /// without leaving a rejected row behind.
  ///
  /// Refuses to overwrite an already-accepted request: re-sending would silently
  /// reset a booked seat to pending and leave the driver's seat count wrong.
  Future<RideRequest> send({
    required String requesterId,
    required Student student,
    required Driver driver,
    required DriverSchedule schedule,
    String? note,
  }) async {
    final id = RideRequest.idFor(driverId: driver.id, studentId: student.id);

    final existing = await Db.rideRequests.doc(id).get();
    final prior = existing.data();
    if (prior != null && prior.isAccepted) {
      throw const RideRequestException(
        'This driver has already accepted this child. Cancel the current seat '
        'before requesting a different one.',
      );
    }
    if (prior != null && prior.isPending) {
      throw const RideRequestException(
        'You already have a request waiting with this driver.',
      );
    }

    if (!schedule.hasSpace) {
      throw const RideRequestException(
        'That round just filled up. Pick another round or another driver.',
      );
    }

    final request = RideRequest(
      id: id,
      requesterId: requesterId,
      studentId: student.id,
      driverId: driver.id,
      scheduleId: schedule.id,
      status: RideRequestStatus.pending,
      studentName: student.name,
      studentGrade: student.grade,
      school: student.school,
      driverName: driver.name,
      scheduleLabel: '${schedule.label} · ${schedule.directionLabel} '
          '${schedule.timeRange}',
      pickupLocation: student.pickupLocation,
      note: note,
    );

    await Db.rideRequests.doc(id).set(request);
    // Separate write: a server timestamp cannot travel through `withConverter`,
    // which serialises a typed model and has no place to put a sentinel.
    await _rawRequest(id).set(
      {'createdAt': Db.now, 'respondedAt': null},
      SetOptions(merge: true),
    );
    return request;
  }

  /// The family withdrawing before the driver has answered.
  Future<void> cancel(String requestId) => _rawRequest(requestId).update({
        'status': RideRequestStatus.cancelled.name,
        'respondedAt': Db.now,
      });

  // ── Driver side ───────────────────────────────────────────────────────────

  /// Accepts a request and books the seat **atomically**.
  ///
  /// Both mutations — the request's status and the round's `bookedSeats` — happen
  /// in one transaction. Without it, two parents racing for the last seat both
  /// read `availableSeats: 1`, both writes succeed, and the round is oversold
  /// with nothing in the data to show it happened. The transaction makes the
  /// second attempt re-read and fail honestly.
  ///
  /// Linking the student to the driver is deliberately a *separate* write, after
  /// this commits — see [linkStudentToDriver] for why the ordering matters to
  /// the security rules.
  Future<void> accept({
    required String requestId,
    required String driverId,
  }) async {
    await Db.fs.runTransaction((tx) async {
      final requestSnap = await tx.get(_rawRequest(requestId));
      final driverSnap = await tx.get(_rawDriver(driverId));

      if (!requestSnap.exists) {
        throw const RideRequestException('That request no longer exists.');
      }
      if (!driverSnap.exists) {
        throw const RideRequestException(
          'Your driver profile could not be read. Try again in a moment.',
        );
      }

      final request = RideRequest.fromMap(requestSnap.id, requestSnap.data()!);
      if (request.driverId != driverId) {
        throw const RideRequestException('That request is not addressed to you.');
      }
      if (request.isAccepted) {
        // Not an error. The follow-up student write may have failed last time,
        // leaving the request accepted but the roster incomplete, and the driver
        // tapping Accept again is exactly how that gets repaired. Returning
        // quietly lets the caller re-run the link step without double-booking
        // the seat.
        return;
      }
      if (!request.isPending) {
        throw const RideRequestException(
          'That request was already closed, so it cannot be accepted.',
        );
      }

      final driver = Driver.fromMap(driverSnap.id, driverSnap.data()!);
      final schedule = driver.scheduleById(request.scheduleId);
      if (schedule == null) {
        throw const RideRequestException(
          'The round this family asked for no longer exists on your schedule. '
          'Ask them to send a new request.',
        );
      }
      if (!schedule.hasSpace) {
        throw const RideRequestException(
          'That round is full. Free a seat or add capacity before accepting.',
        );
      }

      final updated = driver.schedules
          .map(
            (s) => s.id == schedule.id
                ? s.copyWith(bookedSeats: s.bookedSeats + 1)
                : s,
          )
          .map((s) => s.toMap())
          .toList();

      tx.update(_rawDriver(driverId), {
        'schedules': updated,
        'updatedAt': Db.now,
      });
      tx.update(_rawRequest(requestId), {
        'status': RideRequestStatus.accepted.name,
        'respondedAt': Db.now,
      });
    });
  }

  /// Writes the driver, round and vehicle onto the student record.
  ///
  /// Runs **after** [accept] has committed, not inside it, because the security
  /// rule that authorises a driver to write someone else's student document
  /// checks that the matching ride request is already `accepted`. A rule
  /// evaluates against committed state, so a same-transaction write would still
  /// see `pending` and be denied.
  ///
  /// The cost is that the two steps are not atomic. That is the acceptable half
  /// of the trade: if this write fails the seat is booked and the request says
  /// accepted, and re-tapping Accept re-runs the link without re-booking (see
  /// the early return in [accept]). The reverse arrangement — an atomic pair
  /// guarded by a rule loose enough to permit it — would let any driver claim
  /// any student.
  Future<void> linkStudentToDriver({
    required String studentId,
    required String driverId,
    required String scheduleId,
    String? busId,
  }) =>
      Db.fs.collection('students').doc(studentId).update({
        'driverId': driverId,
        'scheduleId': scheduleId,
        if (busId != null && busId.isNotEmpty) 'busId': busId,
        'updatedAt': Db.now,
      });

  /// Declines a request. No seat moves, so no transaction is needed.
  Future<void> reject({
    required String requestId,
    String? responseNote,
  }) =>
      _rawRequest(requestId).update({
        'status': RideRequestStatus.rejected.name,
        if (responseNote != null && responseNote.trim().isNotEmpty)
          'responseNote': responseNote.trim(),
        'respondedAt': Db.now,
      });

  /// A driver removing an accepted student, returning the seat to the pool.
  ///
  /// Transactional for the same reason as [accept]: the decrement must be a
  /// read-modify-write against current state, or two concurrent removals both
  /// subtract from the same starting value and the round leaks a seat.
  Future<void> release({
    required String requestId,
    required String driverId,
    required String studentId,
  }) async {
    await Db.fs.runTransaction((tx) async {
      final requestSnap = await tx.get(_rawRequest(requestId));
      final driverSnap = await tx.get(_rawDriver(driverId));
      if (!requestSnap.exists || !driverSnap.exists) {
        throw const RideRequestException('That booking could not be read.');
      }

      final request = RideRequest.fromMap(requestSnap.id, requestSnap.data()!);
      if (request.driverId != driverId) {
        throw const RideRequestException('That booking is not yours to change.');
      }
      if (!request.isAccepted) {
        throw const RideRequestException(
          'That request is not an active booking.',
        );
      }

      final driver = Driver.fromMap(driverSnap.id, driverSnap.data()!);
      final updated = driver.schedules
          .map(
            (s) => s.id == request.scheduleId && s.bookedSeats > 0
                ? s.copyWith(bookedSeats: s.bookedSeats - 1)
                : s,
          )
          .map((s) => s.toMap())
          .toList();

      tx.update(_rawDriver(driverId), {
        'schedules': updated,
        'updatedAt': Db.now,
      });
      tx.update(_rawRequest(requestId), {
        'status': RideRequestStatus.rejected.name,
        'responseNote': 'Seat released by the driver.',
        'respondedAt': Db.now,
      });
    });

    // Best-effort: the seat is already back in the pool, which is the part that
    // must not be wrong. A stale `driverId` on the student shows as a phantom
    // roster row the driver can clear by tapping Remove again.
    await Db.fs.collection('students').doc(studentId).update({
      'driverId': FieldValue.delete(),
      'scheduleId': FieldValue.delete(),
      'updatedAt': Db.now,
    });
  }
}
