import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:rasq_wasm_runtime/rasq_wasm_runtime.dart';
import 'package:rrl_core/rrl_core.dart';

import 'host_environment.dart';

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
class WasmPluginController extends ChangeNotifier {
  WasmPluginController({required Uint8List wasmBytes, RasqHostEnvironment? env})
      : _bytes = wasmBytes,
        env = env ?? RasqHostEnvironment();

  final Uint8List _bytes;
  final RasqHostEnvironment env;

  RasqWasmPlugin? _plugin;
  RrlDocument? _document;
  String? _lastError;
  Map<String, dynamic>? _lastResult;
  int _callSeq = 0;

  RrlDocument? get document => _document;
  String? get lastError => _lastError;

  /// Result message of the most recent [invoke] (debug surface).
  Map<String, dynamic>? get lastResult => _lastResult;

  bool get isLoaded => _plugin != null;

  void load() {
    if (_plugin != null) return;
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
  void handleEvent(String nodeId, String kind, {String? fn, Map<String, Object?> payload = const {}}) {
    if (fn == null) return; // node declared no handler for this kind
    invoke(fn, {'nodeId': nodeId, 'kind': kind, ...payload});
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
