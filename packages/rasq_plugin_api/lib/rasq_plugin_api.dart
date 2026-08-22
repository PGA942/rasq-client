/// Host-side plugin contracts (叩き台).
///
/// Phase-1 plan: Dart-implemented SNS adapters (`sns_misskey` first, D-010)
/// fulfil exactly this contract; WASM plugins will later be bridged onto the
/// same interfaces by `plugin_runtime`. The shape is expected to be refined
/// together with `ORGATE-question/rasq-sdk-sample`.
library;

export 'src/action.dart';
export 'src/auth.dart';
export 'src/manifest.dart';
export 'src/plugin_registry.dart';
export 'src/server_info.dart';
export 'src/sns_plugin.dart';
export 'src/sns_session.dart';
export 'src/timeline.dart';
