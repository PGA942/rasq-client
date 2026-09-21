import 'dart:js_interop';
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

// ── zstd (D-299): 小さな wasm(ruzstd。`tool/zstd-wasm`)を、ブラウザの WebAssembly で動かす ──

@JS('WebAssembly.instantiate')
external JSPromise<_InstantiateResult> _instantiate(JSUint8Array bytes, JSObject imports);

extension type _InstantiateResult._(JSObject _) implements JSObject {
  external _Instance get instance;
}

extension type _Instance._(JSObject _) implements JSObject {
  external _ZstdExports get exports;
}

extension type _ZstdExports._(JSObject _) implements JSObject {
  external _Memory get memory;
  external int alloc(int len);
  external void dealloc(int ptr, int len);
  external JSBigInt decompress(int ptr, int len, int maxOut);
}

extension type _Memory._(JSObject _) implements JSObject {
  external JSArrayBuffer get buffer;
}

@JS('BigInt.asUintN')
external JSBigInt _asUintN(int bits, JSBigInt v);

@JS('String')
external JSString _jsString(JSAny v);

_ZstdExports? _zstd;

/// Web 版の起動時に 1 回: zstd の wasm を読み込む(wasm の組み立ては非同期なので、同期の [rasqZstdDecompress] の前に済ませておく)。
Future<void> rasqZstdWarmUp(Uint8List wasmBytes) async {
  if (_zstd != null) return;
  final result = await _instantiate(wasmBytes.toJS, JSObject()).toDart;
  _zstd = result.instance.exports;
}

Uint8List rasqZstdDecompress(Uint8List input, {int maxOutput = 256 * 1024 * 1024}) {
  if (input.isEmpty) throw const RasqZstdException('empty input');
  final z = _zstd;
  if (z == null) throw const RasqZstdException('the zstd decoder is not loaded yet');
  final inPtr = z.alloc(input.length);
  z.memory.buffer.toDart.asUint8List(inPtr, input.length).setAll(0, input);
  final packed = _asUintN(64, z.decompress(inPtr, input.length, maxOutput));
  z.dealloc(inPtr, input.length);
  // (ptr << 32) | len。0 = 失敗。
  // 64 ビットの値は JS の Number では正確に持てないので、10 進の文字列を経由して Dart の BigInt で分ける。
  final value = BigInt.parse(_jsString(packed).toDart);
  final len = (value & BigInt.from(0xFFFFFFFF)).toInt();
  final ptr = (value >> 32).toInt();
  if (ptr == 0 && len == 0) throw RasqZstdException('not a valid zstd frame, or the output exceeds $maxOutput bytes');
  // メモリは伸びるたびに作り直されるので、読む直前に取り直す。
  final out = Uint8List.fromList(z.memory.buffer.toDart.asUint8List(ptr, len));
  z.dealloc(ptr, len);
  return out;
}
