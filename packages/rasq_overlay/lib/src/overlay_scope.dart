import 'package:flutter/widgets.dart';

import 'overlay_manager.dart';

/// Makes an [OverlayManager] available to descendants: `OverlayScope.of(context)`.
class OverlayScope extends InheritedNotifier<OverlayManager> {
  const OverlayScope({super.key, required OverlayManager manager, required super.child}) : super(notifier: manager);

  static OverlayManager of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<OverlayScope>();
    assert(scope != null, 'OverlayScope not found above this context');
    return scope!.notifier!;
  }

  /// Non-listening lookup for callbacks.
  static OverlayManager read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<OverlayScope>();
    assert(scope != null, 'OverlayScope not found above this context');
    return scope!.notifier!;
  }
}
