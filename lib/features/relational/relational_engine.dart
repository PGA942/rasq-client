import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:rasq_models/rasq_models.dart';

/// リレーショナルTL v1 — **会話イベント方式** (D-027)。
///
/// v0(クラスタ方式)は「ユーザーの普段の関心圏(Louvain コミュニティ)」と
/// 「数分だけ発生する空リプ会話」を同じクラスタとして扱っていたため、
/// 話題の開始検出に失敗して会話が繋がらなかった。v1 は各投稿について
/// 「既存話題に属するか」ではなく **「どの直前投稿への暗黙応答か /
/// 新しい話題の開始か」** を判定する reply-to グラフ構造に変更する:
///
/// 1. 新投稿 → 直近ウィンドウ内のイベント(会話)を候補にリンクを採点
/// 2. 最良リンクが適応しきい値以上 → そのイベントへ追加(投稿単位所属)
/// 3. しきい値未満 → **仮 ROOT**(新話題候補)として保留。後続の関連投稿が
///    来た時点で ROOT まで遡って 1 イベントに確定(First Story Detection)
/// 4. Louvain コミュニティは**事前分布(加点)に格下げ**。ハードフィルタにしない
/// 5. GTL/トレンドからの投稿連結は停止(誤結合ハブになるため)
/// 6. ユーザー退出(無関係 4 連投)は廃止。所属は投稿単位、参加度は時間減衰
/// 7. イベント表現は EMA 単一重心ではなく **固定アンカー(最初の 2〜3 投稿)+
///    最近プロトタイプ(直近 5〜8 投稿)の max 類似**(重心の話題流出を防ぐ)
/// 8. TTL はイベント別適応: `clamp(2 × 投稿間隔Q90, 最短, 最長)`
///
/// リンク採点は現状ルール重み(SigLIP cos / 文字 n-gram / エンティティ /
/// 強アンカー / 時間差 / ユーザーペア親密度 / 発話交替 / 反応表現 /
/// コミュニティ事前分布)。将来は明示リプライ等を弱教師に
/// LightGBM / ロジスティック回帰へ置き換える。

/// 会話イベントの状態。
enum ConversationState {
  /// 新規らしい単独投稿。保留中(表示しない)。
  tentative,

  /// 進行中の会話(2 投稿以上、TTL 以内)。表示対象。
  active,

  /// 投稿間隔が空いた。強アンカー一致でのみ再開できる。
  dormant,

  /// 再開可能時間を超えた。
  closed,
}

/// リンク採点の重み (D-028)。初期値は実測チューニング前の暫定なので、
/// FOW チューニングパネルからライブ調整できる(通常投稿プロファイル。
/// 反応表現プロファイルは固定比率 + [reactiveBonus] のみ調整可)。
@immutable
class LinkWeights {
  const LinkWeights({
    this.content = 0.45,
    this.entity = 0.20,
    this.time = 0.15,
    this.affinity = 0.10,
    this.turn = 0.05,
    this.anchor = 0.10,
    this.hardAnchorBonus = 0.2,
    this.reactiveBonus = 0.15,
    this.communityPrior = 0.05,
  });

  /// 内容類似(SigLIP cos / 文字 n-gram の max)。
  final double content;

  /// エンティティ一致(1件=0.6 / 2件以上=1.0)。
  final double entity;

  /// 時間減衰 e^(-Δt/τ)。
  final double time;

  /// ユーザーペア親密度。
  final double affinity;

  /// 発話交替(A→B→A)。
  final double turn;

  /// アンカー(ハード=1.0 / ソフト#タグ=0.6)。
  final double anchor;

  /// ハードアンカー(URL・引用先)一致のフラット加点。
  final double hardAnchorBonus;

  /// 反応表現(「それな」等)の応答証拠としてのフラット加点。
  final double reactiveBonus;

  /// Louvain コミュニティ事前分布(同一 +、異なる −)。
  final double communityPrior;

