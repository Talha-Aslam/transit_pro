import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:transit_core/transit_core.dart';

/// Where the person holding the phone is, for ranking search results.
///
/// Every place search in the app — a school, a pickup point, a drop-off —
/// is really the question "which of the four Punjab Colleges do I mean?",
/// and the answer is almost always the nearest one. Without a point to
/// measure from, the list came back in Google's own order and a family in
/// Johar Town was offered a campus in Multan first.
///
/// Deliberately not a precise fix: a last-known position is enough to sort
/// a list by, it costs nothing, and it never shows a permission dialog in
/// the middle of someone typing. A real fix is requested only once per app
/// run, and only if there is no cached one.
class LocationHint {
  LocationHint._();
  static final LocationHint instance = LocationHint._();

  GeoCoord? _cached;
  Future<GeoCoord?>? _inFlight;

  /// The best point available right now, or null when the device will not
  /// say. Callers treat null as "do not sort", never as an error.
  Future<GeoCoord?> current() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _inFlight ??= _resolve();
  }

  /// What is already known, with no awaiting — for a `build` that cannot
  /// wait and will be rebuilt when the future lands anyway.
  GeoCoord? get cached => _cached;

  Future<GeoCoord?> _resolve() async {
    try {
      // Never prompts. On a phone that has had any app ask for location
      // recently this is instant and good enough to sort by.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return _cached = GeoCoord(last.latitude, last.longitude);
      }

      // Only ask the OS if permission is already granted — a search field
      // is the wrong moment to interrupt someone with a dialog.
      final permission = await Geolocator.checkPermission();
      final granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) return null;

      final here = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 6),
        ),
      );
      return _cached = GeoCoord(here.latitude, here.longitude);
    } catch (e) {
      debugPrint('LocationHint: no position available — $e');
      return null;
    } finally {
      _inFlight = null;
    }
  }

  /// Lets a screen that has just learned a better point (a pinned pickup,
  /// say) improve every later search without another GPS read.
  void remember(GeoCoord? point) {
    if (point != null) _cached = point;
  }
}
