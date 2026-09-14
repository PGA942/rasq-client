import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart';
import '../../app/router.dart';

export '../../app/navigation.dart' show visibleLocationOf;
import 'rai_llm.dart';
import 'rai_locator.dart';
import 'rai_reference.dart';
import 'rai_reference_providers.dart';
import 'rai_stats.dart';
import 'rai_widgets.dart' show splitSpeechLines;

/// RAi のモード (D-179): インストラクション(操作を教える、RAi は部品まで移動して指差す)/
/// アシスタント(第二期: LLM。今は枠とトグルだけ、RAi は中央固定)。
enum RaiMode {
  instruction,
  assistant;

  String get label => this == RaiMode.instruction ? 'インストラクション' : 'アシスタント';

  /// バーのモデルチップ(ワイヤーフレーム: 端末内モデル / クラウドモデル)。D-181: アシスタントも
  /// 当面は端末内の 4B(フォールアップ先のサーバーが無い)。
  /// バーのチップの既定表記(実際は選択中モデルのコードネーム、D-198)。
  String get modelName => raiModelSpecs.first.codename;
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
    this.sidebarOpen = false,
    this.conversationId,
    this.hits = const [],
    this.situation,
    this.proposal,
    this.choices = const [],
    this.lastOperation,
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

  /// RAi ホームのサイドバー (D-214) が開いている間は入力タイル(バー)を隠す。
  final bool sidebarOpen;

  /// いまの発言の履歴が属する保存済みの会話(「新しい会話」で区切る)。null = まだ保存していない。
  final String? conversationId;

  /// 直近のリファレンス検索の当たり(id とスコア、D-189)。評価 / 表示用。
  final List<({String id, double score})> hits;

  /// アシスタントで LLM が作ったシチュエーションの一文(無ければ入力そのまま)。
  final String? situation;

  /// 提案中の操作リファレンスの id。
  final String? proposal;

  /// 曖昧な質問の選択肢 (D-194): 吹き出しの上に出す(id と見出し)。
  final List<({String id, String index})> choices;

  /// 直前に手順を出した操作 id(入力欄の補完は、ここから分岐する操作を優先する)。
  final String? lastOperation;

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
    bool? sidebarOpen,
    Object? conversationId = _keep,
    List<({String id, double score})>? hits,
    Object? situation = _keep,
    Object? proposal = _keep,
    List<({String id, String index})>? choices,
    Object? lastOperation = _keep,
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
        sidebarOpen: sidebarOpen ?? this.sidebarOpen,
        conversationId: identical(conversationId, _keep) ? this.conversationId : conversationId as String?,
        hits: hits ?? this.hits,
        situation: identical(situation, _keep) ? this.situation : situation as String?,
        proposal: identical(proposal, _keep) ? this.proposal : proposal as String?,
        choices: choices ?? this.choices,
        lastOperation: identical(lastOperation, _keep) ? this.lastOperation : lastOperation as String?,
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

  void close() {
    _archiveConversation();
    state = const RaiState();
  }

  /// RAi ホームのサイドバー (D-214): 開いている間はバーを隠す。
  void toggleSidebar({bool? open}) => state = state.copyWith(sidebarOpen: open ?? !state.sidebarOpen);

  /// いまの発言の履歴を会話として保存する(空なら何もしない。既に保存済みの会話なら置き換え)。
  void _archiveConversation() {
    final c = RaiConversation.fromLog(state.log, id: state.conversationId);
    if (c == null) return;
    ref.read(raiConversationsProvider.notifier).put(c);
    state = state.copyWith(conversationId: c.id);
  }

  /// 「新しい会話」(D-214): いまの履歴を保存して空にする。吹き出し / 手順も捨てる。
  void newConversation() {
    _archiveConversation();
    _answerSeq++;
    state = state.copyWith(log: const [], conversationId: null, bubble: null, target: null, steps: const [], stepIndex: 0, lineIndex: 0, busy: false, proposal: null, choices: const [], historyOpen: false, sidebarOpen: false);
  }

  /// 保存した会話を開く (D-214): いまの履歴は保存し、その会話の履歴を発言の履歴として出す。
  void openConversation(RaiConversation c) {
    if (state.conversationId != c.id) _archiveConversation();
    _answerSeq++;
    state = state.copyWith(log: c.log, conversationId: c.id, bubble: null, target: null, steps: const [], stepIndex: 0, lineIndex: 0, busy: false, proposal: null, choices: const [], historyOpen: true, sidebarOpen: false, expanded: true);
  }

