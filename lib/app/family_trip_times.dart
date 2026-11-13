import 'package:intl/intl.dart';
import 'package:transit_core/transit_core.dart';

/// When the van is due at the two points a family is waiting on, read off
/// the running trip.
///
/// The driver's app keeps each stop's `etaAt` current — on every stop
/// event, every off-route re-plan and every few minutes in traffic — so the
/// times here cost nothing and agree with the driver's own screen.
class FamilyTripTimes {
  const FamilyTripTimes({required this.toSchool, this.pickupAt, this.arriveAt});

  /// The morning leg, home → institute. Otherwise the ride home.
  final bool toSchool;

  /// When the van is due at the child's pickup point. Morning only, and
  /// only while that stop is still ahead.
  final DateTime? pickupAt;

  /// When the child gets where this leg takes them: the institute in the
  /// morning, their own drop-off point on the way home. Null once reached,
  /// or while unknown.
  final DateTime? arriveAt;

  factory FamilyTripTimes.of(Trip trip, String studentId) {
    final mine = trip.childStopFor(studentId);
    final mineAt = mine != null && mine.isOpen ? mine.etaAt : null;
    if (trip.type == TripType.morning) {
      final end = trip.instituteStopFor(studentId);
      return FamilyTripTimes(
        toSchool: true,
        pickupAt: mineAt,
        arriveAt: end != null && end.isOpen ? end.etaAt : null,
      );
    }
    return FamilyTripTimes(toSchool: false, arriveAt: mineAt);
  }

  /// `7:42 AM`, or empty when unknown.
  static String clock(DateTime? at) =>
      at == null ? '' : DateFormat.jm().format(at.toLocal());

  /// One line for the top of a family's route card, or null when there is
  /// no time to give: "Pickup at 7:42 AM" before the child is collected,
  /// "Reaching Beaconhouse at 8:05 AM" once they are aboard, "Drop-off at
  /// 2:31 PM" on the way home.
  String? headline({required AttendanceStatus? mark, required String school}) {
    switch (mark) {
      case AttendanceStatus.absent:
      case AttendanceStatus.droppedOff:
        return null;
      case AttendanceStatus.boarded:
        if (toSchool) {
          final at = clock(arriveAt);
          return at.isEmpty ? null : 'Reaching $school at $at';
        }
        final at = clock(arriveAt);
        return at.isEmpty ? null : 'Drop-off at $at';
      case AttendanceStatus.pending:
      case null:
        final at = clock(toSchool ? pickupAt : arriveAt);
        if (at.isEmpty) return null;
        return toSchool ? 'Pickup at $at' : 'Drop-off at $at';
    }
  }
}
