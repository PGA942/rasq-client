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
import 'rai_functions.dart';
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
    this.stopAt,
    this.suspended,
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

  /// 案内を何手順目まで進めるか (D-219: LLM が階層へ到達するために呼ぶ途中中断)。null = 最後まで。
  final int? stopAt;

  /// 進められる手順の数(stopAt で打ち切る)。
  int get stepLimit => stopAt == null ? steps.length : math.min(steps.length, stopAt!);

  /// 「さらに尋ねる」で一時停止した案内 (D-220): RAi ページから戻ると続きから再開する。
  final RaiSuspendedGuide? suspended;

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

  bool get hasNext => steps.isNotEmpty && stepIndex + 1 < stepLimit;

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
    Object? stopAt = _keep,
    Object? suspended = _keep,
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
        stopAt: identical(stopAt, _keep) ? this.stopAt : stopAt as int?,
        suspended: identical(suspended, _keep) ? this.suspended : suspended as RaiSuspendedGuide?,
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
  const RaiUtterance({required this.text, required this.at, this.query, this.error = false, this.proposal, this.choices = const []});
  final String text;
  final DateTime at;
  final String? query;
  final bool error;

  /// 提案した操作の id (D-218: チャットでは行の下に「この手順で案内」のタイル)。
  final String? proposal;

  /// 曖昧なときの選択肢(チャットでは行の下のチップ)。
  final List<({String id, String index})> choices;

  /// 本文の URL(チャットでは行の下にリンクカード)。
  List<Uri> get links => raiLinksIn(text);
}

/// 一時停止した案内 (D-220): 手順と位置。
@immutable
class RaiSuspendedGuide {
  const RaiSuspendedGuide({required this.steps, required this.stepIndex, this.stopAt, this.operation});
  final List<RaiStep> steps;
  final int stepIndex;
  final int? stopAt;
  final String? operation;
  String get title => operation ?? '案内';
}

/// LLM が書く案内の呼び出し (D-219): `[[instruction:<opId>|<stopAt>]]`(stopAt は省略可)。
class RaiToolCall {
  const RaiToolCall({required this.op, this.stopAt});
  final String op;
  final int? stopAt;
}

final _toolCallRe = RegExp(r'\[\[\s*instruction\s*:\s*([\w.\-]+)\s*(?:\|\s*(\d+)\s*)?\]\]');

List<RaiToolCall> raiToolCallsIn(String text) => [
      for (final m in _toolCallRe.allMatches(text)) RaiToolCall(op: m.group(1)!, stopAt: m.group(2) == null ? null : int.tryParse(m.group(2)!)),
    ];

String raiStripToolCalls(String text) => text.replaceAll(_toolCallRe, '').replaceAll(RegExp(r'[ \t]+\n'), '\n').trim();

/// 本文の http(s) URL を拾う(末尾の句読点 / 括弧は落とす)。
List<Uri> raiLinksIn(String text) {
  final out = <Uri>[];
  for (final m in RegExp(r'https?://[^\s<>「」()（）]+').allMatches(text)) {
    var raw = m.group(0)!;
    while (raw.isNotEmpty && '.,、。!！?？'.contains(raw[raw.length - 1])) {
      raw = raw.substring(0, raw.length - 1);
    }
    final u = Uri.tryParse(raw);
    if (u != null && u.host.isNotEmpty) out.add(u);
  }
  return out;
}

class RaiController extends Notifier<RaiState> {
  /// 確定した発言を履歴に積む(50 件まで)。
  void _record(String text, {bool error = false, String? proposal, List<({String id, String index})> choices = const []}) {
    if (text.trim().isEmpty || text == '…') return;
    state = state.copyWith(log: [RaiUtterance(text: text, at: DateTime.now(), query: state.query, error: error, proposal: proposal, choices: choices), ...state.log].take(50).toList());
  }

