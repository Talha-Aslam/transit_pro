import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:geolocator/geolocator.dart';
import 'package:transit_core/transit_core.dart';

import 'app/auth_service.dart';
import 'app/geofence_service.dart';
import 'app/notification_service.dart';
import 'app/router.dart';
import 'models/route_data.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

// ─── Background entry point ───────────────────────────────────────────────────
//
// This function is executed inside the Flutter engine that lives in
// BusTrackingService (a foreground service).  It runs independently of the
// app UI and continues to work even after the user closes the app.
//
// @pragma is required to prevent Dart tree-shaking from removing the function.
@pragma('vm:entry-point')
Future<void> busTrackingBackground() async {
  // Required before using any Flutter / plugin APIs in a background isolate.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise the notification plugin so it can show heads-up alerts.
  await NotificationService.instance.init();

  // Forward every new geofence alert to a push notification.
  GeofenceService.instance.alerts.addListener(() {
    final alerts = GeofenceService.instance.alerts.value;
    if (alerts.isNotEmpty) {
      NotificationService.instance.fromGeofence(alerts.last);
    }
  });

  // Load the route stops (mock data; swap with an API call for production).
  final route = MockRouteBuilder.buildMorningRoute();

  // Stream GPS position updates and evaluate geofence thresholds.
  const locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 20, // metres — only re-evaluate after moving 20 m
  );

  Geolocator.getPositionStream(locationSettings: locationSettings).listen(
    (Position position) {
      final busPos = GeoCoord(position.latitude, position.longitude);
      GeofenceService.instance.evaluate(busPos, route.stops);
    },
    onError: (_) {}, // silently ignore permission / hardware errors
  );

  // Park this isolate — it stays alive for as long as the service lives.
  await Completer<void>().future;
}

// ─── App entry point ──────────────────────────────────────────────────────────

/// Keeps an uncaught error on screen instead of taking the app down.
///
/// A crash in the middle of a round is the worst moment this app has: the
/// driver is driving, the families are watching a map, and the only thing
/// anybody learns is that the app closed. Two handlers, because Flutter
/// splits them — one for errors raised while building or laying out a
/// widget, one for everything else that escapes an `async` gap.
///
/// Neither swallows anything: the error and its stack still go to the log,
/// which is what `flutter run` and `adb logcat` print. What changes is that
/// the process survives, and a release build shows a readable message where
/// it would otherwise have shown a grey rectangle.
void _installErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('uncaught widget error: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('uncaught error: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };

  ErrorWidget.builder = (details) => Material(
    color: const Color(0xFF111827),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          kDebugMode
              ? '${details.exception}'
              : 'Something went wrong on this screen.'
                    ' Go back and try again.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 13),
        ),
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();
  // google_maps_flutter needs no Dart-side init — the API key lives in
  // AndroidManifest.xml's <meta-data> entry instead.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialise notifications for the foreground (UI) process.
  await NotificationService.instance.init();

  // Start the background foreground service so notifications keep working
  // after the user closes the app.
  // Skip in debug mode — running two Flutter engines simultaneously during
  // development causes jank, geolocator conflicts, and ANR (SIGQUIT) dumps.
  if (Platform.isAndroid && !kDebugMode) {
    await _startBackgroundService();
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await AuthService.instance.preload();
  runApp(const TransportKidApp());
}

Future<void> _startBackgroundService() async {
  final hasPermission = await _ensureLocationPermissionForService();
  if (!hasPermission) return;

  const channel = MethodChannel('com.example.transit_pro/background_service');
  await channel.invokeMethod<void>('startService').catchError((_) {});
}

Future<bool> _ensureLocationPermissionForService() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    return false;
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  return permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;
}

class TransportKidApp extends StatefulWidget {
  const TransportKidApp({super.key});

  @override
  State<TransportKidApp> createState() => _TransportKidAppState();
}

class _TransportKidAppState extends State<TransportKidApp>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    ThemeProvider.instance.attachTicker(this);
    ThemeProvider.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeProvider.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    final isDark = ThemeProvider.instance.isDark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark
            ? const Color(0xFF0C0120)
            : const Color(0xFFF8FAFC),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fires only on a real toggle now (see ThemeProvider's own doc comment)
    // — cheap, unlike the per-frame rebuild this used to trigger.
    return ListenableBuilder(
      listenable: ThemeProvider.instance,
      builder: (context, _) => MaterialApp.router(
        title: 'TransportKid',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeProvider.instance.mode,
        routerConfig: appRouter,
        // Publishes the animated blend value below the Router, scoped so
        // only widgets that actually read a theme colour rebuild on each
        // tick — see `ThemeBlendScope`'s doc comment for why this replaced
        // rebuilding the whole app on every animation frame.
        builder: (context, child) => ThemeBlendScope(
          notifier: ThemeProvider.instance.blendAnimation,
          child: child!,
        ),
      ),
    );
  }
}
