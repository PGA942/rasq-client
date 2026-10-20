import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../backend/learning_api.dart';
import '../../backend/orgate_client.dart';
import '../../session/session_providers.dart';
import '../child_safe/child_safe_providers.dart';
import '../rai/prompts/rai_prompts.dart' show raiPrompts;
import '../rai/rai_llm.dart';
import '../relational/relational_engine.dart';
import '../relational/relational_providers.dart';
import '../settings/settings_dsl.dart';

/// アルゴリズムとコミュニティへの貢献 (D-363 / Central S-049) — 学習へのデータ提供 (D-243) の同意の先の実体。
///
/// - **リレーショナルタイムライン**: 会話イベント(束)を送る。投稿の書き手ごとに「学習に使ってよいか」を決めてから。
///   1. 端末の規則(自己紹介の「AI学習禁止」「#NoAI」など)と、インストール済みなら端末の 2B モデル(バックグラウンドで
///      先に読み込んでおく)で下見する。
///   2. 下見を添えて Central の `POST /me/learning/judge` へ。**決めるのはクラウドの LLM**(明示の拒否は規則で拒否)。
///   3. 許可の書き手の投稿だけで束を組み直し(2 件未満なら送らない)、`POST /me/learning/contributions`。
/// - **RAi**: 自分の質問と RAi の答え(手順・関数の名前)を送る。ほかの人の投稿は入れない。
/// - 同意していて受付が開いているときだけ。見守り中(チャイルドセーフ)の端末は送らない。種類ごとに設定で止められる。
/// - 本文の @メンションと URL は伏せる。公開の投稿だけ(ダイレクト / フォロワー限定は入れない)。

/// 設定(アカウント毎 KV `learning.contrib.v1`): relational / rai / preload(既定はどれもオン)。
const contributionArea = 'learning.contrib';

/// 端末の下見の結果。
@immutable
class DeviceHint {
  const DeviceHint(this.verdict, this.reason, {this.model = ''});

  /// `allow` / `deny` / `unsure`。
  final String verdict;

  /// 理由。Central の判定に添えて送るデータ(審査で読む)なので、端末で決める固定の理由は言語で変えない(`// l10n-ignore`)。
  final String reason;
  final String model;

  Map<String, Object?> toJson() => {'verdict': verdict, 'reason': reason, 'model': model};
}

/// 判定に渡す書き手。
@immutable
class ContributionAuthor {
  const ContributionAuthor({required this.host, required this.id, this.handle = '', this.bio = '', this.fields = const [], this.bot, this.samples = const [], this.viewer});

  final String host;
  final String id;
  final String handle;
  final String bio;
  final List<String> fields;
  final bool? bot;
  final List<String> samples;

  /// 見ているアカウント(`AccountId.key`、プロフィールを読むセッション)。送らない。
  final String? viewer;

  String get key => '$host|$id';

  Map<String, Object?> toJson({DeviceHint? device}) => {
        'host': host,
        'id': id,
        'handle': handle,
        'bio': bio,
        'fields': fields,
        'flags': {if (bot != null) 'bot': bot},
        'samples': samples,
        if (device != null) 'device': device.toJson(),
      };
}

/// Central の判定。
@immutable
class AuthorVerdict {
  const AuthorVerdict({required this.verdict, required this.reason, required this.judgedBy});

  /// `allow` / `deny` / `unknown`。
  final String verdict;
  final String reason;
  final String judgedBy;

  bool get allowed => verdict == 'allow';

  factory AuthorVerdict.fromJson(Map<String, Object?> j) =>
      AuthorVerdict(verdict: j['verdict'] as String? ?? 'unknown', reason: j['reason'] as String? ?? '', judgedBy: j['judgedBy'] as String? ?? '');
}

