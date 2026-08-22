package com.otha.my_chat_app.assistant

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The always-on-while-active piece of Weby: a foreground service that
 * (1) runs the low-power wake-word standby loop, (2) hosts the floating
 * overlay window via a dedicated FlutterEngine + FlutterView, and (3)
 * executes local commands (open app / call contact) directly, without
 * needing the main app process or its UI to be running.
 *
 * Resource-usage notes (see also VoiceActivityDetector.kt and
 * WakeWordDetector.kt for the listening pipeline itself):
 *  - The overlay FlutterEngine is created LAZILY, on the first confirmed
 *    wake word, not at service startup - while idly waiting for the
 *    wake word, this service holds no Flutter engine/view/window at all,
 *    just the lightweight VAD thread.
 *  - A wake lock is only held for the few seconds of an active STT
 *    session (confirming the wake word / capturing a command), never
 *    while idly standing by.
 *  - onTaskRemoved() restarts the service if the OS/OEM kills it when
 *    the user swipes the app away from Recents, so "app closed, say
 *    Weby" keeps working - see the battery-optimization note in
 *    README_WEBY_NATIVE.md for the one thing only the user can grant
 *    (exemption from OEM background-kill policies).
 */
class OverlayService : Service() {

    companion object {
        const val OVERLAY_ENGINE_ID = "weby_overlay_engine"
        const val OVERLAY_CHANNEL = "com.weby/overlay"
        const val ACTION_STOP = "com.otha.my_chat_app.action.STOP_ASSISTANT"

        // Configurable from Dart via the bridge channel; falls back to the
        // spec's default wake word.
        var wakeWord: String = "Weby"
    }

