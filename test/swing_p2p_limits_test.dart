import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:rasq_client/features/swing/p2p/swing_copy_store.dart';
import 'package:rasq_client/features/swing/p2p/swing_manifest.dart';
import 'package:rasq_client/features/swing/p2p/swing_p2p.dart';
import 'package:rasq_client/features/swing/p2p/swing_signer.dart';
import 'package:rasq_client/features/swing/swing_client.dart';
import 'package:rasq_client/features/swing/swing_models.dart';
import 'package:rasq_client/session/session_storage.dart';

/// セキュリティ確認 2026-11-11 の #16 / #20: P2P の Swing の期限と、配る枠。
void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('swing_limits'));
  tearDown(() async => dir.delete(recursive: true));

  group('#16 取りに行く側の期限', () {
    final keep = SwingP2p.fetchTimeout;
    tearDown(() => SwingP2p.fetchTimeout = keep);

    test('終わりの知らせを送らない相手: 期限で接続・購読を閉じ、bye を送る。再試行も同じ', () async {
      // 期限は、接続を作るまでの本物の非同期(署名・一時フォルダ)より十分長く(混んだ CI では 200ms のうちに接続まで行かなかった)。
      SwingP2p.fetchTimeout = const Duration(milliseconds: 1500);
      final body = Uint8List.fromList(List.generate(5000, (i) => i % 251));
      final sha = sha256Hex(body);
      final signer = SwingSigner(MemorySessionStorage());
      final manifest = {
        'media': {'sha256': sha, 'size': body.length, 'contentType': 'image/webp'},
      };
      final s = Swing.tryParse({
        'id': 'aa-11',
        'author': {'accountId': 'a'},
        'kind': 'image',
        'expiresAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        'delivery': 'p2p',
        'manifest': manifest,
        'signature': await signer.sign('acc', manifest),
        'signingKey': await signer.publicKey('acc'),
      })!;
      final api = _FakeApi(from: [(source: 'peer-x', role: 'author')]);
      final pcs = <_FakePc>[];
      final p2p = SwingP2p(
        api: api,
        store: SwingCopyStore(() async => dir),
        peerConnection: (c, [k = const {}]) async => _FakePc()..also(pcs.add),
      );
      for (var attempt = 1; attempt <= 2; attempt++) {
        final f = p2p.fetch(s);
        await until(() => pcs.length == attempt && pcs.last.channels.isNotEmpty);
        final dc = pcs.last.channels.single;
        // 頭と本文の一部だけ送り、終わりの知らせ(done)は送らない。
        dc.onMessage?.call(RTCDataChannelMessage(swingTransferHeader(swingId: s.id, size: body.length, sha256: sha)));
        dc.onMessage?.call(RTCDataChannelMessage.fromBinary(body.sublist(0, 1000)));
        await expectLater(f, throwsA(isA<SwingP2pException>()));
        expect(pcs.last.closed, isTrue, reason: '期限で接続を閉じる($attempt 回目)');
        expect(api.signals.where((x) => x.kind == 'bye'), hasLength(attempt));
      }
      expect(pcs, hasLength(2));
      await p2p.dispose();
    });

    test('相手がチャネルを閉じたら、期限を待たずに終える', () async {
      SwingP2p.fetchTimeout = const Duration(seconds: 30);
      final signer = SwingSigner(MemorySessionStorage());
      final manifest = {
        'media': {'sha256': 'b' * 64, 'size': 10, 'contentType': 'image/webp'},
      };
      final s = Swing.tryParse({
        'id': 'bb-22',
        'author': {'accountId': 'a'},
        'kind': 'image',
        'expiresAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        'delivery': 'p2p',
        'manifest': manifest,
        'signature': await signer.sign('acc', manifest),
        'signingKey': await signer.publicKey('acc'),
      })!;
      final pcs = <_FakePc>[];
      final p2p = SwingP2p(api: _FakeApi(from: [(source: 'peer-x', role: 'author')]), store: SwingCopyStore(() async => dir), peerConnection: (c, [k = const {}]) async => _FakePc()..also(pcs.add));
      final f = p2p.fetch(s);
      await until(() => pcs.isNotEmpty && pcs.single.channels.isNotEmpty);
      pcs.single.channels.single.onDataChannelState?.call(RTCDataChannelState.RTCDataChannelClosed);
      await expectLater(f.timeout(const Duration(seconds: 2)), throwsA(isA<SwingP2pException>()));
      expect(pcs.single.closed, isTrue);
      await p2p.dispose();
    });
  });

  group('#20 配る枠', () {
    Map<String, Object?> offer(String session, {String from = 'peer'}) => {
          'type': 'swing.signal',
          'kind': 'offer',
          'swingId': 'cc-33',
          'from': '$from-$session',
          'session': session,
          'data': {'sdp': 'v=0', 'type': 'offer'},
        };

    test('読み込みの待ちのあいだに届いた offer も保留の枠に数え、3 つを超えて読み込み・接続しない。読み込みは 1 回', () async {
      final store = _SlowStore(dir);
      final bytes = Uint8List.fromList([1, 2, 3]);
      await store.put('cc-33', bytes, sha256: sha256Hex(bytes), expiresAt: DateTime.now().add(const Duration(hours: 1)));
      final api = _FakeApi();
      final pcs = <_FakePc>[];
      final p2p = SwingP2p(api: api, store: store, peerConnection: (c, [k = const {}]) async => _FakePc()..also(pcs.add));
      for (var i = 0; i < 5; i++) {
        p2p.onLiveEvent(offer('s$i'));
      }
      // 同じ session の重ね: 断る(先の受け渡しの登録は消さない)。
      p2p.onLiveEvent(offer('s0', from: 'other'));
      await until(() => store.entryCalls >= 1 && api.signals.where((x) => x.kind == 'bye').length >= 3);
      expect(store.entryCalls, 1, reason: '同じ Swing の読み込みは 1 回');
      expect(pcs, isEmpty, reason: 'まだ読み込み中');
      expect({for (final x in api.signals) if (x.kind == 'bye') x.session}, {'s3', 's4', 's0'});
      store.gate.complete();
      await until(() => pcs.length >= SwingP2p.maxServing && api.signals.where((x) => x.kind == 'answer').length >= SwingP2p.maxServing);
      expect(pcs, hasLength(SwingP2p.maxServing));
      expect(api.signals.where((x) => x.kind == 'answer').map((x) => x.session).toSet(), {'s0', 's1', 's2'});

      // 裏へ回ると全部閉じ、枠が空く。
      p2p.foreground = false;
      await until(() => pcs.every((p) => p.closed));
      expect(pcs.every((p) => p.closed), isTrue);
      p2p.foreground = true;
      p2p.onLiveEvent(offer('s9'));
      await until(() => api.signals.any((x) => x.kind == 'answer' && x.session == 's9'));
      expect(api.signals.where((x) => x.kind == 'answer').map((x) => x.session), contains('s9'));
      await p2p.dispose();
    });

    test('持っていない Swing の offer は、枠を返して断る', () async {
      final api = _FakeApi();
      final p2p = SwingP2p(api: api, store: SwingCopyStore(() async => dir), peerConnection: (c, [k = const {}]) async => _FakePc());
      for (var i = 0; i < 5; i++) {
        p2p.onLiveEvent(offer('n$i'));
        // 1 つずつ、断り(bye)が届くまで待ってから次へ(同時に抱えて上限で断られたのではないことを見る)。
        await until(() => api.signals.where((x) => x.kind == 'bye').length == i + 1);
      }
      expect(api.signals.where((x) => x.kind == 'bye'), hasLength(5), reason: '枠を抱えたままにしない(上限で断られているのではない)');
      await p2p.dispose();
    });
  });
}

