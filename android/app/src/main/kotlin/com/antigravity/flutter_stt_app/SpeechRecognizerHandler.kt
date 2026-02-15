package com.antigravity.flutter_stt_app

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SpeechRecognizerHandler(
    private val context: Context
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "SpeechRecognizerHandler"
        const val METHOD_CHANNEL = "com.antigravity.stt/speech"
        const val EVENT_CHANNEL = "com.antigravity.stt/speech_events"
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isListening = false

    val streamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
            Log.d(TAG, "EventChannel: onListen")
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
            Log.d(TAG, "EventChannel: onCancel")
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(result)
            "startListening" -> {
                val localeId = call.argument<String>("localeId") ?: "en-US"
                startListening(localeId, result)
            }
            "stopListening" -> stopListening(result)
            "cancelListening" -> cancelListening(result)
            "isAvailable" -> {
                val available = SpeechRecognizer.isRecognitionAvailable(context)
                Log.d(TAG, "isAvailable: $available")
                result.success(available)
            }
            "dispose" -> {
                dispose()
                result.success(null)
            }
            "openLanguageSettings" -> openLanguageSettings(result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                val available = SpeechRecognizer.isRecognitionAvailable(context)
                Log.d(TAG, "SpeechRecognizer.isRecognitionAvailable: $available")

                if (!available) {
                    result.success(mapOf(
                        "success" to false,
                        "error" to "recognizer_not_available",
                        "message" to "SpeechRecognizer is not available on this device. Please install Google App."
                    ))
                    return@post
                }

                // Dispose existing recognizer if any
                speechRecognizer?.destroy()
                speechRecognizer = null

                // Create new recognizer
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)

                if (speechRecognizer == null) {
                    result.success(mapOf(
                        "success" to false,
                        "error" to "create_failed",
                        "message" to "Failed to create SpeechRecognizer instance."
                    ))
                    return@post
                }

                Log.d(TAG, "SpeechRecognizer created successfully")
                result.success(mapOf(
                    "success" to true,
                    "message" to "SpeechRecognizer initialized"
                ))

            } catch (e: Exception) {
                Log.e(TAG, "Initialize error: ${e.message}", e)
                result.success(mapOf(
                    "success" to false,
                    "error" to "exception",
                    "message" to (e.message ?: "Unknown error during initialization")
                ))
            }
        }
    }

    private fun startListening(localeId: String, result: MethodChannel.Result) {
        mainHandler.post {
            try {
                if (speechRecognizer == null) {
                    result.success(mapOf(
                        "success" to false,
                        "error" to "not_initialized",
                        "message" to "SpeechRecognizer not initialized"
                    ))
                    return@post
                }

                Log.d(TAG, "Starting recognition with locale: $localeId")

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeId)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
                }

                speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        Log.d(TAG, "onReadyForSpeech")
                        isListening = true
                        mainHandler.post {
                            Toast.makeText(context, "🟢 準備就緒，請說話", Toast.LENGTH_SHORT).show()
                        }
                        sendEvent(mapOf("type" to "status", "status" to "listening"))
                    }

                    override fun onBeginningOfSpeech() {
                        Log.d(TAG, "onBeginningOfSpeech")
                        mainHandler.post {
                            Toast.makeText(context, "🎤 偵測到語音", Toast.LENGTH_SHORT).show()
                        }
                        sendEvent(mapOf(
                            "type" to "status", 
                            "status" to "speechDetected",
                            "message" to "偵測到語音"
                        ))
                    }

                    override fun onRmsChanged(rmsdB: Float) {
                        // Don't log this — it fires very frequently
                    }

                    override fun onBufferReceived(buffer: ByteArray?) {
                        Log.d(TAG, "onBufferReceived")
                    }

                    override fun onEndOfSpeech() {
                        Log.d(TAG, "onEndOfSpeech")
                        isListening = false
                        mainHandler.post {
                            Toast.makeText(context, "🔴 語音結束", Toast.LENGTH_SHORT).show()
                        }
                        sendEvent(mapOf("type" to "status", "status" to "speechEnd"))
                    }

                    override fun onError(error: Int) {
                        val errorName = getErrorText(error)
                        Log.e(TAG, "onError: $error ($errorName)")
                        isListening = false
                        
                        mainHandler.post {
                            Toast.makeText(context, "❌ 錯誤: $errorName", Toast.LENGTH_LONG).show()
                        }
                        
                        sendEvent(mapOf(
                            "type" to "error",
                            "errorCode" to error,
                            "errorMessage" to errorName
                        ))
                    }

                    override fun onResults(results: Bundle?) {
                        Log.d(TAG, "onResults")
                        isListening = false
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = matches?.firstOrNull() ?: ""
                        Log.d(TAG, "Final result: $text")
                        
                        mainHandler.post {
                            Toast.makeText(context, "✅ $text", Toast.LENGTH_LONG).show()
                        }
                        
                        sendEvent(mapOf(
                            "type" to "result",
                            "text" to text,
                            "isFinal" to true
                        ))
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = matches?.firstOrNull() ?: ""
                        if (text.isNotEmpty()) {
                            Log.d(TAG, "Partial result: $text")
                            
                            mainHandler.post {
                                Toast.makeText(context, "✨ $text", Toast.LENGTH_SHORT).show()
                            }
                            
                            sendEvent(mapOf(
                                "type" to "result",
                                "text" to text,
                                "isFinal" to false
                            ))
                        }
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {
                        Log.d(TAG, "onEvent: $eventType")
                    }
                })

                speechRecognizer?.startListening(intent)
                Log.d(TAG, "startListening called")
                result.success(mapOf("success" to true))

            } catch (e: Exception) {
                Log.e(TAG, "startListening error: ${e.message}", e)
                result.success(mapOf(
                    "success" to false,
                    "error" to "start_failed",
                    "message" to (e.message ?: "Unknown error")
                ))
            }
        }
    }

    private fun stopListening(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                speechRecognizer?.stopListening()
                isListening = false
                result.success(mapOf("success" to true))
            } catch (e: Exception) {
                Log.e(TAG, "stopListening error: ${e.message}", e)
                result.success(mapOf("success" to false, "error" to e.message))
            }
        }
    }

    private fun cancelListening(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                speechRecognizer?.cancel()
                isListening = false
                result.success(mapOf("success" to true))
            } catch (e: Exception) {
                Log.e(TAG, "cancelListening error: ${e.message}", e)
                result.success(mapOf("success" to false, "error" to e.message))
            }
        }
    }

    private fun dispose() {
        mainHandler.post {
            try {
                speechRecognizer?.destroy()
                speechRecognizer = null
                isListening = false
                Log.d(TAG, "SpeechRecognizer disposed")
            } catch (e: Exception) {
                Log.e(TAG, "dispose error: ${e.message}", e)
            }
        }
    }

    private fun openLanguageSettings(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                Log.d(TAG, "openLanguageSettings called")

                // Try 1: Open Google App directly — most reliable on Samsung
                val googleApp = context.packageManager.getLaunchIntentForPackage("com.google.android.googlequicksearchbox")
                if (googleApp != null) {
                    googleApp.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(googleApp)
                    Toast.makeText(context, 
                        "在 Google App 中：\n點右上角頭像 → 設定 → 語音 → 離線語音辨識\n下載需要的語言", 
                        Toast.LENGTH_LONG).show()
                    Log.d(TAG, "Opened Google App")
                    result.success(mapOf("success" to true))
                    return@post
                }

                // Try 2: Open Google Speech Services (Google 語音辨識及合成) settings
                try {
                    val speechServices = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = android.net.Uri.parse("package:com.google.android.tts")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(speechServices)
                    Toast.makeText(context, "請檢查語言包是否已下載", Toast.LENGTH_LONG).show()
                    Log.d(TAG, "Opened Google TTS settings")
                    result.success(mapOf("success" to true))
                    return@post
                } catch (e: Exception) {
                    Log.d(TAG, "Google TTS settings not available: ${e.message}")
                }

                // Try 3: Open general settings
                val fallback = Intent(Settings.ACTION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(fallback)
                Toast.makeText(context, "請到：Google → 搜尋、助理與語音 → 語音 → 離線語音辨識", Toast.LENGTH_LONG).show()
                result.success(mapOf("success" to true))
            } catch (e: Exception) {
                Log.e(TAG, "openLanguageSettings error: ${e.message}", e)
                Toast.makeText(context, "開啟失敗: ${e.message}", Toast.LENGTH_LONG).show()
                result.success(mapOf("success" to false, "error" to e.message))
            }
        }
    }

    private fun sendEvent(data: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(data)
        }
    }

    private fun getErrorText(errorCode: Int): String {
        return when (errorCode) {
            SpeechRecognizer.ERROR_AUDIO -> "error_audio"
            SpeechRecognizer.ERROR_CLIENT -> "error_client"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "error_permission"
            SpeechRecognizer.ERROR_NETWORK -> "error_network"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "error_network_timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "error_no_match"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "error_busy"
            SpeechRecognizer.ERROR_SERVER -> "error_server"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "error_speech_timeout"
            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "error_language_not_supported"
            SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "error_language_unavailable"
            SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> "error_too_many_requests"
            else -> "error_unknown ($errorCode)"
        }
    }
}
