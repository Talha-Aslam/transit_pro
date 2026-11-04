import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:transit_core/transit_core.dart';

/// Trips and their attendance subcollection.
///
/// A trip is created by **Start Route** and closed by **End Route** — controls
/// the prototype never had. Everything else (live position, attendance,
/// geofence alerts) hangs off the active trip id.
class TripRepository {
  TripRepository._();
  static final TripRepository instance = TripRepository._();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Starts a trip and seeds one attendance row per student on the route, so
  /// the driver's attendance screen is populated the moment the route begins.
  Future<Trip> startTrip({
    required BusRoute route,
    required String driverId,
    required String busId,
    required TripType type,
    required List<Student> students,
  }) async {
    final now = DateTime.now();
    final ref = Db.trips
        .doc(); // client-side id so we can return it immediately

    final trip = Trip(
      id: ref.id,
      routeId: route.id,
      busId: busId,
      driverId: driverId,
      dateKey: Trip.dateKeyFor(now),
      type: type,
      status: TripStatus.inProgress,
      startedAt: now,
      studentsExpected: students.length,
    );

    // The trip document and the whole manifest commit together, so a half-open
    // trip with no students can never exist.
    final batch = Db.fs.batch();
    batch.set(Db.fs.collection('trips').doc(ref.id), {
      ...trip.toMap(),
      'startedAt': Db.now,
    });
    for (final s in students) {
      batch.set(
        Db.fs
            .collection('trips')
            .doc(ref.id)
            .collection('attendance')
            .doc(s.id),
        AttendanceRecord(
          studentId: s.id,
          studentName: s.name,
          stopId: s.stopId,
          // Denormalised so `fetchAttendanceForStudent`'s collection-group
          // query can filter/sort without reading the parent trip.
          tripId: ref.id,
          dateKey: trip.dateKey,
          driverId: driverId,
        ).toMap(),
      );
    }
    await batch.commit();

    return trip;
  }

  /// Closes the trip and stamps the on-time verdict.
  Future<void> endTrip(String tripId, {bool? onTime, int? delayMinutes}) async {
    final counts = await _attendanceCounts(tripId);
    await Db.fs.collection('trips').doc(tripId).update({
      'status': TripStatus.completed.name,
      'endedAt': Db.now,
      'studentsBoarded': counts.$1,
      'studentsAbsent': counts.$2,
      'onTime': ?onTime,
      'delayMinutes': ?delayMinutes,
    });
  }

  Future<void> cancelTrip(String tripId) => Db.fs
      .collection('trips')
      .doc(tripId)
      .update({'status': TripStatus.cancelled.name, 'endedAt': Db.now});

  // ── Queries ───────────────────────────────────────────────────────────────

  Stream<Trip?> watchTrip(String tripId) =>
      Db.trips.doc(tripId).snapshots().map((s) => s.data());

