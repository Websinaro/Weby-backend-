# Weby Native Android Integration

This adds the Kotlin pieces described in spec sections 20-28 on top of
your existing `my_chat_app` Android project (package `com.otha.my_chat_app`).

## What's new

```
android/app/src/main/kotlin/com/otha/my_chat_app/
├── MainActivity.kt                  (updated - registers the "com.weby/bridge" channel)
└── assistant/
    ├── OverlayService.kt            Foreground service: wake word + STT + floating overlay window
    ├── WakeWordDetector.kt          SpeechRecognizer-based wake word / command capture loop
    ├── IntentClassifier.kt          Local-vs-AI text routing (mirrors Dart's AssistantController)
    ├── AppLauncher.kt               Enumerate + launch installed apps via Intent
    ├── ContactsBridge.kt            Read contacts locally; place calls (ACTION_CALL/ACTION_DIAL)
    ├── RelationshipStore.kt         "bro" -> contact mapping, local SharedPreferences only
    ├── PermissionsManager.kt        Runtime + overlay permission status/requests
    ├── NotificationHelper.kt        Required foreground-service notification
    └── TextToSpeechHelper.kt        On-device TTS wrapper
```

Plus `AndroidManifest.xml` now declares: `RECORD_AUDIO`, `READ_CONTACTS`,
`CALL_PHONE`, `SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_MICROPHONE`, `POST_NOTIFICATIONS`, the `OverlayService`
declaration, and `<queries>` for launcher/dial/call intents (no
`QUERY_ALL_PACKAGES`, which is Play-Store restricted).

`app/build.gradle.kts` now pulls in `androidx.core:core-ktx` for
`NotificationCompat` / `ContextCompat` / `ActivityCompat`.

## How the pieces fit together

- **Foreground app** (main Flutter engine, package `com.weby/bridge`
  channel via `NativeBridge` in Dart): used for anything the user does
  *inside* the app - Settings > Contacts relationship setup, tap-to-talk
  on the Home screen, permission requests.
- **Background** (`OverlayService`, its own Flutter engine running the
  `overlayMain()` entrypoint): runs independently of the main app process.
  Wake word detected → `WakeWordDetector` captures the command → 
  `IntentClassifier` decides locally (open app / call contact, executed
  immediately and natively) or hands the text to the overlay's Dart
  engine (`onAiPromptRequested`), which calls the real `/ai/chat` backend
  and speaks the reply via `TextToSpeechHelper`.

Both paths share the same Dart `AssistantCircle` widget for the visual
orb - the overlay window (`OverlayService.showOverlayWindow`) attaches a
`FlutterView` to the `overlayMain` engine, so the exact same UI code
renders whether it's shown in-app or in the system overlay.

## Battery/resource optimizations (added after initial review)

The first version of this integration ran Android's `SpeechRecognizer` in
a near-continuous restart loop while waiting for the wake word - that's
expensive (each session can involve network use and keeps a heavier
audio pipeline "hot") and is the main thing fixed here:

- **`VoiceActivityDetector.kt`** is new: a raw `AudioRecord` amplitude
  check running continuously and cheaply (no ASR, no network - just
  float math on 30ms audio frames). It self-calibrates to the room's
  noise floor and only reports "likely speech" after several consecutive
  above-threshold frames (debounced against coughs/door slams).
- **`WakeWordDetector.kt`** now only pays for a real STT session *after*
  the VAD sees real speech-level sound, to confirm whether the wake word
  was actually said - not on a timer. It also passes
  `EXTRA_PREFER_OFFLINE` to prefer on-device recognition when the device
  supports it (faster, no network round-trip) and uses a short silence
  timeout during wake-word confirmation, since only 1-2 words are needed.
- **`OverlayService.kt`**: the overlay's `FlutterEngine`/`FlutterView`
  are now created **lazily**, only once the wake word actually fires -
  while on standby, the service holds no Flutter engine, view, or
  window at all, just the lightweight VAD thread. A `PARTIAL_WAKE_LOCK`
  is acquired only for the few seconds of an active STT session (with a
  hard 15s safety timeout) rather than held continuously.
- **"App fully closed, say Weby, get a spoken answer" reliability**:
  `android:stopWithTask="false"` on the service plus an `onTaskRemoved()`
  override that restarts it cover the common case of the user swiping
  Weby out of Recents. The one thing only the *user* can grant is
  exemption from OEM battery-optimization kill policies (Settings >
  Assistant now has a card explaining this and a button that opens the
  standard Android "ignore battery optimizations" dialog - never
  requested silently).

None of this replaces a dedicated low-power wake-word engine (still not
available as a public Android API - see the limitation below), but it
removes the main unnecessary cost: Weby no longer runs full speech
recognition just to check if the room is quiet.

## Documented platform limitations (per spec section 52 - not silently worked around)

- **No true always-on wake-word API on Android.** `WakeWordDetector` now
  uses a two-stage pipeline - a cheap always-on `VoiceActivityDetector`
  (raw amplitude check, no ASR) gates a real `SpeechRecognizer` session,
  which only runs when the VAD hears real speech. This is significantly
  cheaper than running `SpeechRecognizer` continuously, but it's still
  not as efficient as a dedicated neural wake-word engine (Porcupine,
  Vosk, etc. - third-party SDKs). Swapping one in later only means
  replacing `VoiceActivityDetector`/`WakeWordDetector`; everything
  downstream is unaffected.
- **Overlay permission (`SYSTEM_ALERT_WINDOW`) is a special permission**
  granted via a Settings screen, not the normal runtime dialog -
  `PermissionsManager.requestOverlayPermission()` opens it; the user
  must approve it there.
- **Foreground service + Doze/background limits**: Android may still
  delay or restrict background mic access depending on OEM battery
  optimizations; users may need to disable battery optimization for Weby
  for fully reliable always-listening behavior.
- **Calling** uses `ACTION_CALL` only if `CALL_PHONE` is granted;
  otherwise it degrades to `ACTION_DIAL` (opens the dialer pre-filled,
  needs the user to tap send) rather than failing.

## Testing

No Android SDK/emulator was available in the environment that generated
this code, so it has been carefully hand-reviewed but **not compiled**.
Before relying on it:

```bash
flutter pub get
flutter build apk --debug
```

and fix any compiler errors that surface - most likely candidates are
Flutter embedding API names drifting slightly between Flutter versions
(the `FlutterEngine`/`FlutterView`/`FlutterEngineCache`/`DartExecutor`
APIs used here are stable but do get renamed occasionally across major
Flutter releases).
