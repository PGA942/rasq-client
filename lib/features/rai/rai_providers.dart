import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import 'rai_llm.dart';
import 'rai_locator.dart';
import 'rai_reference.dart';
import 'rai_reference_providers.dart';
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
    this.log = const [],
    this.historyOpen = false,
    this.hits = const [],
    this.situation,
    this.proposal,
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

  /// 発言の履歴 (D-185 / D-187): 新しい順。入力ウィジェットの履歴ボタンで上に広がる。
  final List<RaiUtterance> log;
  final bool historyOpen;

  /// 直近のリファレンス検索の当たり(id とスコア、D-189)。評価 / 表示用。
  final List<({String id, double score})> hits;

  /// アシスタントで LLM が作ったシチュエーションの一文(無ければ入力そのまま)。
  final String? situation;

  /// 提案中の操作リファレンスの id。
  final String? proposal;

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
    List<RaiUtterance>? log,
    bool? historyOpen,
    List<({String id, double score})>? hits,
    Object? situation = _keep,
    Object? proposal = _keep,
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
        log: log ?? this.log,
        historyOpen: historyOpen ?? this.historyOpen,
        hits: hits ?? this.hits,
        situation: identical(situation, _keep) ? this.situation : situation as String?,
        proposal: identical(proposal, _keep) ? this.proposal : proposal as String?,
      );

  static const _keep = Object();
}

/// 発言 1 つ(履歴 FOW のタイル)。
@immutable
class RaiUtterance {
  const RaiUtterance({required this.text, required this.at, this.query, this.error = false});
  final String text;
  final DateTime at;
  final String? query;
  final bool error;
}

class RaiController extends Notifier<RaiState> {
  /// 確定した発言を履歴に積む(50 件まで)。
  void _record(String text, {bool error = false}) {
    if (text.trim().isEmpty || text == '…') return;
    state = state.copyWith(log: [RaiUtterance(text: text, at: DateTime.now(), query: state.query, error: error), ...state.log].take(50).toList());
  }

  @override
  RaiState build() => const RaiState();

  void open({RaiMode? mode, bool asking = false}) => state = state.copyWith(open: true, expanded: true, asking: asking, mode: mode);

  void close() => state = const RaiState();

  void toggleExpanded() => state = state.copyWith(expanded: !state.expanded, asking: false);

  void toggleHistory({bool? open}) => state = state.copyWith(historyOpen: open ?? !state.historyOpen);

  void setAsking(bool v) => state = state.copyWith(asking: v, expanded: true);

  /// モード切り替え: 進行中の手順は捨てる。アシスタントは中央固定。
  void setMode(RaiMode mode) {
    if (mode == state.mode) return;
    state = state.copyWith(mode: mode, bubble: null, target: null, steps: const [], stepIndex: 0);
  }

  void dismissBubble() {
    _answerSeq++; // 生成中なら捨てる
    state = state.copyWith(bubble: null, target: null, steps: const [], stepIndex: 0, lineIndex: 0, busy: false, proposal: null);
  }

