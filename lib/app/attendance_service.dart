import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

/// Mock backend for the per-day attendance notice a parent sends a driver —
/// "my child is/isn't riding on {date}" — read by the day selector's dot in
/// `parent_schedule.dart` and, on the driver's side, whatever builds the
/// day's pickup roster.
///
/// **Mock for now, deliberately.** There is no backend for this yet — see
/// `IMPLEMENTATION.md` P2-11, which sketches the same
/// `students/{id}/.../{dateKey}` shape this mock stands in for. This class
/// exists so the UI has something real to call, updates state optimistically,
/// and is honest about not persisting anywhere yet, the same pattern
/// `_submitAttendance`'s old TODO comment and `student_schedule.dart`'s
/// `_ManualTimetableSection._saveSchedule` already use elsewhere in this app.
class AttendanceService {
  AttendanceService._();
  static final AttendanceService instance = AttendanceService._();

  /// Records whether [studentId] is attending on [date].
  ///
  /// Real replacement — one small document per student per day, not a field
  /// on the student or a whole-week blob:
  ///
  /// ```dart
  /// // Firestore
  /// final dateKey = Trip.dateKeyFor(date); // 'YYYY-MM-DD', shared format
  /// await FirebaseFirestore.instance
  ///     .collection('students').doc(studentId)
  ///     .collection('attendance').doc(dateKey)
  ///     .set({
  ///       'isAttending': isAttending,
  ///       'updatedAt': FieldValue.serverTimestamp(),
  ///     });
  /// ```
  ///
  /// ```dart
  /// // Supabase
  /// await supabase.from('attendance').upsert({
  ///   'student_id': studentId,
  ///   'date_key': dateKey,
  ///   'is_attending': isAttending,
  /// });
  /// ```
  ///
  /// Either way this write should also raise a driver-facing notification —
  /// the same channel `NotificationService`/`MessagingRepository` already
  /// uses for ride-request replies — so the driver doesn't have to poll to
  /// find out. Not added here; out of scope for this mock.
  Future<void> updateAttendance({
    required String studentId,
    required DateTime date,
    required bool isAttending,
  }) async {
    final dateKey = Trip.dateKeyFor(date);
    await Future.delayed(const Duration(milliseconds: 400));
    debugPrint(
      'AttendanceService (mock): $studentId @ $dateKey -> '
      '${isAttending ? 'attending' : 'absent'}',
    );
  }
}
