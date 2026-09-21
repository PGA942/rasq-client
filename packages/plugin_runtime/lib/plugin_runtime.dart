/// RASQ plugin runtime (M3): glues the WASM boundary to the RRL renderer.
///
/// ```
/// .wasm bytes ──▶ RasqWasmPlugin (wasmi, rasq_wasm_runtime)
///                   │  snapshot/patch  ──▶ RrlDocument (rrl_core)
///                   │  events ◀── RrlRenderer (rrl_renderer) ◀── WasmPluginView
///                   └─ rasq.host_fn ──▶ RasqHostEnvironment (storage / net.fetch / ml.infer …)
/// ```
///
/// - [RasqHostEnvironment]: host-function dispatcher per
///   `rasq-sdk-sample/schema/host-fn.schema.json` with injectable backends
///   (tests pass fakes; the app passes real ones).
/// - [WasmPluginController]: owns one plugin instance + its [RrlDocument].
/// - [WasmPluginView]: renders the document and routes events back as `call`s.
library;

export 'src/async_wasm_plugin_controller.dart';
export 'src/host_environment.dart';
export 'src/wasm_fow.dart';
export 'src/wasm_sns_plugin.dart';
export 'src/wasm_sns_session.dart';
export 'src/wasm_timeline_plugin.dart';
export 'src/wasm_plugin_controller.dart';
export 'src/wasm_plugin_view.dart';
export 'src/wasm_plugin_worker.dart';
// .rasqpkg(zstd 圧縮 tar、D-034)の展開に使う zstd の復号。ネイティブランタイム内蔵(純 Rust の ruzstd)。
export 'src/wasm_runtime.dart' show rasqZstdDecompress, RasqZstdException;
