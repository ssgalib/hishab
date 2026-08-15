package com.expense.tracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SpeechChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        OnnxChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
