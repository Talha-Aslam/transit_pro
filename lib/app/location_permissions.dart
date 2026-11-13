import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Why the device cannot be asked for its location right now.
///
/// The old API was a bare `Future<bool>`, which made every caller tell the
/// user the same nothing: a refusal looked identical whether the phone's
/// location was switched off, the user had tapped "deny" once, or they had
/// denied it permanently and could only fix it in Settings. Those three
/// need three different sentences and two different buttons.
enum LocationBlock {
  /// The device's location services are switched off, for every app.
  serviceDisabled,

  /// Denied this time. Asking again is allowed.
  denied,

  /// Denied permanently ("don't ask again"). Only Settings can undo it.
  deniedForever,
}

/// The outcome of asking for location access.
class LocationAccess {
  final bool granted;
  final LocationBlock? block;

  const LocationAccess.granted() : granted = true, block = null;
  const LocationAccess.blocked(this.block) : granted = false;

  /// One sentence the user can act on, naming what is wrong.
  String get message => switch (block) {
    LocationBlock.serviceDisabled =>
      'Location is switched off on this phone. Turn it on to share and '
          'follow the bus.',
    LocationBlock.deniedForever =>
      'Location permission is blocked for Transit Pro. Open Settings to '
          'allow it.',
    LocationBlock.denied =>
      'Transit Pro needs location access to track the bus.',
    null => '',
  };

  /// What the button beside [message] should say, or null when there is
  /// nothing useful to open.
  String? get actionLabel => switch (block) {
    LocationBlock.serviceDisabled => 'Turn on',
    LocationBlock.deniedForever => 'Settings',
    LocationBlock.denied => 'Allow',
    null => null,
  };
}

/// Whether this device can be asked for its location: services on, and
/// permission granted or grantable. Requests permission when it has not
/// been decided yet.
///
/// Never throws — a device that refuses is a state to report, not an error
/// to propagate into a trip that is otherwise fine.
Future<LocationAccess> requestLocationAccess() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    return const LocationAccess.blocked(LocationBlock.serviceDisabled);
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  return switch (permission) {
    LocationPermission.denied => const LocationAccess.blocked(
      LocationBlock.denied,
    ),
    LocationPermission.deniedForever => const LocationAccess.blocked(
      LocationBlock.deniedForever,
    ),
    _ => const LocationAccess.granted(),
  };
}

/// Kept for the callers that only need a yes/no. New code should prefer
/// [requestLocationAccess] and tell the user what went wrong.
Future<bool> ensureLocationPermission() async =>
    (await requestLocationAccess()).granted;

/// Asks for location, and when it is refused explains why on screen with a
/// button that opens the right place to fix it.
///
/// Returns whether access was granted, so the caller can carry on or stop.
Future<bool> ensureLocationOrExplain(
  BuildContext context, {
  Color accent = AppTheme.driverCyan,
}) async {
  final access = await requestLocationAccess();
  if (access.granted) return true;
  if (!context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(access.message),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: access.actionLabel ?? 'OK',
        textColor: accent,
        onPressed: () {
          // Two different destinations: the phone's own location toggle
          // lives in system settings, while a blocked permission is in this
          // app's settings page. Sending the user to the wrong one is a
          // dead end they have no way to recover from.
          switch (access.block) {
            case LocationBlock.serviceDisabled:
              Geolocator.openLocationSettings();
            case LocationBlock.deniedForever:
            case LocationBlock.denied:
            case null:
              Geolocator.openAppSettings();
          }
        },
      ),
    ),
  );
  return false;
}

/// Offers "Allow all the time" once, with the reason in plain words.
///
/// Tracking itself does not depend on it: the trip runs as a location
/// foreground service, which keeps working with the screen off on
/// while-in-use permission. Background permission is what keeps it working
/// on phones whose makers stop foreground services aggressively, so it is
/// offered rather than demanded, and only once — a driver who said no is
/// not asked again every morning.
Future<void> offerBackgroundLocation(BuildContext context) async {
  const askedKey = 'asked_background_location';
  try {
    if (await Geolocator.checkPermission() != LocationPermission.whileInUse) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(askedKey) ?? false) return;
    await prefs.setBool(askedKey, true);
    if (!context.mounted) return;

    final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keep sharing with the screen off?'),
        content: const Text(
          'Families follow the van on their phones during the trip. Choose '
          '"Allow all the time" on the next screen so the van keeps showing '
          'on their map when your screen is locked or you switch to Google '
          'Maps. Location is only shared while a route is running.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (allow == true) await Geolocator.requestPermission();
  } catch (e) {
    debugPrint('background location offer skipped: $e');
  }
}
