import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
      final busPos = LatLng(position.latitude, position.longitude);
      GeofenceService.instance.evaluate(busPos, route.stops);
    },
    onError: (_) {}, // silently ignore permission / hardware errors
  );

  // Park this isolate — it stays alive for as long as the service lives.
  await Completer<void>().future;
}

// ─── App entry point ──────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise notifications for the foreground (UI) process.
  await NotificationService.instance.init();

  // Start the background foreground service so notifications keep working
  // after the user closes the app.
  // Skip in debug mode — running two Flutter engines simultaneously during
  // development causes jank, geolocator conflicts, and ANR (SIGQUIT) dumps.
  if (Platform.isAndroid && !kDebugMode) {
    _startBackgroundService();
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await AuthService.instance.preload();
  runApp(const TransportKidApp());
}

void _startBackgroundService() {
  const channel = MethodChannel('com.example.transit_pro/background_service');
  channel.invokeMethod<void>('startService').catchError((_) {});
}

class TransportKidApp extends StatefulWidget {
  const TransportKidApp({super.key});

  @override
  State<TransportKidApp> createState() => _TransportKidAppState();
}

class _TransportKidAppState extends State<TransportKidApp> {
  @override
  void initState() {
    super.initState();
    ThemeProvider.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeProvider.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {
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
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TransportKid',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeProvider.instance.mode,
      routerConfig: appRouter,
    );
  }
}
