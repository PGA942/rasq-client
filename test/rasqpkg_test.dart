import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' show sha512;
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/store/rasqpkg.dart';

/// `.rasqpkg` の展開と検証(D-034 / D-244d)。
///
/// - 本物(rasq CLI が作った配布物)は本物の zstd(ネイティブランタイム内蔵の ruzstd)で開く。
/// - 改ざんの検出は、zstd の符号化器が Dart に無いので **復号を差し替えて**(先頭 4 バイトのマジックを外すだけ)、
///   テストが組んだ tar をそのまま読ませる。検証の本体(tar 以降)は同じコードを通る。
void main() {
  Uint8List fixture(String name) => File('test/fixtures/rasqpkg/$name').readAsBytesSync();

  // ── 作り物の配布物 ────────────────────────────────────────────────
  const zstdMagic = [0x28, 0xB5, 0x2F, 0xFD];
  Uint8List fakeDecompress(Uint8List input, {int maxOutput = 1 << 30}) {
    final tar = Uint8List.sublistView(input, 4);
    if (tar.length > maxOutput) throw StateError('too large');
    return tar;
  }

  final wasm = Uint8List.fromList([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0]);
  String hex(List<int> b) => sha512.convert(b).toString();
  Map<String, Object?> fileSpec(String path, List<int> data) => {'path': path, 'sha512': hex(data), 'sizeBytes': data.length};
  List<int> manifestBytes(String id, String kind) => utf8.encode(jsonEncode({'schema': 'rasq.plugin-manifest/1', 'id': id, 'name': id, 'version': '0.1.0', 'kind': kind}));

  /// (目次, ファイル) → 先頭にマジックを付けた「配布物」。`files` の順で tar に入れる。
  Uint8List pack(Map<String, Object?> bundle, Map<String, List<int>> files, {bool sums = true, List<String>? order}) {
    final all = <String, List<int>>{'bundle.json': utf8.encode(jsonEncode(bundle)), ...files};
    if (sums) all['SHA512SUMS'] = utf8.encode([for (final e in all.entries) '${hex(e.value)}  ${e.key}'].join('\n'));
    final archive = Archive();
    for (final name in order ?? all.keys) {
      archive.addFile(ArchiveFile.bytes(name, Uint8List.fromList(all[name]!)));
    }
    return Uint8List.fromList([...zstdMagic, ...TarEncoder().encodeBytes(archive)]);
  }

  Map<String, Object?> validBundle({String rootKind = 'action', List<Map<String, Object?>> children = const []}) => {
        'schema': 'rasq.bundle/1',
        'root': {'id': 'net.example.one', 'version': '0.1.0', 'kind': rootKind, 'manifest': 'manifest.json', 'wasm': fileSpec('one.wasm', wasm)},
        'children': children,
        'libs': [],
        'assets': [],
        'models': [],
      };
  Map<String, List<int>> validFiles({String rootKind = 'action'}) => {'manifest.json': manifestBytes('net.example.one', rootKind), 'one.wasm': wasm};

  RasqPackage open(Uint8List bytes) => RasqPackage.open(bytes, decompress: fakeDecompress);
  Matcher rejects(String needle) => throwsA(isA<RasqPackageException>().having((e) => e.message, 'message', contains(needle)));

  group('本物の配布物(rasq build)', () {
    test('他人の土台に足す子: root = 子、requires に土台', () {
      final pkg = RasqPackage.open(fixture('net.example.later-0.1.0.rasqpkg'));
      expect((pkg.root.id, pkg.root.version, pkg.root.kind), ('net.example.later', '0.1.0', 'action'));
      expect(pkg.root.manifest['slots'], ['post.action']);
      expect(isWasmModule(pkg.root.wasm), isTrue);
      expect(pkg.children, isEmpty);
      expect(pkg.requires.map((r) => '${r.id} ${r.version}'), ['dev.test.mysns ^0.1.0']);
      expect(pkg.slotPlugins.map((p) => p.id), ['net.example.later']);
      expect(pkg.files.keys.first, 'bundle.json');
      expect(pkg.files.keys.last, 'SHA512SUMS');
    });

    test('SNS プラグイン + 配下の子: スロットに入るのは子だけ', () {
      final pkg = RasqPackage.open(fixture('dev.test.mysns-0.1.0.rasqpkg'));
      expect((pkg.root.id, pkg.root.isSns), ('dev.test.mysns', true));
      expect(pkg.children.map((c) => (c.id, c.template)), [('dev.test.mysns.hello', 'post.action')]);
      expect(pkg.slotPlugins.map((p) => p.id), ['dev.test.mysns.hello']);
      expect(pkg.plugin('dev.test.mysns.hello').manifest['id'], 'dev.test.mysns.hello');
      expect(pkg.plugin(null).id, 'dev.test.mysns');
      expect(() => pkg.plugin('dev.test.mysns.nope'), rejects('がありません'));
    });

    test('展開後の上限を超えたら開かない(展開爆弾の対策)', () {
      expect(() => RasqPackage.open(fixture('net.example.later-0.1.0.rasqpkg'), maxUnpackedBytes: 1024), rejects('展開できません'));
    });

    test('1 バイト化けた配布物 / zstd でないものは開かない', () {
      final bad = Uint8List.fromList(fixture('net.example.later-0.1.0.rasqpkg'));
      bad[bad.length ~/ 2] ^= 0x55;
      expect(() => RasqPackage.open(bad), throwsA(isA<RasqPackageException>()));
      expect(() => RasqPackage.open(Uint8List.fromList(utf8.encode('rasqpkg-mock:x'))), rejects('zstd'));
      expect(isRasqPackage(wasm), isFalse);
    });

    test('開発者鍵の署名(.sig.json): OK / 署名の改ざん / 別の配布物', () async {
      final bytes = fixture('net.example.later-0.1.0.rasqpkg');
      final sig = (jsonDecode(File('test/fixtures/rasqpkg/net.example.later-0.1.0.rasqpkg.sig.json').readAsStringSync()) as Map).cast<String, Object?>();
      expect(await verifyDevSignature(bytes, sig), matches(RegExp(r'^[0-9a-f]{16}$')));
      final forged = Uint8List.fromList(base64Decode(sig['signature'] as String))..[0] ^= 1;
      await expectLater(verifyDevSignature(bytes, {...sig, 'signature': base64Encode(forged)}), rejects('署名が合いません'));
      await expectLater(verifyDevSignature(fixture('dev.test.mysns-0.1.0.rasqpkg'), sig), rejects('差し替わって'));
      await expectLater(verifyDevSignature(bytes, {...sig, 'alg': 'rsa'}), rejects('ed25519'));
    });
  });

  group('中身の検証(作り物の tar)', () {
    test('正しいものは開く', () {
      final pkg = open(pack(validBundle(), validFiles()));
      expect(pkg.root.id, 'net.example.one');
    });

    test('先頭が bundle.json でない', () {
      expect(() => open(pack(validBundle(), validFiles(), order: ['manifest.json', 'bundle.json', 'one.wasm', 'SHA512SUMS'])), rejects('先頭が bundle.json'));
    });

    test('schema 違い / 目次の形', () {
      expect(() => open(pack({...validBundle(), 'schema': 'rasq.bundle/2'}, validFiles())), rejects('rasq.bundle/1'));
      expect(() => open(pack(validBundle()..remove('libs'), validFiles())), rejects('libs'));
      expect(() => open(pack({...validBundle(), 'root': {'id': 'BadId', 'version': '0.1.0', 'kind': 'action', 'manifest': 'manifest.json', 'wasm': fileSpec('one.wasm', wasm)}}, validFiles())), rejects('id が不正'));
    });

    test('wasm のハッシュ / 大きさが目次と違う、wasm でない', () {
      final other = Uint8List.fromList([...wasm, 9]);
      expect(() => open(pack(validBundle(), {...validFiles(), 'one.wasm': other})), rejects('大きさが目次と違'));
      final sameSize = Uint8List.fromList([0, 0x61, 0x73, 0x6d, 2, 0, 0, 0]);
      expect(() => open(pack(validBundle(), {...validFiles(), 'one.wasm': sameSize})), rejects('SHA-512 が目次と違'));
      final notWasm = utf8.encode('#!/bin/sh');
      final b = validBundle();
      (b['root'] as Map)['wasm'] = fileSpec('one.wasm', notWasm);
      expect(() => open(pack(b, {...validFiles(), 'one.wasm': notWasm})), rejects('wasm ではありません'));
    });

    test('目次にあるのに中に無い / 目次に無いファイルが入っている', () {
      expect(() => open(pack(validBundle(), {'manifest.json': manifestBytes('net.example.one', 'action')})), rejects('中にありません'));
      expect(() => open(pack(validBundle(), {...validFiles(), 'extra.sh': utf8.encode('x')})), rejects('目次に載っていない'));
      // モデル本体(models/ の下)は目次に個別には載らない
      expect(open(pack(validBundle(), {...validFiles(), 'models/m.onnx': [1, 2, 3]})).files.containsKey('models/m.onnx'), isTrue);
    });

    test('パスの文法: 上へ出る / 絶対パスは読まない', () {
      for (final bad in ['../evil.wasm', '/abs.wasm', 'a/../../b.wasm', 'a//b.wasm']) {
        final b = validBundle();
        (b['root'] as Map)['wasm'] = fileSpec(bad, wasm);
        expect(() => open(pack(b, {'manifest.json': manifestBytes('net.example.one', 'action'), bad: wasm})), rejects('パスとして使えません'), reason: bad);
      }
    });

    test('マニフェストが目次と違うものを名乗る', () {
      expect(() => open(pack(validBundle(), {...validFiles(), 'manifest.json': manifestBytes('net.example.other', 'action')})), rejects('目次'));
      expect(() => open(pack(validBundle(), {...validFiles(), 'manifest.json': manifestBytes('net.example.one', 'view')})), rejects('目次'));
    });

    test('子: id は <root>. で始まる、sns 以外の root は子を持てない、子は sns になれない', () {
      Map<String, Object?> child(String id, String kind) => {'id': id, 'version': '0.1.0', 'kind': kind, 'manifest': 'plugins/c/manifest.json', 'wasm': fileSpec('plugins/c/c.wasm', wasm)};
      Map<String, List<int>> files(String id, String kind, {String rootKind = 'sns'}) => {...validFiles(rootKind: rootKind), 'plugins/c/manifest.json': manifestBytes(id, kind), 'plugins/c/c.wasm': wasm};
      final ok = open(pack(validBundle(rootKind: 'sns', children: [child('net.example.one.c', 'action')]), files('net.example.one.c', 'action')));
      expect(ok.slotPlugins.map((p) => p.id), ['net.example.one.c']);
      expect(() => open(pack(validBundle(rootKind: 'sns', children: [child('net.other.c', 'action')]), files('net.other.c', 'action'))), rejects('で始まっていません'));
      expect(() => open(pack(validBundle(children: [child('net.example.one.c', 'action')]), files('net.example.one.c', 'action', rootKind: 'action'))), rejects('children を持てません'));
      expect(() => open(pack(validBundle(rootKind: 'sns', children: [child('net.example.one.c', 'sns')]), files('net.example.one.c', 'sns'))), rejects('sns にできません'));
    });

    test('SHA512SUMS が無い / 中身と違う', () {
      expect(() => open(pack(validBundle(), validFiles(), sums: false)), rejects('SHA512SUMS がありません'));
      final files = {...validFiles(), 'SHA512SUMS': utf8.encode('${'0' * 128}  one.wasm')};
      expect(() => open(pack(validBundle(), files, sums: false)), rejects('SHA512SUMS と違います'));
    });

    test('ファイル数の上限', () {
      final many = {for (var i = 0; i < rasqpkgMaxEntries + 1; i++) 'models/f$i': [i & 0xff]};
      expect(() => open(pack(validBundle(), {...validFiles(), ...many})), rejects('多すぎます'));
    });

    test('登録元の文字列を入れ物と中の id に分ける', () {
      expect(splitPackageSource('store:a.b'), (container: 'store:a.b', pluginId: null));
      expect(splitPackageSource('store:a.b#a.b.c'), (container: 'store:a.b', pluginId: 'a.b.c'));
      expect(splitPackageSource('/x/y.rasqpkg#a.b.c'), (container: '/x/y.rasqpkg', pluginId: 'a.b.c'));
    });
  });
}
