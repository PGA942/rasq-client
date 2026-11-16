import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/swing/p2p/swing_copy_store.dart';
import 'package:rasq_client/features/swing/p2p/swing_manifest.dart';
import 'package:rasq_client/features/swing/p2p/swing_p2p.dart';
import 'package:rasq_client/features/swing/p2p/swing_signer.dart';
import 'package:rasq_client/features/swing/swing_client.dart';
import 'package:rasq_client/features/swing/swing_models.dart';
import 'package:rasq_client/session/session_storage.dart';

/// P2P の Swing (D-549 / Central S-128)。
void main() {
  group('canonical JSON (JCS)', () {
    test('matches the Central test vector (key order by UTF-16, escapes)', () {
      // rasq-central `src/swing/p2p.rs` の `jcs_sorts_keys_and_keeps_strings` と同じ入力と期待値。
      final v = {
        'b': 1,
        'a': {
          'y': [true, null, 'x\n\u0001'],
          'x': -3,
        },
        'é': 'é',
        '\u{10000}': 0,
        '\u{ffff}': 0,
      };
      expect(canonicalJson(v), '{"a":{"x":-3,"y":[true,null,"x\\n\\u0001"]},"b":1,"é":"é","\u{10000}":0,"\u{ffff}":0}');
    });

    test('numbers must be integers', () {
      expect(() => canonicalJson({'n': 1.5}), throwsFormatException);
      expect(canonicalJson({'n': 2}), '{"n":2}');
    });

    test('the same manifest in another key order has the same digest', () {
      final a = {'v': 1, 'kind': 'text', 'text': 'hi'};
      final b = {'text': 'hi', 'v': 1, 'kind': 'text'};
      expect(manifestDigest(a), manifestDigest(b));
    });
  });

  group('manifest', () {
    test('trims text and CW, keeps only known fields', () {
      final m = buildSwingManifest(
        swingId: newSwingId(),
        authorAccountId: 'acc',
        deviceId: 'dev',
        kind: 'image',
        text: '  hello  ',
        cw: '   ',
        media: (sha256: 'a' * 64, size: 10, contentType: 'image/webp'),
        audience: const SwingAudience().toJson(),
        ttlHours: 12,
        createdAt: DateTime.utc(2026, 11, 11),
      );
      expect(m['text'], 'hello');
      expect(m['cw'], isNull);
      expect(m.keys.toSet(), {'v', 'swingId', 'author', 'deviceId', 'kind', 'text', 'cw', 'sensitive', 'media', 'audience', 'ttlHours', 'createdAt'});
      expect(m['createdAt'], '2026-11-11T00:00:00.000Z');
    });

    test('swing ids are UUID v4', () {
      expect(newSwingId(), matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });
  });

  group('signer', () {
    test('registers once, signs, and verifies; tampering fails', () async {
      final signer = SwingSigner(MemorySessionStorage());
      var registered = 0;
      await signer.ensureRegistered('acc', 'dev', (_) async => registered++);
      await signer.ensureRegistered('acc', 'dev', (_) async => registered++);
      expect(registered, 1);
      await signer.forgetRegistration('acc', 'dev');
      await signer.ensureRegistered('acc', 'dev', (_) async => registered++);
      expect(registered, 2);

      final m = {'v': 1, 'kind': 'text', 'text': 'hi'};
      final sig = await signer.sign('acc', m);
      final pk = await signer.publicKey('acc');
      expect(await SwingSigner.verify(manifest: m, signature: sig, publicKey: pk), isTrue);
      expect(await SwingSigner.verify(manifest: {...m, 'text': 'ho'}, signature: sig, publicKey: pk), isFalse);
      expect(await SwingSigner.verify(manifest: m, signature: sig, publicKey: await SwingSigner(MemorySessionStorage()).publicKey('acc')), isFalse);
      expect(await SwingSigner.verify(manifest: m, signature: 'not base64', publicKey: pk), isFalse);
    });
  });

  group('transfer framing', () {
    final body = Uint8List.fromList(List.generate(40000, (i) => i % 251));
    final sha = sha256Hex(body);

    test('head + chunks + done yields the verified body', () {
      final asm = SwingAssembler(expectSha256: sha, maxBytes: body.length);
      expect(asm.text(swingTransferHeader(swingId: 's', size: body.length, sha256: sha)), isNull);
      final chunks = swingChunks(body).toList();
      expect(chunks.length, 3);
      for (final c in chunks) {
        asm.binary(c);
      }
      expect(asm.text(swingTransferDone), body);
    });

    test('a source offering another body, too much data, or a wrong body is refused', () {
      final other = SwingAssembler(expectSha256: sha, maxBytes: body.length);
      expect(() => other.text(swingTransferHeader(swingId: 's', size: body.length, sha256: 'b' * 64)), throwsFormatException);

      final long = SwingAssembler(expectSha256: sha, maxBytes: body.length);
      long.text(swingTransferHeader(swingId: 's', size: 10, sha256: sha));
      expect(() => long.binary(Uint8List(11)), throwsFormatException);

      final wrong = SwingAssembler(expectSha256: sha, maxBytes: body.length);
      wrong.text(swingTransferHeader(swingId: 's', size: body.length, sha256: sha));
      wrong.binary(Uint8List(body.length));
      expect(() => wrong.text(swingTransferDone), throwsFormatException);

      final early = SwingAssembler(expectSha256: sha, maxBytes: body.length);
      expect(() => early.binary(Uint8List(1)), throwsFormatException);
    });
  });

  group('copy store', () {
    late Directory dir;
    var now = DateTime.utc(2026, 11, 11, 12);
    setUp(() async => dir = await Directory.systemTemp.createTemp('swing_copies'));
    tearDown(() async => dir.delete(recursive: true));

    test('keeps copies until the Swing expires, then forgets them', () async {
      final store = SwingCopyStore(() async => dir, now: () => now);
      final bytes = Uint8List.fromList([1, 2, 3]);
      await store.put('aa-11', bytes, sha256: sha256Hex(bytes), expiresAt: now.add(const Duration(hours: 1)), contentType: 'image/webp');
      expect(await store.get('aa-11'), bytes);
      expect((await store.entry('aa-11'))?.contentType, 'image/webp');
      expect(await store.has('aa-11'), isTrue);
      now = now.add(const Duration(hours: 2));
      expect(await store.get('aa-11'), isNull);
      expect(await store.has('aa-11'), isFalse);
    });

    test('does not keep expired Swings and refuses odd ids', () async {
      final store = SwingCopyStore(() async => dir, now: () => now);
      await store.put('bb-22', Uint8List(1), sha256: 'x', expiresAt: now.subtract(const Duration(seconds: 1)));
      expect(await store.has('bb-22'), isFalse);
      await store.put('../etc', Uint8List(1), sha256: 'x', expiresAt: now.add(const Duration(hours: 1)));
      expect(await store.get('../etc'), isNull);
    });

    test('sweep removes expired copies', () async {
      final store = SwingCopyStore(() async => dir, now: () => now);
      await store.put('cc-33', Uint8List(1), sha256: 'x', expiresAt: now.add(const Duration(minutes: 1)));
      await store.put('dd-44', Uint8List(1), sha256: 'x', expiresAt: now.add(const Duration(hours: 5)));
      now = now.add(const Duration(minutes: 2));
      expect(await store.sweep(), 1);
      expect(await store.has('dd-44'), isTrue);
    });
  });

  group('wire', () {
    test('parses P2P fields', () {
      final s = Swing.tryParse({
        'id': 'sw',
        'author': {'accountId': 'a', 'handle': 'h'},
        'kind': 'image',
        'createdAt': '2026-11-11T00:00:00Z',
        'expiresAt': '2026-11-11T12:00:00Z',
        'delivery': 'p2p',
        'manifest': {
          'media': {'sha256': 'a' * 64, 'size': 5, 'contentType': 'image/webp'},
        },
        'manifestSha256': 'm',
        'signature': 'sig',
        'signingKey': 'key',
      })!;
      expect(s.isP2p, isTrue);
      expect(s.p2pMedia?.size, 5);
      expect(s.mediaUrl, isNull);
      expect(s.withMediaUrl(Uri.file('/tmp/x.mp4')).isP2p, isTrue);
      // サーバーの Swing(古い Central)は今まで通り。
      final old = Swing.tryParse({'id': 'x', 'author': {'accountId': 'a'}, 'kind': 'text'})!;
      expect(old.isP2p, isFalse);
      expect(old.delivery, 'server');
    });
  });

  group('evidence', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('swing_evidence'));
    tearDown(() async => dir.delete(recursive: true));

    test('answers a request only when holding the copy', () async {
      final api = _FakeApi();
      final store = SwingCopyStore(() async => dir);
      final p2p = SwingP2p(api: api, store: store);
      await p2p.answerEvidenceRequest('ee-55', manifestSha256: 'm');
      expect(api.uploads, isEmpty);
      final bytes = Uint8List.fromList(utf8.encode('img'));
      await store.put('ee-55', bytes, sha256: sha256Hex(bytes), expiresAt: DateTime.now().add(const Duration(hours: 1)), contentType: 'image/webp');
      await p2p.answerEvidenceRequest('ee-55', manifestSha256: 'm');
      expect(api.uploads, [('ee-55', 'm', 'image/webp', 3)]);
      // `/me/events` の求めからも。
      p2p.onLiveEvent({'type': 'swing.evidence_request', 'swingId': 'ee-55', 'manifestSha256': 'm2'});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.uploads.length, 2);
      await p2p.dispose();
    });

    test('a Swing whose signature does not verify is never fetched', () async {
      final api = _FakeApi();
      final p2p = SwingP2p(api: api, store: SwingCopyStore(() async => dir));
      final otherKey = await SwingSigner(MemorySessionStorage()).publicKey('x');
      final s = Swing.tryParse({
        'id': 'ff-66',
        'author': {'accountId': 'a'},
        'kind': 'image',
        'expiresAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        'delivery': 'p2p',
        'manifest': {
          'media': {'sha256': 'a' * 64, 'size': 5, 'contentType': 'image/webp'},
        },
        'signature': base64.encode(List.filled(64, 1)),
        'signingKey': otherKey,
      })!;
      await expectLater(p2p.fetch(s), throwsA(isA<SwingP2pException>().having((e) => e.failure, 'failure', SwingP2pFailure.unverified)));
      expect(api.sourceCalls, 0);
      await p2p.dispose();
    });
  });
}

class _FakeApi extends Fake implements SwingApi {
  final uploads = <(String, String, String, int)>[];
  var sourceCalls = 0;

  @override
  Future<void> uploadEvidence(String id, Uint8List bytes, {required String manifestSha256, required String contentType}) async => uploads.add((id, manifestSha256, contentType, bytes.length));

  @override
  Future<List<({String source, String role})>> sources(String id) async {
    sourceCalls++;
    return const [];
  }
}
