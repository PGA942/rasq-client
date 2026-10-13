import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

/// もう 1 カラム (D-472、「さらに 1 カラム開く」): 幅の広い画面(≥ [RasqSizes.tabletBreakpoint])で、カラムの中のページ /
/// 右のカラムの Swing が開く画面(落書きの編集画面 = `media.editor.open`)を、そのカラムの**隣に足したカラム**に出す。
/// 開いたページは隠さず(D-413 のカラムの置き換え [ColumnTakeoverStore] と違い、隣のカラムの中身も残したまま)、全画面のルートにもしない。
///
/// - シェル([RasqShell] の幅の広い並び)が [afterColumn](0 = 第2カラム / 1 = 第3カラム)の右に置く。足したぶん、ほかのカラムは
///   「カラムの幅」の比のまま縮む([extraColumnWidth])。
/// - 狭い画面に変わったら、シェルが全画面に重ねて出す(中身は [ExtraColumn.key] で同じ State のまま移す)。
/// - 中身は自分の [Navigator] の中で動く(シート・確認などもこのカラムの中)。閉じるのは [ExtraColumnScope.closeOf] か
///   [ExtraColumnStore.close]。最後のページを `Navigator.pop` しても閉じる。
@immutable
class ExtraColumn {
  ExtraColumn({required this.id, required this.afterColumn, required this.builder}) : done = Completer<Object?>();
  final String id;

  /// どのカラムの右に置くか(開いた画面のあるカラム)。
  final int afterColumn;
  final WidgetBuilder builder;
  final Completer<Object?> done;

  /// 中身の State を、幅の広い並び ↔ 狭い画面の重ねで移しても保つための鍵。
  final GlobalKey key = GlobalKey(debugLabel: 'extraColumn');

  /// 開いたときに中身へ移すフォーカス(開いた画面が前に出て、キーボードの入力を受ける)。
  final FocusScopeNode focus = FocusScopeNode(debugLabel: 'extraColumn');
}

class ExtraColumnStore extends Notifier<ExtraColumn?> {
  @override
  ExtraColumn? build() => null;

  /// [afterColumn] の右にもう 1 カラム開いて [builder] を出す。ほかのものが開いていれば、それは閉じる(null で終わる)。
  Future<T?> open<T>({required String id, required int afterColumn, required WidgetBuilder builder}) {
    final prev = state;
    final c = ExtraColumn(id: id, afterColumn: afterColumn, builder: builder);
    state = c;
    _finish(prev, null);
    return c.done.future.then((v) => v is T ? v : null);
  }

  /// 開いているものを閉じる([id] を渡したら、それが開いているときだけ)。
  /// 組み立ての最中(開いたページの dispose から閉じるときなど)は、結果だけ先に返し、外すのはそのフレームのあと。
  void close({String? id, Object? result}) {
    final c = state;
    if (c == null || (id != null && c.id != id)) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (!c.done.isCompleted) c.done.complete(result);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (identical(state, c)) close(id: c.id, result: result);
      });
      return;
    }
    state = null;
    _finish(c, result);
  }

  void _finish(ExtraColumn? c, Object? result) {
    if (c == null) return;
    if (!c.done.isCompleted) c.done.complete(result);
    // 外したあとのフレームで捨てる(いま組み立て中の木がまだ持っている)。
    WidgetsBinding.instance.addPostFrameCallback((_) => c.focus.dispose());
  }
}

final extraColumnProvider = NotifierProvider<ExtraColumnStore, ExtraColumn?>(ExtraColumnStore.new);

/// 足したカラムの幅: 中身の幅(レールを除く)の 36%、320〜520。残りを「カラムの幅」の比で分ける。
double extraColumnWidth(double content) => (content * 0.36).clamp(320.0, 520.0).toDouble().clamp(0.0, content / 2).toDouble();

/// 足したカラムの中から使う: 閉じる。
class ExtraColumnScope extends InheritedWidget {
  const ExtraColumnScope({super.key, required this.column, required this.onClose, required super.child});
  final ExtraColumn column;
  final void Function([Object? result]) onClose;

  static ExtraColumnScope? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<ExtraColumnScope>();

  /// 足したカラムを閉じる。カラムの外なら false。
  static bool closeOf(BuildContext context, [Object? result]) {
    final s = maybeOf(context);
    if (s == null) return false;
    s.onClose(result);
    return true;
  }

  @override
  bool updateShouldNotify(ExtraColumnScope oldWidget) => oldWidget.column != column;
}

/// 足したカラムの中身(シェルが置く)。
class ExtraColumnView extends ConsumerWidget {
  const ExtraColumnView({super.key, required this.column});
  final ExtraColumn column;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KeyedSubtree(
      key: column.key,
      child: ExtraColumnScope(
        column: column,
        onClose: ([result]) => ref.read(extraColumnProvider.notifier).close(id: column.id, result: result),
        child: FocusScope(node: column.focus, autofocus: true, child: _ExtraColumnNavigator(column: column)),
      ),
    );
  }
}

class _ExtraColumnNavigator extends StatefulWidget {
  const _ExtraColumnNavigator({required this.column});
  final ExtraColumn column;

  @override
  State<_ExtraColumnNavigator> createState() => _ExtraColumnNavigatorState();
}

class _ExtraColumnNavigatorState extends State<_ExtraColumnNavigator> {
  final _nav = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // 開いた画面を前に出す(ほかのカラムの入力欄からフォーカスを移す)。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.column.focus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return HeroControllerScope.none(
      child: NavigatorPopHandler(
        onPopWithResult: (_) => _nav.currentState?.maybePop(),
        child: Navigator(
          key: _nav,
          onGenerateInitialRoutes: (_, _) {
            final page = PageRouteBuilder<Object?>(
              settings: RouteSettings(name: widget.column.id),
              pageBuilder: (ctx, _, _) => Builder(builder: widget.column.builder),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            );
            // 中身のページを `Navigator.pop(result)` で閉じた = カラムを閉じる(結果ごと)。下に空の台を敷いて、Navigator を空にしない。
            final scope = ExtraColumnScope.maybeOf(context);
            unawaited(page.popped.then((result) => scope?.onClose(result)));
            return [PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox.shrink(), transitionDuration: Duration.zero), page];
          },
        ),
      ),
    );
  }
}
