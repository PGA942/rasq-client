import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/features/vc/astell_call.dart';
import 'package:rasq_client/features/vc/astell_client.dart';
import 'package:rasq_client/features/vc/astell_media.dart';
import 'package:rasq_client/features/vc/astell_models.dart';
import 'package:rasq_client/features/vc/astell_providers.dart';
import 'package:rasq_client/features/vc/astell_stream.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';

/// D-317: AsTell の通話(P2P の音声メッシュ)の手順と、配信(LiveKit)の出し入れ。
/// WebRTC / LiveKit の実物は使わず、偽の口で「誰が offer を出すか / answer / ICE の控え / 退出の片付け /
/// ミュート」を確かめる。
void main() {
  group('通話の手順 (AstellCallMesh)', () {
    late FakeMedia media;
    late List<Map<String, Object?>> sent;
    var changed = 0;

    AstellCallMesh mesh({int cap = astellMeshCap}) {
      media = FakeMedia();
      sent = [];
      changed = 0;
      return AstellCallMesh(
        media: media,
        send: sent.add,
        iceServers: () async => const [
          {'urls': 'stun:stun.test:3478'},
        ],
        onChanged: () => changed++,
        levelInterval: null,
        cap: cap,
      );
    }

    List<Map<String, Object?>> sentOf(String type) => [for (final m in sent) if (m['type'] == type) m];

    test('後から入った側が welcome の全員へ offer を出す({sdp, type})。ICE サーバーは 1 度だけ読む', () async {
      final m = mesh();
      await m.start('m', ['a', 'b', 'm']);
      expect([for (final o in sentOf('offer')) o['to']], ['a', 'b'], reason: '自分自身には出さない');
      expect(sentOf('offer').first['payload'], {'sdp': 'offer-from-a', 'type': 'offer'});
      expect(media.links.keys, ['a', 'b']);
      expect(media.links['a']!.offerer, isTrue);
      expect(media.links['a']!.iceServers, [
        {'urls': 'stun:stun.test:3478'},
      ]);
      // 自分の ICE の候補は、その相手へ `ice` で。
      media.links['a']!.emitIce({'candidate': 'candidate:1', 'sdpMid': '0', 'sdpMLineIndex': 0});
      expect(sentOf('ice').single, {
        'type': 'ice',
        'to': 'a',
        'payload': {'candidate': 'candidate:1', 'sdpMid': '0', 'sdpMLineIndex': 0},
      });
      await m.close();
    });

    test('いた側は peer-joined では何もせず、offer に answer で応える', () async {
      final m = mesh();
      await m.start('m', const []);
      expect(sent, isEmpty);
      await m.handle({'type': 'offer', 'from': 'z', 'payload': {'sdp': 'o', 'type': 'offer'}});
      final link = media.links['z']!;
      expect(link.offerer, isFalse);
      expect(link.remote, [
        {'sdp': 'o', 'type': 'offer'},
      ]);
      expect(sentOf('answer').single, {
        'type': 'answer',
        'to': 'z',
        'payload': {'sdp': 'answer-from-z', 'type': 'answer'},
      });
      await m.close();
    });

    test('相手の記述より先に届いた ICE は控えて、answer を入れたあとに入れる', () async {
      final m = mesh();
      await m.start('m', ['a']);
      await m.handle({'type': 'ice', 'from': 'a', 'payload': {'candidate': 'c1', 'sdpMid': '0', 'sdpMLineIndex': 0}});
      await m.handle({'type': 'ice', 'from': 'a', 'payload': {'candidate': 'c2', 'sdpMid': '0', 'sdpMLineIndex': 0}});
      final link = media.links['a']!;
      expect(link.ice, isEmpty, reason: 'まだ answer が無い');
      await m.handle({'type': 'answer', 'from': 'a', 'payload': {'sdp': 'ans', 'type': 'answer'}});
      expect(link.remote.single['type'], 'answer');
      expect([for (final c in link.ice) c['candidate']], ['c1', 'c2']);
      await m.handle({'type': 'ice', 'from': 'a', 'payload': {'candidate': 'c3', 'sdpMid': '0', 'sdpMLineIndex': 0}});
      expect(link.ice.length, 3, reason: '記述のあとはすぐ入れる');
      // 接続の無い相手の answer / ice は捨てる。
      await m.handle({'type': 'answer', 'from': 'x', 'payload': {'sdp': 's', 'type': 'answer'}});
      await m.handle({'type': 'ice', 'from': 'x', 'payload': {'candidate': 'c'}});
      expect(media.links.keys, ['a']);
      await m.close();
    });

    test('peer-left でその相手の接続を閉じる / close で全部閉じ、以後は何もしない', () async {
      final m = mesh();
      await m.start('m', ['a', 'b']);
      await m.peerLeft('a');
      expect(media.links['a']!.closed, isTrue);
      expect(m.peerIds, {'b'});
      await m.close();
      expect(media.links['b']!.closed, isTrue);
      await m.handle({'type': 'offer', 'from': 'c', 'payload': {'sdp': 'o', 'type': 'offer'}});
      expect(media.links.containsKey('c'), isFalse);
    });

    test('offer がぶつかったら: peerId の大きい側は取り下げて受け、小さい側は相手の offer を捨てる', () async {
      // 自分 'm' > 相手 'a' → 自分が譲る側。
      var m = mesh();
      await m.start('m', ['a']);
      await m.handle({'type': 'offer', 'from': 'a', 'payload': {'sdp': 'glare', 'type': 'offer'}});
      var link = media.links['a']!;
      expect(link.rollbacks, 1);
      expect(link.remote.single['sdp'], 'glare');
      expect(sentOf('answer').single['to'], 'a');
      await m.close();

      // 自分 'a' < 相手 'm' → 相手の offer を捨てる(相手が譲って、こちらの offer に answer を返す)。
      m = mesh();
      await m.start('a', ['m']);
      await m.handle({'type': 'offer', 'from': 'm', 'payload': {'sdp': 'glare', 'type': 'offer'}});
      link = media.links['m']!;
      expect(link.rollbacks, 0);
      expect(link.remote, isEmpty);
      expect(sentOf('answer'), isEmpty);
      // 捨てた offer の ICE は入らなくてよい(エラーにしない)。
      link.failIce = true;
      await m.handle({'type': 'answer', 'from': 'm', 'payload': {'sdp': 'ans', 'type': 'answer'}});
      await m.handle({'type': 'ice', 'from': 'm', 'payload': {'candidate': 'x'}});
      expect(link.remote.single['type'], 'answer');
      await m.close();
    });

    test('切れたら(failed)offer を出した側が ICE をやり直す offer を出す', () async {
      final m = mesh();
      await m.start('m', ['a']);
      await m.handle({'type': 'answer', 'from': 'a', 'payload': {'sdp': 'ans', 'type': 'answer'}});
      media.links['a']!.emitState(AstellLinkState.connected);
      expect(m.connectedTo('a'), isTrue);
      media.links['a']!.emitState(AstellLinkState.failed);
      await m.handle(const {}); // 列が捌けるのを待つ
      expect(sentOf('offer').length, 2);
      expect(media.links['a']!.iceRestarts, 1);
      await m.close();
    });

    test('満員: welcome の人数 + 自分が上限を超えたら offer を出さない。上限に達したら新しい offer も受けない', () async {
      var m = mesh(cap: 3);
      await m.start('m', ['a', 'b', 'c']);
      expect(m.full, isTrue);
      expect(sent, isEmpty);
      expect(changed, 1);
      await m.handle({'type': 'offer', 'from': 'a', 'payload': {'sdp': 'o', 'type': 'offer'}});
      expect(media.links, isEmpty);
      await m.close();

      m = mesh(cap: 3);
      await m.start('m', ['a']);
      await m.handle({'type': 'offer', 'from': 'b', 'payload': {'sdp': 'o', 'type': 'offer'}});
      await m.handle({'type': 'offer', 'from': 'c', 'payload': {'sdp': 'o', 'type': 'offer'}});
      expect(media.links.keys, ['a', 'b'], reason: '自分 + 2 人で 3 人');
      await m.close();
    });

    test('鳴らす声: スピーカーミュートで全員、手元のミュートでその人だけ止める(あとから繋いだ人にも)', () async {
      final m = mesh();
      await m.start('m', ['a', 'b']);
      expect(media.links['a']!.playback, isTrue);
      m.setPlayback(speakerMuted: false, mutedPeerIds: {'a'});
      expect([media.links['a']!.playback, media.links['b']!.playback], [false, true]);
      m.setPlayback(speakerMuted: true, mutedPeerIds: const {});
      expect([media.links['a']!.playback, media.links['b']!.playback], [false, false]);
      await m.handle({'type': 'offer', 'from': 'c', 'payload': {'sdp': 'o', 'type': 'offer'}});
      expect(media.links['c']!.playback, isFalse);
      await m.close();
    });

    test('話している印: 受けている声の大きさが閾値を超えた人', () async {
      final m = mesh();
      await m.start('m', ['a', 'b']);
      media.links['a']!.level = 0.2;
      media.links['b']!.level = 0.001;
      final before = changed;
      await m.pollLevels();
      expect(m.speaking, {'a'});
      expect(changed, before + 1);
      await m.pollLevels();
      expect(changed, before + 1, reason: '変わらなければ知らせない');
      await m.peerLeft('a');
      expect(m.speaking, isEmpty);
      await m.close();
    });
  });

  group('マイク / Web の安全な場所', () {
    test('Web 版を http(localhost 以外)で開いていたら、マイクは使えない', () {
      expect(astellInsecureWebContext(web: true, page: Uri.parse('http://100.91.218.56:8080/')), isTrue);
      expect(astellInsecureWebContext(web: true, page: Uri.parse('https://rasq.test/')), isFalse);
      expect(astellInsecureWebContext(web: true, page: Uri.parse('http://localhost:8080/')), isFalse);
      expect(astellInsecureWebContext(web: true, page: Uri.parse('http://127.0.0.1:5000/')), isFalse);
      expect(astellInsecureWebContext(web: false, page: Uri.parse('http://100.91.218.56:8080/')), isFalse);
      expect(const AstellMediaException(AstellMediaIssue.insecureContext).message, 'Web 版の通話は https で開いたときだけ使えます');
    });

    test('プラットフォームの例外の言い換え', () {
      expect(AstellMediaException.from(Exception('NotAllowedError: Permission denied')).issue, AstellMediaIssue.permissionDenied);
      expect(AstellMediaException.from(Exception('NotFoundError: Requested device not found')).issue, AstellMediaIssue.noDevice);
      expect(AstellMediaException.from(Exception('boom')).issue, AstellMediaIssue.unsupported);
    });
  });

  group('セッション (AstellSession) — 通話', () {
    late MockAstellClient client;
    late FakeMedia media;
    late FakeStreamer streamer;
    late ProviderContainer container;

    Future<AstellSession> join(AstellRoom room) async {
      final session = container.read(astellSessionProvider.notifier);
      await session.join(room);
      await Future<void>.delayed(Duration.zero);
      await session.mesh?.handle(const {});
      return session;
    }

    setUp(() {
      client = MockAstellClient();
      media = FakeMedia();
      streamer = FakeStreamer();
      container = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
        astellClientProvider.overrideWithValue(client),
        astellMediaFactoryProvider.overrideWithValue(() => media),
        astellStreamerFactoryProvider.overrideWithValue(() => streamer),
        astellLevelIntervalProvider.overrideWithValue(null),
      ]);
    });
    tearDown(() => container.dispose());

    List<Map<String, Object?>> sentOf(String type) => [for (final m in client.sent) if (m['type'] == type) m];

    test('welcome → 先にいた全員へ offer、answer / ice / peer-left を手順へ渡す', () async {
      final session = await join(MockAstellClient.seededRooms().first);
      expect([for (final o in sentOf('offer')) o['to']], ['p1', 'p2', 'p3', 'p4', 'p5']);
      client.emit('r-launch', {'type': 'answer', 'from': 'p1', 'payload': {'sdp': 'a1', 'type': 'answer'}});
      client.emit('r-launch', {'type': 'ice', 'from': 'p1', 'payload': {'candidate': 'c1', 'sdpMid': '0', 'sdpMLineIndex': 0}});
      await Future<void>.delayed(Duration.zero);
      await session.mesh!.handle(const {});
      expect(media.links['p1']!.remote.single['sdp'], 'a1');
      expect(media.links['p1']!.ice.single['candidate'], 'c1');
      client.emit('r-launch', {'type': 'peer-left', 'peerId': 'p3'});
      await Future<void>.delayed(Duration.zero);
      await session.mesh!.handle(const {});
      expect(media.links['p3']!.closed, isTrue);
      expect(container.read(astellSessionProvider)!.peers.any((p) => p.peerId == 'p3'), isFalse);
      // 話している印は参加者の speaking に。
      media.links['p2']!.level = 0.3;
      await session.mesh!.pollLevels();
      expect([for (final p in container.read(astellSessionProvider)!.peers) if (p.speaking) p.peerId], ['p2']);
      await session.leave();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(media.disposed, isTrue);
      expect(media.links['p1']!.closed, isTrue);
    });

    test('マイク: 立てたときに開いて送る / 許可が無ければ理由を出して立てない / 強制ミュートで止める', () async {
      final session = await join(MockAstellClient.seededRooms().first);
      await session.toggleMic();
      var s = container.read(astellSessionProvider)!;
      expect(s.micOn, isTrue);
      expect([media.opened, media.micEnabled], [1, true]);
      expect((sentOf('state').last['state'] as Map)['micOn'], isTrue);
      await session.toggleMic();
      expect([container.read(astellSessionProvider)!.micOn, media.micEnabled], [false, false]);
      expect(media.opened, 1, reason: '閉じない(次に立てるときはすぐ)');

      // 強制ミュート (D-149) → 声を止める。
      await session.toggleMic();
      client.emit('r-launch', {'type': 'peer-state', 'peer': {'peerId': 'me', 'accountId': 'me', 'handle': 'me', 'displayName': 'あなた', 'state': {'micOn': false, 'mutedByMod': true}}});
      await Future<void>.delayed(Duration.zero);
      s = container.read(astellSessionProvider)!;
      expect([s.forceMuted, s.micOn, media.micEnabled], [true, false, false]);
      await session.toggleMic();
      expect(container.read(astellSessionProvider)!.micOn, isFalse, reason: '強制ミュート中は立たない');
      await session.leave();
    });

    test('マイクの許可が無い / Web の http: 画面に理由を出す', () async {
      media.openError = const AstellMediaException(AstellMediaIssue.permissionDenied);
      final session = await join(MockAstellClient.seededRooms().first);
      await session.toggleMic();
      var s = container.read(astellSessionProvider)!;
      expect(s.micOn, isFalse);
      expect(s.error, contains('マイク(カメラ)を使う許可がありません'));
      media.openError = null;
      media.blocked = AstellMediaIssue.insecureContext;
      await session.toggleMic();
      s = container.read(astellSessionProvider)!;
      expect(s.micOn, isFalse);
      expect(s.error, 'Web 版の通話は https で開いたときだけ使えます');
      await session.leave();
    });

    test('スピーカーミュート / 手元のミュートで、通話の声を止める', () async {
      final session = await join(MockAstellClient.seededRooms().first);
      session.toggleMute('p2');
      expect([media.links['p1']!.playback, media.links['p2']!.playback], [true, false]);
      session.toggleSpeaker();
      expect(media.links.values.every((l) => !l.playback), isTrue);
      session.toggleSpeaker();
      expect([media.links['p1']!.playback, media.links['p2']!.playback], [true, false]);
      await session.leave();
    });

    test('満員(welcome に $astellMeshCap 人以上)なら通話に入らず、案内を出す', () async {
      final session = await join(MockAstellClient.seededRooms().first);
      client.sent.clear();
      client.emit('r-launch', {
        'type': 'welcome',
        'peerId': 'me',
        'accountId': 'me',
        'peers': [
          for (var i = 0; i < astellMeshCap; i++) {'peerId': 'q$i', 'accountId': 'a$i', 'handle': 'h$i', 'displayName': 'P$i', 'state': const {}},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      await session.mesh!.handle(const {});
      final s = container.read(astellSessionProvider)!;
      expect(s.callFull, isTrue);
      expect(s.notice, astellCallFullNotice);
      expect(sentOf('offer'), isEmpty);
      await session.leave();
    });
  });

  group('セッション (AstellSession) — 配信', () {
    late MockAstellClient client;
    late FakeStreamer streamer;
    late ProviderContainer container;

    setUp(() {
      client = MockAstellClient();
      streamer = FakeStreamer();
      container = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
        astellClientProvider.overrideWithValue(client),
        astellMediaFactoryProvider.overrideWithValue(() => FakeMedia()),
        astellStreamerFactoryProvider.overrideWithValue(() => streamer),
        astellLevelIntervalProvider.overrideWithValue(null),
      ]);
    });
    tearDown(() => container.dispose());

    Future<AstellSession> join(AstellRoom room) async {
      final session = container.read(astellSessionProvider.notifier);
      await session.join(room);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      return session;
    }

    test('ホストが配信中のルームに入ると、見るだけのトークンで LiveKit に繋ぐ。通話で繋がっている人の声は LiveKit では鳴らさない', () async {
      final session = await join(MockAstellClient.seededRooms().firstWhere((r) => r.id == 'r-sublrony'));
      expect(client.streamTokens.single, (roomId: 'r-sublrony', publish: false));
      expect(streamer.connectedWith?.canPublish, isFalse);
      expect(container.read(astellSessionProvider)!.streamConnected, isTrue);
      final policy = streamer.policy!;
      expect(policy('douglas'), isFalse, reason: 'ダグラス(p1)とは通話で繋がっている — 声は通話で聞こえる');
      expect(policy('sublrony'), isTrue, reason: '通話に居ないホストの声は配信で');
      session.toggleSpeaker();
      expect(streamer.policy!('sublrony'), isFalse, reason: 'スピーカーミュート');
      await session.leave();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(streamer.connected, isFalse);
    });

    test('ほかの人の画面共有があるルームでも繋ぐ(r-launch の TiVard)', () async {
      final session = await join(MockAstellClient.seededRooms().first);
      expect(client.streamTokens.single.publish, isFalse);
      await session.leave();
    });

    test('ホストの配信: 上げるトークンで繋いでカメラ + マイクを上げ、hostStream を立てる → 止めると下ろして消す', () async {
      final room = await client.createRoom(const NewAstellRoom(title: '自分の配信'));
      final session = await join(room);
      expect(client.streamTokens, isEmpty, reason: '見るものが無ければ繋がない');
      await session.toggleMic();
      await session.startHostStream('camera');
      var s = container.read(astellSessionProvider)!;
      expect(client.streamTokens.single, (roomId: room.id, publish: true));
      expect(streamer.published, [('camera', true)]);
      expect(s.streaming, 'camera');
      expect(s.room.hostStream?.kind, 'video');
      expect(s.room.hostStream?.title, '自分の配信');
      await session.toggleMic();
      expect(streamer.mic, isFalse, reason: 'マイクを切れば配信の声も切る');
      await session.stopHostStream();
      s = container.read(astellSessionProvider)!;
      expect([s.streaming, s.room.hostStream], [null, null]);
      expect(streamer.publishing, isNull);
      expect(streamer.connected, isFalse, reason: '見るものも上げるものも無ければ切る');
      await session.leave();
    });

    test('画面共有: 画面を上げてから state.screenShare を立てる / やめると下ろす。上げられなければ立てない', () async {
      final session = await join(MockAstellClient.seededRooms().firstWhere((r) => r.id == 'r-surprise'));
      await session.toggleScreenShare(screenSourceId: 'screen:0');
      var s = container.read(astellSessionProvider)!;
      expect([s.screenShareOn, s.streaming], [true, 'screen']);
      expect(streamer.published.single, ('screen', false));
      expect(streamer.sourceId, 'screen:0');
      expect((client.sent.where((m) => m['type'] == 'state').last['state'] as Map)['screenShare'], isNotNull);
      await session.toggleScreenShare();
      s = container.read(astellSessionProvider)!;
      expect([s.screenShareOn, s.streaming], [false, null]);
      expect((client.sent.where((m) => m['type'] == 'state').last['state'] as Map)['screenShare'], isNull);

      streamer.publishError = const AstellMediaException(AstellMediaIssue.permissionDenied);
      await session.toggleScreenShare();
      s = container.read(astellSessionProvider)!;
      expect(s.screenShareOn, isFalse);
      expect(s.error, contains('画面共有を始められません'));
      await session.leave();
    });

    test('Central が配信を用意していない (501) / 断った (403) ときの言い換え', () {
      expect(astellStreamErrorText(OrgateException(ErrorCode.tryParse('501')!, 'streaming is not configured')), '配信サーバー(LiveKit)が設定されていません');
      expect(astellStreamErrorText(OrgateException(ErrorCode.tryParse('403')!, 'streaming is limited to moderators in this room')), contains('許可されていません'));
      expect(astellStreamErrorText(const AstellMediaException(AstellMediaIssue.insecureContext)), 'Web 版の通話は https で開いたときだけ使えます');
    });
  });
}

