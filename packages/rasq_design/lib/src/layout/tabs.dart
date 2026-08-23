import 'package:flutter/material.dart';

import '../tokens/sizes.dart';
import '../tokens/typography.dart';

/// Tab mode (原典: タブコンポーネント 2モード).
enum RasqTabsMode {
  /// No plugin-added tabs (ミュート/ブロック・ストア・ブックマーク・レビュー …).
  fixed,

  /// Plugins / standard features may add tabs (TL・通知・ユーザーページ・DM …).
  /// ≤4 items: normal; ≥5 items: horizontally scrollable; max 10.
  extensible,
}

class RasqTabItem {
  const RasqTabItem(this.label, {this.id, this.icon});
  final String label;
  final String? id;
  final IconData? icon;
}

/// Tab bar honouring the 4/5/10 thresholds. The selected tab gets a `v`
/// chevron like the wireframes (「∨引用」「∨フォロワー」).
class RasqTabs extends StatelessWidget implements PreferredSizeWidget {
  RasqTabs({
    super.key,
    required List<RasqTabItem> items,
    this.controller,
    this.mode = RasqTabsMode.extensible,
    this.onTap,
    this.showChevron = true,
    this.onSelectedTabTap,
  }) : items = mode == RasqTabsMode.extensible ? items.take(maxExtensible).toList() : items;

  static const int maxExtensible = 10;
  static const int scrollThreshold = 5;

  final List<RasqTabItem> items;
  final TabController? controller;
  final RasqTabsMode mode;
  final ValueChanged<int>? onTap;
  final bool showChevron;

  /// Tap on the already-selected tab (the one with the `∨`): opens the
  /// sort/filter dropdown. Receives the tab's global rect as anchor.
  final void Function(int index, Rect anchor)? onSelectedTabTap;

  bool get isScrollable => mode == RasqTabsMode.extensible && items.length >= scrollThreshold;

  late final List<GlobalKey> _keys = [for (var i = 0; i < items.length; i++) GlobalKey(debugLabel: 'tab$i')];

  @override
  Size get preferredSize => const Size.fromHeight(RasqSizes.minTap);

  @override
  Widget build(BuildContext context) {
    final ctrl = controller ?? DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) => TabBar(
        controller: ctrl,
        isScrollable: isScrollable,
        tabAlignment: isScrollable ? TabAlignment.start : TabAlignment.fill,
        onTap: (i) {
          if (onSelectedTabTap != null && i == ctrl.previousIndex && i == ctrl.index) {
            final key = _keys[i];
            final box = key.currentContext?.findRenderObject() as RenderBox?;
            if (box != null) onSelectedTabTap!(i, box.localToGlobal(Offset.zero) & box.size);
          }
          onTap?.call(i);
        },
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        tabs: [
          for (var i = 0; i < items.length; i++)
            Tab(
              key: _keys[i],
              height: RasqSizes.minTap,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (showChevron && ctrl.index == i) const Padding(padding: EdgeInsets.only(right: 2), child: Icon(Icons.keyboard_arrow_down, size: 18)),
                if (items[i].icon != null) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(items[i].icon, size: 18)),
                Flexible(child: Text(items[i].label, style: RasqTypography.tab, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis)),
              ]),
            ),
        ],
      ),
    );
  }
}