  /// チャットの提案タイルから案内へ (D-218): インストラクションに切り替え(RAi ページは閉じる)、その操作を進める。
  Future<void> guide(String opId) => runInstruction(opId);

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
    state = state.copyWith(mode: mode, bubble: null, target: null, steps: const [], stepIndex: 0, choices: const [], stopAt: null);
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
    state = state.copyWith(bubble: null, target: null, steps: const [], stepIndex: 0, lineIndex: 0, busy: false, proposal: null, choices: const [], stopAt: null);
  }

  /// 「さらに尋ねる」(D-219 → D-220): 進行中の案内を**一時停止**してアシスタント(RAi ページ = チャット)へ。
  /// 詳しい情報は RAi ページのほうが出せる。ページから戻ると [resumeSuspended] で続きから。
  void cancelInstruction() {
    final saved = state.steps.isEmpty ? null : RaiSuspendedGuide(steps: state.steps, stepIndex: state.stepIndex, stopAt: state.stopAt, operation: state.lastOperation);
    dismissBubble();
    state = state.copyWith(suspended: saved, asking: true, expanded: true, open: true);
    setMode(RaiMode.assistant);
  }

  /// RAi ページから戻った (D-220): 一時停止した案内があれば、インストラクションに戻して続きの手順を指す。
  Future<void> resumeSuspended() async {
    final g = state.suspended;
    if (g == null) return;
    state = state.copyWith(suspended: null);
    if (state.mode != RaiMode.instruction) {
      state = state.copyWith(mode: RaiMode.instruction, bubble: null, target: null, choices: const []);
    }
    state = state.copyWith(steps: g.steps, stepIndex: g.stepIndex, stopAt: g.stopAt, lastOperation: g.operation);
    await WidgetsBinding.instance.endOfFrame;
    if (state.suspended != null || state.steps.isEmpty) return;
    await _showStep(g.stepIndex.clamp(0, g.steps.length - 1));
  }

  /// 一時停止した案内を捨てる(チャットで別の案内を始めたときなど)。
  void dropSuspended() {
    if (state.suspended != null) state = state.copyWith(suspended: null);
  }

  /// LLM / チャットのタイルから案内を呼ぶ (D-219): インストラクションに切り替え、[stopAt] 手順目で止める
  /// (階層への到達に使う。null = 最後まで)。
  Future<void> runInstruction(String opId, {int? stopAt}) async {
    final index = await _index();
    final op = index?.operation(opId);
    if (index == null || op == null) return;
    dropSuspended();
    setMode(RaiMode.instruction);
    await WidgetsBinding.instance.endOfFrame;
    state = state.copyWith(stopAt: stopAt == null || stopAt <= 0 ? null : stopAt);
    await _runOperation(index, op);
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
        await _answerWithPlan(q);
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
    final choices = [for (final h in hits.take(3)) (id: h.item.id, index: h.item.index)];
    state = state.copyWith(busy: false, bubble: text, target: null, steps: const [], stepIndex: 0, lineIndex: 0, proposal: null, choices: choices);
    _record(text, choices: choices);
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
    _record(text, proposal: op.id);
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

  /// 箇条書きの計画 (D-220): 答える前に、質問を最大 [raiPlanMax] 個の短い箇条書きに分けさせる(ローカル LLM が
  /// 途中でコンテキスト切れで落ちないよう短く)。各項目でリファレンスを軽く引き、候補を絞ってから答える。
  static const raiPlanSystem = 'あなたは SNS ブラウザ RASQ のアシスタント「RAi」です。質問に答える前に、やることを日本語の箇条書き(「- 」で始める 1 行ずつ、最大 4 個、各 20 文字以内)だけで書いてください。説明は書かないでください。';
  static const raiPlanMax = 4;

  /// 箇条書きを取り出す(「- 」「・」「1.」)。多ければ [raiPlanMax] で打ち切る。
  static List<String> parsePlan(String text) {
    final out = <String>[];
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      final m = RegExp(r'^(?:[-*・•]|\d+[.)、])\s*(.+)$').firstMatch(line);
      if (m == null) continue;
      final item = m.group(1)!.trim();
      if (item.isEmpty) continue;
      out.add(item.length > 40 ? item.substring(0, 40) : item);
      if (out.length >= raiPlanMax) break;
    }
    return out;
  }

  /// 計画の各項目でリファレンスを軽く引く (D-220): 項目ごとに上位 1 件、重複は落とす → hits に足す。
  Future<List<String>> _narrowByPlan(List<String> plan) async {
    final index = await _index();
    if (index == null || plan.isEmpty) return const [];
    final ids = <String>[for (final h in state.hits) h.id];
    for (final item in plan) {
      final hits = await index.searchOperations(item, k: 1);
      for (final h in hits) {
        if (!ids.contains(h.item.id)) ids.add(h.item.id);
      }
    }
    state = state.copyWith(hits: [for (final id in ids) (id: id, score: 0)]);
    return plan;
  }

  /// 案内の呼び出し (D-219): 候補の操作 id を渡し、本文に `[[instruction:<id>|<何手順目まで>]]` と書かせる。
  String _assistantSystemWithTools({List<String> plan = const []}) {
    final ctx = referenceContext(withIds: true, max: raiPlanMax + 2);
    final planText = plan.isEmpty ? '' : '\nやること: ${plan.join(' / ')}';
    if (ctx.isEmpty) return '$_assistantSystem$planText';
    return '$_assistantSystem$planText\n案内できる操作(id: 見出し: 手順):\n${ctx.join('\n')}\n操作の案内を始めるときは本文の末尾に [[instruction:<id>|<何手順目まで>]] と書く(途中の画面で止めたいときは手順数を指定、最後までなら数字を省く)。$_functionsHint';
  }

  /// 関数の呼び出し (D-221): 本文末尾の `[[call:<関数>|引数=値]]`。取得系は結果を注入して答え直す。
  static final _functionsHint = '\n使える関数(必要なときだけ本文末尾に [[call:<関数>|引数=値|…]] と書く。取得系は結果を受け取ってから答え直す):\n${raiFunctionUsage.map((u) => '- $u').join('\n')}';
  static const _instructionSystem = 'あなたは SNS ブラウザ RASQ の操作を教える「RAi」です。日本語で、操作手順を短く(3 文以内)答えてください。';

  /// 二段の回答 (D-220): ①短い箇条書きの計画(失敗しても無視)→ ②各項目でリファレンスを絞る → ③計画と候補を
  /// 添えて答える(案内の呼び出しつき)。計画が取れなければ従来どおり一段で答える。
  Future<void> _answerWithPlan(String q) async {
    final llm = ref.read(raiLlmProvider);
    final seq = ++_answerSeq;
    state = state.copyWith(busy: true, bubble: '…', target: null, steps: const [], stepIndex: 0, lineIndex: 0, proposal: null, choices: const []);
    var plan = const <String>[];
    try {
      var text = '';
      await for (final tok in llm.chat(q, system: raiPlanSystem, maxTokens: 96)) {
        if (seq != _answerSeq) return;
        text += tok;
      }
      plan = parsePlan(text);
    } on RaiLlmException {
      // 計画が取れなくても答えは出す(下の一段で失敗すればフォールアップ)。
    }
    if (seq != _answerSeq) return;
    if (plan.isNotEmpty) plan = await _narrowByPlan(plan);
    if (seq != _answerSeq) return;
    _lastPlan = plan;
    _answerSeq--; // _answerWithLlm が新しい連番を取る
    await _answerWithLlm(q, system: _assistantSystemWithTools(plan: plan));
  }

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
      await _finishAnswer(text, seq);
      return;
    }
    final e = failure;
    await llm.release(); // フォールアップ時は端末内モデルのメモリを解放する(仕様)
    if (seq != _answerSeq) return;
    try {
      final reply = await ref.read(raiFallUpProvider).chat(q, system: system, context: referenceContext());
      if (seq != _answerSeq) return;
      await _finishAnswer(reply, seq);
    } on RaiLlmException catch (f) {
      if (seq != _answerSeq) return;
      final lines = ['端末内モデル: ${e.message}', 'フォールアップ: ${f.message}', ?fallbackText];
      state = state.copyWith(busy: false, bubble: lines.join('\n'), error: true);
      _record(lines.join('\n'), error: true);
    }
  }

  /// 返事を確定する (D-219): 案内の呼び出しタグを本文から外して記録し、あれば案内を始める(途中中断つき)。
  Future<void> _finishAnswer(String raw, int seq) async {
    final calls = raiToolCallsIn(raw);
    final fnCalls = raiFunctionCallsIn(raw);
    var text = raiStripFunctionCalls(raiStripToolCalls(raw)).trim();
    final index = ref.read(raiReferenceProvider).value;
    // 一時停止中 (D-221): 案内は RAi 経由(続きへ / タイル)以外では始めない = LLM の呼び出しは無視する。
    final call = state.suspended != null ? null : calls.where((c) => index?.operation(c.op) != null).firstOrNull;
    if (call != null) {
      final op = index!.operation(call.op)!;
      final note = call.stopAt == null ? '案内「${op.index}」を始めます' : '案内「${op.index}」を ${call.stopAt} 手順目まで進めます';
      text = text.isEmpty ? note : '$text\n($note)';
    }
    // 関数の呼び出し (D-221): 順に実行して注記。取得系があれば再始動予約 → 注入して答え直す。
    final results = <RaiFunctionResult>[];
    if (fnCalls.isNotEmpty) {
      final runner = RaiFunctionRunner(ref, contextTokens: ref.read(raiLlmProvider).contextTokens);
      for (final c in fnCalls.take(3)) {
        results.add(await runner.run(c));
        if (seq != _answerSeq) return;
      }
      final notes = [for (final r in results) if (!r.fetched || !r.ok) '(${r.name}: ${r.text})'];
      if (notes.isNotEmpty) text = text.isEmpty ? notes.join('\n') : '$text\n${notes.join('\n')}';
    }
    state = state.copyWith(busy: false, bubble: text.isEmpty ? '(返事がありませんでした)' : text);
    _record(state.bubble!);
    if (call != null) {
      ref.read(raiStatsProvider.notifier).bump(instructionAsked: true);
      await runInstruction(call.op, stopAt: call.stopAt);
      return;
    }
    final fetched = [for (final r in results) if (r.fetched && r.ok) r];
    if (fetched.isNotEmpty && _restartDepth < 1) await _restartWithInjection(seq, digest: text, fetched: fetched);
  }

  /// 再始動予約 (D-221): 予約した取得が終わったら、モデルを解放してから ①計画 ②ここまでのダイジェスト
  /// ③取得した情報(KV の 4% で打ち切り)を system に注入して、同じ質問に答え直す。生データは [scratch] に
  /// 置き、注入には鍵(`[名前#n]`)を添える。
  int _restartDepth = 0;
  final Map<String, String> scratch = {};

  Future<void> _restartWithInjection(int seq, {required String digest, required List<RaiFunctionResult> fetched}) async {
    final q = state.query;
    if (q == null) return;
    final llm = ref.read(raiLlmProvider);
    final budget = raiInjectionBudgetChars(llm.contextTokens);
    final keys = <String>[];
    final injected = StringBuffer();
    var used = 0;
    for (final (i, r) in fetched.indexed) {
      final key = '${r.name}#${scratch.length + i + 1}';
      scratch[key] = r.text;
      keys.add(key);
      final piece = raiTruncate(r.text, budget - used);
      injected.writeln('[$key] $piece');
      used += piece.length;
      if (used >= budget) break;
    }
    _record('取得した情報(${keys.join(', ')})を注入してモデルを再始動します');
    _restartDepth++;
    try {
      await llm.release();
      if (seq != _answerSeq) return;
      final plan = _lastPlan.isEmpty ? '' : '\n計画: ${[for (final (i, p) in _lastPlan.indexed) '${i + 1}. $p'].join(' ')}';
      final system = '${_assistantSystemWithTools(plan: _lastPlan)}$plan\nここまでのダイジェスト: ${raiTruncate(digest, 200)}\n取得した情報(これを使って答え直す):\n${injected.toString().trim()}';
      _answerSeq--; // 次の _answerWithLlm が新しい連番を取る
      await _answerWithLlm(q, system: system);
    } finally {
      _restartDepth--;
    }
  }

  List<String> _lastPlan = const [];

  /// 推論サーバーへ添える文脈 (D-216): 直近の検索で近かった操作(上位 3 つ)の見出しと手順。
  List<String> referenceContext({int max = 3, bool withIds = false}) {
    final index = ref.read(raiReferenceProvider).value;
    if (index == null) return const [];
    final out = <String>[];
    for (final h in state.hits.take(max)) {
      final op = index.operation(h.id);
      if (op == null) continue;
      final steps = index.expand(op);
      out.add('- ${withIds ? '${op.id}: ' : ''}${op.index}: ${[for (final s in steps) s.text].join(' → ')}');
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

