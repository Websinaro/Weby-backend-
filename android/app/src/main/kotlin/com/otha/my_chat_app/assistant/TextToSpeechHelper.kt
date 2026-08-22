package com.otha.my_chat_app.assistant

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale

/**
 * Thin wrapper around Android's on-device TextToSpeech engine. Prefers
 * local TTS (per spec section 31) - nothing here sends response text to
 * a third-party TTS service.
 */
class TextToSpeechHelper(context: Context, private val onDone: () -> Unit) {

    private var tts: TextToSpeech? = null
    private var isReady = false
    private val pendingQueue = mutableListOf<String>()

    init {
        tts = TextToSpeech(context.applicationContext) { status ->
            isReady = status == TextToSpeech.SUCCESS
            if (isReady) {
                tts?.language = Locale.getDefault()
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {}
                    override fun onDone(utteranceId: String?) { onDone() }
                    @Deprecated("Deprecated in API, kept for older devices")
                    override fun onError(utteranceId: String?) { onDone() }
                })
                pendingQueue.forEach { speakInternal(it) }
                pendingQueue.clear()
            }
        }
    }

    fun speak(text: String) {
        if (isReady) speakInternal(text) else pendingQueue.add(text)
    }

    private fun speakInternal(text: String) {
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "weby_utterance")
    }

    fun stop() {
        tts?.stop()
    }

    fun release() {
        tts?.stop()
        tts?.shutdown()
        tts = null
    }
}
