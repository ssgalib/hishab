package com.expense.tracker

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class SpeechChannel(private val context: Context, messenger: BinaryMessenger) {

    private val channel = MethodChannel(messenger, "com.expense.tracker/speech")
    private val mainHandler = Handler(Looper.getMainLooper())
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> mainHandler.post { startListening(result) }
                "stopListening" -> mainHandler.post { stopListening(result) }
                else -> result.notImplemented()
            }
        }
    }

    private fun startListening(result: MethodChannel.Result) {
        if (speechRecognizer != null) {
            speechRecognizer?.destroy()
            speechRecognizer = null
        }
        pendingResult = result
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                complete(Result(matches?.firstOrNull() ?: ""))
            }

            override fun onError(error: Int) {
                complete(Result(error = "STT_ERROR: $error"))
            }

            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        speechRecognizer?.startListening(intent)
    }

    private fun stopListening(result: MethodChannel.Result) {
        speechRecognizer?.stopListening()
        result.success(null)
    }

    private fun complete(r: Result) {
        mainHandler.post {
            val res = pendingResult
            pendingResult = null
            speechRecognizer?.destroy()
            speechRecognizer = null
            if (res == null) return@post
            if (r.error == null) res.success(r.text)
            else res.error("STT_ERROR", r.error, null)
        }
    }

    private data class Result(val text: String = "", val error: String? = null)
}
