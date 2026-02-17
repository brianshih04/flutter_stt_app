package com.antigravity.flutter_stt_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var speechHandler: SpeechRecognizerHandler

    companion object {
        const val SPEECH_REQUEST_CODE = 1001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        speechHandler = SpeechRecognizerHandler(this)

        val methodChannel =
                MethodChannel(
                        flutterEngine.dartExecutor.binaryMessenger,
                        SpeechRecognizerHandler.METHOD_CHANNEL
                )
        methodChannel.setMethodCallHandler(speechHandler)
        speechHandler.setMethodChannel(methodChannel)

        EventChannel(
                        flutterEngine.dartExecutor.binaryMessenger,
                        SpeechRecognizerHandler.EVENT_CHANNEL
                )
                .setStreamHandler(speechHandler.streamHandler)
    }

    @Deprecated("Use Activity Result API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SPEECH_REQUEST_CODE) {
            speechHandler.handleActivityResult(resultCode, data)
        }
    }
}
