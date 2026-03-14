package com.example.transit_pro

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BusTrackingService.CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    if (!hasLocationPermission()) {
                        result.error(
                            "MISSING_LOCATION_PERMISSION",
                            "Location permission is required before starting background tracking.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val intent = Intent(this, BusTrackingService::class.java)
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    } catch (e: SecurityException) {
                        result.error(
                            "FGS_START_NOT_ALLOWED",
                            e.message,
                            null
                        )
                    }
                }
                "stopService" -> {
                    stopService(Intent(this, BusTrackingService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasLocationPermission(): Boolean {
        val hasFine =
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        val hasCoarse =
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        return hasFine || hasCoarse
    }
}

