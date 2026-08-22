package com.otha.my_chat_app.assistant

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.util.Locale

/**
 * Wake-word + speech-to-text, optimized to avoid the battery/CPU/network
 * cost of running Android's SpeechRecognizer continuously.
 *
 * IMPORTANT PLATFORM LIMITATION (documented per spec section 52 rather
 * than silently worked around): Android has no public, always-on,
 * low-power wake-word API. Proper wake-word engines (Porcupine, Vosk,
 * etc.) are third-party SDKs that run a tiny on-device neural model
 * continuously for near-zero battery cost. Without pulling one in, the
 * best currently-supported approach is a two-stage pipeline:
 *
 *   1. [VoiceActivityDetector] runs continuously and CHEAPLY (a raw
 *      amplitude check on the mic, no ASR, no network) - this is the
 *      only thing running while the room is quiet.
 *   2. Only once real speech-level sound is detected do we pay for a
 *      single SpeechRecognizer session to check whether the wake word
 *      was actually said. If not, we go straight back to step 1 instead
 *      of leaving STT running.
 *
 * This is meaningfully cheaper than the naive "restart SpeechRecognizer
 * every time it times out" loop, but it is still not as efficient as a
 * dedicated wake-word engine - swapping one in later only means
 * replacing this class; OverlayService and everything downstream is
 * unaffected.
 */
class WakeWordDetector(
    private val context: Context,
    private val wakeWord: String,
    private val onWakeWordDetected: () -> Unit,
    private val onCommandPartialResult: (String) -> Unit,
    private val onCommandFinalResult: (String) -> Unit,
    private val onListeningError: (String) -> Unit,
) {
    private var recognizer: SpeechRecognizer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var mode = Mode.IDLE
    private var isStopped = true

    private val vad = VoiceActivityDetector(onVoiceDetected = ::onVoiceLikelyDetected)

    // Accepts "weby" and "hey weby" (spec section 20's optional variant)
    // without needing two separate detection passes.
    private val wakePhrases: List<String>
        get() = listOf(wakeWord.lowercase(), "hey ${wakeWord.lowercase()}")

    private enum class Mode { IDLE, CONFIRMING_WAKE_WORD, COMMAND }

    /** Cheap standby: only the VAD thread is running. No STT, no network. */
    fun start() {
        isStopped = false
        mode = Mode.IDLE
        vad.start()
    }

    fun stop() {
        isStopped = true
        vad.stop()
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
    }

    /** Called after the wake word is confirmed, to capture the actual
     * command ("call my bro") with live partial results for the overlay UI. */
    fun startCommandCapture() {
        mode = Mode.COMMAND
        listenOnce()
    }

    /** VAD saw speech-level audio - now (and only now) pay for a single
     * real STT session to check whether it was actually the wake word. */
    private fun onVoiceLikelyDetected() {
        if (isStopped) return
        mode = Mode.CONFIRMING_WAKE_WORD
        listenOnce()
    }

    private fun listenOnce() {
        if (isStopped || !SpeechRecognizer.isRecognitionAvailable(context)) {
            if (!SpeechRecognizer.isRecognitionAvailable(context)) {
                onListeningError("Speech recognition is not available on this device")
            }
            resumeIdleIfNeeded()
            return
        }

        recognizer?.destroy()
        recognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
            setRecognitionListener(buildListener())
        }

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            // Prefer on-device recognition when available (faster, no
            // network round-trip, better for battery/data) - falls back
            // to the device default automatically if unsupported.
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            if (mode == Mode.CONFIRMING_WAKE_WORD) {
                // Short-circuit fast: we only need a couple of words to
                // know whether the wake word was said, so cut the session
                // short instead of waiting for a long natural pause.
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 600)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 600)
            }
        }

        recognizer?.startListening(intent)
    }

    /** Back to cheap VAD-only standby - the normal resting state. */
    private fun resumeIdleIfNeeded() {
        if (isStopped) return
        mode = Mode.IDLE
        vad.start()
    }

    private fun buildListener() = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {}
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}

        override fun onError(error: Int) {
            if (mode == Mode.COMMAND) {
                val isExpected = error == SpeechRecognizer.ERROR_NO_MATCH ||
                    error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT
                if (!isExpected) onListeningError("Didn't catch that - error code $error")
            }
            // Whether it was a real error or just "no match" (e.g. it was a
            // door slam, not the wake word) - go back to cheap standby
            // rather than immediately trying STT again.
            resumeIdleIfNeeded()
        }

        override fun onResults(results: Bundle?) {
            val text = bestResult(results)

            when (mode) {
                Mode.CONFIRMING_WAKE_WORD -> {
                    if (text != null && wakePhrases.any { text.lowercase().contains(it) }) {
                        onWakeWordDetected()
                    } else {
                        resumeIdleIfNeeded()
                    }
                }
                Mode.COMMAND -> {
                    if (!text.isNullOrBlank()) {
                        onCommandFinalResult(text)
                    } else {
                        onListeningError("Didn't catch that - please try again")
                    }
                    // Caller (OverlayService) decides when to resume standby
                    // listening after handling the command.
                }
                Mode.IDLE -> Unit
            }
        }

        override fun onPartialResults(partialResults: Bundle?) {
            if (mode == Mode.COMMAND) {
                bestResult(partialResults)?.let(onCommandPartialResult)
            }
        }

        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    private fun bestResult(bundle: Bundle?): String? {
        val matches = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        return matches?.firstOrNull()
    }
}
