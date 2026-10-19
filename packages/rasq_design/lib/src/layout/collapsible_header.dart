import 'package:flutter/material.dart';

/// コラプシブルヘッダー＋リスト系: the top tile scrolls away, the tab bar pins.
/// Used by user pages, plugin pages, threads, reactions.
class RasqCollapsibleTabScaffold extends StatelessWidget {
  const RasqCollapsibleTabScaffold({
    super.key,
    required this.header,
    required this.tabs,
    required this.tabViews,
    this.controller,
    this.pinnedTabsBackground,
    this.nestedScrollKey,
    this.tabViewPhysics,
  }) : assert(tabViews.length > 0);

  /// The collapsible top tile (e.g. UserTileLarge).
  final Widget header;

  /// Pinned tab bar (usually [RasqTabs]).
  final PreferredSizeWidget tabs;
  final List<Widget> tabViews;
  final TabController? controller;
  final Color? pinnedTabsBackground;

  /// 中の [NestedScrollView] のキー (D-514)。`GlobalKey<NestedScrollViewState>` を渡すと、タブの一覧の位置
  /// (`innerController`)を外から見て、いちばん上へ送れる。
  final Key? nestedScrollKey;

  /// タブの中身の横のスワイプ (D-514)。`NeverScrollableScrollPhysics` で、指をチャートに置いている間などに止める。
  final ScrollPhysics? tabViewPhysics;

  @override
  Widget build(BuildContext context) {
    final bg = pinnedTabsBackground ?? Theme.of(context).colorScheme.surface;
    Widget body(TabController ctrl) => NestedScrollView(
          key: nestedScrollKey,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverToBoxAdapter(child: header),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedTabsDelegate(tabs, bg),
            ),
          ],
          body: TabBarView(controller: ctrl, physics: tabViewPhysics, children: tabViews),
        );
    if (controller != null) return body(controller!);
    return DefaultTabController(length: tabViews.length, child: Builder(builder: (context) => body(DefaultTabController.of(context))));
  }
}

class _PinnedTabsDelegate extends SliverPersistentHeaderDelegate {
  _PinnedTabsDelegate(this.tabs, this.background);
  final PreferredSizeWidget tabs;
  final Color background;

  @override
  double get minExtent => tabs.preferredSize.height;
  @override
  double get maxExtent => tabs.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => ColoredBox(color: background, child: tabs);

  @override
  bool shouldRebuild(covariant _PinnedTabsDelegate old) => old.tabs != tabs || old.background != background;
}
