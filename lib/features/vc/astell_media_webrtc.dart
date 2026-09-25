import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart' show AudioManager;

import 'astell_media.dart';

/// 通話の音声の実物 (D-317): flutter_webrtc(Android / iOS / macOS / Windows / Linux / Web)。
///
/// - マイクは 1 本(`getUserMedia({audio})`)を全員に送る。はじめは止めておき(`enabled = false`)、
///   `micOn` の間だけ流す。開く前に作った接続にも、開いたときに `replaceTrack` で差し込む。
/// - 相手ごとの接続は、送受信の音声 1 本だけ。offer を出す側が `addTransceiver(audio, sendrecv)`、受ける側は
///   相手の offer でできた 1 本を `sendrecv` にしてから answer を作る — マイクの出し入れで繋ぎ直さない。
/// - 相手の声: ネイティブは受けたトラックがそのまま鳴る。Web は `<audio>` が要るので、見えないレンダラーに繋ぐ。
///   ミュートは受けたトラックの `enabled`。
class WebRtcAstellMedia implements AstellMedia {
  MediaStream? _mic;
  bool _micEnabled = false;
  final Set<_WebRtcLink> _links = {};
  bool _speakerRouted = false;

  @override
  bool get available => true;

  @override
  AstellMediaIssue? get micBlocked => astellInsecureWebContext() ? AstellMediaIssue.insecureContext : null;

  @override
  bool get micOpen => _mic != null;

  MediaStreamTrack? get _micTrack => _mic?.getAudioTracks().firstOrNull;

  @override
  Future<void> openMic() async {
    if (_mic != null) return;
    final blocked = micBlocked;
    if (blocked != null) throw AstellMediaException(blocked);
    try {
      _mic = await navigator.mediaDevices.getUserMedia({
        'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
        'video': false,
      });
    } catch (e) {
      throw AstellMediaException.from(e);
    }
    final track = _micTrack;
    if (track == null) {
      await _closeMic();
      throw const AstellMediaException(AstellMediaIssue.noDevice);
    }
    track.enabled = _micEnabled;
    for (final l in _links) {
      await l.attachMic(track);
    }
  }

  @override
  void setMicEnabled(bool enabled) {
    _micEnabled = enabled;
    _micTrack?.enabled = enabled;
  }

  @override
  Future<AstellPeerLink> createLink(String peerId, {required bool offerer, required List<Map<String, Object?>> iceServers, required AstellLinkHandlers handlers}) async {
    await _routeToSpeaker();
    final pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });
    final link = _WebRtcLink(peerId, pc, handlers, onClosed: _links.remove);
    await link.init(offerer: offerer, mic: _micTrack);
    _links.add(link);
    return link;
  }

  /// 電話(Android / iOS)は受話口ではなくスピーカーから(複数人の通話なので。ヘッドセットがあればそちら)。
  /// 端末の音のセッションは livekit_client の AudioManager が持つ(読み込んだ時点で flutter_webrtc の
  /// 管理を止めて、同じ WebRTC のエンジンの状態から決める)ので、出し先もそこへ頼む。
  Future<void> _routeToSpeaker() async {
    if (_speakerRouted || kIsWeb) return;
    _speakerRouted = true;
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(true);
    } catch (e) {
      debugPrint('astell media: speakerphone: $e');
    }
  }

  Future<void> _closeMic() async {
    final mic = _mic;
    _mic = null;
    if (mic == null) return;
    for (final t in mic.getTracks()) {
      try {
        await t.stop();
      } catch (_) {}
    }
    await mic.dispose();
  }

  @override
  Future<void> dispose() async {
    for (final l in [..._links]) {
      await l.close();
    }
    _links.clear();
    await _closeMic();
  }
}

class _WebRtcLink implements AstellPeerLink {
  _WebRtcLink(this.peerId, this._pc, this._handlers, {required this.onClosed});

  @override
  final String peerId;
  final RTCPeerConnection _pc;
  final AstellLinkHandlers _handlers;
  final void Function(_WebRtcLink link) onClosed;

  RTCSignalingState? _signaling = RTCSignalingState.RTCSignalingStateStable;
  bool _hasRemote = false;
  bool _playback = true;
  bool _closed = false;
  MediaStreamTrack? _remoteAudio;
  RTCVideoRenderer? _webAudio;
  MediaStreamTrack? _pendingMic;