  LinkWeights copyWith({double? content, double? entity, double? time, double? affinity, double? turn, double? anchor, double? hardAnchorBonus, double? reactiveBonus, double? communityPrior}) => LinkWeights(
        content: content ?? this.content,
        entity: entity ?? this.entity,
        time: time ?? this.time,
        affinity: affinity ?? this.affinity,
        turn: turn ?? this.turn,
        anchor: anchor ?? this.anchor,
        hardAnchorBonus: hardAnchorBonus ?? this.hardAnchorBonus,
        reactiveBonus: reactiveBonus ?? this.reactiveBonus,
        communityPrior: communityPrior ?? this.communityPrior,
      );

  Map<String, Object?> toJson() => {
        'content': content,
        'entity': entity,
        'time': time,
        'affinity': affinity,
        'turn': turn,
        'anchor': anchor,
        'hardAnchorBonus': hardAnchorBonus,
        'reactiveBonus': reactiveBonus,
        'communityPrior': communityPrior,
      };

  factory LinkWeights.fromJson(Map<String, Object?> json) {
    double d(String key, double fallback) => (json[key] as num?)?.toDouble() ?? fallback;
    const def = LinkWeights();
    return LinkWeights(
      content: d('content', def.content),
      entity: d('entity', def.entity),
      time: d('time', def.time),
      affinity: d('affinity', def.affinity),
      turn: d('turn', def.turn),
      anchor: d('anchor', def.anchor),
      hardAnchorBonus: d('hardAnchorBonus', def.hardAnchorBonus),
      reactiveBonus: d('reactiveBonus', def.reactiveBonus),
      communityPrior: d('communityPrior', def.communityPrior),
    );
  }
}

/// リレーショナルTL 設定 (D-027)。
///
/// [linkBias] はリンクしきい値への全体バイアス(**50〜100 正規化のスライダー**、
/// 75 = 補正なし)。しきい値そのものはコミュニティ別に適応させるため
/// (いつも同じ作品の話をするコミュニティでは素の類似度が常時高い)、
/// 普段ユーザーが触るのは「束ねやすさ」の一つまみだけにする。細かい
/// パラメーターは FOW チューニングパネル(D-028)から。
@immutable
class RelationalSettings {
  const RelationalSettings({
    this.linkBias = 75,
    this.candidateWindowMinutes = 30,
    this.tentativeHoldSeconds = 150,
    this.minTtlMinutes = 5,
    this.maxTtlMinutes = 30,
    this.tauSeconds = 600,
    this.weights = const LinkWeights(),
  });

  /// 束ねやすさ(50〜100)。100 に近いほど厳しく(束ねにくく)なる。
  final int linkBias;

  /// 親候補を探す直近ウィンドウ(分)。
  final int candidateWindowMinutes;

  /// 仮 ROOT の保留時間(秒)。この間は「新話題として確定」しない
  /// (リアルタイム性を数分犠牲にして開始点精度を上げる)。
  final int tentativeHoldSeconds;

  /// イベント TTL の下限(分)。
  final int minTtlMinutes;

  /// イベント TTL の上限(分)。
  final int maxTtlMinutes;

  /// 時間減衰 e^(-Δt/τ) の τ(秒)。
  final int tauSeconds;

  /// リンク採点の重み。
  final LinkWeights weights;

  /// スライダー値 → しきい値オフセット(-0.25〜+0.25)。
  double get biasOffset => (linkBias.clamp(50, 100) - 75) / 100.0;

  RelationalSettings copyWith({int? linkBias, int? candidateWindowMinutes, int? tentativeHoldSeconds, int? minTtlMinutes, int? maxTtlMinutes, int? tauSeconds, LinkWeights? weights}) => RelationalSettings(
        linkBias: linkBias ?? this.linkBias,
        candidateWindowMinutes: candidateWindowMinutes ?? this.candidateWindowMinutes,
        tentativeHoldSeconds: tentativeHoldSeconds ?? this.tentativeHoldSeconds,
        minTtlMinutes: minTtlMinutes ?? this.minTtlMinutes,
        maxTtlMinutes: maxTtlMinutes ?? this.maxTtlMinutes,
        tauSeconds: tauSeconds ?? this.tauSeconds,
        weights: weights ?? this.weights,
      );

