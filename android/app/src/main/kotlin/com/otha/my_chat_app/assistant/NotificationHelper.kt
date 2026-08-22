package com.otha.my_chat_app.assistant

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.otha.my_chat_app.MainActivity
import com.otha.my_chat_app.R

/**
 * Builds the persistent, low-priority notification Android requires for
 * any foreground service. Tapping it returns the user to the app - Weby
 * never hides or disguises the fact that the assistant is running, per
 * the spec's "do not disguise the overlay as a system UI" rule.
 */
object NotificationHelper {

    const val CHANNEL_ID = "weby_assistant_channel"
    const val NOTIFICATION_ID = 4201

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Weby Assistant",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Shows when Weby is listening for its wake word"
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }
    }

    fun build(context: Context, contentText: String): android.app.Notification {
        ensureChannel(context)

        val openAppIntent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Weby is listening")
            .setContentText(contentText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setContentIntent(pendingIntent)
            .build()
    }
}
