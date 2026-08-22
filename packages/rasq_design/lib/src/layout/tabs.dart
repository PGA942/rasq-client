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
  }) : items = mode == RasqTabsMode.extensible ? items.take(maxExtensible).toList() : items;

  static const int maxExtensible = 10;
  static const int scrollThreshold = 5;

  final List<RasqTabItem> items;
  final TabController? controller;
  final RasqTabsMode mode;
  final ValueChanged<int>? onTap;
  final bool showChevron;

  bool get isScrollable => mode == RasqTabsMode.extensible && items.length >= scrollThreshold;

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
        onTap: onTap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        tabs: [
          for (var i = 0; i < items.length; i++)
            Tab(
              height: RasqSizes.minTap,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (showChevron && ctrl.index == i) const Padding(padding: EdgeInsets.only(right: 2), child: Icon(Icons.keyboard_arrow_down, size: 18)),
                if (items[i].icon != null) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(items[i].icon, size: 18)),
                Text(items[i].label, style: RasqTypography.tab),
              ]),
            ),
        ],
      ),
    );
  }
}
