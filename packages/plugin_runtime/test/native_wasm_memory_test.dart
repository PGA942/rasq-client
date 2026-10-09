import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';

/// セキュリティ確認 2026-10-09 の [5]: ネイティブ版はメモリ 1 本ごとの上限(256 MiB)しか無く、
/// 初期メモリを何本も宣言したモジュールで合計数 GiB を確保できた。数と合計の予算は
/// rasq_wasm_runtime(rasq-sdk-sample)の load で掛けるので、ネイティブの両方の controller
/// (同期の [WasmPluginController] / ワーカー isolate の [AsyncWasmPluginController])が
/// 同じように断ることをここで確かめる(Web 版は wasm_web_guard の capWasmMemory、D-452)。

/// `(memory (export "memory") <min>)` を [count] 本並べただけのモジュール。
Uint8List _memoriesModule(int count, List<int> minLeb) {
  final mem = <int>[count];
  for (var i = 0; i < count; i++) {
    mem
      ..add(0x00)
      ..addAll(minLeb);
  }
  final export = <int>[0x01, 0x06, ...utf8.encode('memory'), 0x02, 0x00];
  return Uint8List.fromList([
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, //
    0x05, mem.length, ...mem,
    0x07, export.length, ...export,
  ]);
}

/// 1 本ずつは上限ちょうど(4096 ページ = 256 MiB)、合計では 512 MiB。
final _twoMemories = _memoriesModule(2, [0x80, 0x20]);

/// 対照: 1 本(1 ページ)。インスタンス化は通り、snapshot の export が無いので後で落ちる。
final _oneMemory = _memoriesModule(1, [0x01]);

void main() {
  group('メモリを 2 本宣言したモジュールはインスタンス化しない(2026-10-09 の [5])', () {
    test('WasmPluginController(同期)', () {
      final controller = WasmPluginController(wasmBytes: _twoMemories);
      addTearDown(controller.dispose);
      controller.load();
      expect(controller.document, isNull);
      expect(controller.lastError, contains('RasqWasmInstantiateException'));

      final control = WasmPluginController(wasmBytes: _oneMemory);
      addTearDown(control.dispose);
      control.load();
      expect(control.lastError, isNot(contains('RasqWasmInstantiateException')));
    });

    test('AsyncWasmPluginController(ワーカー isolate)', () async {
      final controller = AsyncWasmPluginController(wasmBytes: _twoMemories, nativeFetch: false);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.document, isNull);
      expect(controller.lastError, contains('RasqWasmInstantiateException'));

      final control = AsyncWasmPluginController(wasmBytes: _oneMemory, nativeFetch: false);
      addTearDown(control.dispose);
      await control.load();
      expect(control.lastError, isNot(contains('RasqWasmInstantiateException')));
    });
  });
}
