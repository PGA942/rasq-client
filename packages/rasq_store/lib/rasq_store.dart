/// RASQ Store layer.
///
/// 原典: UI_Elements「状態管理方針」— 状態はDSLの外(Store/Signal)で管理し、
/// コンポーネントはPropsとして受け取るだけ。SNSプラグイン → Store → Props。
///
/// Stores are Riverpod `Notifier`s keyed by account-scoped ids, so that
/// per-account plugin versions and per-account state never collide.
library;

export 'src/action_state.dart';
export 'src/follow_state.dart';
export 'src/read_state.dart';
export 'src/cache.dart';