/// 自己紹介・項目に書かれた「AI の学習に使わないで」の言い回し(Central の規則と同じ。片方を変えたらもう片方も)。
const _optOutPhrases = [
  '#noai', 'no ai', 'noai', 'no-ai', 'ai学習禁止', 'ai学習お断り', 'ai学習ng', 'ai学習不可', 'ai学習への利用', '学習禁止', '無断学習', // // l10n-ignore
  '機械学習禁止', '機械学習への利用を禁', '生成aiへの利用', '生成ai学習', 'do not train', "don't train", 'not for ai', 'no ai training', // // l10n-ignore
  'no machine learning', 'ai利用禁止', 'ai使用禁止', // l10n-ignore
];

/// 全角英数記号を半角に、全角空白を空白にして小文字へ。
String _fold(String s) => String.fromCharCodes([
      for (final c in s.runes) c == 0x3000 ? 0x20 : (c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : c),
    ]).toLowerCase();

/// 端末の下見 (D-363)。規則 → 端末の LLM(読み込み済み / インストール済みのとき)。
class LearnabilityPrescreen {
  LearnabilityPrescreen(this.llm);
  final RaiLlm llm;

  /// 明示の拒否なら deny(許可は規則では決めない)。
  static DeviceHint? rule(ContributionAuthor a) {
    if (a.bot == true) return null;
    final text = _fold('${a.bio} ${a.fields.join(' ')}');
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    for (final p in _optOutPhrases) {
      if (text.contains(p) || compact.contains(p.replaceAll(' ', ''))) return const DeviceHint('deny', '自己紹介で AI の学習への利用を断っています', model: 'rule'); // l10n-ignore
    }
    return null;
  }


  Future<DeviceHint> judge(ContributionAuthor a) async {
    final r = rule(a);
    if (r != null) return r;
    if (!llm.current.ready) return DeviceHint('unsure', '端末のモデルが準備できていません', model: llm.spec.id); // l10n-ignore
    final bio = a.bio.replaceAll('\n', ' ');
    // 指示の文は表示の言語の表から (D-492 / D-532)。
    final prompt = raiPrompts.learnabilityInput(
      bio: bio.length > 300 ? bio.substring(0, 300) : bio,
      fields: a.fields.join(' / '),
      posts: a.samples.take(2).map((s) => s.length > 100 ? s.substring(0, 100) : s).join(' | '),
    );
    try {
      final out = await llm.chat(prompt, system: raiPrompts.learnabilitySystem, maxTokens: 64).join().timeout(const Duration(seconds: 40));
      return parseHint(out, llm.spec.id);
    } catch (e) {
      return DeviceHint('unsure', '端末のモデルが答えませんでした', model: llm.spec.id); // l10n-ignore
    }
  }

  /// 端末のモデルの答え → 下見。JSON が読めなければ unsure。
  static DeviceHint parseHint(String out, String model) {
    var s = out.trim();
    final think = s.indexOf('</think>');
    if (think >= 0) s = s.substring(think + 8);
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final j = jsonDecode(s.substring(start, end + 1));
        if (j is Map) {
          final v = '${j['verdict']}';
          final reason = '${j['reason'] ?? ''}';
          if (v == 'allow' || v == 'deny' || v == 'unsure') return DeviceHint(v, reason.length > 40 ? reason.substring(0, 40) : reason, model: model);
        }
      } catch (_) {}
    }
    return DeviceHint('unsure', '答えを読めませんでした', model: model); // l10n-ignore
  }
}

/// 本文の @メンションと URL を伏せる。
String redactContributionText(String s) =>
    s.replaceAll(RegExp(r'https?://\S+'), '<url>').replaceAll(RegExp(r'@[A-Za-z0-9_.\-]+(@[A-Za-z0-9_.\-]+)?'), '@user');

String _hash(String s) => sha256.convert(utf8.encode(s)).toString().substring(0, 32);

bool _isPublic(Post p) => !p.isDirect && (p.visibility == null || p.visibility == 'public' || p.visibility == 'home' || p.visibility == 'unlisted');