  /// The driver's currently running trip, if any. Drives the Start/End button.
  Stream<Trip?> watchActiveTripForDriver(String driverId) => Db.trips
      .where('driverId', isEqualTo: driverId)
      .where('status', isEqualTo: TripStatus.inProgress.name)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : s.docs.first.data());

  /// The live trip on a route — what parents and students watch.
  Stream<Trip?> watchActiveTripForRoute(String routeId) => Db.trips
      .where('routeId', isEqualTo: routeId)
      .where('status', isEqualTo: TripStatus.inProgress.name)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : s.docs.first.data());

  /// Trip history for a route, newest first.
  Stream<List<Trip>> watchTripsForRoute(String routeId, {int limit = 50}) => Db
      .trips
      .where('routeId', isEqualTo: routeId)
      .orderBy('dateKey', descending: true)
      .limit(limit)
      .snapshots()
      .docsList;

  Stream<List<Trip>> watchTripsForDriver(String driverId, {int limit = 50}) =>
      Db.trips
          .where('driverId', isEqualTo: driverId)
          .orderBy('dateKey', descending: true)
          .limit(limit)
          .snapshots()
          .docsList;

  // ── Attendance ────────────────────────────────────────────────────────────

  Stream<List<AttendanceRecord>> watchAttendance(String tripId) =>
      Db.attendance(tripId).snapshots().docsList;

  /// One student's own attendance row on one trip.
  ///
  /// A parent/student may only read their own child's attendance document
  /// (`firestore.rules`'s `ownsStudent(studentId)` check on
  /// `trips/{tripId}/attendance/{studentId}`) — [watchAttendance] queries the
  /// whole subcollection, which Firestore rejects for anyone but the trip's
  /// driver or an admin. This is the query a family's own tracking screen
  /// can actually run.
  Stream<AttendanceRecord?> watchAttendanceForStudent(
    String tripId,
    String studentId,
  ) => Db.attendance(tripId).doc(studentId).snapshots().map((s) => s.data());

  Future<void> markAttendance({
    required String tripId,
    required String studentId,
    required AttendanceStatus status,
    required String markedBy,
    String? stopId,
  }) => Db.fs
      .collection('trips')
      .doc(tripId)
      .collection('attendance')
      .doc(studentId)
      .set({
        'status': status.name,
        'markedAt': Db.now,
        'markedBy': markedBy,
        'stopId': ?stopId,
      }, SetOptions(merge: true));

  /// Marks everyone still aboard [tripId] as handed over.
  ///
  /// Called when the bus reaches the far end of the leg, and again when the
  /// driver closes the round. Without it `boarded` is a one-way door: the
  /// last thing a family is ever told is that their child got on, which is
  /// why a parent dashboard said "On the bus" long after the child was
  /// sitting in class.
  ///
  /// Returns how many records changed, so a caller can skip the write when
  /// there is nothing to do.
  Future<int> markRemainingDroppedOff({
    required String tripId,
    required String markedBy,
  }) async {
    final snap = await Db.attendance(tripId).get();
    final aboard = snap.docs
        .where((d) => d.data().status == AttendanceStatus.boarded)
        .toList();
    if (aboard.isEmpty) return 0;

    final batch = Db.fs.batch();
    for (final doc in aboard) {
      batch.set(
        Db.fs
            .collection('trips')
            .doc(tripId)
            .collection('attendance')
            .doc(doc.id),
        {
          'status': AttendanceStatus.droppedOff.name,
          'markedAt': Db.now,
          'markedBy': markedBy,
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    return aboard.length;
  }

  /// Student ids on [tripId] that the driver never recorded either way.
  ///
  /// A missing record is not the same as an absence: it means nobody looked.
  /// The family is left reading "waiting to board" for a ride that has
  /// already finished, and the only person who can say what happened is the
  /// driver, who has to be told they skipped it.
  Future<List<String>> unmarkedStudents(String tripId) async {
    final snap = await Db.attendance(tripId).get();
    return [
      for (final doc in snap.docs)
        if (doc.data().status == AttendanceStatus.pending) doc.id,
    ];
  }

  /// A student's attendance across trips, newest first — powers
  /// parent/student trip history.
  ///
  /// This used to filter with `where(FieldPath.documentId, isEqualTo:
  /// studentId)`, which silently returned nothing: a collection-group query's
  /// `__name__`/document-id comparison requires a *full document path*
  /// (`trips/{tripId}/attendance/{studentId}`), not a bare id, and nothing
  /// here ever had the full path to give it. Filtering on the real
  /// `studentId` *field* instead — written by [startTrip] since
  /// `AttendanceRecord` gained denormalised `studentId`/`dateKey` — is what
  /// actually works. Needs the composite index in `firestore.indexes.json`
  /// on the `attendance` collection group (`studentId` asc, `dateKey` desc).
  Future<List<AttendanceRecord>> fetchAttendanceForStudent(
    String studentId, {
    int limit = 50,
  }) async {
    final snap = await Db.fs
        .collectionGroup('attendance')
        .where('studentId', isEqualTo: studentId)
        .orderBy('dateKey', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => AttendanceRecord.fromMap(d.id, d.data()))
        .toList();
  }

  /// Returns `(boarded, absent)`.
  Future<(int, int)> _attendanceCounts(String tripId) async {
    final snap = await Db.attendance(tripId).get();
    var boarded = 0;
    var absent = 0;
    for (final doc in snap.docs) {
      switch (doc.data().status) {
        // A child handed over at the other end rode the bus, so they count
        // towards the trip's boarded total exactly as they did an hour ago.
        case AttendanceStatus.boarded:
        case AttendanceStatus.droppedOff:
          boarded++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.pending:
          break;
      }
    }
    return (boarded, absent);
  }
}