  Map<String, Object?> toJson() => {
        'linkBias': linkBias,
        'candidateWindowMinutes': candidateWindowMinutes,
        'tentativeHoldSeconds': tentativeHoldSeconds,
        'minTtlMinutes': minTtlMinutes,
        'maxTtlMinutes': maxTtlMinutes,
        'tauSeconds': tauSeconds,
        'weights': weights.toJson(),
      };

  factory RelationalSettings.fromJson(Map<String, Object?> json) {
    int i(String key, int fallback) => (json[key] as num?)?.toInt() ?? fallback;
    const def = RelationalSettings();
    return RelationalSettings(
      linkBias: i('linkBias', def.linkBias),
      candidateWindowMinutes: i('candidateWindowMinutes', def.candidateWindowMinutes),
      tentativeHoldSeconds: i('tentativeHoldSeconds', def.tentativeHoldSeconds),
      minTtlMinutes: i('minTtlMinutes', def.minTtlMinutes),
      maxTtlMinutes: i('maxTtlMinutes', def.maxTtlMinutes),
      tauSeconds: i('tauSeconds', def.tauSeconds),
      weights: json['weights'] is Map ? LinkWeights.fromJson((json['weights'] as Map).cast<String, Object?>()) : def.weights,
    );
  }
}

/// 2 投稿の類似度(0〜1、cos 相当)。SigLIP 配線時は
/// `(text_embeds コサイン + 1) / 2` を注入する。
typedef PostSimilarity = double Function(Post a, Post b);

/// 特徴語: #タグ / @メンション / 固有名詞近似(2文字以上のカタカナ・英数語、
/// 2文字以上の漢字連続)。GLiNER 配線後はゼロショット抽出結果を加える。
Set<String> extractFeatures(Post p) {
  final out = <String>{};
  final text = '${p.body} ${p.quote?.body ?? ''}';
  for (final m in RegExp(r'#([^\s#＃]+)').allMatches(text)) {
    out.add(m.group(1)!.toLowerCase());
  }
  for (final m in RegExp(r'@([A-Za-z0-9_.-]+)').allMatches(text)) {
    out.add(m.group(1)!.toLowerCase());
  }
  for (final m in RegExp(r'([ァ-ヴー]{2,}|[A-Za-z0-9][A-Za-z0-9\-_.]{1,})').allMatches(text)) {
    out.add(m.group(1)!.toLowerCase());
  }
  for (final m in RegExp(r'([一-龠々]{2,})').allMatches(text)) {
    out.add(m.group(1)!);
  }
  return out;
}

/// 強い共通アンカー(ソフト): ハッシュタグ。同じ話題の可能性が高いが、
/// `#daily` のような汎用タグもあるため加点どまり(単独ではリンクさせない)。
Set<String> strongAnchors(Post p) {
  final out = <String>{};
  final text = '${p.body} ${p.quote?.body ?? ''}';
  for (final m in RegExp(r'#([^\s#＃]+)').allMatches(text)) {
    out.add('#${m.group(1)!.toLowerCase()}');
  }
  return out;
}

/// 強い共通アンカー(ハード): URL / 引用先。一致すればほぼ確実に同じ話題で、
/// **休眠イベントの再開**にも使える。画像 pHash は端末側実装が入ったら追加。
Set<String> hardAnchors(Post p) {
  final out = <String>{};
  final text = '${p.body} ${p.quote?.body ?? ''}';
  for (final m in RegExp(r'https?://[^\s]+').allMatches(text)) {
    out.add(m.group(0)!.replaceAll(RegExp(r'[).,]+$'), '').toLowerCase());
  }
  if (p.linkUrl != null) out.add(p.linkUrl.toString().toLowerCase());
  if (p.quote != null) out.add('quote:${p.quote!.key}');
  return out;
}

final _reactionLexicon = RegExp(
  r'(それな|それはそう|わか(る|り)|分か(る|り)|たしかに|確かに|ほん(と|ま)それ|ほんそれ|まじ|マジ|ﾏｼﾞ|え[っぇえー]+|うそ|ウソ|嘘でしょ|草|くさ|ｗ+|w{2,}|笑った|わろた|ワロタ|やば|ヤバ|つら|辛|無理|むり|尊い|最高|好き|すき|おめでと|お(つかれ|疲れ)|それ|これ|あれ|だよね|よね[ぇー]?)',
);