  void toggleExpanded() => state = state.copyWith(expanded: !state.expanded, asking: false);

  void toggleHistory({bool? open}) => state = state.copyWith(historyOpen: open ?? !state.historyOpen);

  void setAsking(bool v) => state = state.copyWith(asking: v, expanded: true);

  /// モード切り替え: 進行中の手順は捨てる。アシスタントは中央固定。
  void setMode(RaiMode mode) {
    if (mode == state.mode) return;
    state = state.copyWith(mode: mode, bubble: null, target: null, steps: const [], stepIndex: 0, choices: const []);
    // RAi ページはモードに合わせて自動で開閉 (D-200): アシスタント → 開く、インストラクション → 閉じる。
    final router = ref.read(routerProvider);
    final cur = visibleLocationOf(router.routerDelegate.currentConfiguration);
    if (mode == RaiMode.assistant) {
      if (!cur.startsWith(Routes.rai)) unawaited(router.push(Routes.rai));
    } else if (cur.startsWith(Routes.rai) && router.canPop()) {
      router.pop();
    }
  }

  void dismissBubble() {
    _answerSeq++; // 生成中なら捨てる
    state = state.copyWith(bubble: null, target: null, steps: const [], stepIndex: 0, lineIndex: 0, busy: false, proposal: null, choices: const []);
  }

