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
  bool _playing = false;
  @override
  bool get playing => _playing;
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
class AudioHoldMusic implements HoldMusic {
  AudioHoldMusic({this.volume = 0.5});
  final double volume;
  AudioPlayer? _player;
  bool _playing = false;
  @override
  bool get playing => _playing;

  static final _context = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.playAndRecord, options: const {AVAudioSessionOptions.mixWithOthers, AVAudioSessionOptions.defaultToSpeaker, AVAudioSessionOptions.allowBluetooth}),
    android: const AudioContextAndroid(isSpeakerphoneOn: true, stayAwake: false, contentType: AndroidContentType.music, usageType: AndroidUsageType.voiceCommunication, audioFocus: AndroidAudioFocus.none),
  );

  @override
  Future<void> start() async {
    if (_playing) return;
    _playing = true;
    try {
      final p = _player ??= AudioPlayer(playerId: 'rasq.holdMusic');
      await p.setAudioContext(_context);
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

  AudioPlayer? _chime;

  @override
  Future<void> alarm() async {
    await stop();
    try {
      final p = _chime ??= AudioPlayer(playerId: 'rasq.alarm');
      await p.setAudioContext(_context);
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
