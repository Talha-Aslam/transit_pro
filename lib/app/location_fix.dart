import 'package:transit_core/transit_core.dart';

/// One accepted position from the device, after filtering.
///
/// What `TrackingService` hands the trip controller: it has already thrown
/// away fixes that are too inaccurate to place the van on a street, and
/// fixes that would mean the van teleported.
class LocationFix {
  final GeoCoord coord;

  /// Degrees from north, or null when the device could not tell (stopped,
  /// no compass).
  final double? heading;
  final double speedKmh;

  /// Horizontal accuracy in metres.
  final double accuracy;
  final DateTime at;

  const LocationFix({
    required this.coord,
    required this.at,
    this.heading,
    this.speedKmh = 0,
    this.accuracy = 0,
  });
}

/// Decides which raw fixes are believable.
///
/// Pure, so it can be tested without a phone: a fix worse than
/// [maxAccuracyMeters] cannot place the van on the right street, and one
/// that implies more than [maxSpeedKmh] since the last accepted fix is the
/// receiver jumping, not the van. After [giveUpAfter] rejections in a row
/// the next plausible-accuracy fix is accepted anyway, so a bad *reference*
/// fix cannot lock tracking out for good.
class FixFilter {
  FixFilter({
    this.maxAccuracyMeters = 50,
    this.maxSpeedKmh = 150,
    this.giveUpAfter = 5,
  });

  final double maxAccuracyMeters;
  final double maxSpeedKmh;
  final int giveUpAfter;

  LocationFix? _last;
  int _jumpsInARow = 0;
  int _weakInARow = 0;

  /// True after three inaccurate fixes in a row — worth telling the driver.
  bool get weakSignal => _weakInARow >= 3;

  void reset() {
    _last = null;
    _jumpsInARow = 0;
    _weakInARow = 0;
  }

  bool accept(LocationFix fix, double Function(GeoCoord, GeoCoord) distance) {
    if (fix.accuracy > maxAccuracyMeters) {
      _weakInARow++;
      return false;
    }
    _weakInARow = 0;

    final last = _last;
    if (last != null) {
      final seconds = fix.at.difference(last.at).inMilliseconds / 1000;
      final metres = distance(last.coord, fix.coord);
      final kmh = seconds <= 0
          ? (metres > 30 ? double.infinity : 0)
          : metres / seconds * 3.6;
      if (kmh > maxSpeedKmh && _jumpsInARow < giveUpAfter) {
        _jumpsInARow++;
        return false;
      }
    }
    _jumpsInARow = 0;
    _last = fix;
    return true;
  }
}
