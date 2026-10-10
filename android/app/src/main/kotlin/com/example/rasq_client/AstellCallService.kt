package com.example.rasq_client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * AsTell のルームにいる間の前面サービス (D-455、種類 microphone)。
 *
 * Android 11 からは、前面サービスの無いアプリが裏に回る / 画面が消えると、マイクの音が無音になる(通話の相手にこちらの声が
 * 届かなくなる)。マイクを開いたら [AstellAudioBridge] が始め、ルームを出たら止める。通知をタップすると RASQ に戻る。
 * 何もしない(マイクも音も WebRTC が持つ)。アプリをタスクから消したら止める。
 */
class AstellCallService : Service() {
    companion object {
        private const val TAG = "AstellCall"
        const val NOTIFICATION_ID = 455001
        private const val CHANNEL_ID = "rasq.astell.call"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            val n = notification()
            if (Build.VERSION.SDK_INT >= 30) {
                startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(NOTIFICATION_ID, n)
            }
        } catch (e: Exception) {
            // マイクの許可が無い / 裏から始めた など。サービスは要らないので止める(通話は続く)。
            Log.w(TAG, "startForeground failed", e)
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    private fun notification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(CHANNEL_ID, "ASTell の通話", NotificationManager.IMPORTANCE_LOW).apply {
                description = "ASTell のルームにいる間、マイクを使っていることを知らせます"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }
        val immutable = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0
        val launch = packageManager.getLaunchIntentForPackage(packageName)?.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val open = launch?.let { PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or immutable) }
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL_ID) else @Suppress("DEPRECATION") Notification.Builder(this)
        return b.setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("ASTell")
            .setContentText("ルームに参加しています(マイクを使用中)")
            .setOngoing(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_CALL)
            .apply { if (open != null) setContentIntent(open) }
            .build()
    }
}
