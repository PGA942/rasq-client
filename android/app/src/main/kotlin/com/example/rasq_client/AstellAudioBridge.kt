package com.example.rasq_client

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * AsTell の通話の端末側 (D-455)。チャンネル `rasq/astell_audio`:
 *
 * - `requestMic` → `{mic, bluetooth, bluetoothNewlyGranted}`: マイク(RECORD_AUDIO)の許可を、Android 12 からは
 *   Bluetooth のヘッドセット(BLUETOOTH_CONNECT)の許可も一緒に頼む。Bluetooth の許可が無いと、通話の音の出し先の
 *   切り替え(audioswitch)がヘッドセットを見つけられず、ヘッドセットのマイクを使えない。
 *   許可済みなら聞かずにそのまま返す。
 * - `startCall` / `stopCall`: ルームにいる間、裏に回っても / 画面を消してもマイクを止めない前面サービス
 *   [AstellCallService](種類 microphone)。マイクの許可があるときだけ始める(Android 14 から必須)。
 */
class AstellAudioBridge(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "AstellAudio"
        const val CHANNEL = "rasq/astell_audio"
        private const val RC_MIC = 45501
    }

    private var channel: MethodChannel? = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
    private var pending: MethodChannel.Result? = null
    private var bluetoothBefore = false

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        pending?.success(state())
        pending = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestMic" -> requestMic(result)
            "startCall" -> result.success(startCall())
            "stopCall" -> {
                try {
                    activity.stopService(Intent(activity, AstellCallService::class.java))
                } catch (e: Exception) {
                    Log.w(TAG, "stopService failed", e)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun granted(permission: String): Boolean {
        if (Build.VERSION.SDK_INT < 23) return true
        return activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    /** Bluetooth のヘッドセットを使えるか(Android 11 までは入れたときの許可で足りる)。 */
    private fun bluetoothGranted(): Boolean = Build.VERSION.SDK_INT < 31 || granted(Manifest.permission.BLUETOOTH_CONNECT)

    private fun state(): Map<String, Boolean> {
        val bluetooth = bluetoothGranted()
        return mapOf(
            "mic" to granted(Manifest.permission.RECORD_AUDIO),
            "bluetooth" to bluetooth,
            "bluetoothNewlyGranted" to (bluetooth && !bluetoothBefore),
        )
    }

    private fun requestMic(result: MethodChannel.Result) {
        if (pending != null) {
            // 聞いている最中(Dart 側は 1 本にまとめるので、ふつうは来ない)。いまの状態を返す。
            result.success(state())
            return
        }
        bluetoothBefore = bluetoothGranted()
        val want = mutableListOf<String>()
        if (!granted(Manifest.permission.RECORD_AUDIO)) want += Manifest.permission.RECORD_AUDIO
        if (!bluetoothBefore) want += Manifest.permission.BLUETOOTH_CONNECT
        if (want.isEmpty() || Build.VERSION.SDK_INT < 23) {
            result.success(state())
            return
        }
        pending = result
        if (Build.VERSION.SDK_INT >= 23) activity.requestPermissions(want.toTypedArray(), RC_MIC)
    }

    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != RC_MIC) return false
        val r = pending
        pending = null
        r?.success(state())
        return true
    }

    private fun startCall(): Boolean {
        if (!granted(Manifest.permission.RECORD_AUDIO)) return false
        return try {
            val intent = Intent(activity, AstellCallService::class.java)
            if (Build.VERSION.SDK_INT >= 26) activity.startForegroundService(intent) else activity.startService(intent)
            true
        } catch (e: Exception) {
            // 裏から始めようとした(Android 12 から不可)など。通話は続ける。
            Log.w(TAG, "startForegroundService failed", e)
            false
        }
    }
}
