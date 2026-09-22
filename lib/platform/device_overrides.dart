// 端末だけの実装(FFI: onnxruntime / llama / LiteRT)を差し込む口 (D-295)。Web 版では空。
export 'device_overrides_io.dart' if (dart.library.js_interop) 'device_overrides_web.dart';
