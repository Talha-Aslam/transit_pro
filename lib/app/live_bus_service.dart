import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import '../data/live_location_repository.dart';

/// Follows one bus's live position on behalf of a family.
///
/// Reads two things and computes nothing that costs money:
///
///  * `liveLocations/{busId}` — where the van is, every few seconds;
///  * the running `trips/{tripId}` document — the route the driver's app
///    last computed, and each stop's expected arrival time.
///
/// The minutes a family sees come from the trip's own stop ETAs, counted
/// down on this phone. This service used to ask Google for a fresh route
/// from the van to the school every 30 seconds for every family watching,
/// which cost a request per viewer per half-minute and measured the wrong
/// thing in the morning — the van goes to *this child's door* first.
///
/// Null is meaningful everywhere here: it means "not known", never "zero".
class LiveBusService {
  LiveBusService._();
  static final LiveBusService instance = LiveBusService._();

  /// The latest ping. Null when nothing is broadcasting, or when the last
  /// ping is older than [LiveLocation.isStale] allows.
  final position = ValueNotifier<LiveLocation?>(null);

  /// The last ping received on this follow, kept even after it goes stale
  /// or the node disappears, so the map can say "last seen here, 3 min ago"
  /// instead of the van vanishing.
  final lastKnown = ValueNotifier<LiveLocation?>(null);

  /// The trip being followed, refreshed as the driver's app re-plans.
  final trip = ValueNotifier<Trip?>(null);

  /// Minutes until the van reaches this child's stop — or, once the child
  /// is aboard, the end of the leg. Null while unknown.
  final etaMinutes = ValueNotifier<int?>(null);

  /// Road distance for the same target, e.g. "4.2 km". Null while unknown.
  final distanceLabel = ValueNotifier<String?>(null);

  /// True between [follow] and [stop] — a trip is running and this service
  /// is listening, whether or not a ping has arrived yet.
  final isFollowing = ValueNotifier<bool>(false);

  /// How often a held position is re-checked for staleness and the ETA
  /// counted down. Without this the UI would keep a dead ping on screen
  /// until the next one arrived, which by definition never comes.
  static const _tickInterval = Duration(seconds: 10);

  String? _busId;
  String? _studentId;
  StreamSubscription<LiveLocation?>? _sub;
  Timer? _ticker;

  /// The bus currently being followed, or null.
  String? get busId => _busId;

  /// The child whose stop the ETA is measured to.
  String? get studentId => _studentId;

  /// Start following [busId]. Calling it again with the same bus only
  /// refreshes [trip] and the child, so it is safe to call on every trip
  /// snapshot.
  ///
  /// A [trip] that is not [studentId]'s round is refused: the van is out on
  /// another round, and its stops are other families' homes.
  void follow({required String busId, Trip? trip, String? studentId}) {
    final foreign =
        trip != null && studentId != null && !trip.carries(studentId);
    if (busId.isEmpty || foreign) {
      stop();
      return;
    }
    if (_busId != busId) {
      stop();
      _busId = busId;
      isFollowing.value = true;
      _sub = LiveLocationRepository.instance
          .watchBus(busId)
          .listen(
            _onPing,
            onError: (_) {
              // A dropped subscription is not an empty bus: keep following so
              // the stream can recover, but stop claiming a live position.
              position.value = null;
            },
          );
      _ticker = Timer.periodic(_tickInterval, (_) => _tick());
    }
    _studentId = studentId;
    this.trip.value = trip;
    _refreshEta();
  }

  /// [stop], for a caller that is inside `State.dispose()`.
  ///
  /// Flutter locks the element tree while it tears a widget down, so writing
  /// to a notifier another mounted builder is watching throws *"setState()
  /// or markNeedsBuild() called when widget tree was locked"*. The same
  /// hazard as `TrackingService.stopAfterFrame` — see that method for the
  /// whole story. A microtask runs once the frame's synchronous work is
  /// finished and the tree is unlocked again.
  void stopAfterFrame() {
    scheduleMicrotask(stop);
  }

  /// Stop following, and clear everything derived from the bus.
  void stop() {
    _sub?.cancel();
    _sub = null;
    _ticker?.cancel();
    _ticker = null;
    _busId = null;
    _studentId = null;
    isFollowing.value = false;
    position.value = null;
    lastKnown.value = null;
    trip.value = null;
    etaMinutes.value = null;
    distanceLabel.value = null;
  }

  void _onPing(LiveLocation? ping) {
    if (ping == null) {
      // The node is removed when the driver's connection drops. The van has
      // not gone anywhere: keep the last position, just not as live.
      position.value = null;
      return;
    }
    lastKnown.value = ping;
    position.value = ping.isStale ? null : ping;
  }

  void _tick() {
    final held = position.value;
    if (held != null && held.isStale) position.value = null;
    _refreshEta();
  }

  /// The stop the family is waiting on: their child's, while it is still
  /// ahead; then, in the morning, the institute *they* are set down at;
  /// otherwise the end of the leg.
  TripStop? targetStop() {
    final t = trip.value;
    if (t == null) return null;
    final id = _studentId;
    final mine = id == null ? null : t.childStopFor(id);
    if (mine != null && mine.isOpen) return mine;
    final end = id != null && t.type == TripType.morning
        ? t.instituteStopFor(id)
        : t.destinationStop;
    if (end != null && end.isOpen) return end;
    return null;
  }

  void _refreshEta() {
    final target = targetStop();
    final eta = target?.etaAt;
    if (target == null || eta == null) {
      etaMinutes.value = null;
      distanceLabel.value = null;
      return;
    }
    final seconds = eta.difference(DateTime.now()).inSeconds;
    etaMinutes.value = seconds <= 0 ? 0 : (seconds / 60).ceil();
    final meters = target.distanceMeters;
    distanceLabel.value = meters == null
        ? null
        : meters < 1000
        ? '$meters m'
        : '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

/// Minutes from a human duration string as the Routes API formats it —
/// "7 mins", "1 hour 12 mins", "45 secs".
///
/// Returns null when nothing numeric can be read out of it, which the UI
/// shows as "—" rather than inventing a zero.
int? parseDurationMinutes(String duration) {
  final text = duration.toLowerCase();
  var minutes = 0;
  var matched = false;

  final hour = RegExp(r'(\d+)\s*(?:hours?|hrs?|h\b)').firstMatch(text);
  if (hour != null) {
    minutes += int.parse(hour.group(1)!) * 60;
    matched = true;
  }
  final min = RegExp(r'(\d+)\s*(?:minutes?|mins?|m\b)').firstMatch(text);
  if (min != null) {
    minutes += int.parse(min.group(1)!);
    matched = true;
  }
  if (!matched) {
    // Sub-minute trips still deserve a number rather than a dash.
    final sec = RegExp(r'(\d+)\s*(?:seconds?|secs?|s\b)').firstMatch(text);
    if (sec != null) return int.parse(sec.group(1)!) >= 30 ? 1 : 0;
    return null;
  }
  return minutes;
}
