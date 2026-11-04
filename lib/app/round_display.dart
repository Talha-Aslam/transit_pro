import 'package:transit_core/transit_core.dart';

/// Turning a round into words a parent reads without being told how.
///
/// A round stores `HH:mm` in 24-hour time, twice over — `pickupStart`,
/// `pickupEnd`, `dropoffStart`, `dropoffEnd`. Printed raw that is
/// `06:30 – 07:30 · 13:30 – 14:30`, which asks the reader to work out which
/// pair is the way there, which is the way back, and what `13:30` is in the
/// clock they actually use. Most of the people reading it are parents
/// deciding whether a driver suits their child, not timetable readers.

/// `06:30` → `6:30 AM`. Returns empty for anything unparseable, so a missing
/// time disappears rather than printing a placeholder.
String clock12(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return '';
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return '';
  final period = h < 12 ? 'AM' : 'PM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}

/// What this round does, in one line: `Picks up 6:30 AM · Home by 2:30 PM`.
///
/// Each leg is described by the time that matters to a family — when the van
/// reaches them in the morning, and when the child is back home in the
/// afternoon — not by the range the driver entered. A round that runs only
/// one way says only that.
String roundSummary(DriverSchedule round) {
  final out = clock12(round.pickupStart);
  // The end of the way home is when the child is actually dropped; falling
  // back to the start keeps a round that was only half-timed readable.
  final back = clock12(
    round.dropoffEnd.isNotEmpty ? round.dropoffEnd : round.dropoffStart,
  );
  return [
    if (out.isNotEmpty) 'Picks up $out',
    if (back.isNotEmpty) 'Home by $back',
  ].join('  ·  ');
}

/// The same thing over two lines, for a card with the room for it.
///
/// Returns `(morning, afternoon)`, either of which may be empty.
(String, String) roundLegLines(DriverSchedule round) {
  final pickFrom = clock12(round.pickupStart);
  final pickTo = clock12(round.pickupEnd);
  final dropFrom = clock12(round.dropoffStart);
  final dropTo = clock12(round.dropoffEnd);

  String leg(String verb, String from, String to) {
    if (from.isEmpty) return '';
    return to.isEmpty ? '$verb $from' : '$verb $from, arrives $to';
  }

  return (
    leg('Leaves home', pickFrom, pickTo),
    leg('Leaves institute', dropFrom, dropTo),
  );
}