/// 暗黙応答らしい短文か(「それな」「わかる」「えっ」など)。埋め込みや
/// n-gram では中身が測れないぶん、時間差・親密度・発話交替を重く見る。
bool isReactivePost(Post p) {
  final body = p.body.trim();
  if (body.isEmpty || body.length > 30) return false;
  return _reactionLexicon.hasMatch(body);
}

/// 文字 2〜3-gram プロファイル(表記揺れ・略語・オタク語彙に強い。短文では
/// 埋め込みより効くことがあるため必ず併用する)。
Map<String, double> charNgramProfile(String text) {
  final t = text.toLowerCase().replaceAll(RegExp(r'https?://[^\s]+'), ' ').replaceAll(RegExp(r'[\s#＃@]+'), '');
  final counts = <String, double>{};
  for (final n in const [2, 3]) {
    for (var i = 0; i + n <= t.length; i++) {
      final g = t.substring(i, i + n);
      counts[g] = (counts[g] ?? 0) + 1;
    }
  }
  return counts;
}

double cosineOfProfiles(Map<String, double> a, Map<String, double> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  var na = 0.0;
  var nb = 0.0;
  for (final v in a.values) {
    na += v * v;
  }
  for (final v in b.values) {
    nb += v * v;
  }
  var dot = 0.0;
  final (small, large) = a.length <= b.length ? (a, b) : (b, a);
  for (final e in small.entries) {
    final w = large[e.key];
    if (w != null) dot += e.value * w;
  }
  return dot / (math.sqrt(na) * math.sqrt(nb));
}

/// ルールベースの投稿間類似度(0.5〜1.0 の擬似 cos)。SigLIP の埋め込みが
/// 取れないペアのフォールバック(relational_ml.dart)。
double ruleBasedSimilarity(Post a, Post b) {
  final fa = extractFeatures(a);
  final fb = extractFeatures(b);
  var jaccard = 0.0;
  if (fa.isNotEmpty && fb.isNotEmpty) {
    jaccard = fa.intersection(fb).length / fa.union(fb).length;
  }
  final ngram = cosineOfProfiles(charNgramProfile(a.body), charNgramProfile(b.body));
  return 0.5 + 0.5 * math.max(jaccard, ngram);
}

/// エンティティ一致数。漢字連続の切り出しは活用語尾を巻き込んでズレる
/// (「配信見てる」→「配信見」)ため、完全一致に加えて**片方向の包含**
/// (2 文字以上)も一致に数える。
int entityOverlap(Set<String> a, Set<String> b) {
  var n = 0;
  for (final x in a) {
    if (x.length < 2) continue;
    if (b.contains(x) || b.any((y) => y.length >= 2 && (x.contains(y) || y.contains(x)))) n++;
  }
  return n;
}

/// ユーザーペア親密度: 普段この 2 人が時間的に近接して投稿するか。
/// 明示リプライ・リノート関係が取れたら重み付けを足す。
class UserPairAffinity {
  final Map<String, int> _count = {};

  static String _key(String a, String b) => a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

  void record(String a, String b, {int weight = 1}) {
    if (a == b) return;
    final k = _key(a, b);
    _count[k] = (_count[k] ?? 0) + weight;
  }

  /// 0〜1(共起 3 回で 0.5)。
  double of(String a, String b) {
    final c = _count[_key(a, b)] ?? 0;
    return c / (c + 3);
  }
}

/// 1 会話イベント = 「関連」タブの 1 カード。所属は**投稿単位**で、
/// ユーザーは除外しない(1 人が複数話題を並行するため)。
class ConversationEvent {
  ConversationEvent.root(Post p)
      : id = p.key,
        posts = [p],
        postKeys = {p.key},
        entities = extractFeatures(p),
        anchors = strongAnchors(p),
        hardAnchorSet = hardAnchors(p),
        participants = {
          p.author.key: p.createdAt,
          // リノートで運ばれてきた投稿は、運んだ人(リノート主)も参加者。
          if (p.repostedBy != null) p.repostedBy!.key: p.createdAt,
        },
        intervalSeconds = [],
        lastActivityAt = p.createdAt;

