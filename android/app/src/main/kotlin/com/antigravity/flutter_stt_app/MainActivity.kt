package com.antigravity.flutter_stt_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var speechHandler: SpeechRecognizerHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        speechHandler = SpeechRecognizerHandler(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SpeechRecognizerHandler.METHOD_CHANNEL
        ).setMethodCallHandler(speechHandler)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SpeechRecognizerHandler.EVENT_CHANNEL
        ).setStreamHandler(speechHandler.streamHandler)
    }
}
