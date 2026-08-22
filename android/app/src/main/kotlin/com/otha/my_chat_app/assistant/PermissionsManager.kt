package com.otha.my_chat_app.assistant

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

/**
 * Centralizes every runtime/special permission Weby needs, and reports
 * their status back to Dart as simple booleans so the Flutter settings
 * screens can explain *why* a permission is needed before asking for it,
 * per the spec's "request permissions only when required, with an
 * understandable flow" rule.
 */
object PermissionsManager {

    const val REQUEST_CODE = 8420

    fun runtimePermissions(): Array<String> {
        val perms = mutableListOf(
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.READ_CONTACTS,
            Manifest.permission.CALL_PHONE,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            perms.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        return perms.toTypedArray()
    }

    fun statusMap(context: Context): Map<String, Boolean> {
        val map = mutableMapOf<String, Boolean>()
        map["microphone"] = isGranted(context, Manifest.permission.RECORD_AUDIO)
        map["contacts"] = isGranted(context, Manifest.permission.READ_CONTACTS)
        map["callPhone"] = isGranted(context, Manifest.permission.CALL_PHONE)
        map["overlay"] = Settings.canDrawOverlays(context)
        map["notifications"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            isGranted(context, Manifest.permission.POST_NOTIFICATIONS)
        } else {
            true
        }
        map["batteryUnrestricted"] = isIgnoringBatteryOptimizations(context)
        return map
    }

    private fun isGranted(context: Context, permission: String): Boolean {
        return ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    }

    fun requestRuntimePermissions(activity: Activity) {
        ActivityCompat.requestPermissions(activity, runtimePermissions(), REQUEST_CODE)
    }

    /** Overlay ("draw over other apps") is a special permission granted via
     * Settings, not the normal runtime permission dialog. */
    fun requestOverlayPermission(activity: Activity) {
        if (!Settings.canDrawOverlays(activity)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${activity.packageName}")
            )
            activity.startActivity(intent)
        }
    }

    /**
     * Whether the OS is currently allowed to apply its normal battery
     * optimizations (Doze/App Standby) to this app. If true, background
     * wake-word listening may be delayed or paused by the OS/OEM even
     * with a foreground service running - we surface this clearly rather
     * than silently degrading, and let the USER decide whether to grant
     * the exemption (this is not requested automatically).
     */
    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    /**
     * Opens the system dialog asking the user to exempt Weby from battery
     * optimizations. This is the standard, Play-Store-compliant way to
     * ask (as opposed to silently trying to defeat Doze) - the user can
     * always decline, and the app remains usable either way, just with
     * background wake-word timing being best-effort under Doze if declined.
     */
    fun requestIgnoreBatteryOptimizations(activity: Activity) {
        if (isIgnoringBatteryOptimizations(activity)) return
        val intent = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:${activity.packageName}")
        )
        activity.startActivity(intent)
    }
}
