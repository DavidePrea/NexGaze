package com.example.gps_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import android.view.KeyEvent

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.app/keyevents"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        val flutterEngine = getFlutterEngine()
        flutterEngine?.let {
            MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                result.notImplemented()
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val action = event.action
        val keyCode = event.keyCode
        val flutterEngine = getFlutterEngine()
        flutterEngine?.let {
            val channel = MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL)
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP, // 24
                KeyEvent.KEYCODE_VOLUME_DOWN, // 25
                KeyEvent.KEYCODE_ENTER -> { // 66
                    if (action == KeyEvent.ACTION_DOWN || action == KeyEvent.ACTION_UP) {
                        channel.invokeMethod(if (action == KeyEvent.ACTION_DOWN) "keyDown" else "keyUp", keyCode)
                        return true // Consuma l'evento per bloccare l'azione di sistema
                    }
                }
            }
        }
        return super.dispatchKeyEvent(event) // Propaga l'evento al sistema
    }
}