bool _isSelf(Post p) => p.author.account.instance == p.account.instance && (p.author.account.handle == p.account.handle);

/// 投稿の書き手(判定に渡す形)。
ContributionAuthor contributionAuthorOf(Post p) =>
    ContributionAuthor(host: p.author.account.instance, id: p.author.id, handle: p.author.account.handle, bio: p.author.bio ?? '', viewer: p.account.key);

/// 自分の投稿か(書き手の判定に回さない)。
bool isOwnPost(Post p) => _isSelf(p);

/// 公開の投稿か(ダイレクト / フォロワー限定は送らない)。
bool isPublicPost(Post p) => _isPublic(p);

/// 提供 1 件(送る前)。
@immutable
class PendingContribution implements PendingContributionLike {
  const PendingContribution({required this.key, required this.authors, required this.data, this.posts = 0, this.labels = 0});

  @override
  final String key;
  final List<ContributionAuthor> authors;
  @override
  final Map<String, Object?> data;
  @override
  final int posts;
  @override
  final int labels;

  @override
  List<({String host, String id})> get authorRefs => [for (final a in authors) (host: a.host, id: a.id)];
}

/// 会話イベント → 提供 1 件(公開の投稿が 2 件以上のときだけ)。[allowed] を渡すと、その書き手と自分の投稿だけに絞る。
PendingContribution? relationalContributionOf(ConversationEvent e, {Set<String>? allowed}) {
  final authors = <String, ContributionAuthor>{};
  final posts = <Map<String, Object?>>[];
  final byId = <String, int>{};
  for (final p in e.posts) {
    if (!_isPublic(p)) continue;
    final self = _isSelf(p);
    final a = ContributionAuthor(host: p.author.account.instance, id: p.author.id, handle: p.author.account.handle, bio: p.author.bio ?? '');
    if (!self && allowed != null && !allowed.contains(a.key)) continue;
    if (!self) authors.putIfAbsent(a.key, () => a);
    final authorIndex = self ? -1 : authors.keys.toList().indexOf(a.key);
    byId[p.id] = posts.length;
    final text = [if (p.contentWarning != null) '[cw] ${p.contentWarning}', p.body].join('\n');
    posts.add({
      'a': authorIndex,
      't': redactContributionText(text.length > 500 ? text.substring(0, 500) : text),
      'at': p.createdAt.toUtc().toIso8601String(),
      if (p.replyToId != null && byId.containsKey(p.replyToId)) 'reply': byId[p.replyToId],
      if (p.quote != null) 'quote': true,
      if (p.media.isNotEmpty) 'media': p.media.length,
      if (p.repostedBy != null) 'repost': true,
    });
  }
  if (posts.length < 2) return null;
  return PendingContribution(
    key: _hash('relational|${e.id}'),
    authors: authors.values.toList(),
    posts: posts.length,
    data: {
      'v': 1,
      'entities': e.entities.take(20).toList(),
      'anchors': e.anchors.take(10).toList(),
      'hardAnchors': e.hardAnchorSet.length,
      'participants': e.participants.length,
      'intervals': e.intervalSeconds.take(40).toList(),
      'posts': posts,
    },
  );
}

/// 公開範囲が「公開」と分かる投稿か (D-370)。範囲の分からないものは送らない。Bluesky は投稿に範囲が無く、すべて公開。
bool isKnownPublic(Post p) => p.visibility == 'public' || (p.visibility == null && p.account.kind == SnsKind.bluesky && !p.isDirect);

