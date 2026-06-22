package com.elizerpist.djinn

import com.elizerpist.djinn.voice.NativeSpeechBridge
import com.elizerpist.djinn.voice.VoiceChannels
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = NativeSpeechBridge(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VoiceChannels.METHOD)
            .setMethodCallHandler(bridge)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VoiceChannels.EVENTS)
            .setStreamHandler(bridge)
    }
}
