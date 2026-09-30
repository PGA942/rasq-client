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
  const RasqTabItem(this.label, {this.id, this.icon, this.chevron = true, this.dot = false});
  final String label;
  final String? id;
  final IconData? icon;

  /// 選んでいるときに `∨` を付けるか([RasqTabs.showChevron] が true のとき)。押しても何も開かないタブは false。
  final bool chevron;

  /// 名前の右肩の小さな点(一時的に変えている TL など、幅を取らない印)。
  final bool dot;
}

/// Tab bar honouring the 4/5/10 thresholds. The selected tab gets a `v`
/// chevron like the wireframes (「∨引用」「∨フォロワー」).
///
/// StatefulWidget なのはアンカー計測用の GlobalKey を **State(=マウント毎)**
/// に持たせるため — ウィジェットインスタンスに `late final` で持つと、
/// ピン留めヘッダー(SliverPersistentHeader)が同一インスタンスを再マウント
/// する瞬間に「GlobalKey used multiple times」で落ちる。
class RasqTabs extends StatefulWidget implements PreferredSizeWidget {
  RasqTabs({
    super.key,
    required List<RasqTabItem> items,
    this.controller,
    this.mode = RasqTabsMode.extensible,
    this.onTap,
    this.showChevron = true,
    this.onSelectedTabTap,
    this.chevronTooltip,
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

  /// 選んでいるタブの `∨` の名前(RAi の案内が指す、D-384)。
  final String? chevronTooltip;

  bool get isScrollable => mode == RasqTabsMode.extensible && items.length >= scrollThreshold;

  @override
  /// Tab height + TabBar indicator weight (2).
  Size get preferredSize => const Size.fromHeight(RasqSizes.minTap + 2);

  @override
  State<RasqTabs> createState() => _RasqTabsState();
}

class _RasqTabsState extends State<RasqTabs> {
  List<GlobalKey> _keys = const [];

  @override
  void initState() {
    super.initState();
    _rebuildKeys();
  }

  @override
  void didUpdateWidget(RasqTabs old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length) _rebuildKeys();
  }

  void _rebuildKeys() => _keys = [for (var i = 0; i < widget.items.length; i++) GlobalKey(debugLabel: 'tab$i')];

  List<RasqTabItem> get items => widget.items;
  bool get isScrollable => widget.isScrollable;
  bool get showChevron => widget.showChevron;
  ValueChanged<int>? get onTap => widget.onTap;
  void Function(int index, Rect anchor)? get onSelectedTabTap => widget.onSelectedTabTap;
  TabController? get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final ctrl = controller ?? DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        // 押す前に選んでいたタブ(TabBar は onTap の前に index を進めるので、描いたときの値で比べる。
        // previousIndex は同じタブを押し直しても更新されず、別のタブへ移ったあとは ∨ が開かなかった)。
        final selectedAtBuild = ctrl.index;
        return TabBar(
          controller: ctrl,
          isScrollable: isScrollable,
          tabAlignment: isScrollable ? TabAlignment.start : TabAlignment.fill,
          onTap: (i) {
            if (onSelectedTabTap != null && i == selectedAtBuild && i == ctrl.index && items[i].chevron) {
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
                  if (showChevron && items[i].chevron && ctrl.index == i)
                    widget.chevronTooltip == null
                        ? const Icon(Icons.keyboard_arrow_down, size: 16)
                        : Tooltip(message: widget.chevronTooltip!, triggerMode: TooltipTriggerMode.manual, child: const Icon(Icons.keyboard_arrow_down, size: 16)),
                  if (items[i].icon != null) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(items[i].icon, size: 18)),
                  // 点は名前の右肩に重ねる(幅を取らない。等幅のタブで名前が詰まらないように)。
                  Flexible(
                    child: Stack(clipBehavior: Clip.none, children: [
                      Text(items[i].label, style: RasqTypography.tab, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
                      if (items[i].dot) Positioned(right: -6, top: -1, child: Container(key: const ValueKey('tab.dot'), width: 6, height: 6, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle))),
                    ]),
                  ),
                ]),
              ),
          ],
        );
      },
    );
  }
}
