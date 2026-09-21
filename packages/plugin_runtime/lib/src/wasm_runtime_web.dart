import 'dart:typed_data';

/// Web 版 (D-295) の WASM ランタイムの代わり。`rasq_wasm_runtime` は FFI(wasmi)なので Web には載らない。
/// 形だけ同じにして、**読み込みの時点で断る**(プラグインは「使えない」と出る。黙って動いたふりはしない)。
class RasqWasmInstantiateException implements Exception {
  @override
  String toString() => 'RasqWasmInstantiateException: WASM plugins are not available on the web build';
}

typedef RasqHostFnHandler = String? Function(String requestJson);

class RasqWasmPlugin {
  // ignore: unused_element
  RasqWasmPlugin._();

  factory RasqWasmPlugin.fromBytes(Uint8List wasmBytes, {RasqHostFnHandler? hostFn, bool nativeFetch = false}) => throw RasqWasmInstantiateException();

  String snapshot() => throw RasqWasmInstantiateException();
  String patch() => throw RasqWasmInstantiateException();
  String call({required String fn, required String argsJson, required String callId}) => throw RasqWasmInstantiateException();
  void dispose() {}
}

class RasqZstdException implements Exception {
  const RasqZstdException(this.message);
  final String message;
  @override
  String toString() => 'RasqZstdException: $message';
}

Uint8List rasqZstdDecompress(Uint8List input, {int maxOutput = 256 * 1024 * 1024}) => throw const RasqZstdException('not available on the web build');
