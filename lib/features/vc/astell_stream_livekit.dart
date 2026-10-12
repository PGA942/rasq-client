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
///   iOS は `setScreenShareEnabled` を使わない: livekit_client(2.4 から)は iOS だとそこで Broadcast Extension の
///   選択を出すだけで、拡張が無いと**何も上げずに** null を返す(エラーにもならない)。自分でトラックを作って上げる
///   ([astellScreenCaptureInApp]、D-323)。上げたあとは、映像のトラックが本当に上がったかを確かめる。
/// - 様子 (D-323): 上げた / 受けたトラックをログ(`astell stream:`)に出し、[diagnostics] で一覧にする。
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
    // 実機での切り分け用 (D-323): 上げた / 受けたトラックと、繋がり方の変化。
    events
      ..on<lk.LocalTrackPublishedEvent>((e) => _log('published ${e.publication.source.name} ${e.publication.kind.name}'))
      ..on<lk.TrackPublishedEvent>((e) => _log('${_short(e.participant.identity)} published ${e.publication.source.name} ${e.publication.kind.name}'))
      ..on<lk.TrackSubscribedEvent>((e) => _log('subscribed ${_short(e.participant.identity)} ${e.publication.source.name} ${e.publication.kind.name}'))
      ..on<lk.TrackSubscriptionExceptionEvent>((e) => _log('subscription failed ${_short(e.participant?.identity ?? '?')} ${e.sid}: ${e.reason.name}'))
      ..on<lk.RoomReconnectingEvent>((_) => _log('reconnecting'))
      ..on<lk.RoomDisconnectedEvent>((e) => _log('disconnected (${e.reason?.name})'));
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
    _log('connected to ${token.url} as ${token.canPublish ? 'publisher' : 'subscriber'} (${room.remoteParticipants.length} remote)');
    _applyAudio();
    notifyListeners();
  }

  static String _short(String id) => id.length > 8 ? id.substring(0, 8) : id;

  static void _log(String message) => debugPrint('astell stream: $message');

  @override
  Future<void> publish(String kind, {required bool mic, String? screenSourceId}) async {
    final lp = _room?.localParticipant;
    if (lp == null || !_canPublish) throw StateError('配信サーバーに繋がっていません');
    if (kind == 'screen' && astellInsecureWebContext()) throw const AstellMediaException(AstellMediaIssue.insecureContext);
    final source = kind == 'screen' ? lk.TrackSource.screenShareVideo : lk.TrackSource.camera;
    try {
      if (kind == 'screen') {
        await _startScreenCapture();
        final options = lk.ScreenShareCaptureOptions(sourceId: screenSourceId, maxFrameRate: 15);
        if (astellScreenCaptureInApp() && lp.getTrackPublicationBySource(source) == null) {
          // iOS: このアプリの画面(ReplayKit の RPScreenRecorder)を自分でトラックにして上げる。
          final track = await lk.LocalVideoTrack.createScreenShareTrack(options);
          try {
            await lp.publishVideoTrack(track);
          } catch (_) {
            await track.stop();
            rethrow;
          }
        } else {
          await lp.setScreenShareEnabled(true, captureScreenAudio: false, screenShareCaptureOptions: options);
        }
      } else {
        await lp.setCameraEnabled(true);
      }
      // 上がったか: 何も上げずに戻る道がある(iOS の setScreenShareEnabled など)。黙って「共有中」にしない。
      if (lp.getTrackPublicationBySource(source) == null) {
        throw const AstellMediaException(AstellMediaIssue.unsupported, '映像を配信サーバーに上げられませんでした');
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
      notificationTitle: 'RASQ ASTell',
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

  /// LiveKit のサーバーの話している人 (D-467)。`ActiveSpeakersChanged` も含め、部屋の出来事ごとに
  /// [notifyListeners] している(`connect` の `events.listen`)ので、聞く側はそこで読み直す。
  @override
  Set<String> get speakingIdentities => {
        for (final p in _room?.activeSpeakers ?? const <lk.Participant>[])
          if (p is lk.RemoteParticipant) p.identity,
      };

  @override
  bool get localSpeaking => _room?.localParticipant?.isSpeaking ?? false;

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
  AstellStreamDiagnostics diagnostics() {
    final room = _room;
    if (room == null) return const AstellStreamDiagnostics(connection: 'disconnected');
    String pubLine(lk.TrackPublication pub) => '${pub.source.name} ${pub.kind.name}${pub.muted ? '(ミュート)' : ''}';
    return AstellStreamDiagnostics(
      connection: room.connectionState.name,
      canPublish: canPublish,
      publishing: _publishing,
      local: [for (final pub in room.localParticipant?.trackPublications.values ?? const <lk.LocalTrackPublication>[]) pubLine(pub)],
      remote: {
        for (final p in room.remoteParticipants.values)
          p.identity: [
            for (final pub in p.trackPublications.values)
              '${pubLine(pub)}: ${switch (pub.subscriptionState) {
                lk.TrackSubscriptionState.subscribed => '受信中${pub.kind == lk.TrackType.VIDEO && pub.streamState == lk.StreamState.paused ? '(サーバーが一時停止 — 表示されていない)' : ''}',
                lk.TrackSubscriptionState.notAllowed => '許可されていない',
                lk.TrackSubscriptionState.unsubscribed => '未受信',
              }}',
          ],
      },
      canPlaybackAudio: kIsWeb ? room.canPlaybackAudio : null,
    );
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

/// 画面の取り込みを、LiveKit の `setScreenShareEnabled` ではなく自分で作ったトラックで上げるか (D-323)。
/// iOS(アプリ)だけ: livekit_client の `setScreenShareEnabled` は iOS だと Broadcast Extension の選択を出すだけで、
/// 拡張が無いと何も上げない。flutter_webrtc の `getDisplayMedia` は `deviceId` に `broadcast` を付けなければ
/// このアプリの画面(RPScreenRecorder)を取る。[web] / [platform] はテスト用。
bool astellScreenCaptureInApp({bool web = kIsWeb, TargetPlatform? platform}) => !web && (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;

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
