import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
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

  ({WebRtcAstellMedia media, List<_FakePc> pcs, List<_FakeOut> outs, List<Map<String, dynamic>> asked}) make({bool web = true, _FakeTrack? mic}) {
    final pcs = <_FakePc>[];
    final outs = <_FakeOut>[];
    final asked = <Map<String, dynamic>>[];
    final media = WebRtcAstellMedia(
      web: web,
      peerConnection: (config) async {
        final pc = _FakePc();
        pcs.add(pc);
        return pc;
      },
      userMedia: (constraints) async {
        asked.add(constraints);
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
    test('開いたマイクは、offer を出す側の送受信の 1 本に差し込む(はじめは送らない)', () async {
      final mic = _FakeTrack('audio', 'mic');
      final m = make(mic: mic);
      await m.media.openMic();
      expect(m.asked.single['audio'], isA<Map<String, dynamic>>());
      expect(mic.enabled, isFalse); // 立てるまでは送らない
      await m.media.createLink('p2', offerer: true, iceServers: ice, handlers: handlers);
      final t = m.pcs.single.made.single;
      expect(t.direction, TransceiverDirection.SendRecv);
      expect(t.sender.replaced, [mic]);
      m.media.setMicEnabled(true);
      expect(mic.enabled, isTrue);
    });

    test('受ける側: 相手の offer でできた 1 本を sendrecv にしてマイクを差し込む / あとから開いたマイクも差し込む', () async {
      final mic = _FakeTrack('audio', 'mic');
      final m = make(mic: mic);
      final link = await m.media.createLink('p2', offerer: false, iceServers: ice, handlers: handlers);
      await link.setRemoteDescription({'sdp': 'offer-sdp', 'type': 'offer'});
      final t = m.pcs.single.made.single;
      expect(t.direction, TransceiverDirection.SendRecv); // ブラウザは recvonly で作る
      expect(t.sender.replaced, isEmpty); // マイクはまだ開いていない
      await m.media.openMic();
      expect(t.sender.replaced, [mic]);
    });

    test('Web を http(localhost 以外)で開いていれば開かない。https(安全なコンテキスト)なら開ける', () async {
      expect(astellInsecureWebContext(web: true, secureContext: true), isFalse);
      expect(astellInsecureWebContext(web: true, secureContext: false), isTrue);
      final native = make(web: false);
      expect(native.media.micBlocked, isNull);
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
  @override
  Future<void> stop() async {}
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
  @override
  MediaStreamTrack? get track => replaced.lastOrNull;
  @override
  Future<void> replaceTrack(MediaStreamTrack? track) async => replaced.add(track);
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
