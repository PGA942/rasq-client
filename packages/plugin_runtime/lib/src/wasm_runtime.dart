// WASM ランタイムの入口 (D-295): 端末では `rasq_wasm_runtime`(FFI)、Web では形だけの代わり。
export 'package:rasq_wasm_runtime/rasq_wasm_runtime.dart' if (dart.library.js_interop) 'wasm_runtime_web.dart';
