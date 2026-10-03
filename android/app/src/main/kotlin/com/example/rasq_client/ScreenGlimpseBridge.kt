package com.example.rasq_client

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Flutter との口 `rasq/screen_glimpse` (D-416)。
 *
 * Dart → ネイティブ:
 * - `start` → `{status: started | denied | notifications_denied | busy | unavailable}`
 *   (通知の権限 → MediaProjection の同意 → 前面サービス [ScreenGlimpseService] を始める。ブラウザは Dart が開く)
 * - `cancel` / `state`(idle | armed | capturing)/ `dir`(読み取ったコマを置くフォルダー)/ `takeLaunchOpen`(通知から起動したときの id)
 * - `dismissDone`(「読み取りました」の通知を消す)
 *
 * ネイティブ → Dart: `event` `{type: armed | capturing | done | stopped | open, id?, reason?}`。
 */
class ScreenGlimpseBridge(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "rasq/screen_glimpse"
        const val EXTRA_OPEN_ID = "com.example.rasq_client.glimpse.OPEN_ID"
        private const val RC_CONSENT = 41601
        private const val RC_NOTIFICATIONS = 41602

        private val main = Handler(Looper.getMainLooper())

        @Volatile private var current: ScreenGlimpseBridge? = null

        /** 通知から起動して、まだ Dart が受け取っていない読み取りの id。 */
        @Volatile private var pendingOpen: String? = null

        /** 読み取ったコマを置くフォルダー(アプリのキャッシュの中)。 */
        fun rootDir(context: Context): File = File(context.cacheDir, "screen_glimpse")

        /** サービスからの知らせを Dart へ(エンジンが無ければ捨てる。Dart は起動時に `state` / `takeLaunchOpen` で追いつく)。 */
        fun emit(event: Map<String, Any?>) {
            main.post { current?.channel?.invokeMethod("event", event) }
        }

        /** 「読み取りました」の通知のタップで開いた intent から id を取り出す。 */
        fun takeOpenIntent(intent: Intent?, deliver: Boolean) {
            val id = intent?.getStringExtra(EXTRA_OPEN_ID) ?: return
            intent.removeExtra(EXTRA_OPEN_ID)
            if (!GlimpseFrameMath.isValidId(id)) return
            val bridge = current
            if (deliver && bridge != null) {
                emit(mapOf("type" to "open", "id" to id))
            } else {
                pendingOpen = id
            }
        }
    }

    private var channel: MethodChannel? = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
    private var pendingStart: MethodChannel.Result? = null

    init {
        current = this
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        if (current === this) current = null
        pendingStart?.success(mapOf("status" to "unavailable"))
        pendingStart = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(result)
            "cancel" -> {
                if (ScreenGlimpseService.state != ScreenGlimpseService.STATE_IDLE) {
                    activity.startService(Intent(activity, ScreenGlimpseService::class.java).setAction(ScreenGlimpseService.ACTION_CANCEL))
                }
                result.success(null)
            }
            "state" -> result.success(ScreenGlimpseService.state)
            "dir" -> result.success(rootDir(activity).absolutePath)
            "takeLaunchOpen" -> {
                val id = pendingOpen
                pendingOpen = null
                result.success(id)
            }
            "dismissDone" -> {
                (activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(ScreenGlimpseService.DONE_NOTIFICATION_ID)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun start(result: MethodChannel.Result) {
        if (pendingStart != null || ScreenGlimpseService.state != ScreenGlimpseService.STATE_IDLE) {
            result.success(mapOf("status" to "busy"))
            return
        }
        pendingStart = result
        // 通知(読み取りのボタン)が出せないと先へ進めないので、Android 13 からは先に通知の権限を頼む。
        if (Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), RC_NOTIFICATIONS)
            return
        }
        requestConsent()
    }

    private fun requestConsent() {
        val mpm = activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager?
        if (mpm == null) {
            finishStart("unavailable")
            return
        }
        try {
            // Android 14 から同意は 1 回の取り込みごと(結果の intent は 1 度しか使えない)。毎回ここで聞く。
            @Suppress("DEPRECATION")
            activity.startActivityForResult(mpm.createScreenCaptureIntent(), RC_CONSENT)
        } catch (e: Exception) {
            finishStart("unavailable")
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != RC_NOTIFICATIONS) return false
        if (pendingStart == null) return true
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            requestConsent()
        } else {
            finishStart("notifications_denied")
        }
        return true
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != RC_CONSENT) return false
        if (pendingStart == null) return true
        if (resultCode != Activity.RESULT_OK || data == null) {
            finishStart("denied")
            return true
        }
        // 同意を得てから、前面サービス(種類 mediaProjection)を始める。サービスは startForeground のあとで getMediaProjection する。
        val intent = Intent(activity, ScreenGlimpseService::class.java)
            .setAction(ScreenGlimpseService.ACTION_START)
            .putExtra(ScreenGlimpseService.EXTRA_RESULT_CODE, resultCode)
            .putExtra(ScreenGlimpseService.EXTRA_RESULT_DATA, data)
        try {
            if (Build.VERSION.SDK_INT >= 26) activity.startForegroundService(intent) else activity.startService(intent)
            ScreenGlimpseService.state = ScreenGlimpseService.STATE_ARMED
            finishStart("started")
        } catch (e: Exception) {
            finishStart("unavailable")
        }
        return true
    }

    private fun finishStart(status: String) {
        val r = pendingStart ?: return
        pendingStart = null
        r.success(mapOf("status" to status))
    }
}
