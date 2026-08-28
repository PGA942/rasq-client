import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../app/providers.dart';

/// Wraps the whole app navigator (tab shell *and* root-level pages such as
/// login / settings / catalog) so every overlay request — from any screen or
/// plugin — is rendered by the single [OverlayHost].
///
/// Escape closes the topmost dismissible overlay (desktop/web); the back
/// gesture is handled by [OverlayHost]'s PopScope.
class AppOverlayRoot extends ConsumerWidget {
  const AppOverlayRoot({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(overlayManagerProvider);
    return OverlayScope(
      manager: manager,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => manager.handleBack()},
        child: Focus(
          autofocus: true,
          skipTraversal: true,
          child: OverlayHost(
            manager: manager,
            // stick FOW の根本 = フッターメニュー(グローバルナビ)の上 (D-047)。
            // タブレット幅(≥840dp)は下部ナビが無いので持ち上げない。
            fowDockInset: (ctx) => MediaQuery.sizeOf(ctx).width >= 840 ? 0 : 80 + 1.2 + MediaQuery.paddingOf(ctx).bottom,
            child: child,
          ),
        ),
      ),
    );
  }
}
