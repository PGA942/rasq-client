import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:rasq_client/features/vc/astell_audio_platform.dart';
import 'package:rasq_client/features/vc/astell_media.dart';
import 'package:rasq_client/features/vc/astell_media_webrtc.dart';

/// D-318: 通話の音声の実物(flutter_webrtc の口)を、偽の RTCPeerConnection の上で。
///
/// Web 版で相手の声が鳴らなかった: 受けた音声を `<audio>` に繋ぐのを `ontrack` の `streams.first` に頼っていたが、
/// こちらの送り方(`addTransceiver` + `replaceTrack`)では SDP にストリームが載らず、`streams` は空になる。
/// いまは受けたトラックそのものを鳴らす口に渡す。
void main() {
  const handlers = AstellLinkHandlers(onIceCandidate: _ignore, onState: _ignoreState);
  const ice = <Map<String, Object?>>[];

  ({WebRtcAstellMedia media, List<_FakePc> pcs, List<_FakeOut> outs, List<Map<String, dynamic>> asked}) make({bool web = true, _FakeTrack? mic, AstellAudioPlatform? audio, Future<MediaStream> Function()? userMedia}) {
    final pcs = <_FakePc>[];
    final outs = <_FakeOut>[];
    final asked = <Map<String, dynamic>>[];
    final media = WebRtcAstellMedia(
      web: web,
      audio: audio ?? (web ? null : _FakeAudio()),
      peerConnection: (config) async {
        final pc = _FakePc();
        pcs.add(pc);
        return pc;
      },
      userMedia: (constraints) async {
        asked.add(constraints);
        if (userMedia != null) return userMedia();
        return _FakeStream([mic ?? _FakeTrack('audio', 'mic')]);
      },
      remoteAudio: (track, {required muted}) {
        final o = _FakeOut(track, muted);
        outs.add(o);
        return o;
      },
    );
    return (media: media, pcs: pcs, outs: outs, asked: asked);
  }

  group('相手の声 (Web)', () {
    test('ontrack の streams が空でも(addTransceiver + replaceTrack で送る相手)、受けた音声のトラックを鳴らす口に繋ぐ', () async {
      final m = make();
      await m.media.createLink('p2', offerer: false, iceServers: ice, handlers: handlers);
      final voice = _FakeTrack('audio', 'r1');
      m.pcs.single.onTrack!(RTCTrackEvent(track: voice, streams: const []));
      expect(m.outs.map((o) => o.track), [voice]);
      expect(m.outs.single.muted, isFalse);
      // 映像は繋がない(通話は音声だけ)。
      m.pcs.single.onTrack!(RTCTrackEvent(track: _FakeTrack('video', 'v1'), streams: const []));
      expect(m.outs, hasLength(1));
    });

    test('スピーカーミュート / 手元のミュートで <audio> も止める。あとから来た声も止めたまま。閉じると外す', () async {
      final m = make();
      final link = await m.media.createLink('p2', offerer: true, iceServers: ice, handlers: handlers);
      link.setPlayback(false);
      final voice = _FakeTrack('audio', 'r1');
      m.pcs.single.onTrack!(RTCTrackEvent(track: voice, streams: const []));
      expect(m.outs.single.muted, isTrue);
      expect(voice.enabled, isFalse);
      link.setPlayback(true);
      expect(m.outs.single.muted, isFalse);
      expect(voice.enabled, isTrue);
      // 同じ接続で別のトラックが来たら、前の <audio> は外す。
      m.pcs.single.onTrack!(RTCTrackEvent(track: _FakeTrack('audio', 'r2'), streams: const []));
      expect(m.outs.first.disposed, isTrue);
      await link.close();
      expect(m.outs.last.disposed, isTrue);
      expect(m.pcs.single.closed, isTrue);
    });
  });

  group('マイク (Web でも https ならネイティブと同じ)', () {
    test('開いたマイクは、offer を出す側の送受信の 1 本に、立てたときだけ差し込む。下ろすと外す (D-330)', () async {
      final mic = _FakeTrack('audio', 'mic');
      final m = make(mic: mic);
      await m.media.openMic();
      expect(m.asked.single['audio'], isA<Map<String, dynamic>>());
      expect(mic.enabled, isFalse); // 立てるまでは送らない
      await m.media.createLink('p2', offerer: true, iceServers: ice, handlers: handlers);
      final t = m.pcs.single.made.single;
      expect(t.direction, TransceiverDirection.SendRecv);
      expect(t.sender.replaced, isEmpty, reason: '立てるまでは送る側に差さない');
      m.media.setMicEnabled(true);
      await Future<void>.delayed(Duration.zero);
      expect(mic.enabled, isTrue);
      expect(t.sender.replaced, [mic]);
      // 下ろす: enabled を切るだけでなく、送る側から外す(端末によって enabled=false だけでは声が止まらなかった)。
      m.media.setMicEnabled(false);
      await Future<void>.delayed(Duration.zero);
      expect(mic.enabled, isFalse);
      expect(t.sender.replaced, [mic, null]);
      m.media.setMicEnabled(true);
      await Future<void>.delayed(Duration.zero);
      expect(t.sender.replaced, [mic, null, mic]);
    });

    test('受ける側: 相手の offer でできた 1 本を sendrecv にして、立っているマイクを差し込む / あとから開いて立てたマイクも差し込む', () async {
      final mic = _FakeTrack('audio', 'mic');
      final m = make(mic: mic);
      final link = await m.media.createLink('p2', offerer: false, iceServers: ice, handlers: handlers);
      await link.setRemoteDescription({'sdp': 'offer-sdp', 'type': 'offer'});
      final t = m.pcs.single.made.single;
      expect(t.direction, TransceiverDirection.SendRecv); // ブラウザは recvonly で作る
      expect(t.sender.replaced, isEmpty); // マイクはまだ開いていない
      await m.media.openMic();
      expect(t.sender.replaced, isEmpty, reason: '開いただけ(下ろしたまま)では差さない');
      m.media.setMicEnabled(true);
      await Future<void>.delayed(Duration.zero);
      expect(t.sender.replaced, [mic]);
      // 立てたまま繋いだ相手には、offer が来た時点で差す。
      final mic2 = await m.media.createLink('p3', offerer: false, iceServers: ice, handlers: handlers);
      await mic2.setRemoteDescription({'sdp': 'offer-sdp', 'type': 'offer'});
      expect(m.pcs.last.made.single.sender.replaced, [mic]);
    });

    test('Web を http(localhost 以外)で開いていれば開かない。https(安全なコンテキスト)なら開ける', () async {
      expect(astellInsecureWebContext(web: true, secureContext: true), isFalse);
      expect(astellInsecureWebContext(web: true, secureContext: false), isTrue);
      final native = make(web: false);
      expect(native.media.micBlocked, isNull);
    });
  });

  group('ネイティブ: 下ろしている間は送る側を止める (D-455)', () {
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('offer を出す側: 送受信の 1 本を作った時点で止める(トラックが無くても libwebrtc は送り始めるので)。立てたら差してから入れ、下ろしたら止めてから外す', () async {
      final mic = _FakeTrack('audio', 'mic');
      final m = make(web: false, mic: mic);
      final link = await m.media.createLink('p2', offerer: true, iceServers: ice, handlers: handlers);
      await settle();
      final sender = m.pcs.single.made.single.sender;
      expect(sender.active, isFalse, reason: '接続した直後、ボタンはオフ — 送る側も止まっている');
      expect(sender.replaced, isEmpty);
      // ネゴシエーション(SSRC が付く)のあとも止めたまま。
      await link.createOffer();
      await link.setRemoteDescription({'sdp': 'answer-sdp', 'type': 'answer'});
      await settle();
      expect(sender.active, isFalse);
      expect(sender.ops.where((o) => o == 'active:true'), isEmpty, reason: '一度も入れていない');

      await m.media.openMic();
      m.media.setMicEnabled(true);
      await settle();
      expect([sender.active, sender.replaced], [true, [mic]]);
      expect(sender.ops.sublist(sender.ops.length - 2), ['replace:mic', 'active:true'], reason: '差してから入れる');
      m.media.setMicEnabled(false);
      await settle();
      expect([sender.active, sender.replaced], [false, [mic, null]]);
      expect(sender.ops.sublist(sender.ops.length - 2), ['active:false', 'replace:null'], reason: '止めてから外す');
      expect((await link.diagnostics()).micAttached, isFalse);
    });

    test('受ける側: 相手の offer でできた 1 本は、answer を作る前に止める。立てたまま繋いだ相手には入れる', () async {
      final mic = _FakeTrack('audio', 'mic');
      final m = make(web: false, mic: mic);
      final link = await m.media.createLink('p2', offerer: false, iceServers: ice, handlers: handlers);
      await link.setRemoteDescription({'sdp': 'offer-sdp', 'type': 'offer'});
      final sender = m.pcs.single.made.single.sender;
      expect(sender.active, isFalse);
      await link.createAnswer();
      await settle();
      expect(sender.active, isFalse);

      await m.media.openMic();
      m.media.setMicEnabled(true);
      final l2 = await m.media.createLink('p3', offerer: false, iceServers: ice, handlers: handlers);
      await l2.setRemoteDescription({'sdp': 'offer-sdp', 'type': 'offer'});
      await settle();
      final s2 = m.pcs.last.made.single.sender;
      expect([s2.active, s2.replaced], [true, [mic]]);
    });

    test('立てる途中で下ろす(差し替えを待っている間): 順に済ませて、最後は止めて外した形', () async {
      final mic = _FakeTrack('audio', 'mic');
      final m = make(web: false, mic: mic);
      await m.media.createLink('p2', offerer: true, iceServers: ice, handlers: handlers);
      await settle();
      final sender = m.pcs.single.made.single.sender;
      await m.media.openMic();
      final gate = sender.gate = Completer<void>();
      m.media.setMicEnabled(true);
      await settle();
      m.media.setMicEnabled(false); // 差し替えの最中に下ろす
      await settle();
      gate.complete();
      sender.gate = null;
      await settle();
      expect(sender.replaced, [mic, null]);
      expect(sender.active, isFalse);
      expect(mic.enabled, isFalse);
    });

    test('Web は送る側の符号化を触らない(ブラウザはトラックの無い送り口から何も送らない)', () async {
      final m = make(mic: _FakeTrack('audio', 'mic'));
      await m.media.createLink('p2', offerer: true, iceServers: ice, handlers: handlers);
      await m.media.openMic();
      m.media.setMicEnabled(true);
      await settle();
      expect(m.pcs.single.made.single.sender.ops.where((o) => o.startsWith('active')), isEmpty);
    });
  });

  group('マイクの開け閉めと端末の音 (D-455)', () {
    test('開いている最中にもう一度呼んでも getUserMedia は 1 回。先に音のセッションと許可、開けたら前面サービス', () async {
      final audio = _FakeAudio();
      final gate = Completer<MediaStream>();
      final m = make(web: false, audio: audio, userMedia: () => gate.future);
      final a = m.media.openMic();
      final b = m.media.openMic();
      await Future<void>.delayed(Duration.zero);
      expect(m.asked, hasLength(1));
      gate.complete(_FakeStream([_FakeTrack('audio', 'mic')]));
      await Future.wait([a, b]);
      expect(m.asked, hasLength(1));
      expect(m.media.micOpen, isTrue);
      expect(audio.log, ['start', 'requestMic', 'keepAlive:true']);
      await m.media.openMic();
      expect(m.asked, hasLength(1), reason: '開いていれば開かない');
      await m.media.dispose();
      expect(audio.log.last, 'stop');
    });

    test('マイクの許可が無ければ getUserMedia に進まず、許可が無いと言う', () async {
      final audio = _FakeAudio()..micGranted = false;
      final m = make(web: false, audio: audio);
      await expectLater(m.media.openMic(), throwsA(isA<AstellMediaException>().having((e) => e.issue, 'issue', AstellMediaIssue.permissionDenied)));
      expect(m.asked, isEmpty);
      expect(m.media.micOpen, isFalse);
    });

    test('開いている最中に退出したら、開けたマイクはすぐ止める(OS のマイクを掴んだままにしない)', () async {
      final gate = Completer<MediaStream>();
      final track = _FakeTrack('audio', 'mic');
      final m = make(web: false, userMedia: () => gate.future);
      final opening = m.media.openMic();
      await Future<void>.delayed(Duration.zero);
      await m.media.dispose();
      gate.complete(_FakeStream([track]));
      await expectLater(opening, throwsA(isA<StateError>()));
      expect(track.stopped, isTrue);
      expect(m.media.micOpen, isFalse);
    });

    test('接続を作るときにも音のセッションを始める(1 回だけ)。始めた口でないと止めない', () async {
      final audio = _FakeAudio();
      final m = make(web: false, audio: audio);
      await m.media.createLink('p2', offerer: true, iceServers: ice, handlers: handlers);
      await m.media.createLink('p3', offerer: true, iceServers: ice, handlers: handlers);
      expect(audio.log, ['start']);
      expect(audio.owners.single, same(m.media));
    });
  });

  group('接続の様子 (D-323)', () {
    test('ICE の候補の種類: host / mDNS で隠した host / srflx / relay / TCP。空(候補の終わり)は数えない', () {
      expect(astellCandidateKind('candidate:1 1 udp 2122260223 100.96.57.10 61274 typ host generation 0'), 'host');
      expect(astellCandidateKind('candidate:2 1 udp 2122260223 4b1c2d3e-aaaa-bbbb-cccc-0123456789ab.local 59118 typ host'), 'host(mDNS)');
      expect(astellCandidateKind('candidate:3 1 udp 1686052607 119.231.38.1 64051 typ srflx raddr 0.0.0.0 rport 0'), 'srflx');
      expect(astellCandidateKind('candidate:4 1 udp 41885439 100.91.218.56 3478 typ relay raddr 1.2.3.4 rport 5'), 'relay');
      expect(astellCandidateKind('candidate:5 1 tcp 1518280447 100.91.218.56 7881 typ host tcptype passive'), 'host/tcp');
      expect(astellCandidateKind(''), isNull);
      expect(astellCandidateKind(null), isNull);
    });

    test('統計のまとめ: ブラウザ(transport.selectedCandidatePairId)とネイティブ(nominated + succeeded)の選ばれた組、音声の送受信', () {
      final browser = AstellRtcStats.from([
        (id: 'T01', type: 'transport', values: {'selectedCandidatePairId': 'CP2'}),
        (id: 'CP1', type: 'candidate-pair', values: {'state': 'failed', 'localCandidateId': 'L1', 'remoteCandidateId': 'R1'}),
        (id: 'CP2', type: 'candidate-pair', values: {'state': 'succeeded', 'localCandidateId': 'L2', 'remoteCandidateId': 'R2'}),
        (id: 'L2', type: 'local-candidate', values: {'candidateType': 'prflx', 'protocol': 'udp', 'address': '100.88.46.2', 'port': 64051}),
        (id: 'R2', type: 'remote-candidate', values: {'candidateType': 'host', 'protocol': 'udp', 'address': '100.96.57.10', 'port': 61274}),
        (id: 'IN', type: 'inbound-rtp', values: {'kind': 'audio', 'bytesReceived': 4200, 'packetsReceived': 30, 'packetsLost': 1, 'audioLevel': 0.25}),
        (id: 'OUT', type: 'outbound-rtp', values: {'kind': 'audio', 'bytesSent': 3900}),
        (id: 'V', type: 'inbound-rtp', values: {'kind': 'video', 'bytesReceived': 99999}),
      ]);
      expect(browser.pairState, 'succeeded');
      expect(browser.localCandidate, 'prflx udp 100.88.46.2:64051');
      expect(browser.remoteCandidate, 'host udp 100.96.57.10:61274');
      expect([browser.bytesSent, browser.bytesReceived, browser.packetsReceived, browser.packetsLost], [3900, 4200, 30, 1]);
      expect(browser.audioLevel, 0.25);

      final native = AstellRtcStats.from([
        (id: 'CPa', type: 'candidate-pair', values: {'state': 'in-progress', 'nominated': false}),
        (id: 'CPb', type: 'candidate-pair', values: {'state': 'succeeded', 'nominated': true, 'localCandidateId': 'La', 'remoteCandidateId': 'Rb'}),
        (id: 'La', type: 'local-candidate', values: {'candidateType': 'host', 'protocol': 'udp', 'ip': '100.96.57.10', 'port': 61274}),
        (id: 'IN', type: 'inbound-rtp', values: {'mediaType': 'audio', 'bytesReceived': '10'}),
      ]);
      expect(native.pairState, 'succeeded');
      expect(native.localCandidate, 'host udp 100.96.57.10:61274');
      expect(native.remoteCandidate, isNull, reason: '報告に無い候補は出さない');
      expect(native.bytesReceived, 10);
      expect(native.bytesSent, isNull);

      // まだ組が決まっていない(ICE が繋がっていない)。
      expect(AstellRtcStats.from([(id: 'CPx', type: 'candidate-pair', values: {'state': 'waiting'})]).pairState, isNull);
    });

    test('接続ごとに: 接続 / ICE の状態、出した・受けた候補の種類、選ばれた組、受けた声と <audio> の様子、マイク', () async {
      final mic = _FakeTrack('audio', 'mic');
      final m = make(mic: mic);
      final sentIce = <Map<String, Object?>>[];
      final link = await m.media.createLink('peer-abcdefgh-1', offerer: true, iceServers: ice, handlers: AstellLinkHandlers(onIceCandidate: sentIce.add, onState: _ignoreState));
      final pc = m.pcs.single;
      var d = await link.diagnostics();
      expect([d.connectionState, d.iceConnectionState, d.remoteAudio, d.micAttached], [null, null, false, false]);
      expect(d.lines()[1], '候補: 自分 なし / 相手 なし');

      pc.onIceCandidate!(RTCIceCandidate('candidate:1 1 udp 1 aaaa.local 5000 typ host', '0', 0));
      pc.onIceCandidate!(RTCIceCandidate('candidate:2 1 udp 1 119.231.38.1 5001 typ srflx raddr 0.0.0.0 rport 0', '0', 0));
      await link.addIceCandidate({'candidate': 'candidate:3 1 udp 1 100.96.57.10 61274 typ host', 'sdpMid': '0', 'sdpMLineIndex': 0});
      pc.onIceGatheringState!(RTCIceGatheringState.RTCIceGatheringStateComplete);
      pc.onIceConnectionState!(RTCIceConnectionState.RTCIceConnectionStateChecking);
      pc.onConnectionState!(RTCPeerConnectionState.RTCPeerConnectionStateConnecting);
      d = await link.diagnostics();
      expect([d.connectionState, d.iceConnectionState, d.iceGatheringState], ['connecting', 'checking', 'complete']);
      expect(d.localCandidates, {'host(mDNS)': 1, 'srflx': 1});
      expect(d.remoteCandidates, {'host': 1});
      expect(sentIce, hasLength(2), reason: '数えても、相手へはそのまま送る');
      expect(pc.added.single.candidate, contains('100.96.57.10'));

      await m.media.openMic();
      m.media.setMicEnabled(true); // 立てたときだけ送る側に差さる (D-330)
      await Future<void>.delayed(Duration.zero);
      pc.onTrack!(RTCTrackEvent(track: _FakeTrack('audio', 'r1'), streams: const []));
      pc.onIceConnectionState!(RTCIceConnectionState.RTCIceConnectionStateConnected);
      pc.onConnectionState!(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
      pc.stats = [
        StatsReport('T', 'transport', 0, {'selectedCandidatePairId': 'CP'}),
        StatsReport('CP', 'candidate-pair', 0, {'state': 'succeeded', 'localCandidateId': 'L', 'remoteCandidateId': 'R'}),
        StatsReport('L', 'local-candidate', 0, {'candidateType': 'prflx', 'protocol': 'udp', 'address': '100.88.46.2', 'port': 5000}),
        StatsReport('R', 'remote-candidate', 0, {'candidateType': 'host', 'protocol': 'udp', 'address': '100.96.57.10', 'port': 61274}),
        StatsReport('IN', 'inbound-rtp', 0, {'kind': 'audio', 'bytesReceived': 4200, 'packetsReceived': 30, 'packetsLost': 0, 'audioLevel': 0.1}),
      ];
      d = await link.diagnostics();
      expect([d.connectionState, d.iceConnectionState, d.remoteAudio, d.playout, d.micAttached], ['connected', 'connected', true, 'playing', true]);
      expect(d.stats.remoteCandidate, 'host udp 100.96.57.10:61274');
      expect(d.lines(), [
        '接続 connected / ICE connected(収集 complete)/ SDP stable',
        '候補: 自分 host(mDNS)×1 srflx×1 / 相手 host×1',
        '選ばれた組: succeeded(自分 prflx udp 100.88.46.2:5000 ⇄ 相手 host udp 100.96.57.10:61274)',
        '音声: 送 - B / 受 4200 B(30 パケット、欠 0)/ 声の大きさ 0.100',
        '相手の声: 受けた / <audio> playing / マイク: 差し込み済み',
      ]);
      link.setPlayback(false);
      expect((await link.diagnostics()).playout, 'muted');
      await link.close();
      d = await link.diagnostics();
      expect([d.connectionState, d.playout], ['closed', null], reason: '<audio> は外した');
    });
  });
}

void _ignore(Map<String, Object?> _) {}
void _ignoreState(AstellLinkState _) {}

class _FakeOut implements AstellRemoteAudio {
  _FakeOut(this.track, this.muted);
  final MediaStreamTrack track;
  bool muted;
  bool disposed = false;
  @override
  void setMuted(bool muted) => this.muted = muted;
  @override
  String get state => disposed ? 'closed' : (muted ? 'muted' : 'playing');
  @override
  Future<void> dispose() async => disposed = true;
}

class _FakeTrack extends Fake implements MediaStreamTrack {
  _FakeTrack(this.kind, this.id);
  @override
  final String? kind;
  @override
  final String? id;
  @override
  bool enabled = true;
  bool stopped = false;
  @override
  Future<void> stop() async => stopped = true;
}

class _FakeAudio implements AstellAudioPlatform {
  final log = <String>[];
  final owners = <Object>[];
  bool micGranted = true;
  @override
  Future<void> start(Object owner) async {
    owners.add(owner);
    log.add('start');
  }

  @override
  Future<void> stop(Object owner) async => log.add('stop');
  @override
  Future<bool> requestMic() async {
    log.add('requestMic');
    return micGranted;
  }

  @override
  Future<void> keepAlive(Object owner, bool on) async => log.add('keepAlive:$on');
}

class _FakeStream extends Fake implements MediaStream {
  _FakeStream(this.tracks);
  final List<MediaStreamTrack> tracks;
  @override
  List<MediaStreamTrack> getAudioTracks() => [for (final t in tracks) if (t.kind == 'audio') t];
  @override
  List<MediaStreamTrack> getTracks() => tracks;
  @override
  Future<void> dispose() async {}
}

class _FakeSender extends Fake implements RTCRtpSender {
  final List<MediaStreamTrack?> replaced = [];

  /// 差し替え / 符号化の入れ切りの順(`replace:mic` / `active:false` …)。
  final List<String> ops = [];

  /// 送る側の符号化(libwebrtc の既定は入っている)。
  bool active = true;

  /// 差し替えを待たせる。
  Completer<void>? gate;
  @override
  MediaStreamTrack? get track => replaced.lastOrNull;
  @override
  Future<void> replaceTrack(MediaStreamTrack? track) async {
    final g = gate;
    if (g != null) await g.future;
    replaced.add(track);
    ops.add('replace:${track?.id}');
  }

  @override
  RTCRtpParameters get parameters => RTCRtpParameters(encodings: [RTCRtpEncoding(active: active, numTemporalLayers: null, scaleResolutionDownBy: null)]);

  @override
  Future<bool> setParameters(RTCRtpParameters parameters) async {
    active = parameters.encodings!.single.active;
    ops.add('active:$active');
    return true;
  }
}

class _FakeReceiver extends Fake implements RTCRtpReceiver {
  _FakeReceiver(this.track);
  @override
  final MediaStreamTrack? track;
}

class _FakeTransceiver extends Fake implements RTCRtpTransceiver {
  _FakeTransceiver(this.direction, {MediaStreamTrack? received}) : receiver = _FakeReceiver(received);
  TransceiverDirection direction;
  @override
  final _FakeSender sender = _FakeSender();
  @override
  final RTCRtpReceiver receiver;
  @override
  Future<void> setDirection(TransceiverDirection direction) async => this.direction = direction;
}

class _FakePc extends Fake implements RTCPeerConnection {
  final List<_FakeTransceiver> made = [];
  bool closed = false;

  @override
  Function(RTCSignalingState state)? onSignalingState;
  @override
  Function(RTCPeerConnectionState state)? onConnectionState;
  @override
  Function(RTCIceCandidate candidate)? onIceCandidate;
  @override
  Function(RTCTrackEvent event)? onTrack;
  @override
  Function(RTCIceConnectionState state)? onIceConnectionState;
  @override
  Function(RTCIceGatheringState state)? onIceGatheringState;

  final List<RTCIceCandidate> added = [];
  List<StatsReport> stats = const [];

  @override
  Future<void> addCandidate(RTCIceCandidate candidate) async => added.add(candidate);

  @override
  Future<List<StatsReport>> getStats([MediaStreamTrack? track]) async => stats;

  @override
  Future<RTCRtpTransceiver> addTransceiver({MediaStreamTrack? track, RTCRtpMediaType? kind, RTCRtpTransceiverInit? init}) async {
    final t = _FakeTransceiver(init?.direction ?? TransceiverDirection.SendRecv);
    made.add(t);
    return t;
  }

  @override
  Future<List<RTCRtpTransceiver>> getTransceivers() async => [...made];

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    // ブラウザと同じく、相手の offer の音声の 1 本は recvonly で作られる。
    if (description.type == 'offer' && made.isEmpty) made.add(_FakeTransceiver(TransceiverDirection.RecvOnly, received: _FakeTrack('audio', 'remote')));
  }

  @override
  Future<RTCSessionDescription> createOffer([Map<String, dynamic>? constraints]) async => RTCSessionDescription('offer-sdp', 'offer');

  @override
  Future<RTCSessionDescription> createAnswer([Map<String, dynamic>? constraints]) async => RTCSessionDescription('answer-sdp', 'answer');

  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {}

  @override
  Future<void> close() async => closed = true;

  @override
  Future<void> dispose() async {}
}
