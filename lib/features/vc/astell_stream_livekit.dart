import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;

import 'astell_media.dart';
import 'astell_models.dart';
import 'astell_stream.dart';
import 'astell_web_audio.dart' show astellOnNextUserGesture;

/// 配信の実物 (D-317): livekit_client。
///
/// - 画面の取り込み: Android は MediaProjection の同意 + 前面サービス(flutter_background、`mediaProjection`)、
///   iOS は**アプリの中だけ**(端末全体は ReplayKit の Broadcast Extension が要る — まだ作っていない)、
///   デスクトップは画面 / ウィンドウを選ぶ([pickAstellScreenSource])、Web はブラウザの選択。
/// - 声は [setAudioPolicy] で相手ごとに鳴らす / 止める(通話で聞こえている人の声は二重にしない)。
/// - Web の声: livekit_client が `<audio>` を作って `play()` する。ブラウザの自動再生の制限で断られると
///   `AudioPlaybackStatusChanged(isPlaying: false)` が来るので、次にページを触ったときに `room.startAudio()` する (D-318)。
class LiveKitAstellStreamer extends AstellStreamer {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _events;
  bool _canPublish = false;
  String? _publishing;
  bool _background = false;
  bool Function(String identity) _play = _always;

  static bool _always(String _) => true;

  @override
  bool get connected => _room?.connectionState == lk.ConnectionState.connected;

  @override
  bool get canPublish => _canPublish && connected;

  @override
  String? get publishing => _publishing;

