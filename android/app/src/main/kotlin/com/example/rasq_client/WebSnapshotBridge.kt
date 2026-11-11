package com.example.rasq_client

import android.graphics.Bitmap
import android.graphics.Canvas
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi
import java.io.ByteArrayOutputStream

/**
 * アプリの中のブラウザの「この画面を探す」(D-552): WebView の**いま見えている範囲**を JPEG で返す。
 * ページ全体の写しは、Dart がスクロールしながらこれを何度か呼んでつなぐ(`web_snapshot.dart`)。
 * 撮った画像はどこにも保存しない(Dart に返すだけ)。
 */
class WebSnapshotBridge(private val engine: FlutterEngine) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "rasq/web_snapshot")

    init {
        channel.setMethodCallHandler(this)
    }

    fun detach() = channel.setMethodCallHandler(null)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "captureVisible") {
            result.notImplemented()
            return
        }
        val id = (call.argument<Number>("id"))?.toLong()
        val web = if (id == null) null else WebViewFlutterAndroidExternalApi.getWebView(engine, id)
        if (web == null || web.width <= 0 || web.height <= 0) {
            result.success(null)
            return
        }
        try {
            // 幅を最大 [maxWidth] に縮めて描く(長いページを何枚もつなぐので、メモリを抑える)。
            val maxWidth = (call.argument<Number>("maxWidth"))?.toInt() ?: 720
            val scale = if (web.width > maxWidth) maxWidth.toFloat() / web.width else 1f
            val w = (web.width * scale).toInt().coerceAtLeast(1)
            val h = (web.height * scale).toInt().coerceAtLeast(1)
            val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            canvas.scale(scale, scale)
            // View.draw は中身をスクロール位置の座標で描くので、見えている範囲が左上に来るように戻す。
            canvas.translate(-web.scrollX.toFloat(), -web.scrollY.toFloat())
            web.draw(canvas)
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 88, out)
            bitmap.recycle()
            result.success(out.toByteArray())
        } catch (e: Throwable) {
            result.error("capture_failed", e.message, null)
        }
    }
}
