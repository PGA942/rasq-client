@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';

import 'table_grow_module.dart';

/// ブラウザで動かす確認 (D-546): `flutter test --platform chrome test/web`(packages/plugin_runtime で)。
///
/// セキュリティ確認 2026-10-21 の #1 (csf_bc46b1e657a57e9edd42cafc): 起動前の検査がテーブル節を読み飛ばしていたので、
/// 最大の無いテーブルは `start` / `call` の中で `table.grow` してブラウザの実装上限(V8 で 1,000 万要素)まで
/// 伸ばせた(実行後の checkMemory は線形メモリしか見ない)。起動前に最大を書き込む ([capWasmTables]) ので、
/// 予算 ([webWasmMaxTableElements]) を超えて伸ばそうとしても -1 が返ることを、本物の Web Worker + ブラウザの WebAssembly で確かめる。

void main() {
  test('最大を宣言しないテーブルが start の中で予算を超えて伸ばそうとしても、-1 が返る', () async {
    // 1 + 200,000 要素。直す前はそのまま伸び、線形メモリの検査では止まらなかった。
    final w = await WasmPluginWorker.spawn(WasmWorkerConfig(wasmBytes: tableGrowModule(webWasmMaxTableElements * 2)));
    addTearDown(w.dispose);
    expect(await w.snapshot(), 'refused');
  });

  test('予算の内側なら伸ばせる(書き込んだ最大で、ふつうのプラグインは困らない)', () async {
    final w = await WasmPluginWorker.spawn(WasmWorkerConfig(wasmBytes: tableGrowModule(1000)));
    addTearDown(w.dispose);
    expect(await w.snapshot(), 'grown');
  });

  test('テーブルが 2 本あるモジュールは、ワーカーを起こす前に断る', () async {
    final src = tableGrowModule(1);
    // テーブル節 [4, 4, 1, 0x70, 0, 1] を 2 本に差し替える。
    final i = _indexOf(src, [4, 4, 1, 0x70, 0x00, 1]);
    final two = Uint8List.fromList([...src.sublist(0, i), 4, 7, 2, 0x70, 0x00, 1, 0x70, 0x00, 1, ...src.sublist(i + 6)]);
    await expectLater(WasmPluginWorker.spawn(WasmWorkerConfig(wasmBytes: two)), throwsStateError);
  });
}

int _indexOf(List<int> hay, List<int> needle) {
  for (var i = 0; i + needle.length <= hay.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length && ok; j++) {
      ok = hay[i + j] == needle[j];
    }
    if (ok) return i;
  }
  throw StateError('not found');
}
