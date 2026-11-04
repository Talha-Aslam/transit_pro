import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';

import '../data/live_location_repository.dart';
import 'route_service.dart';

/// Follows one bus's live position on behalf of a family.
///
/// The driver's app has published to `liveLocations/{busId}` since the
/// Routes migration, but nothing on the parent or student side ever read it:
/// both dashboards showed [TrackingService]'s `etaMinutes`, a local
/// `ValueNotifier<int>` seeded with 8 that only the *driver's* own device
/// ever advances. On a parent's phone it never moved off 8, so the dashboard
/// said "8 min to school" with no trip running at all, and said "8 min" just
/// the same while a real trip was halfway finished. This service is the
/// missing half of that link.
///
/// It owns three pieces of state and nothing else:
///
///  * [position] — the latest ping, or null when the bus is not broadcasting
///    or its last ping has gone stale;
///  * [etaMinutes] / [distanceLabel] — derived from that position against a
///    destination, refreshed at most every [_etaInterval];
///  * [isFollowing] — whether a bus is being watched at all, which is what
///    separates "no route running" from "route running, waiting for a fix".
///
/// Null is meaningful everywhere here: it means "not known", never "zero".
class LiveBusService {
  LiveBusService._();
  static final LiveBusService instance = LiveBusService._();

  /// The latest ping. Null when nothing is broadcasting, or when the last
  /// ping is older than [LiveLocation.isStale] allows — a bus that dropped
  /// off the network must not keep showing a position it no longer holds.
  final position = ValueNotifier<LiveLocation?>(null);

  /// Minutes to the destination by road, or null while unknown.
  final etaMinutes = ValueNotifier<int?>(null);

  /// Road distance to the destination, e.g. "4.2 km". Null while unknown.
  final distanceLabel = ValueNotifier<String?>(null);

  /// True between [follow] and [stop] — a trip is running and this service
  /// is listening, whether or not a ping has arrived yet.
  final isFollowing = ValueNotifier<bool>(false);

  /// How often the road ETA may be recomputed. Pings arrive every
  /// `AppConfig.locationPublishInterval` (5s); asking the Routes API that
  /// often would be twelve billed calls a minute per watching family for a
  /// number that barely changes.
  static const _etaInterval = Duration(seconds: 30);

  /// How often a held position is re-checked for staleness. Without this the
  /// UI would keep a dead ping on screen until the next one arrived, which
  /// by definition never comes.
  static const _stalenessInterval = Duration(seconds: 10);

  String? _busId;
  GeoCoord? _destination;
  StreamSubscription<LiveLocation?>? _sub;
  Timer? _stalenessTimer;
  DateTime? _lastEtaAt;
  GeoCoord? _lastEtaFrom;

  /// The bus currently being followed, or null.
  String? get busId => _busId;

  /// Start following [busId], computing ETAs toward [destination] when one
  /// is known. Calling it again with the same pair is a no-op, so it is safe
  /// to call from `build`.
  void follow({required String busId, GeoCoord? destination}) {
    if (_busId == busId && _destination == destination) return;

    stop();
    if (busId.isEmpty) return;

    _busId = busId;
    _destination = destination;
    isFollowing.value = true;

    _sub = LiveLocationRepository.instance
        .watchBus(busId)
        .listen(
          _onPing,
          onError: (_) {
            // A dropped subscription is not an empty bus: keep following so the
            // stream can recover, but stop claiming a position we no longer get.
            position.value = null;
          },
        );
    _stalenessTimer = Timer.periodic(_stalenessInterval, (_) => _dropIfStale());
  }

  /// Stop following, and clear everything derived from the bus.

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

  void stop() {
    _sub?.cancel();
    _sub = null;
    _stalenessTimer?.cancel();
    _stalenessTimer = null;
    _busId = null;
    _destination = null;
    _lastEtaAt = null;
    _lastEtaFrom = null;
    isFollowing.value = false;
    position.value = null;
    etaMinutes.value = null;
    distanceLabel.value = null;
  }

  void _onPing(LiveLocation? ping) {
    if (ping == null || ping.isStale) {
      position.value = null;
      return;
    }
    position.value = ping;
    _maybeRefreshEta(ping.coord);
  }

  void _dropIfStale() {
    final held = position.value;
    if (held != null && held.isStale) {
      position.value = null;
      etaMinutes.value = null;
      distanceLabel.value = null;
    }
  }

  void _maybeRefreshEta(GeoCoord from) {
    final destination = _destination;
    if (destination == null) return;

    final now = DateTime.now();
    final last = _lastEtaAt;
    if (last != null && now.difference(last) < _etaInterval) return;

    // Claim the slot before awaiting, so a burst of pings can't start several
    // overlapping lookups.
    _lastEtaAt = now;
    _lastEtaFrom = from;

    unawaited(() async {
      final result = await RouteService.instance.fetchDistanceDuration(
        origin: from,
        destination: destination,
      );
      // The family may have switched child (and therefore destination) while
      // this was in flight; a stale answer must not overwrite a newer one.
      if (_lastEtaFrom != from || _destination != destination) return;
      if (result == null) return;
      etaMinutes.value = parseDurationMinutes(result.duration);
      distanceLabel.value = result.distance;
    }());
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
