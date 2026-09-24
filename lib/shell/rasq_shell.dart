import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../app/providers.dart';
import '../backend/rasq_account.dart';
import '../features/plugins/sideload_trust.dart' show ownDevKeyFingerprintsProvider;
import '../features/notifications/notifications_screen.dart';
import 'nav.dart';
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
    return LayoutBuilder(builder: (context, constraints) {
      final tablet = constraints.maxWidth >= RasqSizes.tabletBreakpoint;
      return tablet ? _TabletLayout(shell: navigationShell) : _MobileLayout(shell: navigationShell);
    });
  }

  static void openSidebar(BuildContext context, WidgetRef ref) {
    RasqSidebar.open(ref.read(overlayManagerProvider));
  }
}

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.onSurface, width: 1.2))),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            for (final t in RasqNavTab.values)
              NavigationDestination(
                icon: _LongPressable(tab: t, child: _navIcon(t, selected: false)),
                selectedIcon: _LongPressable(tab: t, child: _navIcon(t, selected: true)),
                label: t.label,
                tooltip: t.label,
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
    // 検索ホーム幅(狭)へ縮み、第3カラムが広がる。空のときは逆。
    final occupied = ref.watch(thirdColumnProvider) != null;
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final total = constraints.maxWidth - 72;
        final col2Width = (occupied ? kSearchHomeColumnWidth : total - kSearchHomeColumnWidth).clamp(kSearchHomeColumnWidth, total - kSearchHomeColumnWidth < kSearchHomeColumnWidth ? total / 2 : total - kSearchHomeColumnWidth);
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
                    tooltip: t.label,
                    isSelected: shell.currentIndex == t.index,
                    onPressed: () => shell.goBranch(t.index, initialLocation: t.index == shell.currentIndex),
                    icon: _navIcon(t, selected: false),
                    selectedIcon: _navIcon(t, selected: true),
                  ),
              ]),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: col2Width.toDouble(),
            child: ClipRect(child: shell),
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