// ── 偽の口 ─────────────────────────────────────────────────────────

class FakeMedia implements AstellMedia {
  final links = <String, FakeLink>{};
  int opened = 0;
  bool micEnabled = false;
  bool disposed = false;
  AstellMediaIssue? blocked;
  AstellMediaException? openError;

  @override
  bool get available => true;
  @override
  AstellMediaIssue? get micBlocked => blocked;
  @override
  bool get micOpen => opened > 0;

  @override
  Future<void> openMic() async {
    if (openError != null) throw openError!;
    opened++;
  }

  @override
  void setMicEnabled(bool enabled) => micEnabled = enabled;

  @override
  Future<AstellPeerLink> createLink(String peerId, {required bool offerer, required List<Map<String, Object?>> iceServers, required AstellLinkHandlers handlers}) async =>
      links[peerId] = FakeLink(peerId, offerer: offerer, iceServers: iceServers, handlers: handlers);

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeLink implements AstellPeerLink {
  FakeLink(this.peerId, {required this.offerer, required this.iceServers, required this.handlers});
  @override
  final String peerId;
  final bool offerer;
  final List<Map<String, Object?>> iceServers;
  final AstellLinkHandlers handlers;
  final remote = <Map<String, Object?>>[];
  final ice = <Map<String, Object?>>[];
  var state = 'stable';
  var rollbacks = 0;
  var iceRestarts = 0;
  var playback = true;
  var closed = false;
  var failIce = false;
  double level = 0;

  void emitIce(Map<String, Object?> c) => handlers.onIceCandidate(c);
  void emitState(AstellLinkState s) => handlers.onState(s);

  @override
  String get signalingState => state;
  @override
  bool get hasRemoteDescription => remote.isNotEmpty;

  @override
  Future<Map<String, Object?>> createOffer({bool iceRestart = false}) async {
    if (iceRestart) iceRestarts++;
    state = 'have-local-offer';
    return {'sdp': 'offer-from-$peerId', 'type': 'offer'};
  }

  @override
  Future<Map<String, Object?>> createAnswer() async {
    state = 'stable';
    return {'sdp': 'answer-from-$peerId', 'type': 'answer'};
  }

  @override
  Future<void> setRemoteDescription(Map<String, Object?> description) async {
    remote.add(description);
    state = description['type'] == 'offer' ? 'have-remote-offer' : 'stable';
  }

  @override
  Future<void> rollback() async {
    rollbacks++;
    state = 'stable';
  }

  @override
  Future<void> addIceCandidate(Map<String, Object?> candidate) async {
    if (failIce) throw StateError('no matching m-line');
    ice.add(candidate);
  }

  @override
  void setPlayback(bool on) => playback = on;

  @override
  Future<double> remoteAudioLevel() async => level;

  @override
  Future<void> close() async => closed = true;
}

class FakeStreamer extends AstellStreamer {
  AstellStreamToken? connectedWith;
  bool _connected = false;
  String? _publishing;
  final published = <(String, bool)>[];
  String? sourceId;
  bool? mic;
  bool Function(String identity)? policy;
  AstellMediaException? publishError;

  @override
  bool get connected => _connected;
  @override
  bool get canPublish => connectedWith?.canPublish ?? false;
  @override
  String? get publishing => _publishing;

  @override
  Future<void> connect(AstellStreamToken token) async {
    connectedWith = token;
    _connected = true;
  }

  @override
  Future<void> publish(String kind, {required bool mic, String? screenSourceId}) async {
    if (publishError != null) throw publishError!;
    published.add((kind, mic));
    this.mic = mic;
    sourceId = screenSourceId;
    _publishing = kind;
  }

  @override
  Future<void> setMic(bool on) async {
    if (_publishing != null) mic = on;
  }

  @override
  Future<void> unpublish() async => _publishing = null;

  @override
  bool hasVideo(String identity, {bool screen = false}) => false;

  @override
  Widget? video(String identity, {bool screen = false, BoxFit fit = BoxFit.contain}) => null;

  @override
  void setAudioPolicy(bool Function(String identity) play) => policy = play;

  @override
  Future<void> disconnect() async {
    _connected = false;
    _publishing = null;
  }
}
