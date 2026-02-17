package com.antigravity.flutter_stt_app

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.RecognizerIntent
import android.util.Log
import android.widget.Toast
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SpeechRecognizerHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "SpeechRecognizerHandler"
        const val METHOD_CHANNEL = "com.antigravity.stt/speech"
        const val EVENT_CHANNEL = "com.antigravity.stt/speech_events"
    }

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isListening = false
    private var methodChannel: MethodChannel? = null

    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
        Log.d(TAG, "MethodChannel reference set")
    }

    val streamHandler =
            object : EventChannel.StreamHandler {
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
            "initialize" -> {
                Log.d(TAG, "initialize called — using Activity-based recognition")
                result.success(mapOf("success" to true, "message" to "Ready (Activity mode)"))
            }
            "startListening" -> {
                val localeId = call.argument<String>("localeId") ?: "en-US"
                startListeningViaActivity(localeId, result)
            }
            "stopListening" -> {
                isListening = false
                result.success(mapOf("success" to true))
            }
            "cancelListening" -> {
                isListening = false
                result.success(mapOf("success" to true))
            }
            "isAvailable" -> {
                result.success(true)
            }
            "dispose" -> {
                isListening = false
                result.success(null)
            }
            "openLanguageSettings" -> openLanguageSettings(result)
            else -> result.notImplemented()
        }
    }

    private fun startListeningViaActivity(localeId: String, result: MethodChannel.Result) {
        try {
            Log.d(TAG, "startListeningViaActivity: locale=$localeId")

            val intent =
                    Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(
                                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                        )
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeId)
                        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                        putExtra(RecognizerIntent.EXTRA_PROMPT, "請說話...")
                    }

            isListening = true
            sendEvent(mapOf("type" to "status", "status" to "listening"))

            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, MainActivity.SPEECH_REQUEST_CODE)
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            Log.e(TAG, "Activity recognition failed: ${e.message}", e)
            mainHandler.post {
                Toast.makeText(activity, "❌ 無法啟動語音辨識: ${e.message}", Toast.LENGTH_LONG).show()
            }
            sendEvent(
                    mapOf(
                            "type" to "error",
                            "errorCode" to -1,
                            "errorMessage" to "activity_launch_failed: ${e.message}"
                    )
            )
            result.success(
                    mapOf(
                            "success" to false,
                            "error" to "activity_failed",
                            "message" to (e.message ?: "Unknown error")
                    )
            )
        }
    }

    /**
     * Called from MainActivity.onActivityResult when Google speech recognition Activity finishes.
     */
    fun handleActivityResult(resultCode: Int, data: Intent?) {
        isListening = false
        Log.d(TAG, "handleActivityResult: resultCode=$resultCode, data=$data")

        if (resultCode == Activity.RESULT_OK && data != null) {
            val results = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
            Log.d(TAG, "Activity results: $results")
            val text = results?.firstOrNull() ?: ""

            if (text.isNotEmpty()) {
                Log.d(TAG, "Activity recognized: $text")

                // Delay to ensure Flutter has fully resumed from background
                mainHandler.postDelayed(
                        {
                            mainHandler.post {
                                Toast.makeText(activity, "✅ $text", Toast.LENGTH_SHORT).show()
                            }
                            // Primary: use MethodChannel (more reliable after Activity transitions)
                            sendResultViaMethodChannel(
                                    "speechResult",
                                    mapOf("text" to text, "isFinal" to true)
                            )
                            // Fallback: also try EventChannel
                            sendEvent(mapOf("type" to "result", "text" to text, "isFinal" to true))
                            Log.d(TAG, "Result sent to Flutter via MethodChannel + EventChannel")
                        },
                        800
                )
            } else {
                Log.d(TAG, "Activity returned empty text")
                mainHandler.postDelayed(
                        {
                            sendResultViaMethodChannel(
                                    "speechError",
                                    mapOf("errorCode" to 7, "errorMessage" to "error_no_match")
                            )
                            sendEvent(
                                    mapOf(
                                            "type" to "error",
                                            "errorCode" to 7,
                                            "errorMessage" to "error_no_match"
                                    )
                            )
                        },
                        800
                )
            }
        } else {
            Log.d(TAG, "Activity cancelled or failed")
            mainHandler.postDelayed(
                    {
                        sendResultViaMethodChannel(
                                "speechCancelled",
                                mapOf("status" to "speechEnd")
                        )
                        sendEvent(mapOf("type" to "status", "status" to "speechEnd"))
                    },
                    800
            )
        }
    }

    private fun openLanguageSettings(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                val googleApp =
                        activity.packageManager.getLaunchIntentForPackage(
                                "com.google.android.googlequicksearchbox"
                        )
                if (googleApp != null) {
                    googleApp.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(googleApp)
                    Toast.makeText(
                                    activity,
                                    "在 Google App 中：\n點右上角頭像 → 設定 → 語音 → 離線語音辨識\n下載需要的語言",
                                    Toast.LENGTH_LONG
                            )
                            .show()
                    result.success(mapOf("success" to true))
                    return@post
                }

                val fallback =
                        Intent(Settings.ACTION_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                activity.startActivity(fallback)
                result.success(mapOf("success" to true))
            } catch (e: Exception) {
                Log.e(TAG, "openLanguageSettings error: ${e.message}", e)
                result.success(mapOf("success" to false, "error" to e.message))
            }
        }
    }

    private fun sendResultViaMethodChannel(method: String, data: Map<String, Any?>) {
        mainHandler.post {
            try {
                val channel = methodChannel
                if (channel != null) {
                    channel.invokeMethod(method, data)
                    Log.d(TAG, "sendResultViaMethodChannel: $method -> $data")
                } else {
                    Log.e(TAG, "sendResultViaMethodChannel: methodChannel is null!")
                }
            } catch (e: Exception) {
                Log.e(TAG, "sendResultViaMethodChannel error: ${e.message}")
            }
        }
    }

    private fun sendEvent(data: Map<String, Any?>) {
        mainHandler.post {
            try {
                if (eventSink != null) {
                    eventSink?.success(data)
                    Log.d(TAG, "sendEvent OK: $data")
                } else {
                    Log.w(TAG, "sendEvent SKIPPED (eventSink is null): $data")
                }
            } catch (e: Exception) {
                Log.e(TAG, "sendEvent error: ${e.message}")
            }
        }
    }
}
