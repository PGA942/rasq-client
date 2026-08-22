import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../app/providers.dart';
import 'nav.dart';
import 'sidebar.dart';

/// App shell: layout (モバイル / タブレット), global nav and the OverlayHost.
///
/// * < 840dp: header + content + bottom global nav.
/// * ≥ 840dp: fixed sidebar rail + main pane + third pane (検索 or 1つ前の画面);
///   VC pip docks to the bottom of the third pane (ワイヤーフレーム「タブレット」).
class RasqShell extends ConsumerWidget {
  const RasqShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(overlayManagerProvider);
    return OverlayScope(
      manager: manager,
      child: LayoutBuilder(builder: (context, constraints) {
        final tablet = constraints.maxWidth >= RasqSizes.tabletBreakpoint;
        final content = tablet ? _TabletLayout(shell: navigationShell) : _MobileLayout(shell: navigationShell);
        return OverlayHost(manager: manager, child: content);
      }),
    );
  }

  static void openSidebar(BuildContext context, WidgetRef ref) {
    RasqSidebar.open(ref.read(overlayManagerProvider));
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
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
              NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label, tooltip: t.label),
          ],
        ),
      ),
    );
  }
}

class _TabletLayout extends StatelessWidget {
  const _TabletLayout({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(children: [
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
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.selectedIcon),
                ),
            ]),
          ),
        ),
        Expanded(flex: 5, child: shell),
        // Third pane: 検索 when nothing is open (設定で変更可) — M2 fills this.
        Container(
          width: 320,
          decoration: BoxDecoration(border: Border(left: BorderSide(color: scheme.outlineVariant))),
          child: const _ThirdPanePlaceholder(),
        ),
      ]),
    );
  }
}

class _ThirdPanePlaceholder extends StatelessWidget {
  const _ThirdPanePlaceholder();
  @override
  Widget build(BuildContext context) => Column(children: [
        const Expanded(child: RasqEmptyView(title: '第3カラム', hint: '何も開いてない時は検索(設定で変更可)')),
        Container(
          height: 96,
          margin: const EdgeInsets.all(RasqSpacing.sm),
          decoration: BoxDecoration(color: RasqColors.lightBlue.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
          alignment: Alignment.center,
          child: const Text('VC', style: TextStyle(color: RasqColors.white, fontSize: 32, fontWeight: FontWeight.w300)),
        ),
      ]);
}
