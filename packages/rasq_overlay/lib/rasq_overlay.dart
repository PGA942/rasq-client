/// RASQ Overlay Manager.
///
/// Every overlay request (app or plugin) goes through [OverlayManager]
/// (原典: UI_Elements「Overlay Manager」). It encodes the z-order, the
/// simultaneous-display rules, the close behaviours and the conflict rules
/// as data, and [OverlayHost] renders the resulting stack above the content.
library;

export 'src/fow.dart';
export 'src/overlay_layer.dart';
export 'src/overlay_entry.dart';
export 'src/overlay_manager.dart';
export 'src/overlay_host.dart';
export 'src/overlay_scope.dart';
export 'src/presets.dart';
export 'src/tethered_panel.dart';
