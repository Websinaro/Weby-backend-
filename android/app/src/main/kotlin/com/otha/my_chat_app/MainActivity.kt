package com.otha.my_chat_app

import android.content.Intent
import android.os.Build
import com.otha.my_chat_app.assistant.AppLauncher
import com.otha.my_chat_app.assistant.ContactsBridge
import com.otha.my_chat_app.assistant.OverlayService
import com.otha.my_chat_app.assistant.PermissionsManager
import com.otha.my_chat_app.assistant.RelationshipStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Registers the single "com.weby/bridge" MethodChannel used by the main
 * Flutter app (not the overlay - see OverlayService for that one) to
 * reach every native capability listed in spec section 24: openApp,
 * getAvailableApps, getContacts, callContact, startAssistant,
 * stopAssistant, checkPermissions, requestPermissions.
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val BRIDGE_CHANNEL = "com.weby/bridge"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BRIDGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAvailableApps" -> {
                        val apps = AppLauncher.listLaunchableApps(this).map {
                            mapOf("label" to it.label, "packageName" to it.packageName)
                        }
                        result.success(apps)
                    }

                    "openApp" -> {
                        val target = call.argument<String>("target") ?: ""
                        when (val outcome = AppLauncher.openAppByName(this, target)) {
                            is AppLauncher.OpenAppResult.Opened ->
                                result.success(mapOf("status" to "opened", "label" to outcome.label))
                            is AppLauncher.OpenAppResult.Ambiguous ->
                                result.success(mapOf("status" to "ambiguous", "candidates" to outcome.candidates))
                            AppLauncher.OpenAppResult.NotFound ->
                                result.success(mapOf("status" to "not_found"))
                        }
                    }

                    "getContacts" -> {
                        val contacts = ContactsBridge.listContacts(this).map {
                            mapOf("id" to it.id, "name" to it.name, "phoneNumber" to it.phoneNumber)
                        }
                        result.success(contacts)
                    }

                    "callContact" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        if (phoneNumber.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "phoneNumber is required", null)
                            return@setMethodCallHandler
                        }
                        val outcome = ContactsBridge.callNumber(this, phoneNumber)
                        result.success(
                            mapOf(
                                "status" to when (outcome) {
                                    ContactsBridge.CallResult.Called -> "called"
                                    ContactsBridge.CallResult.OpenedDialer -> "opened_dialer"
                                    ContactsBridge.CallResult.PermissionDenied -> "permission_denied"
                                }
                            )
                        )
                    }

                    "saveRelationship" -> {
                        val relationship = call.argument<String>("relationship") ?: ""
                        val contactId = call.argument<String>("contactId") ?: ""
                        val name = call.argument<String>("name") ?: ""
                        val phoneNumber = call.argument<String>("phoneNumber")
                        RelationshipStore.set(
                            this, relationship,
                            ContactsBridge.Contact(contactId, name, phoneNumber)
                        )
                        result.success(null)
                    }

                    "getRelationships" -> {
                        val map = RelationshipStore.getAll(this).mapValues {
                            mapOf("id" to it.value.id, "name" to it.value.name, "phoneNumber" to it.value.phoneNumber)
                        }
                        result.success(map)
                    }

                    "removeRelationship" -> {
                        val relationship = call.argument<String>("relationship") ?: ""
                        RelationshipStore.remove(this, relationship)
                        result.success(null)
                    }

                    "checkPermissions" -> {
                        result.success(PermissionsManager.statusMap(this))
                    }

                    "requestPermissions" -> {
                        PermissionsManager.requestRuntimePermissions(this)
                        result.success(null)
                    }

                    "requestOverlayPermission" -> {
                        PermissionsManager.requestOverlayPermission(this)
                        result.success(null)
                    }

                    "requestIgnoreBatteryOptimizations" -> {
                        PermissionsManager.requestIgnoreBatteryOptimizations(this)
                        result.success(null)
                    }

                    "startAssistant" -> {
                        val wakeWord = call.argument<String>("wakeWord")
                        if (!wakeWord.isNullOrBlank()) OverlayService.wakeWord = wakeWord
                        val intent = Intent(this, OverlayService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }

                    "stopAssistant" -> {
                        val intent = Intent(this, OverlayService::class.java).apply {
                            action = OverlayService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // Flutter's plugin system already forwards this for registered
        // plugins; PermissionsManager.statusMap() is polled by Dart right
        // after requestPermissions() resolves, so no extra event is needed
        // here beyond letting the system dialog do its job.
    }
}