/// 本人の範囲 (D-370 / S-051): 会話イベント → **自分が書いた公開投稿だけ**の提供 1 件(自分の投稿が無ければ null)。
/// 特徴語もイベント全体ではなく自分の投稿からだけ取る。ほかの人の投稿は数(参加者・間隔)にしか使わない。
PendingContribution? ownContributionOf(ConversationEvent e) {
  final own = [for (final p in e.posts) if (_isSelf(p) && isKnownPublic(p)) p];
  if (own.isEmpty) return null;
  final me = own.first.account;
  final byId = <String, int>{};
  final posts = <Map<String, Object?>>[];
  for (final p in own) {
    byId[p.id] = posts.length;
    final text = [if (p.contentWarning != null) '[cw] ${p.contentWarning}', p.body].join('\n');
    posts.add({
      'a': -1,
      'vis': 'public',
      't': redactContributionText(text.length > 500 ? text.substring(0, 500) : text),
      'at': p.createdAt.toUtc().toIso8601String(),
      if (p.replyToId != null && byId.containsKey(p.replyToId)) 'reply': byId[p.replyToId],
      if (p.media.isNotEmpty) 'media': p.media.length,
    });
  }
  return PendingContribution(
    key: _hash('own|${e.id}'),
    authors: const [],
    posts: posts.length,
    // 自分の投稿どうしが同じ会話 = 関連判定のラベル。
    labels: posts.length >= 2 ? 1 : 0,
    data: {
      'v': 2,
      'self': {'kind': me.kind.name, 'instance': me.instance, 'handle': me.handle},
      'entities': {for (final p in own) ...extractFeatures(p)}.take(20).toList(),
      'participants': e.participants.length,
      'eventPosts': e.posts.length,
      'posts': posts,
    },
  );
}

/// RAi の 1 やりとり → 提供 1 件。
PendingContribution raiContributionOf({required String query, required String answer, required String mode, required String model, String? opId, bool error = false, List<String> steps = const []}) {
  final at = DateTime.now().toUtc();
  return PendingContribution(
    key: _hash('rai|$query|$answer|${at.millisecondsSinceEpoch ~/ 60000}'),
    authors: const [],
    labels: 1,
    data: {
      'v': 1,
      'q': redactContributionText(query.length > 400 ? query.substring(0, 400) : query),
      'a': answer.length > 1200 ? answer.substring(0, 1200) : answer,
      'mode': mode,
      'model': model,
      'op': ?opId,
      if (error) 'error': true,
      if (steps.isNotEmpty) 'steps': steps.take(20).toList(),
      'at': at.toIso8601String(),
    },
  );
}

@immutable
class ContributionState {
  const ContributionState({
    this.active = false,
    this.relational = true,
    this.rai = true,
    this.preload = true,
    this.pendingRelational = 0,
    this.pendingRai = 0,
    this.sentRelational = 0,
    this.sentRai = 0,
    this.skipped = 0,
    this.verdicts = const {},
    this.log = const [],
    this.busy = false,
    this.lastSentAt,
    this.extended = false,
    this.unverified = 0,
  });

  /// 受け付ける範囲が検証用の `extended` か (D-370)。既定の `own` では自分の公開投稿だけを送る。
  final bool extended;

  /// 持ち主の確認が済んでいない SNS アカウントの投稿で、受け付けられなかった数 (D-370)。
  final int unverified;

  /// 同意済み・受付中・見守りでない(= 集めて送る)。
  final bool active;
  final bool relational;
  final bool rai;
  final bool preload;
  final int pendingRelational;
  final int pendingRai;

  /// この起動で送れた件数。
  final int sentRelational;
  final int sentRai;

  /// 書き手の許可が無くて送らなかった束の数。
  final int skipped;

  /// 書き手(`host|id`)→ 判定。
  final Map<String, AuthorVerdict> verdicts;

  /// 開発者モードで見る記録(新しい順、40 行まで)。
  final List<String> log;
  final bool busy;
  final DateTime? lastSentAt;

