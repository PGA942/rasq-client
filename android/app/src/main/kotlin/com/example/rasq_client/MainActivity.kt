package com.example.rasq_client

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var glimpse: ScreenGlimpseBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        glimpse = ScreenGlimpseBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        glimpse?.detach()
        glimpse = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 「読み取りました」の通知から起動した (D-416)。作り直し(回転など)のときは同じ intent が来るので見ない。
        if (savedInstanceState == null) ScreenGlimpseBridge.takeOpenIntent(intent, deliver = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        ScreenGlimpseBridge.takeOpenIntent(intent, deliver = true)
    }

    // 画面の読み取りの同意 (D-416) はここで受ける。ほかはこれまでどおりプラグインへ。
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (glimpse?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (glimpse?.onRequestPermissionsResult(requestCode, grantResults) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
