import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:transit_core/transit_core.dart';

import 'db.dart';

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
    final ref = Db.trips.doc(); // client-side id so we can return it immediately

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
        Db.fs.collection('trips').doc(ref.id).collection('attendance').doc(s.id),
        AttendanceRecord(
          studentId: s.id,
          studentName: s.name,
          stopId: s.stopId,
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

  Future<void> cancelTrip(String tripId) =>
      Db.fs.collection('trips').doc(tripId).update({
        'status': TripStatus.cancelled.name,
        'endedAt': Db.now,
      });

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
  Stream<List<Trip>> watchTripsForRoute(String routeId, {int limit = 50}) =>
      Db.trips
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

  Future<void> markAttendance({
    required String tripId,
    required String studentId,
    required AttendanceStatus status,
    required String markedBy,
    String? stopId,
  }) =>
      Db.fs
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

  /// A student's attendance across trips — powers parent/student trip history.
  Future<List<AttendanceRecord>> fetchAttendanceForStudent(
    String studentId, {
    int limit = 50,
  }) async {
    final snap = await Db.fs
        .collectionGroup('attendance')
        .where(FieldPath.documentId, isEqualTo: studentId)
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
        case AttendanceStatus.boarded:
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
