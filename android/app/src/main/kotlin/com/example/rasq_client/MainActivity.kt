package com.example.rasq_client

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var glimpse: ScreenGlimpseBridge? = null
    private var astellAudio: AstellAudioBridge? = null
    private var webSnapshot: WebSnapshotBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        glimpse = ScreenGlimpseBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        // AsTell の通話 (D-455): マイク / Bluetooth の許可と、ルームにいる間の前面サービス。
        astellAudio = AstellAudioBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        // アプリの中のブラウザの「この画面を探す」(D-552): 見えている範囲の写し。
        webSnapshot = WebSnapshotBridge(flutterEngine)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        glimpse?.detach()
        glimpse = null
        astellAudio?.detach()
        astellAudio = null
        webSnapshot?.detach()
        webSnapshot = null
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
        if (astellAudio?.onRequestPermissionsResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
