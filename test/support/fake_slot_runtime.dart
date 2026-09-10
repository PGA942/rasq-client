import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart' show RrlGeometryRegistry;

/// wasm 無しのスロットプラグイン (D-167 のテスト用): `call` を Dart の
/// クロージャで答え、`fow.open` 等は本物の [WasmFowSurfaceMixin] を通す。
class FakeSlotRuntime extends ChangeNotifier with WasmFowSurfaceMixin implements WasmPluginViewModel, SlotRuntime {
  FakeSlotRuntime({required this.manifest, required this.handler, this.scopeName = 'fake:main'});
  final Map<String, Object?> manifest;

  /// `fn` と args を受け、`value` を返す(null = C01)。
  final FutureOr<Map<String, Object?>?> Function(FakeSlotRuntime rt, String fn, Map<String, Object?> args) handler;
  final String scopeName;
  final List<(String, Map<String, Object?>)> calls = [];
  AppFnRelay? _appFn;
  bool disposed = false;

  @override
  WasmPluginViewModel get view => this;

  @override
  set onAppFn(AppFnRelay? relay) => _appFn = relay;

  /// プラグイン側からホスト関数を呼ぶ(fire-and-forget、テストがトリガー)。
  void hostFn(String fn, Map<String, Object?> args) => _appFn?.call(fn, args);

  /// プラグイン側から FOW を開く。
  void openFow(String id, Map<String, Object?> root, {String? title, String? onClosed}) {
    handleFowHostFn('fow.open', {'id': id, 'spec': {'type': 'widget', 'title': title ?? id}, 'root': root, if (onClosed != null) 'onClosed': onClosed}, scope: scopeName);
  }

  void closeFow(String id) => handleFowHostFn('fow.close', {'id': id}, scope: scopeName);

  @override
  Future<Map<String, dynamic>> invoke(String fn, Map<String, Object?> args) async {
    calls.add((fn, args));
    if (fn == 'plugin.manifest') return {'ok': true, 'value': manifest};
    final v = await handler(this, fn, args);
    if (v == null) return {'ok': false, 'error': {'code': 'C01', 'message': 'unsupported $fn'}};
    return {'ok': true, 'value': v};
  }

  @override
  RrlDocument? get document => RrlDocument.fromSnapshot({'schema': 'rasq.boundary/1', 'scope': scopeName, 'type': 'snapshot', 'rev': 1, 'root': {'t': 'Column', 'k': 'root'}});
  @override
  String? get lastError => null;
  @override
  Map<String, dynamic>? get lastResult => null;
  @override
  final RrlGeometryRegistry geometry = RrlGeometryRegistry();

  @override
  void handleEvent(String nodeId, String kind, {String? fn, Map<String, Object?> payload = const {}}) {
    if (fn != null) invoke(fn, {'nodeId': nodeId, 'kind': kind, ...payload});
  }

  @override
  void invokePluginCallback(String fn, Map<String, Object?> args) => invoke(fn, args);

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

/// [slotRuntimeLoaderProvider] の差し替え: バイト列の先頭文字列で偽物を選ぶ。
SlotRuntimeLoader fakeSlotLoader(Map<String, FakeSlotRuntime Function()> byName) => (Uint8List bytes, {required Set<String> fowPermissions, required Set<String> appFns}) async {
      final name = String.fromCharCodes(bytes);
      final make = byName[name];
      if (make == null) throw StateError('unknown fake plugin: $name');
      return make();
    };
