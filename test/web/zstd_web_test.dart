@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';

/// Web 版の zstd (D-299 / D-472): `assets/web/zstd.wasm`(`tool/zstd-wasm`)が、復号に加えて圧縮(落書きの `svgz`、契約 v0.23)も持つ。
/// `flutter test --platform chrome test/web`。
void main() {
  test('圧縮して戻せる(落書きの SVG がよく縮む)', () async {
    // アプリの資産の zstd.wasm を、VM 側(テストのホスト)で読んで渡す(ブラウザのテストではアセットの束が無い)。
    final channel = spawnHybridCode(r"""
      import 'dart:io';
      hybridMain(channel) async => channel.sink.add(await File('assets/web/zstd.wasm').readAsBytes());
    """);
    final wasm = Uint8List.fromList((await channel.stream.first as List).cast<int>());
    await rasqZstdWarmUp(wasm);
    final svg = utf8.encode('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400">${[
      for (var i = 0; i < 80; i++) '<path d="M$i ${i * 3}L${i * 2} ${i * 5} ${i * 7 % 300} ${i * 11 % 400}" fill="none" stroke="#1D2939" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>',
    ].join()}</svg>');
    final z = rasqZstdCompress(Uint8List.fromList(svg));
    expect(z.sublist(0, 4), [0x28, 0xB5, 0x2F, 0xFD]);
    expect(z.length * 3, lessThan(svg.length));
    expect(rasqZstdDecompress(z, maxOutput: svg.length), svg);
    expect(() => rasqZstdDecompress(z, maxOutput: svg.length - 1), throwsA(isA<RasqZstdException>()));
  });
}
