import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:transit_core/transit_core.dart';

/// The bus's live position — the one thing that does **not** live in Firestore.
///
/// Firestore bills per document write. A 3-hour route publishing every 5
/// seconds is ~2,160 writes per bus per day, which would exhaust the 20k/day
/// free quota with a handful of buses. Realtime Database bills bandwidth
/// instead, and a ~100-byte ping is effectively free at this volume.
///
/// Path: `liveLocations/{busId}`
class LiveLocationRepository {
  LiveLocationRepository._();
  static final LiveLocationRepository instance = LiveLocationRepository._();

  FirebaseDatabase get _db => AppConfig.realtimeDatabaseUrl.isEmpty
      ? FirebaseDatabase.instance
      : FirebaseDatabase.instanceFor(
          app: FirebaseDatabase.instance.app,
          databaseURL: AppConfig.realtimeDatabaseUrl,
        );

  DatabaseReference _busRef(String busId) => _db.ref('liveLocations/$busId');

  // ── Driver side: publish ──────────────────────────────────────────────────

  /// Writes one position ping. Called on a timer while a trip is live.
  Future<void> publish(LiveLocation location) async {
    await _busRef(location.busId).set(location.toMap());
  }

  /// Clears the bus's position when the trip ends, so parents stop seeing a
  /// stale marker parked at the last known point.
  Future<void> clear(String busId) => _busRef(busId).remove();

  /// Removes the position automatically if the driver's app dies or loses
  /// connectivity, rather than leaving a ghost bus on every parent's map.
  Future<void> armDisconnectCleanup(String busId) =>
      _busRef(busId).onDisconnect().remove();

  Future<void> cancelDisconnectCleanup(String busId) =>
      _busRef(busId).onDisconnect().cancel();

  // ── Parent / student side: subscribe ──────────────────────────────────────

  /// Emits null when the bus is not currently broadcasting.
  Stream<LiveLocation?> watchBus(String busId) =>
      _busRef(busId).onValue.map((event) {
        final value = event.snapshot.value;
        if (value is! Map) return null;
        return LiveLocation.fromMap(
          busId,
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      });

  Future<LiveLocation?> fetchOnce(String busId) async {
    final snap = await _busRef(busId).get();
    final value = snap.value;
    if (value is! Map) return null;
    return LiveLocation.fromMap(
      busId,
      value.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  // ── Admin side: watch the whole fleet ─────────────────────────────────────

  Stream<List<LiveLocation>> watchAllBuses() =>
      _db.ref('liveLocations').onValue.map((event) {
        final value = event.snapshot.value;
        if (value is! Map) return <LiveLocation>[];
        return value.entries
            .where((e) => e.value is Map)
            .map((e) => LiveLocation.fromMap(
                  e.key.toString(),
                  (e.value as Map).map((k, v) => MapEntry(k.toString(), v)),
                ))
            .toList();
      });
}
