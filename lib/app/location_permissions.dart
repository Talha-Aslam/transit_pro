import 'package:geolocator/geolocator.dart';

/// Whether this device can currently be asked for its location: the location
/// service is on, and permission is granted or grantable.
///
/// Requests permission if it hasn't been decided yet. Returns false rather
/// than throwing on every kind of "can't" — service disabled, denied, or
/// denied forever — so callers can show one honest message instead of
/// juggling exceptions.
Future<bool> ensureLocationPermission() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return false;

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return false;
  }
  if (permission == LocationPermission.deniedForever) return false;
  return true;
}
