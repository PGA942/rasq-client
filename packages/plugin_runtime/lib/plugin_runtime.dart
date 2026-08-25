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

export 'src/host_environment.dart';
export 'src/wasm_plugin_controller.dart';
export 'src/wasm_plugin_view.dart';
