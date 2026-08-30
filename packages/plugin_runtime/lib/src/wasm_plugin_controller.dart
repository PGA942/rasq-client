import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:rasq_wasm_runtime/rasq_wasm_runtime.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart' show RrlGeometryRegistry;

import 'host_environment.dart';
import 'wasm_fow.dart';

/// [WasmPluginView] が要求する最小面(同期/非同期コントローラ共通)。
abstract class WasmPluginViewModel implements Listenable {
  RrlDocument? get document;
  String? get lastError;
  Map<String, dynamic>? get lastResult;
  void handleEvent(String nodeId, String kind, {String? fn, Map<String, Object?> payload});

  /// 実物ジオメトリの登録簿 (D-072): レンダラーが role 付きノードを登録し、
  /// FOW の実物アンカー(`fow.open` の `anchor`)や `geometry.lookup` が
  /// ここから矩形を引く。コントローラ寿命で安定。
  RrlGeometryRegistry get geometry;
}

/// Owns one WASM plugin instance and its live [RrlDocument].
///
/// - `load()` instantiates the module (host functions served by [env]) and
///   pulls the initial `snapshot`.
/// - [invoke] sends a `call`; when the result carries `treeUpdated: true`
///   the new `snapshot` is pulled automatically.
/// - [applyPatch] pulls a `patch` and applies it atomically; a rev mismatch
///   degrades to a fresh snapshot (`resync`, gate V10).
/// - [handleEvent] is what the renderer's `onEvent` plugs into: the node's
///   `on` function name becomes a `call` (simplified event delivery — the
///   full `event {nodeId, kind}` message channel is a later step).
///
/// v1 calls are synchronous on the calling isolate (PROTOCOL §4.1) — run
/// heavy plugins off the UI isolate later.
class WasmPluginController extends ChangeNotifier with WasmFowSurfaceMixin implements WasmPluginViewModel {
  WasmPluginController({required Uint8List wasmBytes, RasqHostEnvironment? env})
      : _bytes = wasmBytes,
        env = env ?? RasqHostEnvironment();

  final Uint8List _bytes;
  final RasqHostEnvironment env;

  @override
  final RrlGeometryRegistry geometry = RrlGeometryRegistry();

  RasqWasmPlugin? _plugin;
  RrlDocument? _document;
  String? _lastError;
  Map<String, dynamic>? _lastResult;
  int _callSeq = 0;

  @override
  RrlDocument? get document => _document;
  @override
  String? get lastError => _lastError;

  /// Result message of the most recent [invoke] (debug surface).
  @override
  Map<String, dynamic>? get lastResult => _lastResult;

  bool get isLoaded => _plugin != null;

  void load() {
    if (_plugin != null) return;
    // fow.open/close の中継 (D-064): 環境の検証を通った要求を UI 側
    // コールバック(onFowOpen/onFowClose)へ写す。
    env.onFow ??= (fn, args) => handleFowHostFn(fn, args, scope: _document?.scope ?? 'plugin');
    try {
      _plugin = RasqWasmPlugin.fromBytes(_bytes, hostFn: env.dispatch, nativeFetch: env.nativeFetch);
      _lastError = null;
      pullSnapshot();
    } on RasqWasmInstantiateException catch (e) {
      _lastError = '$e';
      notifyListeners();
    }
  }

  /// Pulls the current `snapshot` from the plugin.
  void pullSnapshot() {
    final plugin = _require();
    try {
      final message = (jsonDecode(plugin.snapshot()) as Map).cast<String, Object?>();
      _document = RrlDocument.fromSnapshot(message);
      _lastError = null;
    } catch (e) {
      _lastError = 'snapshot failed: $e';
    }
    notifyListeners();
  }

  /// Sends `call {fn, args}` and returns the plugin's `result` message.
  Map<String, dynamic> invoke(String fn, [Map<String, Object?> args = const {}]) {
    final plugin = _require();
    final result = (jsonDecode(plugin.call(fn: fn, argsJson: jsonEncode(args), callId: 'call-${_callSeq++}')) as Map).cast<String, dynamic>();
    _lastResult = result;
    if (result['ok'] == true && (result['value'] as Map?)?['treeUpdated'] == true) {
      pullSnapshot();
    } else {
      notifyListeners();
    }
    return result;
  }

  /// Pulls one `patch` message and applies it; rev mismatch → resync.
  void applyPatch() {
    final plugin = _require();
    final doc = _document;
    if (doc == null) return pullSnapshot();
    try {
      final message = (jsonDecode(plugin.patch()) as Map).cast<String, Object?>();
      _document = doc.applyPatch(message);
      _lastError = null;
      notifyListeners();
    } on RrlRevMismatchException {
      pullSnapshot(); // resync (V10)
    } catch (e) {
      _lastError = 'patch failed: $e';
      notifyListeners();
    }
  }

  /// Renderer event → plugin function call (`RrlHost.onEvent` adapter).
  @override
  void handleEvent(String nodeId, String kind, {String? fn, Map<String, Object?> payload = const {}}) {
    if (fn == null) return; // node declared no handler for this kind
    invoke(fn, {'nodeId': nodeId, 'kind': kind, ...payload});
  }

  @override
  void invokePluginCallback(String fn, Map<String, Object?> args) {
    if (_plugin == null) return; // dispose 後(closeOwnedBy 連動)は通知不要
    invoke(fn, args);
  }

  RasqWasmPlugin _require() {
    final plugin = _plugin;
    if (plugin == null) throw StateError('WasmPluginController.load() first');
    return plugin;
  }

  @override
  void dispose() {
    _plugin?.dispose();
    _plugin = null;
    super.dispose();
  }
}
