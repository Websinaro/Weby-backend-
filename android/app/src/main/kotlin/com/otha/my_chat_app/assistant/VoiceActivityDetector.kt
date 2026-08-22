package com.otha.my_chat_app.assistant

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * The core battery/CPU optimization for wake-word listening.
 *
 * Running Android's SpeechRecognizer continuously (starting a new
 * recognition session every time the previous one times out) is
 * expensive: each session spins up the system speech service, can
 * involve network traffic, and keeps the mic "hot" with a heavier audio
 * pipeline than is needed 99% of the time nobody is talking to Weby.
 *
 * This class instead does the cheapest possible thing continuously - a
 * raw 16kHz mono AudioRecord loop computing short-term RMS amplitude -
 * and only asks the caller to pay for a real SpeechRecognizer session
 * when it sees sustained voice-level energy. Idle-room silence costs a
 * few basic float operations per ~30ms frame; nothing else runs.
 *
 * This is a threshold/energy-based VAD, not a neural one - it's a
 * pragmatic, dependency-free improvement over "always run full STT",
 * not a replacement for a proper wake-word engine (see README_WEBY_NATIVE.md
 * for that tradeoff).
 */
class VoiceActivityDetector(
    private val onVoiceDetected: () -> Unit,
) {
    companion object {
        private const val SAMPLE_RATE = 16000
        private const val FRAME_MS = 30
        private const val FRAME_SIZE = SAMPLE_RATE * FRAME_MS / 1000 // samples per frame
        // Consecutive above-threshold frames required before we treat it as
        // real speech rather than a door slam / cough - cuts false triggers
        // (and therefore avoids unnecessarily expensive STT sessions).
        private const val REQUIRED_CONSECUTIVE_FRAMES = 4
        // How many quiet frames we average over to learn the room's noise
        // floor, so the same threshold works in a quiet bedroom or a noisy
        // kitchen without hand-tuning.
        private const val CALIBRATION_FRAMES = 40
        private const val VOICE_MULTIPLIER = 2.2
    }

    private var audioRecord: AudioRecord? = null
    private var thread: Thread? = null
    @Volatile private var isRunning = false
    private val mainHandler = Handler(Looper.getMainLooper())

    fun start() {
        if (isRunning) return
        val minBufferSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBufferSize <= 0) return

        val record = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBufferSize, FRAME_SIZE * 4)
            )
        } catch (e: SecurityException) {
            return // RECORD_AUDIO not granted - caller should have checked first
        }

        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            return
        }

        audioRecord = record
        isRunning = true
        record.startRecording()

        thread = Thread(::runLoop, "weby-vad").apply {
            priority = Thread.MIN_PRIORITY + 1 // stay out of the way of everything else
            start()
        }
    }

    fun stop() {
        isRunning = false
        thread?.interrupt()
        thread = null
        audioRecord?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
                // already stopped
            }
            it.release()
        }
        audioRecord = null
    }

    private fun runLoop() {
        val buffer = ShortArray(FRAME_SIZE)
        var noiseFloor = 0.0
        var calibrationCount = 0
        var consecutiveLoudFrames = 0

        while (isRunning) {
            val record = audioRecord ?: break
            val read = record.read(buffer, 0, FRAME_SIZE)
            if (read <= 0) continue

            val rms = rmsOf(buffer, read)

            if (calibrationCount < CALIBRATION_FRAMES) {
                // Learn the ambient noise level first, before treating
                // anything as a candidate wake trigger.
                noiseFloor = ((noiseFloor * calibrationCount) + rms) / (calibrationCount + 1)
                calibrationCount++
                continue
            }

            val threshold = maxOf(noiseFloor * VOICE_MULTIPLIER, 300.0)
            if (rms > threshold) {
                consecutiveLoudFrames++
                if (consecutiveLoudFrames >= REQUIRED_CONSECUTIVE_FRAMES) {
                    consecutiveLoudFrames = 0
                    mainHandler.post { if (isRunning) onVoiceDetected() }
                    // Pause briefly so we don't fire again immediately while
                    // the caller spins up the real recognizer for the same
                    // utterance; caller calls stop()/start() around that.
                    return
                }
            } else {
                consecutiveLoudFrames = 0
                // Slowly adapt to a rising noise floor (e.g. TV turned on)
                // so we don't stay stuck triggering constantly.
                noiseFloor = noiseFloor * 0.98 + rms * 0.02
            }
        }
    }

    private fun rmsOf(buffer: ShortArray, length: Int): Double {
        var sum = 0.0
        for (i in 0 until length) {
            val sample = buffer[i].toDouble()
            sum += sample * sample
        }
        return sqrt(sum / length).let { abs(it) }
    }
}
