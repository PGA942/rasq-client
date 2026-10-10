import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'astell_audio_platform.dart';
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
/// - **下ろしている間は送る側を止める (D-455)**: ネイティブの WebRTC(libwebrtc)は、マイクを取り込む口(ADM)から
///   「送っている」音声の送り口すべてへ直に音を渡す。送受信(sendrecv)の 1 本は、トラックを一度も差していなくても
///   ネゴシエーションが終わると送り始め(トラックが無くても始まり、ミュートもされていない)、端末のマイクが入って
///   **相手に声が届いていた** — 接続した直後、ボタンは「オフ」なのに声が出ていて、1 回目のタップ(立てる)では変わらず、
///   2 回目(下ろす = `replaceTrack(null)` でミュートされる)でやっと止まった。いまは送る側の符号化を
///   `active: false`(`RTCRtpSender.setParameters`)にして、立てている間だけ `true` にする(送り口が止まり、ほかに
///   送っているものが無ければ取り込みも止まる)。Web(ブラウザ)はトラックの無い送り口は何も送らないので、これまでどおり。
/// - マイクの開け閉め (D-455): 開いている最中にもう一度呼ばれても getUserMedia は 1 回だけ(同じ待ちを返す)。
///   開いている間に閉じた(退出)ら、開けたマイクはすぐ止める(OS のマイクを掴んだままにしない)。
/// - 端末の音 (D-455): 最初に接続を作るか、マイクを開くときに [AstellAudioPlatform] で通話の音のセッションを始め
///   (Android は通話のモード)、マイクの前に許可を求め(Android は Bluetooth のヘッドセットの許可も)、開けたら
///   裏に回っても止めない前面サービスを始める。閉じたら全部止める。
class WebRtcAstellMedia implements AstellMedia {
  WebRtcAstellMedia({AstellPeerConnectionFactory? peerConnection, AstellUserMedia? userMedia, AstellRemoteAudioPlayer? remoteAudio, bool? web, AstellAudioPlatform? audio})
      : _peerConnection = peerConnection ?? createPeerConnection,
        _userMedia = userMedia ?? ((constraints) => navigator.mediaDevices.getUserMedia(constraints)),
        _remoteAudio = remoteAudio ?? playAstellRemoteAudio,
        _web = web ?? kIsWeb,
        _audio = audio ?? ((web ?? kIsWeb) ? const NullAstellAudioPlatform() : astellAudioPlatform());

  final AstellPeerConnectionFactory _peerConnection;
  final AstellUserMedia _userMedia;
  final AstellRemoteAudioPlayer _remoteAudio;
  final bool _web;
  final AstellAudioPlatform _audio;
  MediaStream? _mic;
  bool _micEnabled = false;
  final Set<_WebRtcLink> _links = {};
  Future<void>? _sessionStarted;
  Future<void>? _opening;
  bool _disposed = false;

  @override
  bool get available => true;

  @override
  AstellMediaIssue? get micBlocked => astellInsecureWebContext(web: _web) ? AstellMediaIssue.insecureContext : null;

  @override
  bool get micOpen => _mic != null;

  MediaStreamTrack? get _micTrack => _mic?.getAudioTracks().firstOrNull;

  /// 開いている最中に何度呼ばれても、同じ待ちを返す(getUserMedia は 1 回だけ、D-455)。
  @override
  Future<void> openMic() {
    if (_mic != null) return Future.value();
    if (_disposed) return Future.error(StateError('閉じた通話のマイクは開けません'));
    return _opening ??= _openMic().whenComplete(() => _opening = null);
  }

  Future<void> _openMic() async {
    final blocked = micBlocked;
    if (blocked != null) throw AstellMediaException(blocked);
    // 先に通話の音のセッション(Android の通話のモード)と許可。許可が無いまま getUserMedia に進まない。
    await _startSession();
    if (!await _audio.requestMic()) throw const AstellMediaException(AstellMediaIssue.permissionDenied);
    if (_disposed) throw StateError('閉じた通話のマイクは開けません');
    final MediaStream stream;
    try {
      stream = await _userMedia({
        'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
        'video': false,
      });
    } catch (e) {
      throw AstellMediaException.from(e);
    }
    // 開いている間に退出した: 掴んだマイクはすぐ離す。
    if (_disposed || _mic != null) {
      await _stopStream(stream);
      if (_disposed) throw StateError('閉じた通話のマイクは開けません');
      return;
    }
    final track = stream.getAudioTracks().firstOrNull;
    if (track == null) {
      await _stopStream(stream);
      throw const AstellMediaException(AstellMediaIssue.noDevice);
    }
    _mic = stream;
    track.enabled = _micEnabled;
    unawaited(_audio.keepAlive(this, true));
    await Future.wait([for (final l in [..._links]) l.attachMic(track, send: _micEnabled)]);
  }

  /// マイクの上げ下ろし (D-330): `enabled` を切り替えるだけでなく、下ろしたら送る側から**外す**(`replaceTrack(null)`)、
  /// 立てたら差し直す。`enabled = false` だけでは端末によって相手に声が届き続けた(実機の指摘 2026-09-26)。
  @override
  void setMicEnabled(bool enabled) {
    _micEnabled = enabled;
    _micTrack?.enabled = enabled;
    for (final l in _links) {
      unawaited(l.setSending(enabled));
    }
  }

