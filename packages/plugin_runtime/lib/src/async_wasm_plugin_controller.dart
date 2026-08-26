import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:rrl_core/rrl_core.dart';

import 'wasm_plugin_controller.dart';
import 'wasm_plugin_worker.dart';

/// [WasmPluginController] の非同期版: プラグインを [WasmPluginWorker]
/// (専用 isolate)で動かし、UI isolate をブロックしない。
/// `net.fetch`(ランタイム内蔵)や重い snapshot 生成中も画面が止まらない。
class AsyncWasmPluginController extends ChangeNotifier implements WasmPluginViewModel {
  AsyncWasmPluginController({required Uint8List wasmBytes, bool nativeFetch = true, Map<String, Object?> seedStorage = const {}})
      : _config = WasmWorkerConfig(wasmBytes: wasmBytes, nativeFetch: nativeFetch, seedStorage: seedStorage);

  final WasmWorkerConfig _config;
  WasmPluginWorker? _worker;
  RrlDocument? _document;
  String? _lastError;
  Map<String, dynamic>? _lastResult;
  int _callSeq = 0;
  bool _disposed = false;

  @override
  RrlDocument? get document => _document;
  @override
  String? get lastError => _lastError;
  @override
  Map<String, dynamic>? get lastResult => _lastResult;

  bool get isLoaded => _worker != null;

  Future<void> load() async {
    if (_worker != null) return;
    try {
      _worker = await WasmPluginWorker.spawn(_config);
      await pullSnapshot();
    } catch (e) {
      _lastError = '$e';
      _notify();
    }
  }

  Future<void> pullSnapshot() async {
    final worker = _require();
    try {
      final message = (jsonDecode(await worker.snapshot()) as Map).cast<String, Object?>();
      _document = RrlDocument.fromSnapshot(message);
      _lastError = null;
    } catch (e) {
      _lastError = 'snapshot failed: $e';
    }
    _notify();
  }

  Future<Map<String, dynamic>> invoke(String fn, [Map<String, Object?> args = const {}]) async {
    final worker = _require();
    final result = (jsonDecode(await worker.call(fn: fn, argsJson: jsonEncode(args), callId: 'call-${_callSeq++}')) as Map).cast<String, dynamic>();
    _lastResult = result;
    if (result['ok'] == true && (result['value'] as Map?)?['treeUpdated'] == true) {
      await pullSnapshot();
    } else {
      _notify();
    }
    return result;
  }

  Future<void> applyPatch() async {
    final worker = _require();
    final doc = _document;
    if (doc == null) return pullSnapshot();
    try {
      final message = (jsonDecode(await worker.patch()) as Map).cast<String, Object?>();
      _document = doc.applyPatch(message);
      _lastError = null;
      _notify();
    } on RrlRevMismatchException {
      await pullSnapshot(); // resync (V10)
    } catch (e) {
      _lastError = 'patch failed: $e';
      _notify();
    }
  }

  @override
  void handleEvent(String nodeId, String kind, {String? fn, Map<String, Object?> payload = const {}}) {
    if (fn == null) return;
    // Fire and forget — 結果は lastResult / document 更新として観測される。
    invoke(fn, {'nodeId': nodeId, 'kind': kind, ...payload}).catchError((Object e) {
      _lastError = '$e';
      _notify();
      return <String, dynamic>{};
    });
  }

  WasmPluginWorker _require() {
    final w = _worker;
    if (w == null) throw StateError('AsyncWasmPluginController.load() first');
    return w;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _worker?.dispose();
    _worker = null;
    super.dispose();
  }
}