  @override
  Future<void> connect(AstellStreamToken token) async {
    await disconnect();
    final room = lk.Room(roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true));
    final events = room.createListener();
    events.listen((_) {
      _applyAudio();
      notifyListeners();
    });
    if (kIsWeb) {
      events.on<lk.AudioPlaybackStatusChanged>((e) {
        if (!e.isPlaying) _resumeAudioOnGesture(room);
      });
      // 一度断られたあと(canPlaybackAudio が false のまま)に来た声は、状態が変わらないので上の知らせが来ない。
      events.on<lk.TrackSubscribedEvent>((e) {
        if (e.track is lk.RemoteAudioTrack && !room.canPlaybackAudio) _resumeAudioOnGesture(room);
      });
    }
    _room = room;
    _events = events;
    _canPublish = token.canPublish;
    await room.connect(token.url, token.token);
    _applyAudio();
    notifyListeners();
  }

  @override
  Future<void> publish(String kind, {required bool mic, String? screenSourceId}) async {
    final lp = _room?.localParticipant;
    if (lp == null || !_canPublish) throw StateError('配信サーバーに繋がっていません');
    if (kind == 'screen' && astellInsecureWebContext()) throw const AstellMediaException(AstellMediaIssue.insecureContext);
    try {
      if (kind == 'screen') {
        await _startScreenCapture();
        await lp.setScreenShareEnabled(
          true,
          captureScreenAudio: false,
          screenShareCaptureOptions: lk.ScreenShareCaptureOptions(sourceId: screenSourceId, maxFrameRate: 15),
        );
      } else {
        await lp.setCameraEnabled(true);
      }
      await lp.setMicrophoneEnabled(mic);
    } catch (e) {
      await _stopScreenCapture();
      throw AstellMediaException.from(e);
    }
    _publishing = kind;
    notifyListeners();
  }

  /// Web: 自動再生が断られた声を、次の操作で鳴らし直す(まだ断られていれば、また次の操作で)。
  void _resumeAudioOnGesture(lk.Room room) {
    if (_resumeQueued) return;
    _resumeQueued = true;
    astellOnNextUserGesture(() {
      _resumeQueued = false;
      if (identical(_room, room)) unawaited(room.startAudio());
    });
  }

  bool _resumeQueued = false;

  /// Android の画面の取り込みは、同意のあと前面サービスを立ててから(Android 14 から必須)。
  Future<void> _startScreenCapture() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final granted = await rtc.Helper.requestCapturePermission();
    if (!granted) throw const AstellMediaException(AstellMediaIssue.permissionDenied);
    const config = FlutterBackgroundAndroidConfig(
      notificationTitle: 'RASQ AsTell',
      notificationText: '画面を共有しています',
      notificationImportance: AndroidNotificationImportance.normal,
      notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
    );
    if (await FlutterBackground.initialize(androidConfig: config) && !FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.enableBackgroundExecution();
    }
    _background = true;
  }

  Future<void> _stopScreenCapture() async {
    if (!_background) return;
    _background = false;
    try {
      if (FlutterBackground.isBackgroundExecutionEnabled) await FlutterBackground.disableBackgroundExecution();
    } catch (e) {
      debugPrint('astell stream: background: $e');
    }
  }

  @override
  Future<void> setMic(bool on) async {
    final lp = _room?.localParticipant;
    if (lp == null || _publishing == null) return;
    await lp.setMicrophoneEnabled(on);
  }

  @override
  Future<void> unpublish() async {
    final lp = _room?.localParticipant;
    final was = _publishing;
    _publishing = null;
    if (lp != null) {
      try {
        if (was == 'screen') await lp.setScreenShareEnabled(false);
        if (was == 'camera') await lp.setCameraEnabled(false);
        await lp.setMicrophoneEnabled(false);
      } catch (e) {
        debugPrint('astell stream: unpublish: $e');
      }
    }
    await _stopScreenCapture();
    notifyListeners();
  }

  lk.Participant? _participant(String identity) {
    final room = _room;
    if (room == null) return null;
    final local = room.localParticipant;
    if (local != null && local.identity == identity) return local;
    return room.remoteParticipants[identity];
  }

  lk.VideoTrack? _track(String identity, bool screen) {
    final p = _participant(identity);
    if (p == null) return null;
    lk.VideoTrack? pick(lk.TrackSource source) {
      for (final pub in p.videoTrackPublications) {
        final t = pub.track;
        if (pub.source == source && !pub.muted && t is lk.VideoTrack) return t;
      }
      return null;
    }

    return screen ? (pick(lk.TrackSource.screenShareVideo) ?? pick(lk.TrackSource.camera)) : (pick(lk.TrackSource.camera) ?? pick(lk.TrackSource.screenShareVideo));
  }

  @override
  bool hasVideo(String identity, {bool screen = false}) => _track(identity, screen) != null;

  @override
  Widget? video(String identity, {bool screen = false, BoxFit fit = BoxFit.contain}) {
    final t = _track(identity, screen);
    if (t == null) return null;
    return lk.VideoTrackRenderer(t, key: ValueKey(t.sid ?? identity), fit: fit == BoxFit.cover ? lk.VideoViewFit.cover : lk.VideoViewFit.contain);
  }

  @override
  void setAudioPolicy(bool Function(String identity) play) {
    _play = play;
    _applyAudio();
  }

  void _applyAudio() {
    final room = _room;
    if (room == null) return;
    for (final p in room.remoteParticipants.values) {
      final on = _play(p.identity);
      for (final pub in p.audioTrackPublications) {
        final t = pub.track;
        if (t == null) continue;
        on ? t.enable() : t.disable();
      }
    }
  }

  @override
  Future<void> disconnect() async {
    final room = _room;
    final events = _events;
    _room = null;
    _events = null;
    _canPublish = false;
    _publishing = null;
    await _stopScreenCapture();
    await events?.dispose();
    if (room != null) {
      try {
        await room.disconnect();
      } catch (e) {
        debugPrint('astell stream: disconnect: $e');
      }
      await room.dispose();
    }
    notifyListeners();
  }
}

/// デスクトップ(macOS / Windows / Linux)で画面の取り込みの前に、画面 / ウィンドウを選ぶか。
bool get astellNeedsScreenPicker => !kIsWeb && const {TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux}.contains(defaultTargetPlatform);

/// 画面 / ウィンドウを選ぶ(LiveKit の選択ダイアログ)。やめたら null。
Future<String?> pickAstellScreenSource(BuildContext context) async {
  final source = await showDialog<rtc.DesktopCapturerSource>(
    context: context,
    builder: (_) => lk.ScreenSelectDialog(titleText: '共有する画面を選ぶ', screenTabText: '画面全体', windowTabText: 'ウィンドウ', cancelText: 'やめる', shareText: '共有する'),
  );
  return source?.id;
}
