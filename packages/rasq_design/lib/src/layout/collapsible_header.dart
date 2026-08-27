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
  }) : assert(tabViews.length > 0);

  /// The collapsible top tile (e.g. UserTileLarge).
  final Widget header;

  /// Pinned tab bar (usually [RasqTabs]).
  final PreferredSizeWidget tabs;
  final List<Widget> tabViews;
  final TabController? controller;
  final Color? pinnedTabsBackground;

  @override
  Widget build(BuildContext context) {
    final bg = pinnedTabsBackground ?? Theme.of(context).colorScheme.surface;
    Widget body(TabController ctrl) => NestedScrollView(
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
          body: TabBarView(controller: ctrl, children: tabViews),
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
