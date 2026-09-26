import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart' show AudioManager;

import 'astell_media.dart';
import 'astell_web_audio.dart';

/// 相手 1 人との接続を作る口(既定は flutter_webrtc の `createPeerConnection`)。テストは偽物。
typedef AstellPeerConnectionFactory = Future<RTCPeerConnection> Function(Map<String, dynamic> configuration);

/// マイクを開く口(既定は `navigator.mediaDevices.getUserMedia`)。テストは偽物。
typedef AstellUserMedia = Future<MediaStream> Function(Map<String, dynamic> constraints);

/// 受けた音声を鳴らし始める口(Web は `<audio>`、ネイティブは null = 繋がなくても鳴る)。[muted] = はじめから止めておく。
typedef AstellRemoteAudioPlayer = AstellRemoteAudio? Function(MediaStreamTrack track, {required bool muted});

/// 通話の音声の実物 (D-317): flutter_webrtc(Android / iOS / macOS / Windows / Linux / Web)。
///
/// - マイクは 1 本(`getUserMedia({audio})`)を全員に送る。はじめは止めておき(`enabled = false`)、
///   `micOn` の間だけ流す。開く前に作った接続にも、開いたときに `replaceTrack` で差し込む。
/// - 相手ごとの接続は、送受信の音声 1 本だけ。offer を出す側が `addTransceiver(audio, sendrecv)`、受ける側は
///   相手の offer でできた 1 本を `sendrecv` にしてから answer を作る — マイクの出し入れで繋ぎ直さない。
/// - 相手の声: ネイティブは受けたトラックがそのまま鳴る。Web は `<audio>` が要るので、受けた**トラック**を繋ぐ
///   (`ontrack` の `streams` は、こちらの送り方では空。D-318)。ミュートは受けたトラックの `enabled` と `<audio>` の muted。
/// - Web のマイク: https(安全なコンテキスト)なら、ネイティブと同じく開ける。http のときだけ [micBlocked]。
/// - 様子 (D-323): 接続 / ICE の状態の変化と、受けた声・`<audio>` の様子をログ(`astell call:`)に出し、
///   [AstellPeerLink.diagnostics] で ICE の候補の種類・選ばれた組・送受信のバイト数を返す(設定の「接続の状態」)。
class WebRtcAstellMedia implements AstellMedia {
  WebRtcAstellMedia({AstellPeerConnectionFactory? peerConnection, AstellUserMedia? userMedia, AstellRemoteAudioPlayer? remoteAudio, bool? web})
      : _peerConnection = peerConnection ?? createPeerConnection,
        _userMedia = userMedia ?? ((constraints) => navigator.mediaDevices.getUserMedia(constraints)),
        _remoteAudio = remoteAudio ?? playAstellRemoteAudio,
        _web = web ?? kIsWeb;

  final AstellPeerConnectionFactory _peerConnection;
  final AstellUserMedia _userMedia;
  final AstellRemoteAudioPlayer _remoteAudio;
  final bool _web;
  MediaStream? _mic;
  bool _micEnabled = false;
  final Set<_WebRtcLink> _links = {};
  bool _speakerRouted = false;

  @override
  bool get available => true;

  @override
  AstellMediaIssue? get micBlocked => astellInsecureWebContext(web: _web) ? AstellMediaIssue.insecureContext : null;

  @override
  bool get micOpen => _mic != null;

  MediaStreamTrack? get _micTrack => _mic?.getAudioTracks().firstOrNull;

  @override
  Future<void> openMic() async {
    if (_mic != null) return;
    final blocked = micBlocked;
    if (blocked != null) throw AstellMediaException(blocked);
    try {
      _mic = await _userMedia({
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
      await l.attachMic(track, send: _micEnabled);
    }
  }

  /// マイクの上げ下ろし (D-330): `enabled` を切り替えるだけでなく、下ろしたら送る側から**外す**(`replaceTrack(null)`)、
  /// 立てたら差し直す。`enabled = false` だけでは端末によって相手に声が届き続けた(実機の指摘 2026-09-26)。
  @override
  void setMicEnabled(bool enabled) {
    _micEnabled = enabled;
    _micTrack?.enabled = enabled;
    for (final l in _links) {
      unawaited(l.setSending(enabled).catchError((Object e) => debugPrint('astell media: mic ${enabled ? 'on' : 'off'}: $e')));
    }
  }

  @override
  Future<AstellPeerLink> createLink(String peerId, {required bool offerer, required List<Map<String, Object?>> iceServers, required AstellLinkHandlers handlers}) async {
    await _routeToSpeaker();
    final pc = await _peerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });
    final link = _WebRtcLink(peerId, pc, handlers, remoteAudio: _remoteAudio, onClosed: _links.remove);
    await link.init(offerer: offerer, mic: _micTrack, send: _micEnabled);
    _links.add(link);
    return link;
  }

