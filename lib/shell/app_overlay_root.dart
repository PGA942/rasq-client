import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../app/providers.dart';

/// stick FOW の根本を持ち上げる量 = フッターメニューの実高さ (D-047/D-049)。
/// 実高さ = NavigationBar のテーマ高さ + 上枠線 1.2(rasq_shell)。
/// タブレット幅(≥840dp)は下部ナビが無いので持ち上げない。
/// 高さ段階の実測(コンポーザーの「全部ピッタリ」計算)も同じ値を使う。
double fowDockInsetOf(BuildContext ctx) => MediaQuery.sizeOf(ctx).width >= 840 ? 0 : RasqSizes.navHeight + 1.2 + MediaQuery.paddingOf(ctx).bottom;

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
          child: OverlayHost(manager: manager, fowDockInset: fowDockInsetOf, child: child),
        ),
      ),
    );
  }
}
