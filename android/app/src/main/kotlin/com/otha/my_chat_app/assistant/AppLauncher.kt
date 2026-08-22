package com.otha.my_chat_app.assistant

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

/**
 * Local app registry + launcher. Enumerates only apps that declare a
 * MAIN/LAUNCHER activity (visible via the <queries> block in the
 * manifest, not the QUERY_ALL_PACKAGES restricted permission), and opens
 * them via a plain launch Intent - entirely on-device, no network call.
 */
object AppLauncher {

    data class AppInfo(val label: String, val packageName: String)

    fun listLaunchableApps(context: Context): List<AppInfo> {
        val pm = context.packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolved = pm.queryIntentActivities(launcherIntent, PackageManager.MATCH_ALL)
        return resolved.mapNotNull { info ->
            val label = info.loadLabel(pm)?.toString() ?: return@mapNotNull null
            val pkg = info.activityInfo?.packageName ?: return@mapNotNull null
            AppInfo(label, pkg)
        }.distinctBy { it.packageName }.sortedBy { it.label.lowercase() }
    }

    /**
     * Resolves a spoken app name (e.g. "whatsapp") against installed apps
     * using a simple case-insensitive contains/startsWith match, then
     * launches it. Returns a result the Dart side can turn into the
     * "Weby couldn't find WhatsApp" / success message.
     */
    fun openAppByName(context: Context, spokenName: String): OpenAppResult {
        val query = spokenName.trim().lowercase()
        if (query.isEmpty()) return OpenAppResult.NotFound

        val apps = listLaunchableApps(context)
        val exact = apps.firstOrNull { it.label.lowercase() == query }
        val startsWith = apps.firstOrNull { it.label.lowercase().startsWith(query) }
        val contains = apps.filter { it.label.lowercase().contains(query) }

        val match = exact ?: startsWith ?: contains.firstOrNull()
            ?: return OpenAppResult.NotFound

        if (contains.size > 1 && exact == null && startsWith == null) {
            return OpenAppResult.Ambiguous(contains.map { it.label })
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(match.packageName)
            ?: return OpenAppResult.NotFound
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(launchIntent)
        return OpenAppResult.Opened(match.label)
    }

    sealed class OpenAppResult {
        data class Opened(val label: String) : OpenAppResult()
        data class Ambiguous(val candidates: List<String>) : OpenAppResult()
        object NotFound : OpenAppResult()
    }
}
