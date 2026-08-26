import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';

/// ワーカー isolate 版コントローラ: UI isolate を塞がずに同じ境界を張れるか。
void main() {
  final wasmFile = File('../../../rasq-sdk-sample/rust/target/wasm32-unknown-unknown/release/misskey_wasm_sample.wasm');
  if (!wasmFile.existsSync()) {
    test('misskey-wasm-sample built', () {}, skip: 'build misskey-wasm-sample first');
    return;
  }
  final bytes = Uint8List.fromList(wasmFile.readAsBytesSync());

  test('load → snapshot → storageRoundTrip(ワーカー内 storage)→ dispose', () async {
    final controller = AsyncWasmPluginController(wasmBytes: bytes, nativeFetch: false);
    await controller.load();
    expect(controller.document, isNotNull);
    expect(controller.document!.rev, 1);

    final result = await controller.invoke('storageRoundTrip', {'key': 'k', 'value': 'ワーカー'});
    expect(result['ok'], true, reason: '$result');
    expect((result['value'] as Map)['stored'], 'ワーカー');

    controller.dispose();
  });

  test('patch → rev2、fetch バックエンド無しの timeline は B01', () async {
    final controller = AsyncWasmPluginController(wasmBytes: bytes, nativeFetch: false);
    await controller.load();
    await controller.applyPatch();
    expect(controller.document!.rev, 2);

    final result = await controller.invoke('timeline', {'host': 'x.example'});
    expect(result['ok'], false);
    expect((result['error'] as Map)['code'], 'B01');
    controller.dispose();
  });

  test('handleEvent は fire-and-forget で call になる', () async {
    final controller = AsyncWasmPluginController(wasmBytes: bytes, nativeFetch: false);
    await controller.load();
    controller.handleEvent('scope:node', 'tap', fn: 'openThread', payload: {'postId': 'p1'});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final echo = ((controller.lastResult!['value'] as Map)['echo'] as Map).cast<String, Object?>();
    expect(echo['fn'], 'openThread');
    controller.dispose();
  });
}
