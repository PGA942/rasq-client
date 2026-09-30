import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../app/providers.dart';
import '../backend/rasq_account.dart';
import '../features/child_safe/child_safe_providers.dart' show childGateProvider;
import '../features/child_safe/child_safe_screens.dart' show ChildSafeWindowBanner;
import '../features/plugins/sideload_trust.dart' show ownDevKeyFingerprintsProvider;
import '../session/sns_share.dart' show snsShareProvider;
import '../features/notifications/notifications_screen.dart';
import '../features/plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import 'column_layout.dart';
import 'nav.dart';
import 'pane_swipe_back.dart';
import 'sidebar.dart';
import 'third_column.dart';

/// App shell: layout (モバイル / タブレット) and global nav. Overlays are
/// rendered by [AppOverlayRoot] above the whole navigator.
///
/// * < 840dp: header + content + bottom global nav.
/// * ≥ 840dp: fixed sidebar rail + main pane + third pane (検索 or 1つ前の画面);
///   VC pip docks to the bottom of the third pane (ワイヤーフレーム「タブレット」).
class RasqShell extends ConsumerWidget {
  const RasqShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // アカウントバンドル (D-087) をサーバーへ同期し続ける。シェルは常時
    // 生きているので、ここで 1 度 watch しておけばログインの増減に追随する。
    // 接続先が未設定なら何もしない。
    ref.watch(orgateBundleSyncProvider);
    // 自分の開発者鍵の指紋 (D-306) を起動時から取っておく(サイドロードの段を決める。変わってもシェルは作り直さない)。
    ref.listen(ownDevKeyFingerprintsProvider, (_, _) {});
    // SNS のアクセストークンの端末間共有 (D-319): 起動から見回りを続ける(新しい端末の承認の問い / 本体との同期)。
    ref.listen(snsShareProvider, (_, _) {});
    return LayoutBuilder(builder: (context, constraints) {
      final tablet = constraints.maxWidth >= RasqSizes.tabletBreakpoint;
      return tablet ? _TabletLayout(shell: navigationShell) : _MobileLayout(shell: navigationShell);
    });
  }

  static void openSidebar(BuildContext context, WidgetRef ref) {
    RasqSidebar.open(ref.read(overlayManagerProvider));
  }
}

/// タブのルート(チャイルドセーフの関所に問い合わせる)。
String _tabPath(RasqNavTab t) => switch (t) { RasqNavTab.home => '/home', RasqNavTab.search => '/search', RasqNavTab.vc => '/vc', RasqNavTab.notifications => '/notifications', RasqNavTab.dm => '/dm' };

/// チャイルドセーフ (D-307): 止めているタブは薄く出し、押したら理由を出す(ルーターも止める)。
String? _tabBlocked(WidgetRef ref, RasqNavTab t) => ref.watch(childGateProvider).routeBlockReason(_tabPath(t));

void _goTab(WidgetRef ref, StatefulNavigationShell shell, int i) {
  final reason = ref.read(childGateProvider).routeBlockReason(_tabPath(RasqNavTab.values[i]));
  if (reason != null) {
    ref.read(rootMessengerKeyProvider).currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(reason)));
    return;
  }
  shell.goBranch(i, initialLocation: i == shell.currentIndex);
}

Widget _greyed(bool blocked, Widget child) => blocked ? Opacity(opacity: 0.38, child: child) : child;

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      // 見守りの時間の帯 (D-307)。
      body: Column(children: [const ChildSafeWindowBanner(), Expanded(child: shell)]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.onSurface, width: 1.2))),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => _goTab(ref, shell, i),
          destinations: [
            for (final t in RasqNavTab.values)
              NavigationDestination(
                icon: _greyed(_tabBlocked(ref, t) != null, _LongPressable(tab: t, child: _navIcon(t, selected: false))),
                selectedIcon: _LongPressable(tab: t, child: _navIcon(t, selected: true)),
                label: t.label,
                tooltip: _tabBlocked(ref, t) ?? t.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// Nav glyphs: AsTell uses the brand mark (特殊なコンポーネント置き場), the rest
/// Material icons until the RASQ icon font lands.
Widget _navIcon(RasqNavTab t, {required bool selected}) => t == RasqNavTab.vc ? RasqAsTellIcon(size: 26, selected: selected) : Icon(selected ? t.selectedIcon : t.icon);

/// 通知 / DM ボタン長押し → 一括既読・通知オフ のドロップダウン (ワイヤーフレーム注釈).
class _LongPressable extends ConsumerWidget {
  const _LongPressable({required this.tab, required this.child});
  final RasqNavTab tab;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tab != RasqNavTab.notifications && tab != RasqNavTab.dm) return child;
    return GestureDetector(
      onLongPress: () {
        final box = context.findRenderObject() as RenderBox;
        showNotificationQuickMenu(ref, box.localToGlobal(Offset.zero) & box.size);
      },
      child: child,
    );
  }
}

class _TabletLayout extends ConsumerWidget {
  const _TabletLayout({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // ペインモデル (D-057): 第3カラムにページが開いている間は第2カラムが
    // 小型カラムへ縮み、第3カラムが大型に広がる。空のときは逆。
    // 小型 / 大型の幅は設定「カラムの幅」 (D-320) の比で決める。
    final occupied = ref.watch(thirdColumnProvider) != null;
    final layout = ref.watch(columnLayoutProvider);
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final split = splitColumns(constraints.maxWidth - 72, layout);
        final col2Width = occupied ? split.small : split.large;
        return Row(children: [
          // Sidebar rail (何も開いてない時はサイドバー).
          Container(
            width: 72,
            decoration: BoxDecoration(border: Border(right: BorderSide(color: scheme.outlineVariant))),
            child: SafeArea(
              child: Column(children: [
                const SizedBox(height: RasqSpacing.lg),
                for (final t in RasqNavTab.values)
                  IconButton(
                    tooltip: _tabBlocked(ref, t) ?? t.label,
                    isSelected: shell.currentIndex == t.index,
                    onPressed: () => _goTab(ref, shell, t.index),
                    icon: _greyed(_tabBlocked(ref, t) != null, _navIcon(t, selected: false)),
                    selectedIcon: _navIcon(t, selected: true),
                  ),
              ]),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: col2Width,
            // 左カラムも右へスワイプで戻る (D-388): タブの中のページは router のルートだが、幅の広い画面では端末の
            // 「スワイプで戻る」が効かなかった(デスクトップ / タブレットの横)。戻れるページがあるときだけ。
            child: ClipRect(
              child: Column(children: [
                const ChildSafeWindowBanner(),
                Expanded(
                  child: PaneSwipeBack(
                    key: const ValueKey('pane.swipe.left'),
                    canBack: () => GoRouter.of(context).canPop(),
                    onBack: () {
                      final router = GoRouter.of(context);
                      if (router.canPop()) router.pop();
                    },
                    child: shell,
                  ),
                ),
              ]),
            ),
          ),
          // 第3カラム (D-056/D-057): 空のときは検索(設定で変更可)。ページが
          // 開くと広がり、M5c 以降は FOW の移動先になる。
          Expanded(
            child: Container(
              decoration: BoxDecoration(border: Border(left: BorderSide(color: scheme.outlineVariant))),
              // VC ミニプレイヤーのスタブは撤去 (D-178): AsTell は FOW で動く。
              child: const SafeArea(child: ThirdColumnView()),
            ),
          ),
        ]);
      }),
    );
  }
}