  Future<void> init({required bool offerer, MediaStreamTrack? mic}) async {
    _pc.onSignalingState = (s) => _signaling = s;
    _pc.onIceCandidate = (c) {
      if (c.candidate == null || _closed) return;
      _handlers.onIceCandidate({'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex});
    };
    _pc.onConnectionState = (s) => _handlers.onState(switch (s) {
          RTCPeerConnectionState.RTCPeerConnectionStateConnected => AstellLinkState.connected,
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected => AstellLinkState.disconnected,
          RTCPeerConnectionState.RTCPeerConnectionStateFailed => AstellLinkState.failed,
          RTCPeerConnectionState.RTCPeerConnectionStateClosed => AstellLinkState.closed,
          _ => AstellLinkState.connecting,
        });
    _pc.onTrack = (e) {
      if (e.track.kind != 'audio') return;
      _remoteAudio = e.track;
      e.track.enabled = _playback;
      if (kIsWeb && e.streams.isNotEmpty) _playOnWeb(e.streams.first);
    };
    if (offerer) {
      // 送受信の音声 1 本。マイクがまだ無ければ空で出しておき、開いたら差し込む。
      await _pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );
    }
    _pendingMic = mic;
    if (offerer && mic != null) await attachMic(mic);
  }

  Future<void> _playOnWeb(MediaStream stream) async {
    final r = _webAudio ??= RTCVideoRenderer();
    try {
      await r.initialize();
      r.srcObject = stream;
      r.muted = !_playback;
    } catch (e) {
      debugPrint('astell media: web audio: $e');
    }
  }

  Future<RTCRtpTransceiver?> _audioTransceiver() async {
    for (final t in await _pc.getTransceivers()) {
      final kind = t.receiver.track?.kind ?? t.sender.track?.kind;
      if (kind == null || kind == 'audio') return t;
    }
    return null;
  }

  /// マイクを送る側に差し込む(繋ぎ直しは要らない)。
  Future<void> attachMic(MediaStreamTrack track) async {
    _pendingMic = track;
    if (_closed) return;
    final t = await _audioTransceiver();
    if (t == null) return; // 受ける側で、まだ相手の offer が来ていない — setRemoteDescription のあとで差し込む
    await t.sender.replaceTrack(track);
  }

  @override
  String get signalingState => switch (_signaling) {
        RTCSignalingState.RTCSignalingStateHaveLocalOffer => 'have-local-offer',
        RTCSignalingState.RTCSignalingStateHaveRemoteOffer => 'have-remote-offer',
        RTCSignalingState.RTCSignalingStateHaveLocalPrAnswer => 'have-local-pranswer',
        RTCSignalingState.RTCSignalingStateHaveRemotePrAnswer => 'have-remote-pranswer',
        RTCSignalingState.RTCSignalingStateClosed => 'closed',
        _ => 'stable',
      };

  @override
  bool get hasRemoteDescription => _hasRemote;

  Map<String, Object?> _desc(RTCSessionDescription d) => {'sdp': d.sdp, 'type': d.type};

  @override
  Future<Map<String, Object?>> createOffer({bool iceRestart = false}) async {
    final offer = await _pc.createOffer({if (iceRestart) 'iceRestart': true});
    await _pc.setLocalDescription(offer);
    _signaling = RTCSignalingState.RTCSignalingStateHaveLocalOffer;
    return _desc(offer);
  }

  @override
  Future<Map<String, Object?>> createAnswer() async {
    final answer = await _pc.createAnswer();
    await _pc.setLocalDescription(answer);
    _signaling = RTCSignalingState.RTCSignalingStateStable;
    return _desc(answer);
  }

  @override
  Future<void> setRemoteDescription(Map<String, Object?> description) async {
    final type = description['type'] as String?;
    await _pc.setRemoteDescription(RTCSessionDescription(description['sdp'] as String?, type));
    _hasRemote = true;
    _signaling = type == 'offer' ? RTCSignalingState.RTCSignalingStateHaveRemoteOffer : RTCSignalingState.RTCSignalingStateStable;
    if (type == 'offer') {
      // 相手の offer でできた音声の 1 本を送受信にして、マイクがあれば差し込む(answer に sendrecv が載る)。
      final t = await _audioTransceiver();
      if (t != null) {
        await t.setDirection(TransceiverDirection.SendRecv);
        final mic = _pendingMic;
        if (mic != null) await t.sender.replaceTrack(mic);
      }
    }
  }

  @override
  Future<void> rollback() async {
    await _pc.setLocalDescription(RTCSessionDescription('', 'rollback'));
    _signaling = RTCSignalingState.RTCSignalingStateStable;
  }

  @override
  Future<void> addIceCandidate(Map<String, Object?> candidate) =>
      _pc.addCandidate(RTCIceCandidate(candidate['candidate'] as String?, candidate['sdpMid'] as String?, (candidate['sdpMLineIndex'] as num?)?.toInt()));

  @override
  void setPlayback(bool on) {
    _playback = on;
    _remoteAudio?.enabled = on;
    _webAudio?.muted = !on;
  }

  @override
  Future<double> remoteAudioLevel() async {
    if (_closed) return 0;
    var level = 0.0;
    for (final r in await _pc.getStats()) {
      final v = r.values;
      final audio = v['kind'] == 'audio' || v['mediaType'] == 'audio';
      final remote = r.type == 'inbound-rtp' || (r.type == 'track' && v['remoteSource'] == true);
      final l = v['audioLevel'];
      if (audio && remote && l is num && l > level) level = l.toDouble();
    }
    return level;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    onClosed(this);
    try {
      _webAudio?.srcObject = null;
      await _webAudio?.dispose();
    } catch (_) {}
    await _pc.close();
    await _pc.dispose();
  }
}
