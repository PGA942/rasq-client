import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'third_column.dart' show PaneScope;

/// カラムを置き換えて開く画面 (D-413): 幅の広い画面(≥840dp)で、ボタンを押したカラム(第2カラム = 0 / 第3カラム = 1)の中身の
/// **上に**画面を重ねる。下のカラムの中身(ホームの TL・第3カラムのページ)は作り直さずに残し、閉じると元に戻る。
///
/// 重ねた画面は自分の [Navigator] の中で動く(シート・編集画面などもそのカラムの中に開き、`Navigator.pop` もカラムの中で
/// 閉じる)。Swing を作る画面 (D-410 の 2 段) がこれで開く。狭い画面では使わない(呼ぶ側が全画面のルートへ)。
@immutable
class ColumnTakeover {
  const ColumnTakeover({required this.id, required this.builder, required this.done});
  final String id;
  final WidgetBuilder builder;
  final Completer<Object?> done;
}

class ColumnTakeoverStore extends Notifier<Map<int, ColumnTakeover>> {
  @override
  Map<int, ColumnTakeover> build() => const {};

  /// [column] に [builder] の画面を重ねる。そのカラムに別のものが重なっていれば、それは閉じる(null で終わる)。
  Future<T?> open<T>(int column, {required String id, required WidgetBuilder builder}) {
    final prev = state[column];
    final t = ColumnTakeover(id: id, builder: builder, done: Completer<Object?>());
    state = {...state, column: t};
    if (prev != null && !prev.done.isCompleted) prev.done.complete(null);
    return t.done.future.then((v) => v is T ? v : null);
  }

  /// [column] の重ねた画面を閉じる([id] を渡したら、それが重なっているときだけ)。
  void close(int column, {String? id, Object? result}) {
    final t = state[column];
    if (t == null || (id != null && t.id != id)) return;
    state = {...state}..remove(column);
    if (!t.done.isCompleted) t.done.complete(result);
  }

  /// [id] がどこかのカラムに重なっているか。
  int? columnOf(String id) => state.entries.where((e) => e.value.id == id).firstOrNull?.key;
}

final columnTakeoverProvider = NotifierProvider<ColumnTakeoverStore, Map<int, ColumnTakeover>>(ColumnTakeoverStore.new);

/// 重ねた画面の中から使う: どのカラムか、閉じる。
class ColumnTakeoverScope extends InheritedWidget {
  const ColumnTakeoverScope({super.key, required this.column, required this.takeover, required this.onClose, required super.child});
  final int column;
  final ColumnTakeover takeover;
  final void Function([Object? result]) onClose;

  static ColumnTakeoverScope? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<ColumnTakeoverScope>();

  /// 重ねた画面を閉じる。カラムの外(全画面のルート)なら false。
  static bool closeOf(BuildContext context, [Object? result]) {
    final s = maybeOf(context);
    if (s == null) return false;
    s.onClose(result);
    return true;
  }

  @override
  bool updateShouldNotify(ColumnTakeoverScope oldWidget) => oldWidget.takeover != takeover || oldWidget.column != column;
}

/// カラムの中身([child])の上に、そのカラムの重ねた画面を出す。シェルが第2 / 第3カラムをこれで包む。
class ColumnTakeoverHost extends ConsumerWidget {
  const ColumnTakeoverHost({super.key, required this.column, required this.child});
  final int column;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(columnTakeoverProvider.select((m) => m[column]));
    return Stack(fit: StackFit.expand, children: [
      // 下の中身は残す(閉じたらそのまま戻る)。重ねている間は触れない・読み上げない。
      Offstage(offstage: t != null, child: TickerMode(enabled: t == null, child: child)),
      if (t != null)
        ColumnTakeoverScope(
          key: ValueKey('column.takeover.$column.${t.id}.${identityHashCode(t)}'),
          column: column,
          takeover: t,
          onClose: ([result]) => ref.read(columnTakeoverProvider.notifier).close(column, id: t.id, result: result),
          child: _TakeoverNavigator(key: ValueKey('column.takeover.$column'), takeover: t),
        ),
    ]);
  }
}

/// 重ねた画面のための Navigator。土台のページの上に [ColumnTakeover.builder] を置き、`Navigator.pop` がカラムの外へ出ないよう
/// 最後のページの pop は「閉じる」に変える。
class _TakeoverNavigator extends StatefulWidget {
  const _TakeoverNavigator({super.key, required this.takeover});
  final ColumnTakeover takeover;

  @override
  State<_TakeoverNavigator> createState() => _TakeoverNavigatorState();
}

class _TakeoverNavigatorState extends State<_TakeoverNavigator> {
  final _nav = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return HeroControllerScope.none(
      // 中に積んだもの(編集画面・シート)は、端末の「戻る」でこの Navigator の中から閉じる。
      child: NavigatorPopHandler(
        onPopWithResult: (_) => _nav.currentState?.maybePop(),
        child: Navigator(
          key: _nav,
          onGenerateInitialRoutes: (_, _) => [
            PageRouteBuilder<void>(
              settings: RouteSettings(name: widget.takeover.id),
              pageBuilder: (ctx, _, _) => Builder(builder: widget.takeover.builder),
              transitionDuration: Duration.zero,
            ),
          ],
        ),
      ),
    );
  }
}

/// ボタンを押した場所のカラム: 重ねた画面の中ならそのカラム、第3カラムの中なら 1、それ以外(第2カラム)は 0。
int takeoverColumnOf(BuildContext context) => ColumnTakeoverScope.maybeOf(context)?.column ?? (PaneScope.maybeOf(context) != null ? 1 : 0);
