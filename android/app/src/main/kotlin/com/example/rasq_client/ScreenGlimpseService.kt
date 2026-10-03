package com.example.rasq_client

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.view.Display
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.security.SecureRandom

/**
 * いつものブラウザで見ている画面を 3 秒だけ読み取る前面サービス (D-416、D-415 のダミーの置き換え)。
 *
 * 1. [ScreenGlimpseBridge] が同意を得て [ACTION_START] で始める → すぐ `startForeground`(種類 mediaProjection、Android 14 から
 *    getMediaProjection より前に要る)→ MediaProjection を受け、コールバックを登録してから VirtualDisplay を **1 回だけ** 作る
 *    (ImageReader、長辺 [LONG_EDGE]、RGBA_8888)。待っている間は最新の 1 コマを持つだけ(書き出さない、送らない)。
 * 2. 通知のボタン「この画面を読み取る(3 秒)」→ [ScreenGlimpseTriggerActivity](透明で、すぐ閉じる。通知のシェードを閉じる
 *    ためだけ。RASQ は前に出ない)→ [ACTION_CAPTURE]。シェードが閉じるのを [SETTLE_MS] 待ってから [CAPTURE_MS] の間、
 *    1 秒ごとにコマを取り(同じコマは飛ばす)、JPEG(品質 [JPEG_QUALITY])でキャッシュに書く。
 * 3. 読み終えたら **すぐに取り込みとサービスを止め**、「読み取りました — タップで結果を見る」の通知を出す(タップで RASQ が開き、
 *    Dart が `/sns-discover/content?glimpse=done&id=…` へ)。
 * 待っている間に [ARMED_TIMEOUT_MS] たったら / 「やめる」/ 端末が取り込みを止めた(onStop)/ サービスが壊された ときも片付けて Dart に知らせる。
 */
class ScreenGlimpseService : Service() {
    companion object {
        private const val TAG = "ScreenGlimpse"
        const val ACTION_START = "com.example.rasq_client.glimpse.START"
        const val ACTION_CAPTURE = "com.example.rasq_client.glimpse.CAPTURE"
        const val ACTION_CANCEL = "com.example.rasq_client.glimpse.CANCEL"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_RESULT_DATA = "resultData"

        const val STATE_IDLE = "idle"
        const val STATE_ARMED = "armed"
        const val STATE_CAPTURING = "capturing"

        const val ONGOING_NOTIFICATION_ID = 416001
        const val DONE_NOTIFICATION_ID = 416002
        private const val CHANNEL_ARMED = "rasq.discover.glimpse.armed"
        private const val CHANNEL_DONE = "rasq.discover.glimpse.done"

        const val LONG_EDGE = 1080
        const val JPEG_QUALITY = 80
        const val CAPTURE_MS = 3000L
        const val FRAME_INTERVAL_MS = 1000L
        const val SETTLE_MS = 400L
        const val ARMED_TIMEOUT_MS = 10 * 60 * 1000L

        @Volatile var state: String = STATE_IDLE
    }

    private val main = Handler(Looper.getMainLooper())
    private lateinit var worker: HandlerThread
    private lateinit var handler: Handler

    // ここから下は worker のスレッドだけで触る。
    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var reader: ImageReader? = null
    private var latest: Image? = null
    private var width = 0
    private var height = 0
    private var densityDpi = DisplayMetrics.DENSITY_DEFAULT
    private var captureId: String? = null
    private var captureDir: File? = null
    private var capturedAt = 0L
    private val files = mutableListOf<String>()
    private var lastFingerprint: IntArray? = null
    private var lastTimestamp = Long.MIN_VALUE

    @Volatile private var finished = false

