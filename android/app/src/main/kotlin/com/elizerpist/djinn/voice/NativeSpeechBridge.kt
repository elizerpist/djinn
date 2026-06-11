package com.elizerpist.djinn.voice

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NativeSpeechBridge(private val context: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    RecognitionListener {

    private var eventSink: EventChannel.EventSink? = null
    private var recognizer: SpeechRecognizer? = null
    private var currentSessionId: Int = 0
    private var sessionCounter: Int = 0

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val locale = call.argument<String>("locale")
                start(locale, result)
            }

            "stop" -> {
                stop()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun start(locale: String?, result: MethodChannel.Result) {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            emitError("error_unavailable")
            result.error("unavailable", "SpeechRecognizer unavailable", null)
            return
        }

        if (ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.RECORD_AUDIO
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            emitError("error_permission")
            result.error("permission_denied", "Microphone permission missing", null)
            return
        }

        stopRecognizer()
        sessionCounter += 1
        currentSessionId = sessionCounter

        recognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
            setRecognitionListener(this@NativeSpeechBridge)
        }

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale ?: "")
        }

        recognizer?.startListening(intent)
        result.success(
            mapOf(
                "sessionId" to currentSessionId,
                "locale" to (locale ?: "")
            )
        )
    }

    private fun stop() {
        recognizer?.stopListening()
    }

    private fun stopRecognizer() {
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
    }

    private fun emitStatus(status: String) {
        eventSink?.success(
            mapOf(
                "type" to "status",
                "sessionId" to currentSessionId,
                "status" to status,
            )
        )
    }

    private fun emitResult(text: String, final: Boolean) {
        eventSink?.success(
            mapOf(
                "type" to "result",
                "sessionId" to currentSessionId,
                "text" to text,
                "final" to final,
            )
        )
    }

    private fun emitError(code: String) {
        eventSink?.success(
            mapOf(
                "type" to "error",
                "sessionId" to currentSessionId,
                "code" to code,
            )
        )
    }

    override fun onReadyForSpeech(params: Bundle?) {
        emitStatus("listening")
    }

    override fun onBeginningOfSpeech() {}

    override fun onRmsChanged(rmsdB: Float) {}

    override fun onBufferReceived(buffer: ByteArray?) {}

    override fun onEndOfSpeech() {
        emitStatus("notListening")
    }

    override fun onError(error: Int) {
        emitError(mapError(error))
        emitStatus("done")
        stopRecognizer()
    }

    override fun onResults(results: Bundle?) {
        val text = results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            ?.trim()
            .orEmpty()
        if (text.isNotEmpty()) {
            emitResult(text, true)
        }
        emitStatus("done")
        stopRecognizer()
    }

    override fun onPartialResults(partialResults: Bundle?) {
        val text = partialResults
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            ?.trim()
            .orEmpty()
        if (text.isNotEmpty()) {
            emitResult(text, false)
        }
    }

    override fun onEvent(eventType: Int, params: Bundle?) {}

    private fun mapError(error: Int): String {
        return when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "error_audio_error"
            SpeechRecognizer.ERROR_CLIENT -> "error_client"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "error_permission"
            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "error_language_not_supported"
            SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "error_language_not_supported"
            SpeechRecognizer.ERROR_NETWORK -> "error_network"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "error_network_timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "error_no_match"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "error_server_disconnected"
            SpeechRecognizer.ERROR_SERVER -> "error_server_disconnected"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "error_speech_timeout"
            else -> "error_unknown"
        }
    }
}