  /// 電話(Android / iOS)は受話口ではなくスピーカーから(複数人の通話なので。ヘッドセットがあればそちら)。
  /// 端末の音のセッションは livekit_client の AudioManager が持つ(読み込んだ時点で flutter_webrtc の
  /// 管理を止めて、同じ WebRTC のエンジンの状態から決める)ので、出し先もそこへ頼む。
  Future<void> _routeToSpeaker() async {
    if (_speakerRouted || _web) return;
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
  _WebRtcLink(this.peerId, this._pc, this._handlers, {required AstellRemoteAudioPlayer remoteAudio, required this.onClosed}) : _playRemote = remoteAudio;

  @override
  final String peerId;
  final RTCPeerConnection _pc;
  final AstellLinkHandlers _handlers;
  final void Function(_WebRtcLink link) onClosed;
  final AstellRemoteAudioPlayer _playRemote;

  RTCSignalingState? _signaling = RTCSignalingState.RTCSignalingStateStable;
  String? _connection;
  String? _ice;
  String? _gathering;
  final Map<String, int> _localKinds = {};
  final Map<String, int> _remoteKinds = {};
  bool _micAttached = false;
  bool _hasRemote = false;
  bool _playback = true;
  bool _closed = false;
  MediaStreamTrack? _remoteAudio;
  AstellRemoteAudio? _out;
  /// 持っているマイク。送る側に差すのは [_send](マイクが立っている)のときだけ (D-330)。
  MediaStreamTrack? _pendingMic;
  bool _send = false;

  Future<void> init({required bool offerer, MediaStreamTrack? mic, bool send = false}) async {
    _pc.onSignalingState = (s) => _signaling = s;
    _pc.onIceCandidate = (c) {
      if (c.candidate == null || _closed) return;
      _tally(_localKinds, c.candidate);
      _handlers.onIceCandidate({'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex});
    };
    _pc.onIceGatheringState = (s) => _gathering = _w3c(s.name, 'RTCIceGatheringState');
    _pc.onIceConnectionState = (s) {
      _ice = _w3c(s.name, 'RTCIceConnectionState');
      _log('ice=$_ice (candidates: local ${_kinds(_localKinds)} / remote ${_kinds(_remoteKinds)})');
    };
    _pc.onConnectionState = (s) {
      _connection = _w3c(s.name, 'RTCPeerConnectionState');
      _log('connection=$_connection');
      _handlers.onState(switch (s) {
        RTCPeerConnectionState.RTCPeerConnectionStateConnected => AstellLinkState.connected,
        RTCPeerConnectionState.RTCPeerConnectionStateDisconnected => AstellLinkState.disconnected,
        RTCPeerConnectionState.RTCPeerConnectionStateFailed => AstellLinkState.failed,
        RTCPeerConnectionState.RTCPeerConnectionStateClosed => AstellLinkState.closed,
        _ => AstellLinkState.connecting,
      });
    };
    _pc.onTrack = (e) {
      if (e.track.kind != 'audio') return;
      _remoteAudio = e.track;
      e.track.enabled = _playback;
      _playOut(e.track);
      _log('remote audio track (streams: ${e.streams.length}${_out != null ? ', <audio> ${_out!.state}' : ''})');
    };
    if (offerer) {
      // 送受信の音声 1 本。マイクがまだ無ければ空で出しておき、開いたら差し込む。
      await _pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );
    }
    _pendingMic = mic;
    _send = send;
    if (offerer && mic != null && send) await _applyMic();
  }

  /// Web: 受けたトラックを `<audio>` に繋ぐ(`e.streams` は見ない — 送る側が `addTransceiver` + `replaceTrack` なので、
  /// SDP にストリームが載らず空になる。D-318)。同じ接続で別のトラックが来たら、前の `<audio>` は外す。
  void _playOut(MediaStreamTrack track) {
    if (_closed) return;
    final before = _out;
    try {
      _out = _playRemote(track, muted: !_playback);
    } catch (e) {
      debugPrint('astell media: web audio: $e');
      _out = null;
    }
    if (before != null && !identical(before, _out)) unawaited(before.dispose());
  }

  Future<RTCRtpTransceiver?> _audioTransceiver() async {
    for (final t in await _pc.getTransceivers()) {
      final kind = t.receiver.track?.kind ?? t.sender.track?.kind;
      if (kind == null || kind == 'audio') return t;
    }
    return null;
  }

  /// マイクを持つ(繋ぎ直しは要らない)。[send] = 立っている(送る側に差す)。
  Future<void> attachMic(MediaStreamTrack track, {required bool send}) async {
    _pendingMic = track;
    _send = send;
    await _applyMic();
  }

  /// マイクを立てる / 下ろす (D-330): 立てたら差す、下ろしたら `replaceTrack(null)` で外す。
  Future<void> setSending(bool send) async {
    _send = send;
    await _applyMic();
  }

  Future<void> _applyMic() async {
    if (_closed) return;
    final t = await _audioTransceiver();
    if (t == null) return; // 受ける側で、まだ相手の offer が来ていない — setRemoteDescription のあとで差し込む
    final track = _send ? _pendingMic : null;
    if (track == null && !_micAttached) return; // 外すものが無い
    await t.sender.replaceTrack(track);
    _micAttached = track != null;
  }

  static void _tally(Map<String, int> into, String? candidate) {
    final kind = astellCandidateKind(candidate);
    if (kind != null) into[kind] = (into[kind] ?? 0) + 1;
  }

  static String _kinds(Map<String, int> m) => m.isEmpty ? '-' : [for (final e in m.entries) '${e.key}:${e.value}'].join(',');

  /// `RTCIceConnectionStateConnected` → `connected`(W3C の綴り)。
  static String _w3c(String name, String prefix) {
    final rest = name.startsWith(prefix) ? name.substring(prefix.length) : name;
    return rest.isEmpty ? rest : rest[0].toLowerCase() + rest.substring(1);
  }

  void _log(String message) => debugPrint('astell call: ${peerId.length > 8 ? peerId.substring(0, 8) : peerId} $message');

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
      // 相手の offer でできた音声の 1 本を送受信にして、マイクが立っていれば差し込む(answer に sendrecv が載る)。
      final t = await _audioTransceiver();
      if (t != null) {
        await t.setDirection(TransceiverDirection.SendRecv);
        await _applyMic();
      }
    }
  }

