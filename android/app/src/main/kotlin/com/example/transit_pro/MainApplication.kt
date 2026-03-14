package com.example.transit_pro

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class MainApplication : Application() {

    companion object {
        /** Channel used for geofence / bus-event push notifications. */
        const val MAIN_CHANNEL_ID = "transit_pro_channel"

        /** Channel used for the silent foreground-service notification. */
        const val SERVICE_CHANNEL_ID = "transit_pro_service_channel"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)

            // High-importance channel for bus-event alerts
            val mainChannel = NotificationChannel(
                MAIN_CHANNEL_ID,
                "Transit Pro",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Bus tracking notifications"
                enableLights(true)
                enableVibration(true)
            }

            // Low-importance channel for the persistent foreground service tile
            val serviceChannel = NotificationChannel(
                SERVICE_CHANNEL_ID,
                "Background Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps bus tracking active in the background"
                setShowBadge(false)
            }

            manager.createNotificationChannel(mainChannel)
            manager.createNotificationChannel(serviceChannel)
        }
    }
}
