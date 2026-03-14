package com.example.transit_pro

import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * A START_STICKY foreground service that keeps a Flutter engine alive so that
 * geofence-based bus notifications can be delivered even when the user has
 * closed the app UI.
 *
 * The service:
 *  1. Displays a silent "monitoring" foreground notification (required by Android).
 *  2. Starts a separate Flutter engine that executes the Dart function
 *     `busTrackingBackground` (declared with @pragma('vm:entry-point')).
 *  3. All Flutter plugins (geolocator, flutter_local_notifications, …) are
 *     registered with that engine via GeneratedPluginRegistrant so they work
 *     normally inside the background isolate.
 *  4. Exposes a MethodChannel so the background Dart code can ask the service
 *     to stop itself when tracking is no longer needed.
 */
class BusTrackingService : Service() {

    companion object {
        private const val FOREGROUND_NOTIFICATION_ID = 999
        const val CHANNEL_NAME = "com.example.transit_pro/background_service"
    }

    private var flutterEngine: FlutterEngine? = null

    // ─── Service lifecycle ────────────────────────────────────────────────────

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        showForegroundNotification()
        if (flutterEngine == null) {
            startBackgroundFlutter()
        }
        // START_STICKY: if Android kills the service (low memory) it will
        // automatically restart it with a null intent.
        return START_STICKY
    }

    override fun onDestroy() {
        flutterEngine?.destroy()
        flutterEngine = null
        super.onDestroy()
    }

    // ─── Foreground notification ─────────────────────────────────────────────

    private fun showForegroundNotification() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification =
            NotificationCompat.Builder(this, MainApplication.SERVICE_CHANNEL_ID)
                .setContentTitle("Transit Pro")
                .setContentText("Monitoring your bus route in the background")
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setSilent(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()

        startForeground(FOREGROUND_NOTIFICATION_ID, notification)
    }

    // ─── Background Flutter engine ────────────────────────────────────────────

    private fun startBackgroundFlutter() {
        val engine = FlutterEngine(this)
        flutterEngine = engine

        // Register all plugins so geolocator, flutter_local_notifications, etc.
        // work inside the background Dart isolate.
        GeneratedPluginRegistrant.registerWith(engine)

        // MethodChannel: lets the background Dart code call back into this service
        // (e.g. to request a stop when the route finishes).
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "stopService" -> {
                        stopSelf()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Execute the dedicated background Dart entry point.
        val bundlePath =
            FlutterInjector.instance().flutterLoader().findAppBundlePath()
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(bundlePath, "busTrackingBackground")
        )
    }
}