  final String id;

  /// 時系列順の所属投稿。先頭が ROOT(開始点)。
  final List<Post> posts;
  final Set<String> postKeys;

  /// 共通エンティティ(特徴語の和集合)。
  final Set<String> entities;

  /// ソフトアンカー(#タグ)。
  final Set<String> anchors;

  /// ハードアンカー(URL / 引用先)。休眠からの再開判定に使う。
  final Set<String> hardAnchorSet;

  /// 参加ユーザー → 最終参加時刻(参加度の時間減衰用。除外はしない)。
  final Map<String, DateTime> participants;

  /// 投稿間隔の実測(TTL の適応に使う)。
  final List<int> intervalSeconds;

  DateTime lastActivityAt;

  Post get root => posts.first;

  /// 固定アンカー投稿: 最初の 2〜3 投稿(話題の原点。EMA のように流されない)。
  List<Post> get anchorPosts => posts.length <= 3 ? posts : posts.sublist(0, 3);

  /// 可変プロトタイプ: 直近の投稿(会話の発展に追従する)。
  List<Post> get recentPosts => posts.length <= 8 ? posts : posts.sublist(posts.length - 8);

  /// 参加メンバー(著者 + リノート主)。自分自身も含む — タイル表示側で
  /// 自分のアイコンだけ除外する。
  List<UserSummary> get members {
    final seen = <String>{};
    return [
      for (final p in posts) ...[
        if (seen.add(p.author.key)) p.author,
        if (p.repostedBy != null && seen.add(p.repostedBy!.key)) p.repostedBy!,
      ],
    ];
  }

  void add(Post p) {
    intervalSeconds.add(p.createdAt.difference(lastActivityAt).inSeconds.abs());
    posts.add(p);
    postKeys.add(p.key);
    entities.addAll(extractFeatures(p));
    anchors.addAll(strongAnchors(p));
    hardAnchorSet.addAll(hardAnchors(p));
    void touch(String key) {
      final prev = participants[key];
      if (prev == null || p.createdAt.isAfter(prev)) participants[key] = p.createdAt;
    }

    touch(p.author.key);
    if (p.repostedBy != null) touch(p.repostedBy!.key);
    if (p.createdAt.isAfter(lastActivityAt)) lastActivityAt = p.createdAt;
  }

  /// イベント別 TTL: `clamp(2 × 投稿間隔Q90, 最短, 最長)`。テンポの速い
  /// 空リプ会話は早く沈み、ゆっくりした会話は長く保つ。
  Duration ttl(RelationalSettings s) {
    if (intervalSeconds.isEmpty) return Duration(minutes: s.minTtlMinutes);
    final sorted = [...intervalSeconds]..sort();
    final q90 = sorted[((sorted.length - 1) * 0.9).round()];
    final sec = (2 * q90).clamp(s.minTtlMinutes * 60, s.maxTtlMinutes * 60);
    return Duration(seconds: sec);
  }

  ConversationState stateAt(DateTime now, RelationalSettings s) {
    if (posts.length < 2) {
      return now.difference(root.createdAt) > Duration(minutes: s.candidateWindowMinutes) ? ConversationState.closed : ConversationState.tentative;
    }
    final idle = now.difference(lastActivityAt);
    final t = ttl(s);
    if (idle <= t) return ConversationState.active;
    if (idle <= t * 2) return ConversationState.dormant;
    return ConversationState.closed;
  }
}

/// 会話イベントエンジン (D-027)。投稿を時系列に処理し、投稿ごとに
/// 「どの会話への暗黙応答か / 新話題の開始か」を判定する。
class ConversationEngine {
  ConversationEngine({this.settings = const RelationalSettings(), this.semantic, this.communityOf});

  final RelationalSettings settings;