  ContributionState copyWith({
    bool? active,
    bool? relational,
    bool? rai,
    bool? preload,
    int? pendingRelational,
    int? pendingRai,
    int? sentRelational,
    int? sentRai,
    int? skipped,
    Map<String, AuthorVerdict>? verdicts,
    List<String>? log,
    bool? busy,
    DateTime? lastSentAt,
    bool? extended,
    int? unverified,
  }) =>
      ContributionState(
        active: active ?? this.active,
        relational: relational ?? this.relational,
        rai: rai ?? this.rai,
        preload: preload ?? this.preload,
        pendingRelational: pendingRelational ?? this.pendingRelational,
        pendingRai: pendingRai ?? this.pendingRai,
        sentRelational: sentRelational ?? this.sentRelational,
        sentRai: sentRai ?? this.sentRai,
        skipped: skipped ?? this.skipped,
        verdicts: verdicts ?? this.verdicts,
        log: log ?? this.log,
        busy: busy ?? this.busy,
        lastSentAt: lastSentAt ?? this.lastSentAt,
        extended: extended ?? this.extended,
        unverified: unverified ?? this.unverified,
      );
}

/// 貢献の集めと送り (D-363)。アプリの上で watch しておく(`app.dart`)。
class ContributionController extends Notifier<ContributionState> {
  /// 束が変わってから送るまでの待ち(まとめて送る)。
  static Duration debounce = const Duration(seconds: 20);

  /// 1 回の送りで判定に回す書き手の数 / 端末の下見に回す数。
  static const maxAuthorsPerRun = 20;
  static const maxDeviceChecksPerRun = 8;

  final _relational = <String, ConversationEvent>{};
  final _rai = <String, PendingContribution>{};
  final _sent = <String>{};
  Timer? _timer;
  Timer? _warmTimer;
  bool _warmed = false;

  /// 建て直し(同意の状態や設定が変わったとき)でも、判定・件数・記録は引き継ぐ。
  ContributionState? _last;

  @override
  set state(ContributionState value) {
    _last = value;
    super.state = value;
  }