    private val callback = object : MediaProjection.Callback() {
        override fun onStop() {
            // 端末が止めた(ステータスバーの「共有を停止」、画面のロックなど)。
            handler.post { finish(reason = "system") }
        }

        override fun onCapturedContentResize(width: Int, height: Int) {
            // Android 14 から: 1 つのアプリだけを共有している / 回転したとき。VirtualDisplay は作り直さず、大きさと受け口だけ替える。
            handler.post { resize(width, height) }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        worker = HandlerThread("rasq-screen-glimpse").also { it.start() }
        handler = Handler(worker.looper)
        createChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> begin(intent)
            ACTION_CAPTURE -> handler.post { capture() }
            ACTION_CANCEL -> handler.post { finish(reason = "cancel") }
            else -> if (projection == null && state == STATE_IDLE) stopSelf(startId)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        // 壊された(メモリ不足など)。持っているものを放して Dart に知らせる。
        if (!finished) {
            handler.post { finish(reason = "killed", stopService = false) }
        }
        worker.quitSafely()
        super.onDestroy()
    }

    // ---------------------------------------------------------------------------------------------
    // 始める

    private fun begin(intent: Intent) {
        // Android 14 から: getMediaProjection より前に、種類 mediaProjection で前面に出ていないといけない。
        try {
            val n = armedNotification()
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(ONGOING_NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            } else {
                startForeground(ONGOING_NOTIFICATION_ID, n)
            }
        } catch (e: Exception) {
            Log.w(TAG, "startForeground failed", e)
            handler.post { finish(reason = "error") }
            return
        }
        val code = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
        val data: Intent? = if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
        } else {
            @Suppress("DEPRECATION") intent.getParcelableExtra(EXTRA_RESULT_DATA)
        }
        handler.post { open(code, data) }
    }

    private fun open(code: Int, data: Intent?) {
        if (finished) return
        if (projection != null) return // 2 度目の START(同意は 1 回の取り込みごと。今のものを使い続ける)
        val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val p = try {
            if (data == null) null else mpm.getMediaProjection(code, data)
        } catch (e: Exception) {
            Log.w(TAG, "getMediaProjection failed", e)
            null
        }
        if (p == null) {
            finish(reason = "error")
            return
        }
        projection = p
        // Android 14 から: コールバックは createVirtualDisplay より前に登録する。
        p.registerCallback(callback, handler)
        val (w, h, dpi) = screenSize()
        val (sw, sh) = GlimpseFrameMath.scaledSize(w, h, LONG_EDGE)
        width = sw
        height = sh
        densityDpi = dpi
        val r = newReader(sw, sh)
        reader = r
        display = try {
            // 1 つの MediaProjection につき 1 回だけ(Android 14 から 2 回目は例外)。
            p.createVirtualDisplay("rasq-screen-glimpse", sw, sh, dpi, DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, r.surface, null, handler)
        } catch (e: Exception) {
            Log.w(TAG, "createVirtualDisplay failed", e)
            null
        }
        if (display == null) {
            finish(reason = "error")
            return
        }
        state = STATE_ARMED
        ScreenGlimpseBridge.emit(mapOf("type" to "armed"))
        handler.postDelayed({ if (state == STATE_ARMED) finish(reason = "timeout") }, ARMED_TIMEOUT_MS)
    }

    private fun newReader(w: Int, h: Int): ImageReader {
        val r = ImageReader.newInstance(w, h, PixelFormat.RGBA_8888, 3)
        r.setOnImageAvailableListener({ ir ->
            // 最新の 1 コマだけを持つ(書き出さない)。静止した画面では新しいコマが来ないので、押したときにこれを使う。
            val img = try { ir.acquireLatestImage() } catch (e: Exception) { null } ?: return@setOnImageAvailableListener
            if (ir !== reader) {
                img.close()
                return@setOnImageAvailableListener
            }
            latest?.close()
            latest = img
        }, handler)
        return r
    }

    private fun resize(w: Int, h: Int) {
        val d = display ?: return
        if (w <= 0 || h <= 0 || finished) return
        val (sw, sh) = GlimpseFrameMath.scaledSize(w, h, LONG_EDGE)
        if (sw == width && sh == height) return
        val old = reader
        latest?.close()
        latest = null
        val r = newReader(sw, sh)
        reader = r
        width = sw
        height = sh
        d.resize(sw, sh, densityDpi)
        d.surface = r.surface
        old?.close()
    }

    private fun screenSize(): Triple<Int, Int, Int> {
        val dm = DisplayMetrics()
        val disp = (getSystemService(Context.DISPLAY_SERVICE) as DisplayManager).getDisplay(Display.DEFAULT_DISPLAY)
        @Suppress("DEPRECATION")
        disp?.getRealMetrics(dm)
        if (dm.widthPixels <= 0 || dm.heightPixels <= 0) {
            val r = resources.displayMetrics
            return Triple(maxOf(r.widthPixels, 2), maxOf(r.heightPixels, 2), r.densityDpi)
        }
        return Triple(dm.widthPixels, dm.heightPixels, dm.densityDpi)
    }

