import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

/// 画面ごとのスクロール位置 (D-504)。
///
/// TL のタブ / 通知や DM のタブを切り替えて戻ったとき、第3カラムのページが第2カラムへ移ったとき(作り直される)、
/// 関連 TL のように隠れると捨てる(重いので生かしておかない、D-508)画面に戻ったときに、**前に見ていた位置から**始める。
/// 位置は TL / 画面の id ごと(アカウントごとに分ける、[scrollMemoryKey])に、動くたびに覚える(メモリーの中だけ、
/// アプリを閉じれば忘れる)。PageStorage はルート(Navigator のページ)ごとに分かれるので、カラムをまたぐと引き継げない。
@immutable
class ScrollMark {
  const ScrollMark(this.offset, {this.anchor});
  final double offset;

  /// 位置の基準(TL の中心の投稿 D-298)。基準が変わっていれば、[offset] は使えない。
  final String? anchor;
}

class ScrollMemory {
  final _marks = <String, ScrollMark>{};

  ScrollMark? operator [](String id) => _marks[id];

  void save(String id, double offset, {String? anchor}) => _marks[id] = ScrollMark(offset, anchor: anchor);

  void forget(String id) => _marks.remove(id);
}

final scrollMemoryProvider = Provider<ScrollMemory>((ref) => ScrollMemory());

/// 覚える id: いまのアカウント(総合表示なら `bundle`)ごとに分ける。
String scrollMemoryKey(WidgetRef ref, String id) => '${ref.read(bundleViewProvider) ? 'bundle' : ref.read(currentAccountProvider)?.key}|$id';

/// [memory] の [id] の位置から始め、動くたびに覚える ScrollController (D-504)。
///
/// 一覧が作り直される(読み込み中 → 中身)たびに、覚えた位置から始める。[id] は呼ぶたびに求める(アカウントを切り替えたら別の位置)。
/// [anchor] を渡すと、位置と一緒に基準も覚える([ScrollMark.anchor])。
class RememberedScrollController extends ScrollController {
  RememberedScrollController({required this.memory, required this.id, this.anchor, super.debugLabel}) : super(keepScrollOffset: false) {
    addListener(_save);
  }

  final ScrollMemory memory;
  final String Function() id;
  final String? Function()? anchor;

  /// 覚えた位置(無ければ 0)。
  double get rememberedOffset => memory[id()]?.offset ?? 0;

  void _save() {
    if (positions.length != 1 || !position.hasPixels) return;
    memory.save(id(), position.pixels, anchor: anchor?.call());
  }

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) => ScrollPositionWithSingleContext(
        physics: physics,
        context: context,
        initialPixels: oldPosition?.hasPixels == true ? oldPosition!.pixels : rememberedOffset,
        keepScrollOffset: false,
        oldPosition: oldPosition,
        debugLabel: debugLabel,
      );
}

/// 一覧に [RememberedScrollController] を渡す(State を持たない一覧のため)。[id] = 画面の中の一覧の名前(アカウントは足す)。
class RememberScroll extends ConsumerStatefulWidget {
  const RememberScroll({super.key, required this.id, required this.builder});
  final String id;
  final Widget Function(BuildContext context, ScrollController controller) builder;

  @override
  ConsumerState<RememberScroll> createState() => _RememberScrollState();
}

class _RememberScrollState extends ConsumerState<RememberScroll> {
  late final RememberedScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RememberedScrollController(memory: ref.read(scrollMemoryProvider), id: () => scrollMemoryKey(ref, widget.id));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
