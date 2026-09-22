import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';

/// ワーカー isolate 版コントローラ: UI isolate を塞がずに同じ境界を張れるか。
/// サンプルプラグインが function.json で宣言する権限 (D-004)。
const _samplePermissions = {'network', 'storage.safe'};
const _sampleHosts = {'misskey.example'};

void main() {
  final wasmFile = File('../../../rasq-sdk-sample/rust/target/wasm32-unknown-unknown/release/misskey_wasm_sample.wasm');
  if (!wasmFile.existsSync()) {
    test('misskey-wasm-sample built', () {}, skip: 'build misskey-wasm-sample first');
    return;
  }
  final bytes = Uint8List.fromList(wasmFile.readAsBytesSync());

  test('load → snapshot → storageRoundTrip(ワーカー内 storage)→ dispose', () async {
    final controller = AsyncWasmPluginController(wasmBytes: bytes, nativeFetch: false, permissions: _samplePermissions, fetchHosts: _sampleHosts);
    await controller.load();
    expect(controller.document, isNotNull);
    expect(controller.document!.rev, 1);

    final result = await controller.invoke('storageRoundTrip', {'key': 'k', 'value': 'ワーカー'});
    expect(result['ok'], true, reason: '$result');
    expect((result['value'] as Map)['stored'], 'ワーカー');

    controller.dispose();
  });

  test('patch → rev2、fetch バックエンド無しの timeline は B01', () async {
    final controller = AsyncWasmPluginController(wasmBytes: bytes, nativeFetch: false, permissions: _samplePermissions, fetchHosts: _sampleHosts);
    await controller.load();
    await controller.applyPatch();
    expect(controller.document!.rev, 2);

    final result = await controller.invoke('timeline', {'host': 'x.example'});
    expect(result['ok'], false);
    expect((result['error'] as Map)['code'], 'B01');
    controller.dispose();
  });

  test('FOW surface (D-064): ワーカー中継で fow.open → タップで fow.close → onClosed 通知', () async {
    final controller = AsyncWasmPluginController(wasmBytes: bytes, nativeFetch: false, permissions: _samplePermissions, fetchHosts: _sampleHosts);
    await controller.load();
    WasmFowRequest? opened;
    final closes = <(String, Object?)>[];
    controller.onFowOpen = (req) => opened = req;
    controller.onFowClose = (id, {result, reason}) => closes.add((id, result));

    final result = await controller.invoke('pickReaction', {'postId': 'p1'});
    expect(result['ok'], true, reason: '$result');
    expect((result['value'] as Map)['opened'], true); // v1 = 受理
    // fow.open はワーカーから fire-and-forget で中継される — 到着を待つ。
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(opened, isNotNull);
    expect(opened!.document.root.findByKey('emoji-tada'), isNotNull);

    controller.handleEvent('${opened!.document.scope}:emoji-tada', 'tap', fn: 'reactFromFow');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(closes.single.$1, 'reaction-picker');
    expect(closes.single.$2, '🎉');

    controller.notifyFowClosed('reaction-picker', reason: 'dismissed', result: '🎉');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final last = await controller.invoke('lastFowClosed');
    expect((last['value'] as Map)['reason'], 'dismissed');
    expect((last['value'] as Map)['result'], '🎉');
    controller.dispose();
  });

  test('handleEvent は fire-and-forget で call になる', () async {
    final controller = AsyncWasmPluginController(wasmBytes: bytes, nativeFetch: false, permissions: _samplePermissions, fetchHosts: _sampleHosts);
    await controller.load();
    controller.handleEvent('scope:node', 'tap', fn: 'openThread', payload: {'postId': 'p1'});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final echo = ((controller.lastResult!['value'] as Map)['echo'] as Map).cast<String, Object?>();
    expect(echo['fn'], 'openThread');
    controller.dispose();
  });
}
