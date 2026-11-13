import 'package:transit_core/transit_core.dart';

/// A family's ride figures, as the Home screen's stat tiles show them.
class FamilyTripStats {
  final int totalTrips;
  final int onTimePct;
  final int thisWeek;

  const FamilyTripStats({
    this.totalTrips = 0,
    this.onTimePct = 0,
    this.thisWeek = 0,
  });
}

/// Family-wide figures from every child's attendance.
///
/// A ride counts once the child was actually on the van: `boarded`, or
/// `droppedOff` — which is where every finished ride ends up, at school in
/// the morning and at home in the afternoon. Counting `boarded` alone left
/// every completed ride out, so a family that rode all month read zero.
///
/// `onTimePct` needs each trip's on-time verdict, which [AttendanceRecord]
/// does not carry, so the trips are read through [tripFor]; a trip still
/// running has no verdict yet and is left out of the percentage rather than
/// counted late. `thisWeek` uses the trip's start, falling back to when the
/// child was marked.
Future<FamilyTripStats> familyTripStats(
  List<AttendanceRecord> records, {
  required Future<Trip?> Function(String tripId) tripFor,
  DateTime? now,
}) async {
  final rode = records.where(rodeOn).toList();
  if (rode.isEmpty) return const FamilyTripStats();

  final tripIds = {
    for (final r in rode)
      if (r.tripId.isNotEmpty) r.tripId,
  };
  final fetched = await Future.wait(tripIds.map(tripFor));
  final trips = {for (final t in fetched.nonNulls) t.id: t};

  final rated = rode.where((r) => trips[r.tripId]?.onTime != null);
  final onTimeCount = rated
      .where((r) => trips[r.tripId]!.onTime == true)
      .length;
  final ratedCount = rated.length;
  final onTimePct = ratedCount == 0
      ? 0
      : ((onTimeCount / ratedCount) * 100).round();

  final weekAgo = (now ?? DateTime.now()).subtract(const Duration(days: 7));
  final thisWeek = rode.where((r) {
    final when = trips[r.tripId]?.startedAt ?? r.markedAt;
    return when != null && when.isAfter(weekAgo);
  }).length;

  return FamilyTripStats(
    totalTrips: rode.length,
    onTimePct: onTimePct,
    thisWeek: thisWeek,
  );
}

/// Whether [record] is a ride the child actually took: aboard, or delivered
/// at the other end — which is where every finished ride ends up.
bool rodeOn(AttendanceRecord record) =>
    record.status == AttendanceStatus.boarded ||
    record.status == AttendanceStatus.droppedOff;