    private var windowManager: WindowManager? = null
    private var flutterView: FlutterView? = null
    private var flutterEngine: FlutterEngine? = null
    private var overlayChannel: MethodChannel? = null
    private var wakeWordDetector: WakeWordDetector? = null
    private var ttsHelper: TextToSpeechHelper? = null
    private var isOverlayShown = false
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val notification = NotificationHelper.build(this, "Standing by for \"$wakeWord\"")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NotificationHelper.NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(NotificationHelper.NOTIFICATION_ID, notification)
        }

        // NOTE: the overlay FlutterEngine is intentionally NOT created
        // here - see setupOverlayEngineIfNeeded(), called only once a
        // wake word actually fires. Standby costs just the VAD thread.
        setupWakeWordDetector()
        ttsHelper = TextToSpeechHelper(this) {
            overlayChannel?.invokeMethod("onSpeakingDone", null)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        wakeWordDetector?.start()
        return START_STICKY
    }

    /**
     * Called when the user swipes Weby out of Recents. Without this, many
     * OEM launchers (and even stock AOSP in some configurations) kill a
     * foreground service along with the task, which would silently break
     * "say Weby while the app is fully closed". We immediately restart.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        val restartIntent = Intent(applicationContext, OverlayService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            applicationContext.startForegroundService(restartIntent)
        } else {
            applicationContext.startService(restartIntent)
        }
    }

    override fun onDestroy() {
        wakeWordDetector?.stop()
        releaseWakeLock()
        ttsHelper?.release()
        hideOverlayWindow()
        flutterEngine?.destroy()
        flutterEngine = null
        FlutterEngineCache.getInstance().remove(OVERLAY_ENGINE_ID)
        super.onDestroy()
    }

    // ---- Flutter overlay engine (lazy) ----

    private fun setupOverlayEngineIfNeeded() {
        if (flutterEngine != null) return

        val loader = FlutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
        }

        val engine = FlutterEngine(applicationContext)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "overlayMain")
        )
        FlutterEngineCache.getInstance().put(OVERLAY_ENGINE_ID, engine)
        flutterEngine = engine

        overlayChannel = MethodChannel(engine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result -> handleOverlayChannelCall(call, result) }
        }
    }

    private fun handleOverlayChannelCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Dart tells native it's done rendering this turn - either
            // dismiss or resume wake-word standby.
            "closeOverlay" -> {
                hideOverlayWindow()
                wakeWordDetector?.start()
                result.success(null)
            }
            "speak" -> {
                val text = call.argument<String>("text") ?: ""
                ttsHelper?.speak(text)
                result.success(null)
            }
            "stopSpeaking" -> {
                ttsHelper?.stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ---- Wake word / STT ----

    private fun setupWakeWordDetector() {
        wakeWordDetector = WakeWordDetector(
            context = this,
            wakeWord = wakeWord,
            onWakeWordDetected = {
                acquireWakeLockBriefly()
                setupOverlayEngineIfNeeded()
                showOverlayWindow()
                overlayChannel?.invokeMethod("onWakeWordDetected", null)
                wakeWordDetector?.startCommandCapture()
            },
            onCommandPartialResult = { partial ->
                overlayChannel?.invokeMethod("onPartialTranscript", mapOf("text" to partial))
            },
            onCommandFinalResult = { finalText ->
                releaseWakeLock()
                overlayChannel?.invokeMethod("onFinalTranscript", mapOf("text" to finalText))
                handleFinalTranscript(finalText)
            },
            onListeningError = { message ->
                releaseWakeLock()
                overlayChannel?.invokeMethod("onListeningError", mapOf("message" to message))
            },
        )
    }

    /**
     * Held only for the few seconds of an active wake-word-confirmation or
     * command-capture STT session, so a short screen-off Doze window can't
     * cut it off mid-sentence. Always paired with a release - see
     * onCommandFinalResult/onListeningError above and the safety-net
     * timeout below in case a recognizer callback is ever missed.
     */
    private fun acquireWakeLockBriefly() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Weby:CommandCapture").apply {
            acquire(15_000L) // hard safety timeout - never held indefinitely
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    private fun handleFinalTranscript(text: String) {
        when (val intent = IntentClassifier.classify(text)) {
            is IntentClassifier.LocalIntent.OpenApp -> {
                val outcome = AppLauncher.openAppByName(this, intent.target)
                val message = when (outcome) {
                    is AppLauncher.OpenAppResult.Opened -> "Opening ${outcome.label}"
                    is AppLauncher.OpenAppResult.Ambiguous ->
                        "I found multiple apps matching that: ${outcome.candidates.joinToString(", ")}"
                    AppLauncher.OpenAppResult.NotFound -> "I couldn't find that app"
                }
                overlayChannel?.invokeMethod("onLocalExecutionResult", mapOf("message" to message))
            }
            is IntentClassifier.LocalIntent.CallContact -> {
                val contact = RelationshipStore.resolve(this, intent.relationship)
                val message = if (contact?.phoneNumber != null) {
                    ContactsBridge.callNumber(this, contact.phoneNumber)
                    "Calling ${contact.name}"
                } else {
                    "You haven't set up who your ${intent.relationship} is yet. Add it in Settings > Contacts."
                }
                overlayChannel?.invokeMethod("onLocalExecutionResult", mapOf("message" to message))
            }
            IntentClassifier.LocalIntent.None -> {
                // Not a recognized local command - hand off to Dart, which
                // calls the authenticated /ai/chat backend and manages the
                // processing/speaking states and reply text.
                overlayChannel?.invokeMethod("onAiPromptRequested", mapOf("prompt" to text))
            }
        }
    }

    // ---- Overlay window management ----

    private fun showOverlayWindow() {
        if (isOverlayShown) return
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        windowManager = wm

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            // Permission not granted - Dart side should have already guided
            // the user through PermissionsManager.requestOverlayPermission.
            overlayChannel?.invokeMethod(
                "onListeningError",
                mapOf("message" to "Overlay permission not granted")
            )
            return
        }

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = 48
        }

        val engine = flutterEngine ?: return
        val view = FlutterView(this).apply {
            attachToFlutterEngine(engine)
        }
        flutterView = view
        wm.addView(view, params)
        isOverlayShown = true
    }

    private fun hideOverlayWindow() {
        if (!isOverlayShown) return
        flutterView?.let { view ->
            view.detachFromFlutterEngine()
            windowManager?.removeView(view)
        }
        flutterView = null
        isOverlayShown = false
    }
}