  /// SigLIP 類似度((cos+1)/2 に写像済み)。無ければ文字 n-gram のみ。
  final PostSimilarity? semantic;

  /// SigLIP EMA → Louvain の著者コミュニティ(D-024)。**事前分布**として
  /// ±の加点にだけ使い、束ねの可否を決めるフィルタにはしない。
  final Map<String, int>? communityOf;

  final Map<String, Map<String, double>> _profiles = {};

  /// コミュニティ別: ROOT 判定時(= 無関係だった)のベストスコア標本。
  final Map<int?, List<double>> _rootScoreSamples = {};

  Map<String, double> _profile(Post p) => _profiles.putIfAbsent(p.key, () => charNgramProfile(p.body));

  /// 適応しきい値: 無関係投稿のベストスコアの `中央値 + 2.5 × MAD` を
  /// コミュニティ別に推定(いつも同じ作品の話をするコミュニティでは素の
  /// 類似度が常時高いため、全体共通にしない)。標本不足の間は既定 0.5。
  @visibleForTesting
  double thresholdFor(int? community) {
    var base = 0.5;
    final samples = _rootScoreSamples[community];
    if (samples != null && samples.length >= 8) {
      final sorted = [...samples]..sort();
      final median = sorted[sorted.length ~/ 2];
      final devs = [for (final s in samples) (s - median).abs()]..sort();
      final mad = devs[devs.length ~/ 2];
      base = (median + 2.5 * mad).clamp(0.35, 0.8);
    }
    return (base + settings.biasOffset).clamp(0.3, 0.95);
  }

  double _contentPair(Post a, Post b) {
    var s = cosineOfProfiles(_profile(a), _profile(b));
    final sem = semantic;
    if (sem != null) {
      // (cos+1)/2 の写像を 0..1 に伸長(無関係 ≈ 0.5 が床にならないように)。
      s = math.max(s, (2 * sem(a, b) - 1).clamp(0.0, 1.0));
    }
    return s;
  }

  /// P(p が イベント e への暗黙応答)。ルール重み(将来 LightGBM に置換)。
  @visibleForTesting
  double linkScore(Post p, ConversationEvent e, UserPairAffinity affinity, {required bool anchorMatch, required bool hardMatch}) {
    final w = settings.weights;
    var content = 0.0;
    for (final q in {...e.anchorPosts, ...e.recentPosts}) {
      content = math.max(content, _contentPair(p, q));
    }
    final dtSec = p.createdAt.difference(e.lastActivityAt).inSeconds.abs();
    final timeDecay = math.exp(-dtSec / settings.tauSeconds);
    final overlap = entityOverlap(extractFeatures(p), e.entities);
    final entityScore = overlap >= 2 ? 1.0 : (overlap == 1 ? 0.6 : 0.0);
    var aff = 0.0;
    for (final u in e.participants.keys) {
      aff = math.max(aff, affinity.of(p.author.key, u));
    }
    // 発話交替: A→B→A のような往復は空リプらしさが強い。
    var turn = 0.0;
    if (e.participants.containsKey(p.author.key)) {
      turn = e.posts.last.author.key != p.author.key ? 1.0 : 0.4;
    }
    // ハードアンカー(URL/引用先)一致はほぼ確実に同じ話題 → フラット加点。
    // ソフトアンカー(#タグ)は汎用タグの誤結合があるので小さめ。
    final anchor = hardMatch ? 1.0 : (anchorMatch ? 0.6 : 0.0);
    final hardBonus = hardMatch ? w.hardAnchorBonus : 0.0;
    var prior = 0.0;
    final ca = communityOf?[p.author.key];
    final ce = communityOf?[e.root.author.key];
    if (ca != null && ce != null) prior = ca == ce ? w.communityPrior : -w.communityPrior;

    if (isReactivePost(p)) {
      // 反応表現は中身が測れない: それ自体が「直前の何かへの応答」の証拠
      // ([LinkWeights.reactiveBonus])とみなし、時間差・親密度・往復を重く
      // 見る固定プロファイル(比率は通常プロファイルと独立)。
      return (0.15 * content + 0.40 * timeDecay + 0.20 * aff + 0.15 * turn + 0.10 * math.max(entityScore, anchor) + w.reactiveBonus + hardBonus + prior).clamp(0.0, 1.0);
    }
    return (w.content * content + w.entity * entityScore + w.time * timeDecay + w.affinity * aff + w.turn * turn + w.anchor * anchor + hardBonus + prior).clamp(0.0, 1.0);
  }

