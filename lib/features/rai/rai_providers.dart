import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import 'rai_locator.dart';
import 'rai_reference.dart';

/// RAi のモード (D-179): インストラクション(操作を教える、RAi は部品まで移動して指差す)/
/// アシスタント(第二期: LLM。今は枠とトグルだけ、RAi は中央固定)。
enum RaiMode {
  instruction,
  assistant;

  String get label => this == RaiMode.instruction ? 'インストラクション' : 'アシスタント';

  /// バーのモデルチップ(ワイヤーフレーム: 端末内モデル / クラウドモデル)。
  String get modelName => this == RaiMode.instruction ? 'Agents-A1-4B' : 'Qwen3.9 33B A3B';
  IconData get modelIcon => this == RaiMode.instruction ? Icons.smartphone : Icons.language;
}

@immutable
class RaiState {
  const RaiState({
    this.mode = RaiMode.instruction,
    this.open = false,
    this.expanded = true,
    this.asking = false,
    this.busy = false,
    this.query,
    this.bubble,
    this.target,
    this.steps = const [],
    this.stepIndex = 0,
    this.history = const [],
  });

  final RaiMode mode;

  /// バー(+ RAi)を出しているか。
  final bool open;

  /// バーの上段(見出し / 入力)を畳んでいないか。
  final bool expanded;

  /// 入力欄を出しているか(「質問する」)。
  final bool asking;
  final bool busy;
  final String? query;

  /// RAi の吹き出し(null なら RAi は隠れる)。
  final String? bubble;

  /// 指差す部品の矩形(グローバル座標)。null なら中央。
  final Rect? target;
  final List<RaiStep> steps;
  final int stepIndex;
  final List<String> history;

  bool get hasNext => steps.isNotEmpty && stepIndex + 1 < steps.length;

  RaiState copyWith({
    RaiMode? mode,
    bool? open,
    bool? expanded,
    bool? asking,
    bool? busy,
    String? query,
    Object? bubble = _keep,
    Object? target = _keep,
    List<RaiStep>? steps,
    int? stepIndex,
    List<String>? history,
  }) =>
      RaiState(
        mode: mode ?? this.mode,
        open: open ?? this.open,
        expanded: expanded ?? this.expanded,
        asking: asking ?? this.asking,
        busy: busy ?? this.busy,
        query: query ?? this.query,
        bubble: identical(bubble, _keep) ? this.bubble : bubble as String?,
        target: identical(target, _keep) ? this.target : target as Rect?,
        steps: steps ?? this.steps,
        stepIndex: stepIndex ?? this.stepIndex,
        history: history ?? this.history,
      );

  static const _keep = Object();
}

class RaiController extends Notifier<RaiState> {
  @override
  RaiState build() => const RaiState();

  void open({RaiMode? mode, bool asking = false}) => state = state.copyWith(open: true, expanded: true, asking: asking, mode: mode);

  void close() => state = const RaiState();

  void toggleExpanded() => state = state.copyWith(expanded: !state.expanded, asking: false);

  void setAsking(bool v) => state = state.copyWith(asking: v, expanded: true);

  /// モード切り替え: 進行中の手順は捨てる。アシスタントは中央固定。
  void setMode(RaiMode mode) {
    if (mode == state.mode) return;
    state = state.copyWith(mode: mode, bubble: null, target: null, steps: const [], stepIndex: 0);
  }

  void dismissBubble() => state = state.copyWith(bubble: null, target: null, steps: const [], stepIndex: 0);

  /// 「質問する」: インストラクションなら参照から手順を引いて最初の部品へ、
  /// アシスタントは(第二期まで)固定の返事を中央で。
  Future<void> ask(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final history = [q, ...state.history.where((h) => h != q)].take(20).toList();
    state = state.copyWith(query: q, asking: false, busy: true, history: history);
    if (state.mode == RaiMode.assistant) {
      state = state.copyWith(busy: false, bubble: 'アシスタントモード(LLM)は第二期です。いまはインストラクションモードで操作をご案内できます。', target: null, steps: const [], stepIndex: 0);
      return;
    }
    final m = matchInstruction(q);
    if (m == null) {
      state = state.copyWith(busy: false, bubble: 'まだ覚えていない操作です。「投稿」「ログイン」「共有」などで聞いてみてください。', target: null, steps: const [], stepIndex: 0);
      return;
    }
    state = state.copyWith(steps: m.instruction.steps, stepIndex: 0);
    await _showStep(0);
  }

  Future<void> next() async {
    if (!state.hasNext) {
      dismissBubble();
      return;
    }
    await _showStep(state.stepIndex + 1);
  }

  Future<void> _showStep(int i) async {
    final step = state.steps[i];
    state = state.copyWith(stepIndex: i, busy: true);
    // 先に画面を開く(ディープリンク)。
    final route = step.route;
    if (route != null) {
      final router = ref.read(routerProvider);
      // 見えている画面 = 一番上の一致(push で積んだ画面は uri に出ないので辿る)。
      final cur = visibleLocationOf(router.routerDelegate.currentConfiguration);
      if (!cur.startsWith(route)) {
        router.go(route); // 見ていた画面の代わりに(RAi バーは rai 層なので残る)
        await WidgetsBinding.instance.endOfFrame;
      }
    }
    // 部品の矩形を探す(画面遷移直後は数フレーム待つ)。
    Rect? rect;
    if (step.hasTarget) {
      for (var attempt = 0; attempt < 6 && rect == null; attempt++) {
        await WidgetsBinding.instance.endOfFrame;
        if (attempt > 0) await Future<void>.delayed(const Duration(milliseconds: 80));
        rect = locateWidgetRect(tooltip: step.tooltip, text: step.label);
      }
    }
    if (state.stepIndex != i) return; // 途中で別の質問に変わった
    state = state.copyWith(busy: false, bubble: step.text, target: rect);
  }
}

final raiProvider = NotifierProvider<RaiController, RaiState>(RaiController.new);

/// いま見えている画面の場所 (D-179): `RouteMatchList.uri` は push で積んだ画面を含まないので、
/// 一番上の一致(シェルの中 / 積んだ画面)まで辿る。
String visibleLocationOf(RouteMatchList config) {
  if (config.isEmpty) return '/';
  RouteMatchBase m = config.matches.last;
  while (m is ShellRouteMatch) {
    m = m.matches.last;
  }
  if (m is ImperativeRouteMatch) return visibleLocationOf(m.matches);
  return m.matchedLocation;
}