  /// 「質問する」 (D-189): 操作リファレンスをハイブリッド検索(ベクトル + キーワード)して手順を出す。
  /// - インストラクション: 入力そのままで検索 → 手順ごとに部品へ移動して指差す。当たらなければ LLM へ。
  /// - アシスタント: 端末内モデルが使えれば「シチュエーション」の一文を作ってから検索し、関数リファレンスの
  ///   検索手順(関数 / 入力するもの / 決まっているもの)を提案する(中央固定)。当たらなければ LLM の返事。
  Future<void> ask(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    // 実績 (D-214): 聞いた回数と、同じ質問の聞き直し。
    final repeated = state.history.contains(q);
    final history = [q, ...state.history.where((h) => h != q)].take(20).toList();
    final seq = ++_answerSeq;
    state = state.copyWith(query: q, asking: false, busy: true, history: history, hits: const []);
    final stats = ref.read(raiStatsProvider.notifier);
    stats.bump(instructionAsked: state.mode == RaiMode.instruction, assistantAsked: state.mode == RaiMode.assistant, repeated: repeated);
    final index = await _index();
    if (seq != _answerSeq) return;
    if (state.mode == RaiMode.assistant) {
      final situation = await _situate(q);
      if (seq != _answerSeq) return;
      final hits = index == null ? const <RaiHit<RaiOperation>>[] : await index.searchOperations(q, situation: situation);
      if (seq != _answerSeq) return;
      state = state.copyWith(hits: [for (final h in hits) (id: h.item.id, score: h.score)], situation: situation);
      // アプリについての会話 = 操作リファレンスに当たった (D-214)。
      if (hits.isNotEmpty) stats.bump(assistantApp: true);
      if (hits.isEmpty) {
        await _answerWithLlm(q, system: _assistantSystem);
        return;
      }
      if (_ambiguous(hits)) {
        _askChoice(hits);
        return;
      }
      _propose(index!, hits.first.item);
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
    if (_ambiguous(hits)) {
      _askChoice(hits);
      return;
    }
    await _runOperation(index!, hits.first.item);
  }

  /// 上位 2 つのスコアが近い = 曖昧 (D-194)。
  static bool _ambiguous(List<RaiHit<RaiOperation>> hits) => hits.length >= 2 && hits[1].score >= hits[0].score - 0.06;

  void _askChoice(List<RaiHit<RaiOperation>> hits) {
    const text = 'どれのことですか？ 上の選択肢から選んでください';
    state = state.copyWith(busy: false, bubble: text, target: null, steps: const [], stepIndex: 0, lineIndex: 0, proposal: null, choices: [for (final h in hits.take(3)) (id: h.item.id, index: h.item.index)]);
    _record(text);
  }

  /// 選択肢を選ぶ (D-194)。
  Future<void> pick(String id) async {
    final index = await _index();
    final op = index?.operation(id);
    if (index == null || op == null) return;
    state = state.copyWith(choices: const [], busy: true);
    if (state.mode == RaiMode.assistant) {
      _propose(index, op);
    } else {
      await _runOperation(index, op);
    }
  }

  void _propose(RaiReferenceIndex index, RaiOperation op) {
    final steps = index.expand(op);
    final text = proposalLines(op, steps).join('\n');
    state = state.copyWith(busy: false, bubble: text, target: null, steps: const [], stepIndex: 0, lineIndex: 0, proposal: op.id, choices: const [], lastOperation: op.id);
    _record(text);
  }

  Future<void> _runOperation(RaiReferenceIndex index, RaiOperation op) async {
    state = state.copyWith(steps: index.expand(op), stepIndex: 0, choices: const [], lastOperation: op.id);
    await _showStep(0);
  }

  /// 入力欄の薄い補完 (D-194): 直前の操作から分岐する操作を優先し、見出し / タグが入力で始まるものを返す。
  String? suggest(String typed) {
    final q = typed.trim();
    if (q.isEmpty) return null;
    final index = ref.read(raiReferenceProvider).value;
    if (index == null) return null;
    final last = state.lastOperation;
    final ops = [
      if (last != null) ...index.operations.where((o) => o.base == last),
      ...index.operations,
    ];
    for (final o in ops) {
      if (o.index.startsWith(q) && o.index != q) return o.index;
    }
    for (final o in ops) {
      for (final t in o.tags) {
        if (t.startsWith(q) && o.index.contains(t)) return o.index;
      }
    }
    return null;
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

  /// 端末内 LLM で答える(トークンを吹き出しへ流す)。だめ / 返事が空ならフォールアップ(推論サーバー、D-216:
  /// 質問と MiniLM で近かったリファレンスを添える)→ それもだめなら失敗表示。
  Future<void> _answerWithLlm(String q, {required String system, String? fallbackText}) async {
    final llm = ref.read(raiLlmProvider);
    final seq = ++_answerSeq;
    state = state.copyWith(busy: true, bubble: '…', target: null, steps: const [], stepIndex: 0, lineIndex: 0, proposal: null, choices: const []);
    var text = '';
    RaiLlmException? failure;
    try {
      await for (final tok in llm.chat(q, system: system)) {
        if (seq != _answerSeq) return;
        text += tok;
        state = state.copyWith(bubble: text);
      }
      if (seq != _answerSeq) return;
      if (text.trim().isEmpty) failure = const RaiLlmException('返事がありませんでした');
    } on RaiLlmException catch (e) {
      failure = e;
    }
    if (seq != _answerSeq) return;
    if (failure == null) {
      state = state.copyWith(busy: false, bubble: text.trim());
      _record(state.bubble!);
      return;
    }
    final e = failure;
    await llm.release(); // フォールアップ時は端末内モデルのメモリを解放する(仕様)
    if (seq != _answerSeq) return;
    try {
      final reply = await ref.read(raiFallUpProvider).chat(q, system: system, context: referenceContext());
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

  /// 推論サーバーへ添える文脈 (D-216): 直近の検索で近かった操作(上位 3 つ)の見出しと手順。
  List<String> referenceContext({int max = 3}) {
    final index = ref.read(raiReferenceProvider).value;
    if (index == null) return const [];
    final out = <String>[];
    for (final h in state.hits.take(max)) {
      final op = index.operation(h.id);
      if (op == null) continue;
      final steps = index.expand(op);
      out.add('- ${op.index}: ${[for (final s in steps) s.text].join(' → ')}');
    }
    return out;
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
      // 最後の手順まで進んだ = 順調に進んだ (D-214)。
      if (state.mode == RaiMode.instruction && state.steps.isNotEmpty && state.stepIndex == state.steps.length - 1) ref.read(raiStatsProvider.notifier).bump(completed: true);
      dismissBubble();
      return;
    }
    await _showStep(state.stepIndex + 1);
  }

  /// 指差した部品が押された (D-193): 少し待ってから次の手順へ(最後なら閉じる)。
  /// 押した先の画面 / FOW が開いてから次の部品を探せるよう、遅らせる。
  Future<void> targetTapped() async {
    if (state.mode != RaiMode.instruction || state.target == null || state.busy) return;
    final i = state.stepIndex;
    final seq = _answerSeq;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (state.stepIndex != i || seq != _answerSeq || state.target == null) return;
    await next();
  }

  Future<void> _showStep(int i) async {
    final step = state.steps[i];
    state = state.copyWith(stepIndex: i, busy: true);
    // 先に画面を開く(ディープリンク)。
    final route = step.route;
    if (route != null) {
      final router = ref.read(routerProvider);
      // 見えている画面 = 一番上の一致(push で積んだ画面は uri に出ないので辿る)。
      // 手順の画面と**同じ場所**にいるときだけ何もしない (D-205: 前方一致だと `/settings/...` から
      // `/settings` へ戻れなかった)。
      final cur = visibleLocationOf(router.routerDelegate.currentConfiguration);
      if (!sameRoute(cur, route)) {
        if (routeInHistory(router.routerDelegate.currentConfiguration, route)) {
          // 履歴にあればそこまで戻る (D-204)。
          for (var k = 0; k < 12 && router.canPop() && !sameRoute(visibleLocationOf(router.routerDelegate.currentConfiguration), route); k++) {
            router.pop();
            await WidgetsBinding.instance.endOfFrame;
          }
        } else if (raiTabRoots.contains(route)) {
          // タブの根(ホーム / 検索 / AsTell / 通知 / DM)は go、それ以外は push (D-193): go だと
          // 戻るボタンや「決定」(context.pop)の戻り先が無くなる。
          router.go(route);
        } else {
          unawaited(router.push(route));
        }
        await WidgetsBinding.instance.endOfFrame;
      }
    }
    // 部品の矩形を探す(画面遷移 / FOW のアニメーション直後は少し待つ)。
    // 遷移のアニメーション中に取った矩形はずれる (D-203): 2 回続けて同じ矩形になるまで待つ。
    Rect? rect;
    if (step.hasTarget) {
      Rect? prev;
      for (var attempt = 0; attempt < 14 && rect == null; attempt++) {
        await WidgetsBinding.instance.endOfFrame;
        if (attempt > 0) await Future<void>.delayed(const Duration(milliseconds: 120));
        if (state.stepIndex != i) return;
        // 同じ部品が複数見えていれば(TL の各投稿のボタンなど)表示されている中からランダムに選び (D-204)、
        // 以後の取り直しはその近くのものに固定する。
        final r = locateWidgetRect(tooltip: step.tooltip, text: step.label, near: prev, random: prev == null ? _random : null);
        if (r != null && r == prev) rect = r;
        prev = r;
      }
      rect ??= prev;
    }
    if (state.stepIndex != i) return; // 途中で別の質問に変わった
    state = state.copyWith(busy: false, bubble: step.text, target: rect, lineIndex: 0);
    _record(step.text);
    if (rect != null) unawaited(_followTarget(i, step));
  }

  /// 指した後もしばらく矩形を追う (D-203): 遷移の終わり / 一覧の読み込みでずれたら目標を更新する。
  /// タイマーは使わずフレームで数える(描画が止まっていれば追わない)。
  Future<void> _followTarget(int i, RaiStep step) async {
    final seq = _answerSeq;
    for (var k = 0; k < 4; k++) {
      for (var f = 0; f < 10; f++) {
        await WidgetsBinding.instance.endOfFrame;
      }
      if (state.stepIndex != i || seq != _answerSeq || state.target == null || state.mode != RaiMode.instruction) return;
      final r = locateWidgetRect(tooltip: step.tooltip, text: step.label, near: state.target);
      if (r != null && r != state.target) state = state.copyWith(target: r);
    }
  }

  final _random = math.Random();

  /// ウィンドウのリサイズ後に矩形を取り直す (D-204: レイアウトが変わっても目標が古いままだった)。
  Future<void> relocate() async {
    final i = state.stepIndex;
    final seq = _answerSeq;
    if (state.mode != RaiMode.instruction || state.target == null || i >= state.steps.length) return;
    final step = state.steps[i];
    for (var f = 0; f < 3; f++) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (state.stepIndex != i || seq != _answerSeq || state.target == null) return;
    final r = locateWidgetRect(tooltip: step.tooltip, text: step.label, near: state.target);
    if (r != null && r != state.target) state = state.copyWith(target: r);
  }

  /// 指した部品と同じ部品(別のコンポーネントの同じボタンでもよい、D-204)が [point] にあるか。
  bool isStepWidgetAt(Offset point) {
    final t = state.target;
    if (t == null || state.mode != RaiMode.instruction) return false;
    if (t.inflate(4).contains(point)) return true;
    final i = state.stepIndex;
    if (i >= state.steps.length) return false;
    final step = state.steps[i];
    if (!step.hasTarget) return false;
    return locateWidgetRects(tooltip: step.tooltip, text: step.label).any((r) => r.inflate(4).contains(point));
  }
}

/// タブの根(StatefulShellRoute の枝)。ここへは go、それ以外の画面は push で開く (D-193)。
const raiTabRoots = {Routes.home, Routes.search, Routes.vc, Routes.notifications, Routes.dm};

final raiProvider = NotifierProvider<RaiController, RaiState>(RaiController.new);