  /// 「質問する」 (D-189): 操作リファレンスをハイブリッド検索(ベクトル + キーワード)して手順を出す。
  /// - インストラクション: 入力そのままで検索 → 手順ごとに部品へ移動して指差す。当たらなければ LLM へ。
  /// - アシスタント: 端末内モデルが使えれば「シチュエーション」の一文を作ってから検索し、関数リファレンスの
  ///   検索手順(関数 / 入力するもの / 決まっているもの)を提案する(中央固定)。当たらなければ LLM の返事。
  Future<void> ask(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final history = [q, ...state.history.where((h) => h != q)].take(20).toList();
    final seq = ++_answerSeq;
    state = state.copyWith(query: q, asking: false, busy: true, history: history, hits: const []);
    final index = await _index();
    if (seq != _answerSeq) return;
    if (state.mode == RaiMode.assistant) {
      final situation = await _situate(q);
      if (seq != _answerSeq) return;
      final hits = index == null ? const <RaiHit<RaiOperation>>[] : await index.searchOperations(q, situation: situation);
      if (seq != _answerSeq) return;
      state = state.copyWith(hits: [for (final h in hits) (id: h.item.id, score: h.score)], situation: situation);
      if (hits.isEmpty) {
        await _answerWithLlm(q, system: _assistantSystem);
        return;
      }
      final op = hits.first.item;
      final steps = index!.expand(op);
      final text = proposalLines(op, steps).join('\n');
      state = state.copyWith(busy: false, bubble: text, target: null, steps: const [], stepIndex: 0, lineIndex: 0, proposal: op.id);
      _record(text);
      return;
    }
    final hits = index == null ? const <RaiHit<RaiOperation>>[] : await index.searchOperations(q);
    if (seq != _answerSeq) return;
    state = state.copyWith(hits: [for (final h in hits) (id: h.item.id, score: h.score)]);
    if (hits.isEmpty) {
      // 参照に無い質問は LLM へバイパス(端末内 → フォールアップ)。どちらも無ければ案内文。
      await _answerWithLlm(q, system: _instructionSystem, fallbackText: 'まだ覚えていない操作です。「投稿」「ログイン」「共有」などで聞いてみてください。');
      return;
    }
    state = state.copyWith(steps: index!.expand(hits.first.item), stepIndex: 0);
    await _showStep(0);
  }

  /// 索引(組めていれば同期で返す。組み上がり待ちなら待つ。読めなければ null = LLM だけで答える)。
  Future<RaiReferenceIndex?> _index() async {
    final v = ref.read(raiReferenceProvider);
    if (v.hasValue) return v.value;
    try {
      return await ref.read(raiReferenceProvider.future);
    } catch (_) {
      return null;
    }
  }

  /// LLM にシチュエーションの一文を作らせる(モデルが準備できていないときは null = 入力そのままで検索)。
  Future<String?> _situate(String q) async {
    final llm = ref.read(raiLlmProvider);
    if (!llm.current.ready) return null;
    try {
      final buf = StringBuffer();
      await for (final tok in llm.chat(q, system: raiSituationSystem)) {
        buf.write(tok);
        if (buf.length > 120) break;
      }
      final s = buf.toString().trim().split('\n').first.trim();
      return s.isEmpty ? null : s;
    } on RaiLlmException {
      return null;
    }
  }

  static const _assistantSystem = 'あなたは SNS ブラウザ RASQ のアシスタント「RAi」です。日本語で、短く(3 文以内)答えてください。';
  static const _instructionSystem = 'あなたは SNS ブラウザ RASQ の操作を教える「RAi」です。日本語で、操作手順を短く(3 文以内)答えてください。';

  /// 端末内 LLM で答える(トークンを吹き出しへ流す)。だめならフォールアップ → それもだめなら失敗表示。
  Future<void> _answerWithLlm(String q, {required String system, String? fallbackText}) async {
    final llm = ref.read(raiLlmProvider);
    final seq = ++_answerSeq;
    state = state.copyWith(busy: true, bubble: '…', target: null, steps: const [], stepIndex: 0, lineIndex: 0, proposal: null);
    var text = '';
    try {
      await for (final tok in llm.chat(q, system: system)) {
        if (seq != _answerSeq) return;
        text += tok;
        state = state.copyWith(bubble: text);
      }
      if (seq != _answerSeq) return;
      state = state.copyWith(busy: false, bubble: text.trim().isEmpty ? '(返事がありませんでした)' : text.trim());
      _record(state.bubble!);
      return;
    } on RaiLlmException catch (e) {
      if (seq != _answerSeq) return;
      await llm.release(); // フォールアップ時は端末内モデルのメモリを解放する(仕様)
      try {
        final reply = await ref.read(raiFallUpProvider).chat(q);
        if (seq != _answerSeq) return;
        state = state.copyWith(busy: false, bubble: reply);
        _record(reply);
      } on RaiLlmException catch (f) {
        if (seq != _answerSeq) return;
        final lines = ['端末内モデル: ${e.message}', 'フォールアップ: ${f.message}', ?fallbackText];
        state = state.copyWith(busy: false, bubble: lines.join('\n'), error: true);
        _record(lines.join('\n'), error: true);
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
    _record(step.text);
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
