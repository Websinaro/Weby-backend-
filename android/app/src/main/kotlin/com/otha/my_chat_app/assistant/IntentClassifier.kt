package com.otha.my_chat_app.assistant

/**
 * Mirrors the local-vs-AI routing rule from the product spec (section 29)
 * natively, so local commands still work when only the background
 * OverlayService is alive and the main Flutter engine isn't running.
 * The Dart-side AssistantController applies the same rule when the app
 * itself is in the foreground - the two are kept intentionally simple
 * and in sync rather than sharing code across the Kotlin/Dart boundary.
 */
object IntentClassifier {

    sealed class LocalIntent {
        data class OpenApp(val target: String) : LocalIntent()
        data class CallContact(val relationship: String) : LocalIntent()
        object None : LocalIntent()
    }

    private val openPrefixes = listOf("open ", "launch ", "start ")
    private val callPrefixes = listOf("call my ", "call ", "phone my ", "phone ")

    fun classify(text: String): LocalIntent {
        val normalized = text.trim().lowercase()

        for (prefix in openPrefixes) {
            if (normalized.startsWith(prefix)) {
                return LocalIntent.OpenApp(normalized.removePrefix(prefix).trim())
            }
        }

        for (prefix in callPrefixes) {
            if (normalized.startsWith(prefix)) {
                return LocalIntent.CallContact(normalized.removePrefix(prefix).trim())
            }
        }

        return LocalIntent.None
    }
}
