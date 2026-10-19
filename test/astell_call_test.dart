import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
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
import 'package:rasq_client/features/vc/astell_stream_livekit.dart' show astellScreenCaptureInApp;
import 'package:rasq_client/features/vc/astell_web_audio.dart' show astellAudioAwaitingGesture;
import 'package:rasq_client/features/vc/hold_music.dart';
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

    test('話している印の立て下ろし (D-467): 閾値を超えたらすぐ立て、続けて 2 回静かだったら下ろす', () {
      final g = AstellSpeakingGate();
      expect([for (final l in [0.0, 0.019, 0.02, 0.001, 0.3, 0.0, 0.0, 0.0]) g.update(l)], [false, false, true, true, true, true, false, false]);
      g.update(0.5);
      g.reset();
      expect(g.speaking, isFalse);
      expect(AstellSpeakingGate(release: 1).update(0.5), isTrue);
      expect(astellLevelInterval, const Duration(milliseconds: 300));
    });

    test('自分の話している印 (D-467): 送っているマイクの大きさ。静かになって 2 回で消える / 統計が取れない接続は黙っている扱い / 接続が無くなれば消える', () async {
      final m = mesh();
      await m.start('m', ['a', 'b']);
      media.links['a']!.localLevel = 0.25;
      await m.pollLevels();
      expect([m.selfSpeaking, m.speaking], [true, isEmpty]);
      final before = changed;
      // 相手の声の印は、言葉の切れ目(1 回だけ静か)では消えない。
      media.links['a']!
        ..localLevel = 0
        ..level = 0.4;
      await m.pollLevels();
      expect([m.selfSpeaking, m.speaking], [true, {'a'}]);
      media.links['a']!.level = 0;
      await m.pollLevels();
      expect([m.selfSpeaking, m.speaking], [false, {'a'}]);
      await m.pollLevels();
      expect([m.selfSpeaking, m.speaking], [false, isEmpty]);
      expect(changed, before + 3);
      // 1 本の getStats が失敗しても、ほかの接続の印は出る。
      media.links['a']!.levelError = Exception('closed');
      media.links['b']!.level = 0.5;
      await m.pollLevels();
      expect(m.speaking, {'b'});
      media.links['b']!.localLevel = 0.5;
      await m.pollLevels();
      expect(m.selfSpeaking, isTrue);
      await m.peerLeft('a');
      expect(m.selfSpeaking, isTrue);
      await m.peerLeft('b');
      expect([m.selfSpeaking, m.speaking], [false, isEmpty], reason: 'ひとりになったら測れない(印は残さない)');
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

    test('話している印 (D-467): 自分も参加メンバーに入り、マイクを立てて話している間だけ印が立つ / peer-state で相手の印が消えない', () async {
      final session = await join(MockAstellClient.seededRooms().first);
      AstellSessionState now() => container.read(astellSessionProvider)!;
      // 自分(welcome の me)は peers に入らず、表示の members の先頭に。
      expect(now().peers.any((p) => p.peerId == 'me'), isFalse);
      expect([for (final p in now().members) p.peerId], ['me', 'p1', 'p2', 'p3', 'p4', 'p5']);
      expect(now().members.first.displayName, 'あなた');
      // マイクを下ろしている間は、測った値が残っていても印は立てない。
      media.links['p1']!.localLevel = 0.3;
      await session.mesh!.pollLevels();
      expect(now().selfSpeaking, isTrue);
      expect(now().members.first.speaking, isFalse);
      await session.toggleMic();
      await Future<void>.delayed(Duration.zero);
      expect([now().members.first.micOn, now().members.first.speaking], [true, true]);
      // 相手が話している間に peer-state(マイク / 画面共有の変化)が来ても、印は消えない。
      media.links['p1']!.level = 0.3;
      await session.mesh!.pollLevels();
      expect(now().peers.firstWhere((p) => p.peerId == 'p1').speaking, isTrue);
      client.emit('r-launch', {'type': 'peer-state', 'peer': {'peerId': 'p1', 'accountId': 'douglas', 'handle': 'douglas', 'displayName': 'ダグラス', 'state': {'micOn': true}}});
      await Future<void>.delayed(Duration.zero);
      expect(now().peers.firstWhere((p) => p.peerId == 'p1').speaking, isTrue);
      // 下ろしたら自分の印はすぐ消える(次の見直しを待たない)。
      await session.toggleMic();
      await Future<void>.delayed(Duration.zero);
      expect([now().members.first.micOn, now().members.first.speaking], [false, false]);
      await session.leave();
    });

    test('話している印 (D-467): 通話に入っていない人は配信(LiveKit)の話している人から。閉鎖で消える', () async {
      await join(MockAstellClient.seededRooms().first); // TiVard が画面共有中 → 配信に繋ぐ
      await Future<void>.delayed(Duration.zero);
      AstellSessionState now() => container.read(astellSessionProvider)!;
      expect(streamer.connected, isTrue);
      streamer.speak({'yamahaya'});
      expect([for (final p in now().peers) if (p.speaking) p.peerId], ['p3']);
      streamer.speak({'yamahaya'}, local: true);
      expect(now().selfSpeaking, isTrue);
      client.emit('r-launch', {'type': 'closed'});
      await Future<void>.delayed(Duration.zero);
      expect([now().selfSpeaking, now().peers.any((p) => p.speaking)], [false, false]);
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
      expect(s.error, contains('マイク(カメラ)の許可がありません'));
      media.openError = null;
      media.blocked = AstellMediaIssue.insecureContext;
      await session.toggleMic();
      s = container.read(astellSessionProvider)!;
      expect(s.micOn, isFalse);
      expect(s.error, 'Web 版の通話は https で開いたときだけ使えます');
      await session.leave();
    });

    group('マイクのボタンと実際の送り (D-455)', () {
      AstellSessionState now() => container.read(astellSessionProvider)!;

      test('開いている最中(OS の許可のダイアログ)にもう一度押すと、やめる — 開け終わっても立てない。getUserMedia は 1 回', () async {
        final session = await join(MockAstellClient.seededRooms().first);
        final gate = media.openGate = Completer<void>();
        final first = session.toggleMic();
        expect([now().micOn, now().micOpening], [false, true], reason: 'まだ送っていない — 「オン」とは出さない');
        final second = session.toggleMic(); // ダイアログの裏でもう一度
        gate.complete();
        await Future.wait([first, second]);
        expect([now().micOn, now().micOpening, media.micEnabled], [false, false, false]);
        expect(media.openCalls, 1);
        expect(sentOf('state').where((m) => (m['state'] as Map)['micOn'] == true), isEmpty, reason: '一度も立てていない');
        // 次に押せばすぐ立つ(開いたまま)。
        await session.toggleMic();
        expect([now().micOn, media.micEnabled, media.openCalls], [true, true, 1]);
        await session.leave();
      });

      test('開いている最中に 3 回押す(立てる → やめる → 立てる): 開け終わったら立てる', () async {
        final session = await join(MockAstellClient.seededRooms().first);
        final gate = media.openGate = Completer<void>();
        final runs = [session.toggleMic(), session.toggleMic(), session.toggleMic()];
        gate.complete();
        await Future.wait(runs);
        expect([now().micOn, now().micOpening, media.micEnabled, media.openCalls], [true, false, true, 1]);
        expect((sentOf('state').last['state'] as Map)['micOn'], isTrue);
        await session.leave();
      });

      test('開いている最中に強制ミュートされたら、開け終わっても立てない', () async {
        final session = await join(MockAstellClient.seededRooms().first);
        final gate = media.openGate = Completer<void>();
        final run = session.toggleMic();
        client.emit('r-launch', {'type': 'peer-state', 'peer': {'peerId': 'me', 'accountId': 'me', 'handle': 'me', 'displayName': 'あなた', 'state': {'micOn': false, 'mutedByMod': true}}});
        await Future<void>.delayed(Duration.zero);
        gate.complete();
        await run;
        expect([now().forceMuted, now().micOn, now().micOpening, media.micEnabled], [true, false, false, false]);
        await session.leave();
      });

      test('開いている最中に退出 → 別のルームでは、前のルームの揃えは何もしない', () async {
        final rooms = MockAstellClient.seededRooms();
        final session = await join(rooms.first);
        final gate = media.openGate = Completer<void>();
        final run = session.toggleMic();
        await session.leave();
        media = FakeMedia();
        await join(rooms[1]);
        gate.complete();
        await run;
        expect([now().micOn, now().micOpening, media.micEnabled], [false, false, false]);
        await session.toggleMic();
        expect(now().micOn, isTrue, reason: '新しいルームでは押せばふつうに立つ');
        await session.leave();
      });

      test('サーバーの自分の状態と突き合わせる: サーバーが下ろした(話せない)なら下ろす / 古い「立てている」は送り直す / サーバーの値で立てはしない', () async {
        final session = await join(MockAstellClient.seededRooms().first);
        await session.toggleMic();
        await Future<void>.delayed(Duration.zero); // 折り返しを受ける
        expect(now().micOn, isTrue);
        // サーバーから(役割が変わった等)「下ろしている」。
        client.emit('r-launch', {'type': 'peer-state', 'peer': {'peerId': 'me', 'accountId': 'me', 'handle': 'me', 'displayName': 'あなた', 'state': {'micOn': false}}});
        await Future<void>.delayed(Duration.zero);
        expect([now().micOn, media.micEnabled], [false, false]);
        await Future<void>.delayed(Duration.zero);
        // サーバーが古い「立てている」のまま: 立てずに、いまの向き(下ろしている)を送り直す。
        final before = sentOf('state').length;
        client.emit('r-launch', {'type': 'peer-state', 'peer': {'peerId': 'me', 'accountId': 'me', 'handle': 'me', 'displayName': 'あなた', 'state': {'micOn': true}}});
        await Future<void>.delayed(Duration.zero);
        expect([now().micOn, media.micEnabled], [false, false]);
        expect(sentOf('state').length, before + 1);
        expect((sentOf('state').last['state'] as Map)['micOn'], isFalse);
        await session.leave();
      });

      test('welcome: 入る前に立てたマイクは繋がったら全員へ送る / 強制ミュートのまま入り直したら立てられない', () async {
        final session = container.read(astellSessionProvider.notifier);
        final joining = session.join(MockAstellClient.seededRooms().first);
        await joining;
        await Future<void>.delayed(Duration.zero);
        client.emit('r-launch', {
          'type': 'welcome',
          'peerId': 'me',
          'accountId': 'me',
          'me': {'peerId': 'me', 'accountId': 'me', 'state': {'micOn': false, 'mutedByMod': true}},
          'peers': const [],
        });
        await Future<void>.delayed(Duration.zero);
        expect(now().forceMuted, isTrue);
        await session.toggleMic();
        expect(now().micOn, isFalse);
        await session.leave();
      });

      test('保留音の口の音の設定は、通話の口を作る前に済ませる(Android は端末全体のモードを書くので)', () async {
        var preparedBeforeMedia = -1;
        final c = ProviderContainer(overrides: [
          sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
          astellClientProvider.overrideWithValue(client),
          astellMediaFactoryProvider.overrideWith((ref) => () {
                preparedBeforeMedia = (ref.read(holdMusicProvider) as MemoryHoldMusic).prepares;
                return media;
              }),
          astellStreamerFactoryProvider.overrideWithValue(() => streamer),
          astellLevelIntervalProvider.overrideWithValue(null),
        ]);
        addTearDown(c.dispose);
        await c.read(astellSessionProvider.notifier).join(MockAstellClient.seededRooms().first);
        expect(preparedBeforeMedia, 1);
        await c.read(astellSessionProvider.notifier).leave();
      });

      test('保留音の音の設定 (Android): 通話の音の道で、焦点を取らず、端末全体のモード / スピーカーは通話の前の値(書いても壊さない)', () {
        final a = AudioHoldMusic.context.android;
        expect(a.usageType, AndroidUsageType.voiceCommunication);
        expect(a.audioFocus, AndroidAudioFocus.none);
        expect(a.audioMode, AndroidAudioMode.normal);
        expect(a.isSpeakerphoneOn, isFalse);
      });
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

    test('接続の状態(開発者向け、D-323): 自分・マイク・ICE サーバー・相手ごとの接続・配信を行にする', () async {
      final session = await join(MockAstellClient.seededRooms().first);
      final lines = await session.diagnostics();
      expect(lines.first, startsWith('自分: peer me'));
      expect(lines, contains(startsWith('マイク: 下ろしている / まだ開いていない')));
      expect(lines, contains('通話: 接続 5 本 / ICE サーバー: stun:stun.l.google.com:19302'));
      expect(lines.where((l) => l.startsWith('— ')), hasLength(5));
      expect(lines, contains('  接続 connected / ICE -(収集 -)/ SDP have-local-offer'));
      // r-launch には TiVard の画面共有があるので、見るだけで配信に繋いでいる。
      expect(lines, contains('配信: connected'));
      await session.leave();
      expect(await session.diagnostics(), ['ルームに入っていません']);
    });

    test('Web でブラウザが声の自動再生を止めている間は「触ると鳴ります」を出し、鳴ったら消す (D-323)', () async {
      final session = await join(MockAstellClient.seededRooms().first);
      astellAudioAwaitingGesture.value = true;
      expect(container.read(astellSessionProvider)!.notice, astellAudioBlockedNotice);
      expect(await session.diagnostics(), contains(startsWith('声: ブラウザが自動再生を止めている')));
      astellAudioAwaitingGesture.value = false;
      expect(container.read(astellSessionProvider)!.notice, isNull);
      await session.leave();
      // 退出したあとは見ない。
      astellAudioAwaitingGesture.value = true;
      expect(container.read(astellSessionProvider), isNull);
      astellAudioAwaitingGesture.value = false;
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

    test('強制ミュートされた人の声は、LiveKit に上がっていても鳴らさない。解除で戻る(セキュリティ確認 2026-10-09 の [7])', () async {
      final session = await join(MockAstellClient.seededRooms().firstWhere((r) => r.id == 'r-sublrony'));
      Map<String, Object?> peer(String peerId, {required bool muted}) => {
            'type': 'peer-state',
            'peer': {'peerId': peerId, 'accountId': 'kurt', 'handle': 'kurt', 'displayName': 'クルト', 'state': {'micOn': false, 'mutedByMod': muted}},
          };
      // 通話に繋がっていない(満員などで LiveKit で聞く)話す人。
      client.emit('r-sublrony', peer('p9', muted: false));
      await Future<void>.delayed(Duration.zero);
      expect(streamer.policy!('kurt'), isTrue);
      final applied = streamer.policySet;
      client.emit('r-sublrony', peer('p9', muted: true));
      await Future<void>.delayed(Duration.zero);
      expect(streamer.policy!('kurt'), isFalse, reason: '強制ミュート中は配信の声も止める');
      expect(streamer.policySet, greaterThan(applied), reason: 'いま鳴っているトラックにもすぐ効かせる');
      // 同じアカウントの別の接続はミュートされていなくても、どれかがミュートなら止める(LiveKit の識別子はアカウント)。
      client.emit('r-sublrony', peer('p10', muted: false));
      await Future<void>.delayed(Duration.zero);
      expect(streamer.policy!('kurt'), isFalse);
      client.emit('r-sublrony', peer('p9', muted: false));
      await Future<void>.delayed(Duration.zero);
      expect(streamer.policy!('kurt'), isTrue, reason: '解除で戻る');
      expect(streamer.policy!('sublrony'), isTrue, reason: 'ほかの人の声はそのまま');
      await session.leave();
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

    test('iOS の画面共有は LiveKit の setScreenShareEnabled を使わず自分でトラックを作る(Broadcast Extension が無いと何も上げないので、D-323)', () {
      expect(astellScreenCaptureInApp(web: false, platform: TargetPlatform.iOS), isTrue);
      expect(astellScreenCaptureInApp(web: true, platform: TargetPlatform.iOS), isFalse, reason: 'Safari はブラウザの getDisplayMedia');
      for (final p in [TargetPlatform.android, TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux]) {
        expect(astellScreenCaptureInApp(web: false, platform: p), isFalse, reason: '$p');
      }
    });

    test('配信の様子(開発者向け、D-323): 上げている / 受けているトラックと数', () {
      const d = AstellStreamDiagnostics(
        connection: 'connected',
        local: ['microphone audio'],
        remote: {
          'e7cc4808-771e-46c5-841b-06ba648605ab': ['screenShareVideo video: 受信中', 'microphone audio: 受信中'],
          'a21fc79e': [],
        },
        canPlaybackAudio: false,
      );
      expect(d.subscribed, 2);
      expect(d.lines(), [
        '配信: connected / 声: ブラウザが止めている(操作待ち)',
        '自分のトラック: microphone audio',
        'e7cc4808: screenShareVideo video: 受信中, microphone audio: 受信中',
        'a21fc79e: トラック無し',
        '受けているトラック: 2',
      ]);
      // 偽物 / 何もしない口は、繋がっているかだけ。
      expect(NullAstellStreamer().diagnostics().lines().first, '配信: disconnected');
    });

    test('Central が配信を用意していない (501) / 断った (403) ときの言い換え', () {
      expect(astellStreamErrorText(OrgateException(ErrorCode.tryParse('501')!, 'streaming is not configured')), '配信はまだ使えません(配信サーバーが未設定)');
      // D-503: 見るのは番号だけ(サーバーの文は表示の言語に訳される)。
      expect(astellStreamErrorText(OrgateException(ErrorCode.tryParse('501')!, '配信の設定がありません')), '配信はまだ使えません(配信サーバーが未設定)');
      expect(astellStreamErrorText(OrgateException(ErrorCode.tryParse('403')!, 'streaming is limited to moderators in this room')), contains('許可されていません'));
      expect(astellStreamErrorText(const AstellMediaException(AstellMediaIssue.insecureContext)), 'Web 版の通話は https で開いたときだけ使えます');
    });
  });
}

// ── 偽の口 ─────────────────────────────────────────────────────────

class FakeMedia implements AstellMedia {
  final links = <String, FakeLink>{};
  int opened = 0;
  int openCalls = 0;

  /// 開くのを待たせる(OS の許可のダイアログの間)。
  Completer<void>? openGate;
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
    openCalls++;
    final g = openGate;
    if (g != null) await g.future;
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

  /// 自分のマイクの大きさ(`media-source`)。
  double localLevel = 0;

  /// `getStats` が返ってこない / 失敗する(閉じかけ)。
  Exception? levelError;

  @override
  Future<AstellAudioLevels> audioLevels() async {
    if (levelError != null) throw levelError!;
    return (remote: level, local: localLevel);
  }

  @override
  Future<AstellLinkDiagnostics> diagnostics() async => AstellLinkDiagnostics(peerId: peerId, connectionState: closed ? 'closed' : 'connected', signalingState: state);

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
  int policySet = 0;
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
  void setAudioPolicy(bool Function(String identity) play) {
    policy = play;
    policySet++;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _publishing = null;
  }

  Set<String> _speakers = const {};
  bool _localSpeaks = false;

  @override
  Set<String> get speakingIdentities => _speakers;
  @override
  bool get localSpeaking => _localSpeaks;

  /// LiveKit のサーバーの話している人が変わった(`ActiveSpeakersChanged`)。
  void speak(Set<String> identities, {bool local = false}) {
    _speakers = identities;
    _localSpeaks = local;
    notifyListeners();
  }
}
