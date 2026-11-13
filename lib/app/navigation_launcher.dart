import 'package:flutter/foundation.dart';
import 'package:transit_core/transit_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands one stop to Google Maps for turn-by-turn directions.
///
/// Only the *next* stop, never the whole round: Google Maps would re-order
/// a multi-stop trip its own way, and the order is ours. Tracking keeps
/// running underneath — the position stream is a foreground service, so
/// switching to Google Maps does not pause what the families see.
///
/// Tried in order: the Android navigation intent (straight into driving
/// mode), the Google Maps app on iOS, then the universal directions link,
/// which opens the app if it is installed and the browser if not.
class NavigationLauncher {
  NavigationLauncher._();

  static Uri androidIntent(GeoCoord to) =>
      Uri.parse('google.navigation:q=${to.lat},${to.lng}&mode=d');

  static Uri iosApp(GeoCoord to) => Uri.parse(
    'comgooglemaps://?daddr=${to.lat},${to.lng}&directionsmode=driving',
  );

  static Uri universal(GeoCoord to) => Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=${to.lat},${to.lng}&travelmode=driving',
  );

  /// Returns false when nothing could be opened.
  static Future<bool> navigateTo(GeoCoord to) async {
    final candidates = [
      if (defaultTargetPlatform == TargetPlatform.android) androidIntent(to),
      if (defaultTargetPlatform == TargetPlatform.iOS) iosApp(to),
      universal(to),
    ];
    for (final uri in candidates) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {
        // No app for that scheme; try the next.
      }
    }
    return false;
  }
}
