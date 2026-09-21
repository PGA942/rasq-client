// WASM プラグインのワーカーの入口 (D-297): 端末では isolate + wasmi (FFI)、Web では Web Worker + ブラウザの WebAssembly。
export 'wasm_plugin_worker.dart' if (dart.library.js_interop) 'wasm_plugin_worker_web.dart';
