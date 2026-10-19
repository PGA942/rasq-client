import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nav.dart';

/// 開いている画面のボタン(下のナビ / レール)をもう一度押すと、その画面をいちばん上へ (D-505、iOS / X と同じ)。
///
/// タブの一番上の画面(ホーム / 検索 / ASTell / 通知 / DM)を [ScrollToTopScope] で包む(router)。シェルは、押したタブが
/// すでに開いていて、そのタブの中で別のページを開いていなければ(開いていれば今までどおり一番上の画面へ戻る)、
/// [ScrollToTopHub.scrollToTop] を呼ぶ。包んだ画面の中の、**いま見えている**縦の一覧を全部いちばん上へ送る
/// ([scrollToTopIn]。隠れたタブ = [TickerMode] が切れている / [Offstage] の中は動かさない。前の位置は D-504 で覚えたまま)。
/// TL は中心より上に足した新しい投稿 (D-298) のいちばん上まで送る(いちばん新しい投稿が見える)。
class ScrollToTopHub {
  final _scopes = <RasqNavTab, Set<_ScrollToTopScopeState>>{};

  /// [tab] の画面をいちばん上へ。動かしたものがあれば true。
  bool scrollToTop(RasqNavTab tab) {
    var moved = false;
    for (final s in [...?_scopes[tab]]) {
      if (s.mounted && scrollToTopIn(s.context)) moved = true;
    }
    return moved;
  }

  void _add(RasqNavTab tab, _ScrollToTopScopeState s) => _scopes.putIfAbsent(tab, () => {}).add(s);
  void _remove(RasqNavTab tab, _ScrollToTopScopeState s) => _scopes[tab]?.remove(s);
}

final scrollToTopHubProvider = Provider<ScrollToTopHub>((ref) => ScrollToTopHub());

/// [tab] の一番上の画面を包む。
class ScrollToTopScope extends ConsumerStatefulWidget {
  const ScrollToTopScope({super.key, required this.tab, required this.child});
  final RasqNavTab tab;
  final Widget child;

  @override
  ConsumerState<ScrollToTopScope> createState() => _ScrollToTopScopeState();
}

class _ScrollToTopScopeState extends ConsumerState<ScrollToTopScope> {
  late final ScrollToTopHub _hub;

  @override
  void initState() {
    super.initState();
    _hub = ref.read(scrollToTopHubProvider).._add(widget.tab, this);
  }

  @override
  void didUpdateWidget(ScrollToTopScope old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) {
      _hub
        .._remove(old.tab, this)
        .._add(widget.tab, this);
    }
  }

  @override
  void dispose() {
    _hub._remove(widget.tab, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// [context] の下の、いま見えている縦の一覧を全部いちばん上へ送る。動かしたものがあれば true。
/// 遠いとき(画面 4 枚ぶんより下)は、1 枚ぶん手前まで飛んでから送る(長い TL をずっと送り続けない)。
bool scrollToTopIn(BuildContext context, {Duration duration = const Duration(milliseconds: 350)}) {
  var moved = false;
  void visit(Element e) {
    final w = e.widget;
    // 隠れているもの(開いていないタブ / 重ねた画面の下)は動かさない。
    if (w is TickerMode && !w.enabled) return;
    if (w is Offstage && w.offstage) return;
    if (e is StatefulElement && e.state is ScrollableState) {
      final s = e.state as ScrollableState;
      final p = s.position;
      if (axisDirectionToAxis(s.axisDirection) == Axis.vertical && p.hasPixels && p.hasContentDimensions && p.pixels > p.minScrollExtent + 0.5) {
        final page = p.hasViewportDimension ? p.viewportDimension : 600.0;
        if (p.pixels - p.minScrollExtent > page * 4) p.jumpTo(p.minScrollExtent + page);
        p.animateTo(p.minScrollExtent, duration: duration, curve: Curves.easeOutCubic);
        moved = true;
      }
    }
    e.visitChildElements(visit);
  }

  context.visitChildElements(visit);
  return moved;
}

/// タブの中身(TabBarView の 1 ページ)のうち、**いま見えているものだけ** [TickerMode] を入れたままにする (D-505 / D-508)。
///
/// TabBarView は開いたタブの中身を生かしたまま(AutomaticKeepAlive)隠すが、隠れたページの [TickerMode] は入ったまま。
/// 隠れたページで切ると: いちばん上へ送る ([scrollToTopIn]) の対象から外れ、Riverpod の監視が止まる(隠れた TL は読み直さない、D-508)。
/// 指で横に送っている途中は、隣のページも見えているとみなす。
class VisibleTabPage extends StatefulWidget {
  const VisibleTabPage({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<VisibleTabPage> createState() => _VisibleTabPageState();
}

class _VisibleTabPageState extends State<VisibleTabPage> {
  Animation<double>? _animation;
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final a = DefaultTabController.maybeOf(context)?.animation;
    if (a == _animation) return;
    _animation?.removeListener(_update);
    _animation = a?..addListener(_update);
    _visible = _compute();
  }

  @override
  void didUpdateWidget(VisibleTabPage old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _visible = _compute();
  }

  @override
  void dispose() {
    _animation?.removeListener(_update);
    super.dispose();
  }

  bool _compute() {
    final a = _animation;
    return a == null || (a.value - widget.index).abs() < 1.0;
  }

  void _update() {
    final v = _compute();
    if (v != _visible) setState(() => _visible = v);
  }

  @override
  Widget build(BuildContext context) => TickerMode(enabled: _visible, child: widget.child);
}
