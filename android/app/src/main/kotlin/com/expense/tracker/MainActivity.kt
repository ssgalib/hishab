package com.expense.tracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Speech recognition moved to Dart (sherpa_onnx plugin + bundled
        // streaming Zipformer). Only the Gemma ONNX channel stays native.
        OnnxChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
