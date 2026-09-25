import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../app/providers.dart';
import '../app/router.dart';
import 'column_layout.dart';
import 'third_column.dart';

/// stick FOW の根本を持ち上げる量 = フッターメニューの実高さ (D-047/D-049)。
/// 実高さ = NavigationBar のテーマ高さ + 上枠線 1.2(rasq_shell)。
/// フッターが見えていないとき(タブレット幅 ≥840dp、またはタブ外の
/// アプリ直下ページ D-038)は持ち上げない (D-050)。
/// 高さ段階の実測(コンポーザーの「全部ピッタリ」計算)も同じ値を使う。
double fowDockInsetOf(BuildContext ctx, GoRouter router) {
  if (MediaQuery.sizeOf(ctx).width >= 840) return 0;
  final loc = router.routerDelegate.currentConfiguration.uri.path;
  final inTab = [Routes.home, Routes.search, Routes.vc, Routes.notifications, Routes.dm].any(loc.startsWith);
  if (!inTab) return 0;
  return RasqSizes.navHeight + 1.2 + MediaQuery.paddingOf(ctx).bottom;
}

/// アプリヘッダーの実高さ (D-065): FOW を「ヘッダーに下付き」で付けるときの
/// 上端 = ステータスバー + ページヘッダー高さ。
double fowTopInsetOf(BuildContext ctx) => MediaQuery.paddingOf(ctx).top + RasqSizes.headerHeight;

/// FOW の列スロット (D-062): タブレット幅では第2 / 第3カラムの幾何。840px 未満は空(単一スロット = 中央)。
/// RAi の入力タイルのカラム移動 (D-233) も同じスロットを使う。幅はシェルと同じ [splitColumns] (D-320)。
List<FowColumnSlot> fowColumnSlotsOf(BuildContext ctx, {required bool thirdColumnOccupied, required ColumnLayout layout}) {
  final total = MediaQuery.sizeOf(ctx).width;
  if (total < 840) return const <FowColumnSlot>[];
  final content = total - 72;
  final split = splitColumns(content, layout);
  final col2W = thirdColumnOccupied ? split.small : split.large;
  return [
    FowColumnSlot(x: 72, width: col2W),
    FowColumnSlot(x: 72 + col2W, width: content - col2W),
  ];
}

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
            fowDockInset: (ctx) => fowDockInsetOf(ctx, ref.read(routerProvider)),
            fowTopInset: fowTopInsetOf,
            // FOW の上辺はステータスバー + 32px より下 (D-178): ハンドルがコントロールセンター等に吸われない。
            fowTopClearance: (ctx) => MediaQuery.paddingOf(ctx).top + 32,
            // 壁付けピン (D-063) は小型カラムの幅で壁側カラムに張り付く(幅は設定「カラムの幅」 D-320)。
            fowPinnedWidth: _pinnedWidth(context, ref.watch(columnLayoutProvider)),
            // FOW の列スロット (D-062): タブレット幅では第2/第3カラムの幾何を
            // 供給し、FOW はカラム中心に揃いカラム幅に収まる。
            fowColumns: (ctx) => fowColumnSlotsOf(ctx, thirdColumnOccupied: ref.read(thirdColumnProvider) != null, layout: ref.read(columnLayoutProvider)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 壁付けピンの幅 = 小型カラムの幅 (D-320)。840px 未満はこれまでの検索ホーム幅。
double _pinnedWidth(BuildContext context, ColumnLayout layout) {
  final total = MediaQuery.sizeOf(context).width;
  if (total < 840) return kSearchHomeColumnWidth;
  return splitColumns(total - 72, layout).small;
}
