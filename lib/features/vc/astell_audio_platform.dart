// livekit_client 2.13 で Android の音のセッションを Room の外から始める / 止める口(`setAudioSessionOptions` /
// `deactivateAudioSession`)は experimental の印つき。ほかに口が無いので使う(版を上げるときにここを見直す、D-455)。
// ignore_for_file: experimental_member_use
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

/// 通話の端末の音 (D-455) の口: 音のセッション、マイクの許可、裏に回っても止めない前面サービス。
///
/// **Android でマイクがうまく働かなかった理由**: livekit_client は読み込まれた時点で flutter_webrtc 自身の音の管理
/// (`AudioSwitchManager`: getUserMedia / 相手の声が来たら通話のモード `MODE_IN_COMMUNICATION` + 音の焦点 + 出し先)を
/// 止め(`LiveKitPlugin.kt` の `AudioSwitchManager.setAudioSessionManagementEnabled(false)`)、代わりに自分の
/// `LKAudioSwitchManager` を **LiveKit の `Room.connect` のときだけ** 始める(`AudioManager.applyOptionsForConnect`)。
/// 通話(P2P)は LiveKit の Room を使わないので、Android は通話のモードに入らないまま(`MODE_NORMAL`: 端末の
/// エコーキャンセル / 通話用のマイクの道 / Bluetooth のヘッドセットのマイクが使われない)だった。スピーカーの指定
/// (`setSpeakerOutputPreferred`)も、始まっていないセッションには何もしない。
///
/// ここで LiveKit の音のセッションを **通話の形(communication)で自分で始め**(手動のモード — LiveKit の Room の
/// 接続 / 切断では始めも止めもしない)、ルームを出たら止める(入る前のモードに戻る)。iOS は WebRTC のエンジンの
/// 状態から LiveKit が音のセッションを決めるので、これまでどおりスピーカーを優先するだけ。
///
/// 端末の音のセッションはアプリに 1 つなので、持ち主([owner] = ルームごとの通話の口)を覚える。退出の片付けは待たずに
/// 走るので、前のルームの [stop] が次のルームの [start] より後に届いても、次のルームのセッションは止めない。
abstract class AstellAudioPlatform {
  /// 通話の音のセッションを始める(何度呼んでもよい)。[owner] が持ち主になる。
  Future<void> start(Object owner);

  /// 止める(ルームを出た)。[owner] が持ち主のときだけ。前面サービスも止める。
  Future<void> stop(Object owner);

  /// マイクの許可を求める(Android: RECORD_AUDIO、12 からは Bluetooth のヘッドセットの許可も)。断られたら false。
  /// ほかの端末は true(getUserMedia が聞く)。
  Future<bool> requestMic();

  /// ルームにいる間、裏に回っても / 画面を消してもマイクを止めない(Android: 前面サービス、種類 microphone)。
  /// [owner] が持ち主のときだけ。
  Future<void> keepAlive(Object owner, bool on);
}

/// 何もしない(Web / デスクトップ / テスト)。
class NullAstellAudioPlatform implements AstellAudioPlatform {
  const NullAstellAudioPlatform();
  @override
  Future<void> start(Object owner) async {}
  @override
  Future<void> stop(Object owner) async {}
  @override
  Future<bool> requestMic() async => true;
  @override
  Future<void> keepAlive(Object owner, bool on) async {}
}

/// Android / iOS の実物。Android の許可と前面サービスは `MainActivity` の `AstellAudioBridge`(チャンネル
/// [astellAudioChannelName])。
class NativeAstellAudioPlatform implements AstellAudioPlatform {
  NativeAstellAudioPlatform({TargetPlatform? platform, MethodChannel? channel})
      : _platform = platform ?? defaultTargetPlatform,
        _channel = channel ?? const MethodChannel(astellAudioChannelName);

  final TargetPlatform _platform;
  final MethodChannel _channel;
  Object? _owner;
  bool _started = false;
  bool _keepAlive = false;

  bool get _android => _platform == TargetPlatform.android;

  @override
  Future<void> start(Object owner) async {
    _owner = owner;
    await _start();
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    try {
      // 通話は複数人なので受話口ではなくスピーカーから(ヘッドセットがあればそちら)。セッションより先に決めておく。
      await lk.AudioManager.instance.setSpeakerOutputPreferred(true);
      if (_android) await lk.AudioManager.instance.setAudioSessionOptions(const lk.AudioSessionOptions.communication());
    } catch (e) {
      debugPrint('astell audio: start: $e');
    }
  }

  @override
  Future<void> stop(Object owner) async {
    if (!identical(owner, _owner)) return;
    await keepAlive(owner, false);
    _owner = null;
    if (!_started) return;
    _started = false;
    if (!_android) return;
    try {
      await lk.AudioManager.instance.deactivateAudioSession();
    } catch (e) {
      debugPrint('astell audio: stop: $e');
    }
  }

  @override
  Future<bool> requestMic() async {
    if (!_android) return true;
    Map<Object?, Object?>? r;
    try {
      r = await _channel.invokeMapMethod<Object?, Object?>('requestMic');
    } on MissingPluginException {
      return true; // 古い組み立て(橋が無い): getUserMedia に任せる
    } catch (e) {
      debugPrint('astell audio: requestMic: $e');
      return true;
    }
    if (r == null) return true;
    // Bluetooth の許可がいま出た: 始めていたセッションを作り直して、ヘッドセットを見つけさせる。
    if (r['bluetoothNewlyGranted'] == true && _started) {
      _started = false;
      try {
        await lk.AudioManager.instance.deactivateAudioSession();
      } catch (e) {
        debugPrint('astell audio: restart: $e');
      }
      await _start();
    }
    return r['mic'] != false;
  }

  @override
  Future<void> keepAlive(Object owner, bool on) async {
    if (!_android || on == _keepAlive || !identical(owner, _owner)) return;
    _keepAlive = on;
    try {
      await _channel.invokeMethod<Object?>(on ? 'startCall' : 'stopCall');
    } on MissingPluginException {
      // 古い組み立て: 前面サービスなし
    } catch (e) {
      debugPrint('astell audio: keepAlive($on): $e');
    }
  }
}

/// `MainActivity` の `AstellAudioBridge` のチャンネル。
const astellAudioChannelName = 'rasq/astell_audio';

/// いまの端末の口(アプリに 1 つ)。Web とデスクトップは何もしない。
AstellAudioPlatform astellAudioPlatform() {
  if (kIsWeb) return const NullAstellAudioPlatform();
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => _native ??= NativeAstellAudioPlatform(),
    _ => const NullAstellAudioPlatform(),
  };
}

NativeAstellAudioPlatform? _native;