  @override
  ContributionState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _warmTimer?.cancel();
    });
    final learning = ref.watch(learningProvider).value;
    final settings = ref.watch(settingsAreaProvider(contributionArea)).value ?? const {};
    final supervised = ref.watch(childGateProvider).supervised;
    final active = learning != null && learning.granted && learning.open && !supervised;
    final extended = learning?.extended ?? false;
    final relational = settings['relational'] != false;
    // RAi のやりとりと端末のモデルの下見は、検証用の範囲 (extended) だけ (D-370)。
    final rai = extended && settings['rai'] != false;
    final preload = extended && settings['preload'] != false;
    if (active && relational) {
      // 関連 TL が組んだ会話だけを見る (D-508): 見ても会話を組ませない(関連 TL を開いていないときに、裏で組み直さない)。
      ref.listen(latestConversationEventsProvider, (_, next) => _offerEvents(next));
      // いまある束も(build の中では state を触れないので、次のマイクロタスクで)。
      scheduleMicrotask(() {
        if (ref.mounted) _offerEvents(ref.read(latestConversationEventsProvider));
      });
      if (preload) _warmUp();
    }
    if (!active) {
      _relational.clear();
      _rai.clear();
    }
    final prev = _last ?? const ContributionState();
    return _last = prev.copyWith(active: active, extended: extended, relational: relational, rai: rai, preload: preload, pendingRelational: _relational.length, pendingRai: _rai.length, busy: false);
  }

  void _log(String line) {
    final t = DateTime.now();
    final stamp = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    state = state.copyWith(log: ['$stamp $line', ...state.log].take(40).toList());
  }

  /// 端末の 2B モデルを先に読み込む(インストール済みのときだけ。1 起動 1 回)。
  void _warmUp() {
    if (_warmed) return;
    _warmed = true;
    _warmTimer = Timer(const Duration(seconds: 8), () async {
      try {
        final llm = ref.read(raiLlmProvider);
        if (llm.current.phase != RaiLlmPhase.ready) return;
        _log('端末のモデル(${llm.spec.codename})を読み込みます');
        await llm.warmUp();
      } catch (_) {}
    });
  }

  void _offerEvents(List<ConversationEvent> events) {
    if (!state.active || !state.relational) return;
    var added = 0;
    for (final e in events) {
      final c = state.extended ? relationalContributionOf(e) : ownContributionOf(e);
      if (c == null || _sent.contains(c.key)) continue;
      if (!_relational.containsKey(c.key)) added++;
      _relational[c.key] = e;
    }
    if (added > 0) {
      state = state.copyWith(pendingRelational: _relational.length);
      _schedule();
    }
  }

  /// RAi のやりとりを 1 件足す(`RaiController._record` から)。
  void offerRai({required String query, required String answer, required String mode, String? opId, bool error = false, List<String> steps = const []}) {
    if (!state.active || !state.rai || query.trim().isEmpty) return;
    final c = raiContributionOf(query: query, answer: answer, mode: mode, model: ref.read(raiLlmProvider).spec.id, opId: opId, error: error, steps: steps);
    if (_sent.contains(c.key)) return;
    _rai[c.key] = c;
    state = state.copyWith(pendingRai: _rai.length);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  LearningApi? get _api {
    final c = ref.read(centralClientProvider);
    return c == null ? null : LearningApi(c);
  }

  /// たまっている分を送る(開発者モードの「今すぐ送る」からも)。
  Future<void> flush() async {
    _timer?.cancel();
    final api = _api;
    if (api == null || !state.active || state.busy) return;
    state = state.copyWith(busy: true);
    try {
      if (state.relational && _relational.isNotEmpty) await _flushRelational(api);
      if (state.rai && _rai.isNotEmpty) await _flushRai(api);
      ref.invalidate(learningProvider);
    } catch (e) {
      _log('送れませんでした: $e');
    } finally {
      state = state.copyWith(busy: false, pendingRelational: _relational.length, pendingRai: _rai.length);
    }
  }

  /// 書き手の判定を揃える (D-363 / D-367): 判定がまだの人だけ、端末の下見 → Central の判定。判定の一覧を返す。
  /// クラウド版のリレーショナル TL ([relationalCloudProvider]) からも使う。
  Future<Map<String, AuthorVerdict>> ensureVerdicts(Iterable<ContributionAuthor> authors) async {
    final api = _api;
    if (api == null || !state.active) return state.verdicts;
    final unjudged = <String, ContributionAuthor>{};
    for (final a in authors) {
      if (state.verdicts[a.key]?.verdict case 'allow' || 'deny') continue;
      unjudged.putIfAbsent(a.key, () => a);
    }
    final targets = unjudged.values.take(maxAuthorsPerRun).toList();
    if (targets.isEmpty) return state.verdicts;
    // 自己紹介が TL に無い書き手はプロフィールを読む(数を絞る)。
    final enriched = <ContributionAuthor>[];
    for (final a in targets) {
      enriched.add(await _enrich(a));
    }
    // 端末の下見。
    final pre = LearnabilityPrescreen(ref.read(raiLlmProvider));
    final hints = <String, DeviceHint>{};
    var checks = 0;
    for (final a in enriched) {
      final r = LearnabilityPrescreen.rule(a);
      if (r != null) {
        hints[a.key] = r;
      } else if (checks++ < maxDeviceChecksPerRun) {
        hints[a.key] = await pre.judge(a);
      }
    }
    // クラウドの判定。
    final verdicts = await api.judge([for (final a in enriched) a.toJson(device: hints[a.key])]);
    final next = {...state.verdicts};
    for (final v in verdicts) {
      next['${v['host']}|${v['id']}'] = AuthorVerdict.fromJson(v);
    }
    state = state.copyWith(verdicts: next);
    final allow = verdicts.where((v) => v['verdict'] == 'allow').length;
    final deny = verdicts.where((v) => v['verdict'] == 'deny').length;
    _log('書き手 ${verdicts.length} 人を判定: 許可 $allow / 拒否 $deny / 保留 ${verdicts.length - allow - deny}(端末の下見 ${hints.length} 人)');
    return next;
  }

  Future<void> _flushRelational(LearningApi api) async {
    if (!state.extended) return _flushOwn(api);
    // 1〜3. 判定がまだの書き手を判定する。
    await ensureVerdicts([
      for (final e in _relational.values)
        for (final p in e.posts)
          if (_isPublic(p) && !_isSelf(p)) contributionAuthorOf(p),
    ]);
    // 4. 許可の書き手だけで組み直して送る。判定待ちの書き手が残る束は次へ回す。
    final allowed = {for (final e in state.verdicts.entries) if (e.value.allowed) e.key};
    final items = <PendingContribution>[];
    final done = <String>[];
    var skipped = 0;
    for (final entry in _relational.entries) {
      final waiting = entry.value.posts.any((p) => _isPublic(p) && !_isSelf(p) && !state.verdicts.containsKey('${p.author.account.instance}|${p.author.id}'));
      if (waiting) continue;
      final c = relationalContributionOf(entry.value, allowed: allowed);
      done.add(entry.key);
      if (c == null) {
        skipped++;
      } else {
        items.add(PendingContribution(key: entry.key, authors: c.authors, data: c.data, posts: c.posts));
      }
    }
    for (final k in done) {
      _relational.remove(k);
      _sent.add(k);
    }
    if (skipped > 0) state = state.copyWith(skipped: state.skipped + skipped);
    if (items.isEmpty) return;
    final res = await api.contribute('relational', items);
    state = state.copyWith(sentRelational: state.sentRelational + res.accepted, lastSentAt: DateTime.now());
    _log('リレーショナル: ${items.length} 件を送信(受付 ${res.accepted} / 重複 ${res.duplicate} / 不可 ${res.rejected.length})、許可が無く送らなかった束 $skipped');
  }

  /// 本人の範囲 (D-370): 自分の公開投稿だけ。書き手の判定は要らない。
  Future<void> _flushOwn(LearningApi api) async {
    final items = [for (final e in _relational.values) ?ownContributionOf(e)];
    _sent.addAll(_relational.keys);
    _relational.clear();
    if (items.isEmpty) return;
    final res = await api.contribute('relational', items);
    final unverified = res.rejected.where((r) => r == 'self-unverified').length;
    state = state.copyWith(sentRelational: state.sentRelational + res.accepted, unverified: state.unverified + unverified, lastSentAt: DateTime.now());
    _log('自分の公開投稿: ${items.length} 件を送信(受付 ${res.accepted} / 重複 ${res.duplicate} / 不可 ${res.rejected.length}${unverified > 0 ? '、うち持ち主の確認が未完了 $unverified' : ''})'); // l10n-ignore
  }

  Future<ContributionAuthor> _enrich(ContributionAuthor a) async {
    if (a.bio.isNotEmpty) return a;
    try {
      final session = ref.read(sessionForAccountProvider(a.viewer)) ?? ref.read(currentSnsSessionProvider);
      if (session == null) return a;
      final p = await session.user(a.id).timeout(const Duration(seconds: 8));
      return ContributionAuthor(
        host: a.host,
        id: a.id,
        handle: a.handle,
        bio: p.description ?? '',
        fields: [for (final f in p.fields) '${f.name}: ${f.value}'],
        bot: p.isBot,
        samples: [for (final post in p.pinnedPosts.take(2)) post.body],
        viewer: a.viewer,
      );
    } catch (_) {
      return a;
    }
  }

  Future<void> _flushRai(LearningApi api) async {
    final items = _rai.values.toList();
    _rai.clear();
    _sent.addAll(items.map((i) => i.key));
    final res = await api.contribute('rai', items);
    state = state.copyWith(sentRai: state.sentRai + res.accepted, lastSentAt: DateTime.now());
    _log('RAi: ${items.length} 件を送信(受付 ${res.accepted} / 重複 ${res.duplicate})');
  }
}

final contributionProvider = NotifierProvider<ContributionController, ContributionState>(ContributionController.new);