  @override
  Future<AstellPeerLink> createLink(String peerId, {required bool offerer, required List<Map<String, Object?>> iceServers, required AstellLinkHandlers handlers}) async {
    await _startSession();
    final pc = await _peerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });
    final link = _WebRtcLink(peerId, pc, handlers, remoteAudio: _remoteAudio, onClosed: _links.remove, gateSender: !_web)
      .._pendingMic = _micTrack
      .._send = _micEnabled;
    // 作っている間にマイクを開けた / 立てた・下ろした分も、この接続に届くよう先に並べる。
    _links.add(link);
    await link.init(offerer: offerer);
    if (_disposed) await link.close(); // 作っている間に閉じた(退出)
    return link;
  }

  /// 通話の音のセッション(Android: 通話のモード + 音の焦点 + スピーカー優先、iOS: スピーカー優先)を 1 回だけ。
  Future<void> _startSession() => _sessionStarted ??= _audio.start(this).catchError((Object e) => debugPrint('astell media: audio session: $e'));

  static Future<void> _stopStream(MediaStream stream) async {
    for (final t in stream.getTracks()) {
      try {
        await t.stop();
      } catch (_) {}
    }
    try {
      await stream.dispose();
    } catch (_) {}
  }

  Future<void> _closeMic() async {
    final mic = _mic;
    _mic = null;
    if (mic == null) return;
    await _stopStream(mic);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final l in [..._links]) {
      await l.close();
    }
    _links.clear();
    await _closeMic();
    try {
      await _audio.stop(this);
    } catch (e) {
      debugPrint('astell media: audio session stop: $e');
    }
  }
}

class _WebRtcLink implements AstellPeerLink {
  _WebRtcLink(this.peerId, this._pc, this._handlers, {required AstellRemoteAudioPlayer remoteAudio, required this.onClosed, required this.gateSender}) : _playRemote = remoteAudio;

  /// 下ろしている間、送る側の符号化を止める(`active: false`)か (D-455)。ネイティブだけ。
  final bool gateSender;

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

  /// 送る側にいま差しているトラック(差し替えが済んだもの)。
  MediaStreamTrack? _attached;

  /// 送る側の符号化を最後に何にしたか(`active`)。null = まだ決めていない(ネゴシエーションのたびに決め直す)。
  bool? _active;

  /// 送る側の差し替えを 1 本ずつ (D-455): 立てる途中に下ろしても、順に済ませて最後の向きに揃える。
  Future<void> _micOps = Future.value();

  /// マイク([_pendingMic])と向き([_send])は、作った側が先に入れておく。
  Future<void> init({required bool offerer}) async {
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
    // 送受信の 1 本を作ったらすぐ、下ろしていれば送る側を止めておく(トラックが無くても送り始めるので、D-455)。
    if (offerer) await _applyMic();
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
  Future<void> attachMic(MediaStreamTrack track, {required bool send}) {
    _pendingMic = track;
    _send = send;
    return _applyMic();
  }

  /// マイクを立てる / 下ろす (D-330): 立てたら差す、下ろしたら `replaceTrack(null)` で外す。
  Future<void> setSending(bool send) {
    _send = send;
    return _applyMic();
  }

  /// 送る側を、いまの向き([_send] / [_pendingMic])に揃える。1 本ずつ順に(前の差し替えが済んでから)。
  /// 揃える中身は実行するときに読むので、立てる → 下ろす が重なっても最後は下ろした形になる (D-455)。
  Future<void> _applyMic() {
    final op = _micOps.then((_) => _syncSender()).catchError((Object e) => debugPrint('astell media: ${peerId.length > 8 ? peerId.substring(0, 8) : peerId} mic: $e'));
    return _micOps = op;
  }

  Future<void> _syncSender() async {
    if (_closed) return;
    final t = await _audioTransceiver();
    if (t == null) return; // 受ける側で、まだ相手の offer が来ていない — setRemoteDescription のあとで差し込む
    final track = _send ? _pendingMic : null;
    final sending = track != null;
    // 下ろす: 先に符号化を止めてから外す。立てる: 差してから符号化を始める(止めている間は何も送らない)。
    if (!sending) await _setActive(t.sender, false);
    if (!identical(track, _attached)) {
      await t.sender.replaceTrack(track);
      _attached = track;
    }
    _micAttached = sending;
    if (sending) await _setActive(t.sender, true);
  }

  /// 送る側の符号化を入れる / 止める (D-455、ネイティブだけ)。いまの値は送り手から読み直して、`active` だけ変える。
  /// 失敗しても差し替え(`replaceTrack`)は続ける(下ろすときのミュートは D-330 の外し方でも効く)。
  Future<void> _setActive(RTCRtpSender sender, bool active) async {
    if (!gateSender || _active == active || _closed) return;
    try {
      final p = sender.parameters;
      final encodings = p.encodings;
      if (encodings == null || encodings.isEmpty) {
        p.encodings = [RTCRtpEncoding(active: active, numTemporalLayers: null, scaleResolutionDownBy: null)];
      } else {
        for (final e in encodings) {
          e.active = active;
        }
      }
      await sender.setParameters(p);
      _active = active;
    } catch (e) {
      _log('sender active=$active: $e');
    }
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
    await _resyncSender();
    return _desc(offer);
  }

  @override
  Future<Map<String, Object?>> createAnswer() async {
    final answer = await _pc.createAnswer();
    await _pc.setLocalDescription(answer);
    _signaling = RTCSignalingState.RTCSignalingStateStable;
    await _resyncSender();
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
      if (t != null) await t.setDirection(TransceiverDirection.SendRecv);
    }
    await _resyncSender();
  }

  /// ネゴシエーションのたびに(送り手に SSRC が付いた / 付け直した)、送る側の止める / 入れるを決め直す (D-455)。
  /// 送り始めるのは ICE が繋がってからなので、下ろしていればそれより前に止まる。
  Future<void> _resyncSender() {
    _active = null;
    return _applyMic();
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