    // ---------------------------------------------------------------------------------------------
    // 読み取る

    private fun capture() {
        if (finished) return
        if (projection == null) {
            // 取り込みが無い(古い通知のボタンなど)。何も読まずに閉じる。
            finish(reason = "error")
            return
        }
        if (state != STATE_ARMED) return // 読み取り中の 2 度押し
        state = STATE_CAPTURING
        val id = newId()
        val dir = File(ScreenGlimpseBridge.rootDir(this), id)
        if (!dir.mkdirs() && !dir.isDirectory) {
            finish(reason = "error")
            return
        }
        captureId = id
        captureDir = dir
        files.clear()
        lastFingerprint = null
        lastTimestamp = Long.MIN_VALUE
        notify(ONGOING_NOTIFICATION_ID, capturingNotification())
        ScreenGlimpseBridge.emit(mapOf("type" to "capturing", "id" to id))
        // シェードが閉じるのを待ってから 0, 1, 2, 3 秒の 4 コマ(同じコマは飛ばす)。
        val start = SETTLE_MS
        capturedAt = System.currentTimeMillis() + SETTLE_MS
        var t = 0L
        while (t <= CAPTURE_MS) {
            val last = t == CAPTURE_MS
            handler.postDelayed({
                grab()
                if (last) complete()
            }, start + t)
            t += FRAME_INTERVAL_MS
        }
    }

