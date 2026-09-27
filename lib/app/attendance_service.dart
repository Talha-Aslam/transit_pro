import 'package:transit_core/transit_core.dart';

/// The per-day attendance notice a parent sends a driver — "my child
/// is/isn't riding on {date}" — read by the day selector's dot in
/// `parent_schedule.dart` and, on the driver's side, whatever builds the
/// day's pickup roster.
///
/// One small document per student per day, keyed by [Trip.dateKeyFor] (the
/// same `YYYY-MM-DD` format trip history already uses), not a single field
/// on the student document — so the family's history of notices is never
/// overwritten, just added to. Distinct from `AttendanceRecord`
/// (`trips/{tripId}/attendance/{studentId}`), which is the driver's record
/// of who actually boarded a specific route run; this is the family's own
/// advance notice, sent before that trip ever starts.
class AttendanceService {
  AttendanceService._();
  static final AttendanceService instance = AttendanceService._();

  /// Records whether [studentId] is attending on [date].
  Future<void> updateAttendance({
    required String studentId,
    required DateTime date,
    required bool isAttending,
  }) async {
    final dateKey = Trip.dateKeyFor(date);
    await Db.fs
        .collection('students')
        .doc(studentId)
        .collection('attendance')
        .doc(dateKey)
        .set({'isAttending': isAttending, 'updatedAt': Db.now});
  }
}
