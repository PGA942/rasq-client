// zstd の支度の入口 (D-299): Web 版だけ中身がある。
export 'wasm_runtime_warmup_io.dart' if (dart.library.js_interop) 'wasm_runtime_web.dart' show rasqZstdWarmUp;