    private fun grab() {
        if (finished || state != STATE_CAPTURING) return
        val img = latest ?: return
        if (img.timestamp == lastTimestamp) return // 前のコマから画面が変わっていない
        val bmp = try { toBitmap(img) } catch (e: Exception) {
            Log.w(TAG, "frame copy failed", e)
            return
        }
        try {
            val fp = GlimpseFrameMath.fingerprint(bmp.width, bmp.height) { x, y -> bmp.getPixel(x, y) }
            lastTimestamp = img.timestamp
            if (GlimpseFrameMath.sameFrame(lastFingerprint, fp)) return
            lastFingerprint = fp
            val name = "frame_${files.size}.jpg"
            val f = File(captureDir ?: return, name)
            FileOutputStream(f).use { out -> bmp.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out) }
            files.add(name)
        } catch (e: Exception) {
            Log.w(TAG, "frame write failed", e)
        } finally {
            bmp.recycle()
        }
    }

    /** RGBA_8888 の Image を Bitmap に(行の詰め物を外して写す)。 */
    private fun toBitmap(img: Image): Bitmap {
        val plane = img.planes[0]
        val src = plane.buffer
        val w = img.width
        val h = img.height
        val rowBytes = w * 4
        val packed = ByteBuffer.allocateDirect(rowBytes * h)
        val rowStride = plane.rowStride
        for (y in 0 until h) {
            val from = y * rowStride
            val dup = src.duplicate()
            dup.position(from)
            dup.limit(from + rowBytes)
            packed.put(dup)
        }
        packed.rewind()
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        bmp.copyPixelsFromBuffer(packed)
        return bmp
    }

    private fun complete() {
        if (finished) return
        val id = captureId
        val dir = captureDir
        if (id == null || dir == null || files.isEmpty()) {
            dir?.deleteRecursively()
            finish(reason = "empty")
            return
        }
        try {
            val tmp = File(dir, "meta.json.tmp")
            tmp.writeText(GlimpseFrameMath.metaJson(id, capturedAt, width, height, files))
            if (!tmp.renameTo(File(dir, "meta.json"))) throw IllegalStateException("rename failed")
        } catch (e: Exception) {
            Log.w(TAG, "meta write failed", e)
            dir.deleteRecursively()
            finish(reason = "error")
            return
        }
        // 先に取り込みを止める(読み取りの窓の外は 1 コマも取らない)。
        finish(reason = null, doneId = id)
    }

    // ---------------------------------------------------------------------------------------------
    // 片付け

    /** 取り込みを止め、前面サービスを終える。[doneId] があれば「読み取りました」の通知を出し、Dart に done を、無ければ stopped を知らせる。 */
    private fun finish(reason: String?, doneId: String? = null, stopService: Boolean = true) {
        if (finished) return
        finished = true
        handler.removeCallbacksAndMessages(null)
        val wasCapturing = state == STATE_CAPTURING
        state = STATE_IDLE
        try { latest?.close() } catch (_: Exception) {}
        latest = null
        try { display?.release() } catch (_: Exception) {}
        display = null
        try { reader?.close() } catch (_: Exception) {}
        reader = null
        projection?.let {
            try { it.unregisterCallback(callback) } catch (_: Exception) {}
            try { it.stop() } catch (_: Exception) {}
        }
        projection = null
        if (doneId == null && wasCapturing) captureDir?.deleteRecursively()
        if (doneId != null) notify(DONE_NOTIFICATION_ID, doneNotification(doneId))
        ScreenGlimpseBridge.emit(
            if (doneId != null) mapOf("type" to "done", "id" to doneId, "frames" to files.size)
            else mapOf("type" to "stopped", "reason" to (reason ?: "error"))
        )
        if (stopService) {
            main.post {
                if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
                stopSelf()
            }
        }
    }

    private fun newId(): String {
        val bytes = ByteArray(6)
        SecureRandom().nextBytes(bytes)
        val hex = bytes.joinToString("") { "%02x".format(it.toInt() and 0xff) }
        return "g${System.currentTimeMillis()}-$hex"
    }

    // ---------------------------------------------------------------------------------------------
    // 通知

    private fun manager() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun notify(id: Int, n: Notification) {
        try { manager().notify(id, n) } catch (e: Exception) { Log.w(TAG, "notify failed", e) }
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < 26) return
        // 待っている間の通知は、ブラウザの上にボタンが見えるよう重要度を高く(音は鳴らさない)。
        val armed = NotificationChannel(CHANNEL_ARMED, "画面の読み取り(待機中)", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "いつものブラウザで見ている画面を、ボタンを押したときだけ 3 秒読み取ります"
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        val done = NotificationChannel(CHANNEL_DONE, "画面の読み取り(結果)", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "読み取りが終わったことを知らせます"
            setSound(null, null)
            enableVibration(false)
        }
        manager().createNotificationChannels(listOf(armed, done))
    }

    private fun builder(channel: String): Notification.Builder {
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel) else @Suppress("DEPRECATION") Notification.Builder(this)
        return b.setSmallIcon(R.mipmap.ic_launcher).setShowWhen(false)
    }

    private val immutable = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0

    private fun armedNotification(): Notification {
        val read = PendingIntent.getActivity(
            this, 1,
            Intent(this, ScreenGlimpseTriggerActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION),
            PendingIntent.FLAG_UPDATE_CURRENT or immutable,
        )
        val cancel = PendingIntent.getService(this, 2, Intent(this, ScreenGlimpseService::class.java).setAction(ACTION_CANCEL), PendingIntent.FLAG_UPDATE_CURRENT or immutable)
        val b = builder(CHANNEL_ARMED)
            .setContentTitle("RASQ で探す")
            .setContentText("見たい画面を開いたら「この画面を読み取る」を押してください")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setContentIntent(read)
            .addAction(Notification.Action.Builder(null, "この画面を読み取る(3 秒)", read).build())
            .addAction(Notification.Action.Builder(null, "やめる", cancel).build())
        if (Build.VERSION.SDK_INT < 26) @Suppress("DEPRECATION") b.setPriority(Notification.PRIORITY_HIGH)
        if (Build.VERSION.SDK_INT >= 31) b.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        return b.build()
    }

    private fun capturingNotification(): Notification =
        builder(CHANNEL_ARMED)
            .setContentTitle("RASQ で探す")
            .setContentText("画面を読み取っています(3 秒)")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(0, 0, true)
            .build()

    private fun doneNotification(id: String): Notification {
        val open = PendingIntent.getActivity(
            this, 3,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra(ScreenGlimpseBridge.EXTRA_OPEN_ID, id),
            PendingIntent.FLAG_UPDATE_CURRENT or immutable,
        )
        val b = builder(CHANNEL_DONE)
            .setContentTitle("読み取りました")
            .setContentText("タップで結果を見る")
            .setAutoCancel(true)
            .setContentIntent(open)
        if (Build.VERSION.SDK_INT < 26) @Suppress("DEPRECATION") b.setPriority(Notification.PRIORITY_HIGH)
        return b.build()
    }
}
