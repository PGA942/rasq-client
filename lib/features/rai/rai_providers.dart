import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import 'rai_llm.dart';
import 'rai_locator.dart';
import 'rai_reference.dart';
import 'rai_widgets.dart' show splitSpeechLines;

/// RAi のモード (D-179): インストラクション(操作を教える、RAi は部品まで移動して指差す)/
/// アシスタント(第二期: LLM。今は枠とトグルだけ、RAi は中央固定)。
enum RaiMode {
  instruction,
  assistant;

  String get label => this == RaiMode.instruction ? 'インストラクション' : 'アシスタント';

  /// バーのモデルチップ(ワイヤーフレーム: 端末内モデル / クラウドモデル)。D-181: アシスタントも
  /// 当面は端末内の 4B(フォールアップ先のサーバーが無い)。
  String get modelName => raiLocalModelLabel;
  IconData get modelIcon => Icons.smartphone;
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
    this.error = false,
    this.lineIndex = 0,
  });

  final RaiMode mode;

  /// バー(+ RAi)を出しているか。
  final bool open;

  /// バーの上段(見出し / 入力)を畳んでいないか。
  final bool expanded;

  /// 入力欄にフォーカスを入れる(ログインの「Raiのインストラクチャ」など)。入力欄自体は常に上段。
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

  /// 直近の返事が失敗表示か(端末内モデル / フォールアップとも不可)。
  final bool error;

  /// 発言のうち今見せている行 (D-182: 1 行ずつ)。
  final int lineIndex;

  List<String> get lines => bubble == null ? const [] : splitSpeechLines(bubble!);
  String? get currentLine => lines.isEmpty ? (bubble == null ? null : '…') : lines[lineIndex.clamp(0, lines.length - 1)];
  bool get hasMoreLines => lineIndex + 1 < lines.length;

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
    bool? error,
    int? lineIndex,
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
        error: error ?? (bubble is String ? false : this.error),
        lineIndex: lineIndex ?? this.lineIndex,
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

  void dismissBubble() {
    _answerSeq++; // 生成中なら捨てる
    state = state.copyWith(bubble: null, target: null, steps: const [], stepIndex: 0, lineIndex: 0, busy: false);
  }

  /// 「質問する」: インストラクションなら参照から手順を引いて最初の部品へ、
  /// アシスタントは(第二期まで)固定の返事を中央で。
  Future<void> ask(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final history = [q, ...state.history.where((h) => h != q)].take(20).toList();
    state = state.copyWith(query: q, asking: false, busy: true, history: history);
    if (state.mode == RaiMode.assistant) {
      await _answerWithLlm(q, system: _assistantSystem);
      return;
    }
    final m = matchInstruction(q);
    if (m == null) {
      // 参照に無い質問は LLM へバイパス(端末内 → フォールアップ)。どちらも無ければ案内文。
      await _answerWithLlm(q, system: _instructionSystem, fallbackText: 'まだ覚えていない操作です。「投稿」「ログイン」「共有」などで聞いてみてください。');
      return;
    }
    state = state.copyWith(steps: m.instruction.steps, stepIndex: 0);
    await _showStep(0);
  }

  static const _assistantSystem = 'あなたは SNS ブラウザ RASQ のアシスタント「RAi」です。日本語で、短く(3 文以内)答えてください。';
  static const _instructionSystem = 'あなたは SNS ブラウザ RASQ の操作を教える「RAi」です。日本語で、操作手順を短く(3 文以内)答えてください。';

  /// 端末内 LLM で答える(トークンを吹き出しへ流す)。だめならフォールアップ → それもだめなら失敗表示。
  Future<void> _answerWithLlm(String q, {required String system, String? fallbackText}) async {
    final llm = ref.read(raiLlmProvider);
    final seq = ++_answerSeq;
    state = state.copyWith(busy: true, bubble: '…', target: null, steps: const [], stepIndex: 0, lineIndex: 0);
    var text = '';
    try {
      await for (final tok in llm.chat(q, system: system)) {
        if (seq != _answerSeq) return;
        text += tok;
        state = state.copyWith(bubble: text);
      }
      if (seq != _answerSeq) return;
      state = state.copyWith(busy: false, bubble: text.trim().isEmpty ? '(返事がありませんでした)' : text.trim());
      return;
    } on RaiLlmException catch (e) {
      if (seq != _answerSeq) return;
      await llm.release(); // フォールアップ時は端末内モデルのメモリを解放する(仕様)
      try {
        final reply = await ref.read(raiFallUpProvider).chat(q);
        if (seq != _answerSeq) return;
        state = state.copyWith(busy: false, bubble: reply);
      } on RaiLlmException catch (f) {
        if (seq != _answerSeq) return;
        final lines = ['端末内モデル: ${e.message}', 'フォールアップ: ${f.message}', ?fallbackText];
        state = state.copyWith(busy: false, bubble: lines.join('\n'), error: true);
      }
    }
  }

  int _answerSeq = 0;

  /// ▶: 次の行 → 無ければ次の手順 → 無ければ閉じる。
  Future<void> advance() async {
    if (state.hasMoreLines) {
      state = state.copyWith(lineIndex: state.lineIndex + 1);
      return;
    }
    if (state.busy) return; // まだ行が増える
    await next();
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
    state = state.copyWith(busy: false, bubble: step.text, target: rect, lineIndex: 0);
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