  @override
  Future<void> rollback() async {
    await _pc.setLocalDescription(RTCSessionDescription('', 'rollback'));
    _signaling = RTCSignalingState.RTCSignalingStateStable;
  }

  @override
  Future<void> addIceCandidate(Map<String, Object?> candidate) {
    _tally(_remoteKinds, candidate['candidate'] as String?);
    return _pc.addCandidate(RTCIceCandidate(candidate['candidate'] as String?, candidate['sdpMid'] as String?, (candidate['sdpMLineIndex'] as num?)?.toInt()));
  }

  @override
  void setPlayback(bool on) {
    _playback = on;
    _remoteAudio?.enabled = on;
    _out?.setMuted(!on);
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
  Future<AstellLinkDiagnostics> diagnostics() async {
    var stats = const AstellRtcStats();
    if (!_closed) {
      try {
        stats = AstellRtcStats.from([for (final r in await _pc.getStats()) (id: r.id, type: r.type, values: r.values)]);
      } catch (e) {
        debugPrint('astell call: stats: $e');
      }
    }
    return AstellLinkDiagnostics(
      peerId: peerId,
      connectionState: _closed ? 'closed' : _connection,
      iceConnectionState: _ice,
      iceGatheringState: _gathering,
      signalingState: signalingState,
      localCandidates: {..._localKinds},
      remoteCandidates: {..._remoteKinds},
      stats: stats,
      remoteAudio: _remoteAudio != null,
      playout: _out?.state,
      micAttached: _micAttached,
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    onClosed(this);
    try {
      await _out?.dispose();
    } catch (_) {}
    _out = null;
    await _pc.close();
    await _pc.dispose();
  }
}