/// 状態がそろうまで待つ(上限 5 秒)。決め打ちの時間(20ms / 50ms)では、混んだ CI で本物の非同期(一時フォルダ・署名・
/// ファイルの読み書き)が間に合わず落ちていた。
Future<void> until(bool Function() ok, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!ok()) {
    if (DateTime.now().isAfter(end)) fail('待ち切れなかった($timeout)');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

extension<T> on T {
  void also(void Function(T) f) => f(this);
}

class _SlowStore extends SwingCopyStore {
  _SlowStore(Directory dir) : super(() async => dir);
  final gate = Completer<void>();
  var entryCalls = 0;
  @override
  Future<({Uint8List bytes, String sha256, String? contentType})?> entry(String swingId) async {
    entryCalls++;
    await gate.future;
    return super.entry(swingId);
  }
}

class _FakeApi extends Fake implements SwingApi {
  _FakeApi({this.from = const []});
  final List<({String source, String role})> from;
  final signals = <({String kind, String session})>[];

  @override
  Future<List<({String source, String role})>> sources(String id) async => from;

  @override
  Future<void> signal(String id, {required String to, required String session, required String kind, Object? data}) async => signals.add((kind: kind, session: session));

  @override
  Future<({List<Map<String, Object?>> iceServers, int ttlSecs})> turn() async => (iceServers: const <Map<String, Object?>>[], ttlSecs: 3600);

  @override
  Future<void> integrity(String id, String source) async {}
}

class _FakeDc extends Fake implements RTCDataChannel {
  @override
  Function(RTCDataChannelState state)? onDataChannelState;
  @override
  Function(RTCDataChannelMessage data)? onMessage;
  @override
  int? get bufferedAmount => 0;
  @override
  Future<void> send(RTCDataChannelMessage message) async {}
  @override
  Future<void> close() async {}
}

class _FakePc extends Fake implements RTCPeerConnection {
  final channels = <_FakeDc>[];
  bool closed = false;
  @override
  Function(RTCPeerConnectionState state)? onConnectionState;
  @override
  Function(RTCIceCandidate candidate)? onIceCandidate;
  @override
  Function(RTCDataChannel channel)? onDataChannel;
  @override
  Future<RTCDataChannel> createDataChannel(String label, RTCDataChannelInit dataChannelDict) async => _FakeDc()..also(channels.add);
  @override
  Future<RTCSessionDescription> createOffer([Map<String, dynamic> constraints = const {}]) async => RTCSessionDescription('v=0', 'offer');
  @override
  Future<RTCSessionDescription> createAnswer([Map<String, dynamic> constraints = const {}]) async => RTCSessionDescription('v=0', 'answer');
  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {}
  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {}
  @override
  Future<void> addCandidate(RTCIceCandidate candidate) async {}
  @override
  Future<void> close() async => closed = true;
}
