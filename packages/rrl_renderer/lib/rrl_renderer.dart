/// RRL renderer (M3, D-002): turns an `rrl_core` node tree into Flutter
/// widgets.
///
/// - **L1 Primitive** (`Text` `Icon` `Image` `Row` `Column` `Stack` `Grid`
///   `Scroll` `Canvas` `Spacer`) — rendered directly, geometry tokens stay
///   host-owned.
/// - **L2 Standard Component** — *delegated* to the host implementations in
///   `rasq_design` through [RrlComponentRegistry]; plugins get Props only.
/// - **L3 Control** (`If` `ForEach` `Call` `Bind` `Slot` `Stream`) — evaluated
///   against the [RrlScope] Bind context.
/// - **L4** host surfaces never appear as nodes (requested via host functions).
///
/// Events bubble out through [RrlHost.onEvent] as
/// `event { nodeId, kind }` per PROTOCOL §3.2; per-node failures collapse to
/// an inline error box instead of taking the tree down (V12 障害隔離).
library;

export 'src/budget.dart';
export 'src/geometry.dart';
export 'src/host.dart';
export 'src/registry.dart';
export 'src/renderer.dart';
export 'src/svg_lite.dart';