  /// フォロイーの投稿列から会話イベントを組む(仮 ROOT 含む全イベント)。
  /// GTL/トレンド候補の連結は v1 で**廃止**(人気話題が複数コミュニティを
  /// 誤結合するハブになるため。残すなら確定後の背景情報検索に分離する)。
  List<ConversationEvent> buildAll({required List<Post> followeePosts, DateTime? now}) {
    final posts = [...followeePosts]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final events = <ConversationEvent>[];
    final affinity = UserPairAffinity();
    final window = Duration(minutes: settings.candidateWindowMinutes);
    Post? prev;
    for (final p in posts) {
      // 近接投稿ペア → 親密度(普段この 2 人が近くで投稿するか)。
      if (prev != null && p.createdAt.difference(prev.createdAt) <= const Duration(minutes: 5)) {
        affinity.record(prev.author.key, p.author.key);
      }
      // リノートは直接のインタラクション → 近接共起より強く効かせる。
      if (p.repostedBy != null) {
        affinity.record(p.repostedBy!.key, p.author.key, weight: 2);
      }
      final anchorsOfP = strongAnchors(p);
      final hardOfP = hardAnchors(p);
      ConversationEvent? best;
      var bestScore = 0.0;
      var sawCandidate = false;
      for (final e in events) {
        if (e.postKeys.contains(p.key)) continue;
        final hardMatch = hardOfP.any(e.hardAnchorSet.contains);
        final anchorMatch = hardMatch || anchorsOfP.any(e.anchors.contains);
        final within = p.createdAt.difference(e.lastActivityAt) <= window;
        // 休眠イベントはハードアンカー一致でのみ再開候補になる。
        if (!within && !hardMatch) continue;
        if (e.stateAt(p.createdAt, settings) == ConversationState.closed && !hardMatch) continue;
        sawCandidate = true;
        final s = linkScore(p, e, affinity, anchorMatch: anchorMatch, hardMatch: hardMatch);
        if (s > bestScore) {
          bestScore = s;
          best = e;
        }
      }
      final community = communityOf?[p.author.key];
      if (best != null && bestScore >= thresholdFor(community)) {
        best.add(p);
      } else {
        if (sawCandidate) (_rootScoreSamples[community] ??= []).add(bestScore);
        events.add(ConversationEvent.root(p));
      }
      prev = p;
    }
    return events;
  }

  /// 表示対象 = ACTIVE のイベントだけ、活動が新しい順。仮 ROOT(単独投稿)は
  /// 後続が来るまで表示しない(「保留して遡る」— 開始点はどのみち batch
  /// 再構築で遡及的に含まれる)。
  ///
  /// [lookback] を渡すと、TTL で沈んだ(DORMANT/CLOSED)会話も最終活動が
  /// lookback 以内なら表示に含める(D-028: アクティブフォロイーが少ない
  /// ときに、リスト末尾で引っ張って過去の空リプを遡るため)。
  List<ConversationEvent> build({required List<Post> followeePosts, DateTime? now, Duration? lookback}) {
    final clock = now ?? DateTime.now();
    final all = buildAll(followeePosts: followeePosts, now: clock);
    final out = [
      for (final e in all)
        if (e.posts.length >= 2 && (e.stateAt(clock, settings) == ConversationState.active || (lookback != null && clock.difference(e.lastActivityAt) <= lookback))) e,
    ];
    out.sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    return out;
  }

  /// 自分の関連投稿にアクション(リアクション・返信等)が付いた → 浮上。
  void markAction(List<ConversationEvent> events, {required String postKey, required DateTime at}) {
    for (final e in events) {
      if (e.postKeys.contains(postKey) && at.isAfter(e.lastActivityAt)) e.lastActivityAt = at;
    }
  }
}
