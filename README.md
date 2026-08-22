# Weby Frontend (Flutter)

This is the Weby Flutter application: authentication, settings/management
screens, and the animated Weby assistant orb + floating overlay.

## Merging into your existing Android Studio project

You uploaded an existing Flutter project scaffold (`my_chat_app`) that
already has working `android/` and `ios/` folders. Rather than
regenerating those (which would just reproduce Android Studio's own
defaults), drop these files into that project:

1. Copy `lib/` from this zip over your project's `lib/` folder (replacing the counter-app boilerplate).
2. Replace your `pubspec.yaml` with the one in this zip, then run `flutter pub get`.
3. Keep your existing `android/`, `ios/`, `test/` folders as-is - native Android work (overlay, foreground service, contacts, telephony, MethodChannel) lands in the next build stage and will edit `android/app/src/main/kotlin/...` directly.

## Configuration

Point the app at your deployed (or local) backend at build/run time:

```bash
flutter run --dart-define=API_BASE_URL=https://your-backend.example.com/api/v1
```

Defaults to `http://10.0.2.2:3000/api/v1`, which is how the Android
emulator reaches `localhost:3000` on your dev machine - convenient for
testing against the backend from stage 1 with no config needed.

## What's implemented in this stage

- **Auth:** Splash (session bootstrap) → Login / Register → Home. Google Sign-In UI is wired up but needs `google_sign_in` configured with your `GOOGLE_CLIENT_ID` to actually obtain a real ID token (currently shows a placeholder message).
- **Token handling:** access + refresh tokens in `flutter_secure_storage`; a Dio interceptor auto-refreshes on 401, queues concurrent requests during a refresh, and force-signs-out on an unrecoverable refresh failure.
- **The Weby orb** (`lib/features/assistant/presentation/assistant_circle.dart`): a from-scratch `CustomPainter` animation - breathing ripple rings, a rotating gradient "thinking" ring, a glassy gradient core, and a live equalizer-style waveform - driven purely by `AnimationController`s, no image assets. Six states: idle, listening, processing, speaking, executing, error.
- **Floating overlay** (`assistant_overlay.dart`): bottom-anchored, non-blocking, shows the orb + live transcript + AI response, in-app today, and it's the exact widget the native stage will render inside Android's overlay window.
- **Settings hub:** Account, Assistant (name/wake word/voice verification/AI provider), Privacy (plain-language explanations, not just toggles), History (list + delete).
- **AI round-trip works today:** since there's no real STT wired in yet, the listening sheet has a text field standing in for the live transcript - type a question and it hits your real `/ai/chat` backend end-to-end. This is the exact seam the Kotlin `SpeechRecognizer` stream will plug into next.

## Not yet implemented (next stage: Android/Kotlin native)

- Real wake-word detection & speech-to-text (currently a text-input stand-in)
- The true system-level floating overlay (`TYPE_APPLICATION_OVERLAY`)
- Foreground service for background listening
- Contacts + relationship mapping ("call my bro")
- App-launching via Android Intents
- Text-to-speech playback of responses
- The Flutter↔Kotlin MethodChannel itself

These all have clean seams already: `AssistantController` in
`lib/features/assistant/state/assistant_controller.dart` is where
`updateTranscript()` will be fed from a native EventChannel stream, and
`_localCommandPrefixes` is where the open/call intent detection will
hand off to the platform channel instead of showing a placeholder message.
