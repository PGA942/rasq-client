package com.example.rasq_client

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle

/**
 * 「この画面を読み取る(3 秒)」のボタンの受け口 (D-416)。**透明で、何も描かずにすぐ閉じる**。
 *
 * ボタンの PendingIntent をサービスに直接向けると、Android 12 からは通知のシェードが開いたまま残り(シェードを閉じる
 * `ACTION_CLOSE_SYSTEM_DIALOGS` はアプリから送れない)、読み取ったコマにシェードが写る。アクティビティを開く PendingIntent なら
 * システムがシェードを閉じるので、ここを挟む。RASQ のタスク(MainActivity)とは別のタスク(taskAffinity を分け、履歴にも出さない)
 * で開くので、RASQ は前に出ず、ブラウザがそのまま見えている。サービスへ渡したらすぐ閉じる。
 */
class ScreenGlimpseTriggerActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            startService(Intent(this, ScreenGlimpseService::class.java).setAction(ScreenGlimpseService.ACTION_CAPTURE))
        } catch (_: Exception) {
            // サービスへ渡せない(取り込みはもう止まっている)。何もしない。
        }
        finish()
        if (Build.VERSION.SDK_INT >= 34) {
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
        } else {
            @Suppress("DEPRECATION") overridePendingTransition(0, 0)
        }
    }
}
