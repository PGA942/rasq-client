import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 保留音 (D-325 → D-327): `assets/audio/hold_music.wav`(ユーザー提供、12.8 秒、ループで鳴らす)。
///
/// AsTell のルームで、**開催予約の開始を待っている間**と、**全員がマイクを下ろして(画面共有 / 配信も無く)チャットが
/// 1 分以上流れていない間**に、参加者それぞれの端末で鳴る。鳴らす条件は `AstellSession._syncHoldMusic`(自分の端末の設定
/// `astell.holdMusic` と、ルームの `holdMusic`(オーナー)の両方がオンのとき)。
const holdMusicAsset = 'audio/hold_music.wav';

/// 開催のチャイム (D-331): ユーザー提供の目覚まし用の音源(`We：Astronomies on the Blue Planet.wav`、16 秒)。開催予約の開始を
/// 保留音で待っていた人に、開催が始まった瞬間に 1 回鳴らす。Android の開始通知(`res/raw/alarm.wav`)/ iOS・macOS の
/// 開始通知(`alarm.wav` を Runner に同梱したとき)にも同じ音。
const alarmAsset = 'audio/alarm.wav';

/// 保留音の口。テストは [MemoryHoldMusic](鳴らさず回数だけ数える)。
abstract class HoldMusic {
  /// いま鳴らしている(始めた直後から true。読み込み中も含む)。
  bool get playing;

  /// 鳴らす口の音の設定を先に済ませる (D-455)。ルームに入るとき、通話の音のセッションより**前に**呼ぶ。何度呼んでもよい。
  Future<void> prepare();
  Future<void> start();
  Future<void> stop();

  /// 開催のチャイムを 1 回鳴らす (D-331)。保留音が鳴っていれば止めてから。
  Future<void> alarm();
  Future<void> dispose();
}

/// 鳴らさない(テスト / プラグインの無い環境)。
class MemoryHoldMusic implements HoldMusic {
  int starts = 0;
  int stops = 0;
  int alarms = 0;
  int prepares = 0;
  bool _playing = false;
  @override
  bool get playing => _playing;
  @override
  Future<void> prepare() async => prepares++;
  @override
  Future<void> start() async {
    if (_playing) return;
    _playing = true;
    starts++;
  }

  @override
  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    stops++;
  }

  @override
  Future<void> alarm() async {
    await stop();
    alarms++;
  }

  @override
  Future<void> dispose() async {}
}

/// audioplayers で鳴らす。通話(WebRTC)と同じ音の道(iOS は playAndRecord + mixWithOthers、Android は voiceCommunication)に
/// 乗せて、通話の音を止めたり奪ったりしない。失敗しても通話は続ける(ログだけ)。
///
/// **Android の注意 (D-455)**: audioplayers_android は、プレイヤーの音の設定が前と違うと、その設定の
/// `audioMode` と `isSpeakerphoneOn` を**端末全体の** AudioManager に書く(`WrappedPlayer.updateAudioContext` の
/// `audioManager.mode = context.audioMode` / `audioManager.isSpeakerphoneOn = …`、同じ設定なら何もしない)。
/// 前は通話の最中に初めて鳴らしたとき `MODE_NORMAL` + スピーカー強制を書き、通話のモード(エコーキャンセル /
/// 通話用のマイクの道 / Bluetooth のヘッドセット)を壊していた。いまは [prepare] で、**ルームに入るとき(通話の音の
/// セッションを始める前)に** 2 つのプレイヤーの設定を一度だけ入れておく。書くのは通話の前の値と同じ(通常のモード、
/// スピーカーの強制なし)なので、通話のセッションはそれを「入る前の状態」として覚えて、出るときに戻す。通話の最中の
/// [start] / [alarm] は同じ設定を入れ直すだけなので、端末全体には何も書かない。
class AudioHoldMusic implements HoldMusic {
  AudioHoldMusic({this.volume = 0.5});
  final double volume;
  AudioPlayer? _player;
  bool _playing = false;
  @override
  bool get playing => _playing;

  /// 保留音とチャイムの音の設定 (D-455)。Android: 通話の音の道(`voiceCommunication`)で、音の焦点は取らない(通話の
  /// 焦点を奪わない)。`audioMode` / `isSpeakerphoneOn` は通話の前の値と同じ(通常のモード / 強制なし)— 上の注意。
  @visibleForTesting
  static final context = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.playAndRecord, options: const {AVAudioSessionOptions.mixWithOthers, AVAudioSessionOptions.defaultToSpeaker, AVAudioSessionOptions.allowBluetooth}),
    android: const AudioContextAndroid(isSpeakerphoneOn: false, audioMode: AndroidAudioMode.normal, stayAwake: false, contentType: AndroidContentType.music, usageType: AndroidUsageType.voiceCommunication, audioFocus: AndroidAudioFocus.none),
  );

  AudioPlayer? _chime;
  Future<void>? _prepared;

  AudioPlayer get _hold => _player ??= AudioPlayer(playerId: 'rasq.holdMusic');
  AudioPlayer get _alarm => _chime ??= AudioPlayer(playerId: 'rasq.alarm');

  /// Android だけ先に入れる(iOS はこれまでどおり鳴らすときに。音のセッションの種類を先に変えない)。
  @override
  Future<void> prepare() {
    if (kIsWeb || !Platform.isAndroid) return Future.value();
    return _prepared ??= () async {
      try {
        await _hold.setAudioContext(context);
        await _alarm.setAudioContext(context);
      } catch (e) {
        debugPrint('hold music: prepare: $e');
      }
    }();
  }

  @override
  Future<void> start() async {
    if (_playing) return;
    _playing = true;
    try {
      await prepare();
      final p = _hold;
      await p.setAudioContext(context);
      await p.setReleaseMode(ReleaseMode.loop);
      await p.play(AssetSource(holdMusicAsset), volume: volume);
    } catch (e) {
      debugPrint('hold music: start: $e');
    }
  }

  @override
  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('hold music: stop: $e');
    }
  }

  @override
  Future<void> alarm() async {
    await stop();
    try {
      await prepare();
      final p = _alarm;
      await p.setAudioContext(context);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.play(AssetSource(alarmAsset), volume: 1);
    } catch (e) {
      debugPrint('hold music: alarm: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _playing = false;
    final p = _player;
    final c = _chime;
    _player = null;
    _chime = null;
    _prepared = null;
    try {
      await p?.dispose();
      await c?.dispose();
    } catch (e) {
      debugPrint('hold music: dispose: $e');
    }
  }
}

/// 保留音の口。テスト(FLUTTER_TEST)ではプラグインが無いので鳴らさない口。
final holdMusicProvider = Provider<HoldMusic>((ref) {
  final HoldMusic music = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST') ? MemoryHoldMusic() : AudioHoldMusic();
  ref.onDispose(() => music.dispose());
  return music;
});
