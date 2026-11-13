import 'package:transit_core/transit_core.dart';

import 'driver_data_service.dart' show kWeekdayKeys;

/// One child's timings for one day, as their family recorded them on
/// `Student.requestedSchedule` — when the institute starts and ends, and the
/// pickup and drop-off they would like from the van.
///
/// Read the same way by the family's Home screen and by the driver, so the
/// two can never show different times for the same child.
class WeeklyTimes {
  const WeeklyTimes({
    this.schoolStartAt = '',
    this.schoolEndAt = '',
    this.pickupAt = '',
    this.dropoffAt = '',
  });

  static const schoolStart = 'schoolStart';
  static const schoolEnd = 'schoolEnd';
  static const pickup = 'morningPickup';
  static const dropoff = 'eveningDropoff';

  /// `HH:mm`, or empty when the family has not set it.
  final String schoolStartAt;
  final String schoolEndAt;
  final String pickupAt;
  final String dropoffAt;

  bool get isEmpty =>
      schoolStartAt.isEmpty &&
      schoolEndAt.isEmpty &&
      pickupAt.isEmpty &&
      dropoffAt.isEmpty;

  /// [student]'s timings on [day] — today unless given. Sunday has none.
  static WeeklyTimes on(Student student, [DateTime? day]) {
    final weekday = (day ?? DateTime.now()).weekday;
    if (weekday == DateTime.sunday) return const WeeklyTimes();
    final times = student.requestedSchedule[kWeekdayKeys[weekday - 1]];
    if (times == null) return const WeeklyTimes();
    return WeeklyTimes(
      schoolStartAt: times[schoolStart] ?? '',
      schoolEndAt: times[schoolEnd] ?? '',
      pickupAt: times[pickup] ?? '',
      dropoffAt: times[dropoff] ?? '',
    );
  }
}
