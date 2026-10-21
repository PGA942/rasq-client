import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' show sha512;

/// テストが組む `.rasqpkg`(rasqpkg_test と同じ作り方): zstd の符号化器が Dart に無いので、先頭に zstd のマジックだけ付けた
/// tar にして、[fakeZstdDecompress](マジックを外すだけ)を `rasqpkgZstdProvider` に差し替えて読ませる。検証の本体は同じコード。
const _zstdMagic = [0x28, 0xB5, 0x2F, 0xFD];

Uint8List fakeZstdDecompress(Uint8List input, {int maxOutput = 1 << 30}) {
  final tar = Uint8List.sublistView(input, 4);
  if (tar.length > maxOutput) throw StateError('too large');
  return tar;
}

/// root と子のマニフェスト(`id` / `version` / `kind` を持つこと)→ 配布物。wasm は中身の無いモジュール(偽のローダーが登録元で選ぶ)。
Uint8List fakeRasqPackage(Map<String, Object?> root, {List<Map<String, Object?>> children = const []}) {
  String hex(List<int> b) => sha512.convert(b).toString();
  final files = <String, List<int>>{};
  Map<String, Object?> spec(Map<String, Object?> m, String dir) {
    final wasm = [0, 0x61, 0x73, 0x6d, 1, 0, 0, 0, ...utf8.encode('${m['id']}')];
    files['${dir}manifest.json'] = utf8.encode(jsonEncode({'schema': 'rasq.plugin-manifest/1', ...m}));
    files['${dir}plugin.wasm'] = wasm;
    return {'id': m['id'], 'version': m['version'], 'kind': m['kind'], 'manifest': '${dir}manifest.json', 'wasm': {'path': '${dir}plugin.wasm', 'sha512': hex(wasm), 'sizeBytes': wasm.length}};
  }

  final bundle = {
    'schema': 'rasq.bundle/1',
    'root': spec(root, ''),
    'children': [for (final c in children) spec(c, 'plugins/${(c['id'] as String).split('.').last}/')],
    'libs': [],
    'assets': [],
    'models': [],
  };
  final all = <String, List<int>>{'bundle.json': utf8.encode(jsonEncode(bundle)), ...files};
  all['SHA512SUMS'] = utf8.encode([for (final e in all.entries) '${hex(e.value)}  ${e.key}'].join('\n'));
  final archive = Archive();
  for (final e in all.entries) {
    archive.addFile(ArchiveFile.bytes(e.key, Uint8List.fromList(e.value)));
  }
  return Uint8List.fromList([..._zstdMagic, ...TarEncoder().encodeBytes(archive)]);
}
