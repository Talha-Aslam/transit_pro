import 'package:transit_core/transit_core.dart';

/// The four figures the report shows beyond the raw trip count, each
/// derived from something that actually happened.
///
/// Returning null for "not enough evidence" is the point. A driver with two
/// trips and no ratings has no satisfaction score, and inventing a 98% for
/// them is how the old version made every driver look identical.
class DriverScores {
  /// Families' average rating as a fraction. Null until somebody rates.
  final double? satisfaction;

  /// Completed trips ÷ trips that were not cancelled. A driver who starts a
  /// round and abandons it has not complied with it.
  final double? compliance;

  /// Rounds driven without an emergency being filed against them, as a
  /// fraction. Null when nothing has been driven yet.
  final double? safety;

  /// On-time arrivals as a fraction, from `Trip.onTime`.
  final double? onTime;

  const DriverScores({this.satisfaction, this.compliance, this.safety, this.onTime});

  /// A single 0-100 figure, averaging whichever components exist. Null when
  /// none do, so the big circle shows "N/A" rather than a number nobody
  /// earned.
  int? get overall {
    final parts = <double>[?satisfaction, ?compliance, ?safety, ?onTime];
    if (parts.isEmpty) return null;
    return (parts.reduce((a, b) => a + b) / parts.length * 100).round();
  }

  /// The label under the circle. Bands, not adjectives applied to everyone:
  /// the old screen said "Excellent Performance" for any driver with at
  /// least one trip.
  String get label {
    final o = overall;
    if (o == null) return 'No data available';
    if (o >= 90) return 'Excellent performance';
    if (o >= 75) return 'Good performance';
    if (o >= 60) return 'Room to improve';
    return 'Needs attention';
  }
}

DriverScores computeDriverScores({
  required List<Trip> trips,
  required List<DriverRating> ratings,
  required List<Incident> incidents,
}) {
  final completed = trips.where((t) => t.status == TripStatus.completed);
  final cancelled = trips.where((t) => t.status == TripStatus.cancelled);
  final finishedOrCancelled = completed.length + cancelled.length;
  final onTimeOf = completed.where((t) => t.onTime == true).length;

  return DriverScores(
    satisfaction: ratings.isEmpty
        ? null
        : (ratings.map((r) => r.rating).reduce((a, b) => a + b) /
                  ratings.length /
                  5)
              .clamp(0.0, 1.0),
    compliance: finishedOrCancelled == 0
        ? null
        : completed.length / finishedOrCancelled,
    // One emergency in ten rounds is a 90% safety score. A driver who has
    // never raised one scores 100 — which is the honest reading, not a
    // flattering one: it is exactly what the record says.
    safety: trips.isEmpty
        ? null
        : ((trips.length - incidents.length) / trips.length).clamp(0.0, 1.0),
    onTime: completed.isEmpty ? null : onTimeOf / completed.length,
  );
}
