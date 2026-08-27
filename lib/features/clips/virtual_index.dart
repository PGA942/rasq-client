import 'package:flutter/foundation.dart';
import 'package:rasq_models/rasq_models.dart';

import '../relational/relational_engine.dart';

/// 仮想目次 (D-036)。クリップ / リスト / TL の投稿列の上に重ねる
/// **ナビゲーション用の索引** — 投稿を別のタイムラインへ再編成するのではなく、
/// 参照(post key)だけを保持する。見出しは LLM 生成ではなく**投稿内に実在する
/// 語**から組み立てる(要約ではなく索引)。
///
/// ラベルの優先順位(アドバイス原文): 手動見出し > 共通ハッシュタグ >
/// エンティティ(GLiNER 配線後は実 NER) > 頻出 n-gram > URL ドメイン >
/// 投稿者名 > 日付。適切な語が無ければ無理に命名せず「関連投稿 N件」。
/// 階層は**最大 2**(3 階層以上は自動分類の誤りが目立つ)。
enum IndexEntryState { tentative, active, dormant }

@immutable
class IndexEntry {
  const IndexEntry({
    required this.id,
    required this.label,
    required this.labelSource,
    required this.postKeys,
    this.representativeKeys = const [],
    this.participantKeys = const {},
    required this.startedAt,
    required this.lastActiveAt,
    this.confidence = 1.0,
    this.state = IndexEntryState.active,
    this.children = const [],
  });

  final String id;

  /// 表示ラベル(実在語。`#タグ` / 語 / ドメイン / 「関連投稿 N件」)。
  final String label;

  /// hashtag | entity | url | author | date | event | fallback
  final String labelSource;

  /// 所属投稿(参照のみ。並びは元の一覧のまま)。
  final List<String> postKeys;

  /// 「この分類になった根拠」として見せる代表投稿(開始候補 / 共通語最多 /
  /// 強アンカー持ち、2〜3件)。
  final List<String> representativeKeys;
  final Set<String> participantKeys;
  final DateTime startedAt;
  final DateTime lastActiveAt;

  /// 低いうちは仮ラベル(「関連投稿 N件」)で出し、根拠が増えたら命名する。
  final double confidence;
  final IndexEntryState state;

  /// 第 2 階層(これ以上は掘らない)。
  final List<IndexEntry> children;

  int get count => postKeys.length;
}

const fallbackIndexLabel = '話題を特定できない投稿';

/// ラベル候補: 優先度つきの (語, 重み)。
Map<String, double> _labelCandidates(Post p) {
  final out = <String, double>{};
  // 共通ハッシュタグ(最優先)。
  for (final a in strongAnchors(p)) {
    out[a] = 3.0;
  }
  // URL ドメイン。
  for (final h in hardAnchors(p)) {
    final uri = Uri.tryParse(h.startsWith('quote:') ? '' : h);
    final domain = uri?.host ?? '';
    if (domain.isNotEmpty) out[domain] = (out[domain] ?? 0) < 2.0 ? 2.0 : out[domain]!;
  }
  // エンティティ近似(GLiNER 配線後は実 NER 結果に置き換え)。
  for (final f in extractFeatures(p)) {
    if (f.length < 2 || f.startsWith('#')) continue;
    out.putIfAbsent(f, () => 1.0);
  }
  // 漢字+カタカナ混在の名詞(「猫カフェ」「夏イベント」等)。片方だけの
  // 切り出しより長い表層語を少しだけ優先する(後続の動詞漢字は食わない)。
  final text = '${p.body} ${p.quote?.body ?? ''}';
  for (final m in RegExp(r'([一-龠々]{1,3}[ァ-ヴー]{2,}|[ァ-ヴー]{2,}[一-龠々]{1,3})').allMatches(text)) {
    final t = m.group(1)!;
    if (t.length >= 3) out[t] = 1.2;
  }
  return out;
}

List<String> _representatives(List<Post> posts, String label) {
  final sorted = [...posts]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final keys = <String>[sorted.first.key]; // 開始候補
  // 強アンカー(URL/引用)持ち。
  final anchored = posts.where((p) => hardAnchors(p).isNotEmpty).firstOrNull;
  if (anchored != null && !keys.contains(anchored.key)) keys.add(anchored.key);
  // ラベル語を含む最初の投稿。
  final labeled = posts.where((p) => _labelCandidates(p).containsKey(label)).firstOrNull;
  if (labeled != null && !keys.contains(labeled.key)) keys.add(labeled.key);
  return keys.take(3).toList();
}

IndexEntry _entryFor(String id, String label, String source, List<Post> posts, {double confidence = 1.0, List<IndexEntry> children = const []}) {
  final sorted = [...posts]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return IndexEntry(
    id: id,
    label: label,
    labelSource: source,
    postKeys: [for (final p in posts) p.key],
    representativeKeys: _representatives(posts, label),
    participantKeys: {for (final p in posts) p.author.key, for (final p in posts) if (p.repostedBy != null) p.repostedBy!.key},
    startedAt: sorted.first.createdAt,
    lastActiveAt: sorted.last.createdAt,
    confidence: confidence,
    children: children,
  );
}

/// 貪欲ラベル被覆: 最も多くの未割当投稿を覆う実在語から章を切り出す。
/// [excludeLabels] は第 2 階層で親ラベルを除外するために使う。
/// [fullCoverageSize] を渡すと、その件数を丸ごと覆うラベル(=親と同じ集合を
/// 別名で覆うだけの語)を分割候補から外す。
List<(String, String, List<Post>)> _greedyGroups(List<Post> posts, {required int minGroupSize, required int maxEntries, Set<String> excludeLabels = const {}, int? fullCoverageSize}) {
  final remaining = [...posts];
  final groups = <(String, String, List<Post>)>[];
  while (remaining.length >= minGroupSize && groups.length < maxEntries) {
    // ラベル → (重み, 該当投稿)。
    final byLabel = <String, (double, List<Post>)>{};
    for (final p in remaining) {
      for (final e in _labelCandidates(p).entries) {
        if (excludeLabels.contains(e.key)) continue;
        final cur = byLabel[e.key];
        byLabel[e.key] = (cur == null ? e.value : (cur.$1 > e.value ? cur.$1 : e.value), [...?cur?.$2, p]);
      }
    }
    (String, double, List<Post>)? best;
    for (final e in byLabel.entries) {
      if (e.value.$2.length < minGroupSize) continue;
      if (fullCoverageSize != null && e.value.$2.length >= fullCoverageSize) continue;
      final score = e.value.$1 * e.value.$2.length;
      if (best == null || score > best.$2) best = (e.key, score, e.value.$2);
    }
    if (best == null) break;
    final source = best.$1.startsWith('#') ? 'hashtag' : (best.$1.contains('.') && Uri.tryParse('https://${best.$1}')?.host == best.$1 ? 'url' : 'entity');
    groups.add((best.$1, source, best.$3));
    remaining.removeWhere(best.$3.contains);
  }
  return groups;
}

/// 投稿集合の見出し(最も多くの投稿に共通する実在語)。2 投稿未満の共有なら
/// null(無理に命名しない)。リレーショナルページ / イベントタイルの 1 行
/// 見出しに使う。
String? sharedHeadline(List<Post> posts) {
  final counts = <String, (double, int)>{};
  for (final p in posts) {
    for (final e in _labelCandidates(p).entries) {
      final cur = counts[e.key];
      counts[e.key] = (cur == null ? e.value : (cur.$1 > e.value ? cur.$1 : e.value), (cur?.$2 ?? 0) + 1);
    }
  }
  String? best;
  var bestScore = 0.0;
  counts.forEach((label, v) {
    if (v.$2 < 2) return;
    final score = v.$1 * v.$2 + label.length * 0.01;
    if (score > bestScore) {
      best = label;
      bestScore = score;
    }
  });
  return best;
}

/// 上位の共有ラベル(キーワードチップ用、共有数順・最大 [max] 件)。
List<String> topSharedLabels(List<Post> posts, {int max = 4}) {
  final counts = <String, (double, int)>{};
  for (final p in posts) {
    for (final e in _labelCandidates(p).entries) {
      final cur = counts[e.key];
      counts[e.key] = (cur == null ? e.value : (cur.$1 > e.value ? cur.$1 : e.value), (cur?.$2 ?? 0) + 1);
    }
  }
  final shared = [for (final e in counts.entries) if (e.value.$2 >= 2) (e.key, e.value.$1 * e.value.$2)]..sort((a, b) => b.$2.compareTo(a.$2));
  final out = <String>[];
  for (final (label, _) in shared) {
    // ほぼ同じ表層語(包含)は 1 つに寄せる。
    if (out.any((o) => o.contains(label) || label.contains(o))) continue;
    out.add(label);
    if (out.length >= max) break;
  }
  return out;
}

/// リストTL 用の目次「いま話されていること」: 会話イベント(2 投稿以上)を
/// 章にし、単発投稿は 1 つのバケツにまとめる(アドバイス原文の表示例)。
List<IndexEntry> indexForListTimeline(List<Post> posts, {ConversationEngine? engine, DateTime? now}) {
  if (posts.isEmpty) return const [];
  final e = engine ?? ConversationEngine();
  final events = e.buildAll(followeePosts: posts, now: now);
  final multi = [for (final ev in events) if (ev.posts.length >= 2) ev];
  final entries = indexFromConversationEvents(multi, now: now, settings: e.settings);
  final singles = [for (final ev in events) if (ev.posts.length < 2) ...ev.posts];
  if (singles.isNotEmpty) {
    final sorted = [...singles]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [
      ...entries,
      IndexEntry(
        id: 'singles',
        label: '単発投稿',
        labelSource: 'fallback',
        postKeys: [for (final p in sorted) p.key],
        startedAt: sorted.first.createdAt,
        lastActiveAt: sorted.last.createdAt,
        confidence: 0.2,
        state: IndexEntryState.dormant,
      ),
    ];
  }
  return entries;
}

/// クリップ用の目次: 長期的な話題を内容ベース(時間窓なし)で束ねる。
/// 保存時 or 閲覧時に再計算(D-036: クリップ行)。
List<IndexEntry> buildClipIndex(List<Post> posts, {int minGroupSize = 2, int maxEntries = 8}) {
  if (posts.isEmpty) return const [];
  final groups = _greedyGroups(posts, minGroupSize: minGroupSize, maxEntries: maxEntries);
  final assigned = <String>{};
  final entries = <IndexEntry>[];
  for (final (label, source, members) in groups) {
    assigned.addAll([for (final p in members) p.key]);
    // 第 2 階層: 大きい章は中をもう一段だけ分類する(親ラベル語は除いて)。
    var children = const <IndexEntry>[];
    if (members.length >= 6) {
      // 親ラベルは # 付き / # なしの表層語どちらも除外(同じ集合を覆うだけの
      // 分割を防ぐ)。
      final sub = _greedyGroups(members, minGroupSize: 2, maxEntries: 4, excludeLabels: {label, label.startsWith('#') ? label.substring(1) : '#$label'}, fullCoverageSize: members.length);
      children = [
        for (final (sl, ss, sm) in sub)
          if (sm.length < members.length) _entryFor('$label/$sl', sl, ss, sm),
      ];
    }
    entries.add(_entryFor(label, label, source, members, children: children));
  }
  entries.sort((a, b) => b.count.compareTo(a.count)); // クリップは件数順
  final rest = [for (final p in posts) if (!assigned.contains(p.key)) p];
  if (rest.isNotEmpty) {
    entries.add(_entryFor('fallback', fallbackIndexLabel, 'fallback', rest, confidence: 0.2));
  }
  return entries;
}

/// リスト / TL 用: 会話イベント(D-027)をそのまま目次の章に変換する。
/// 確信度が低い(共有エンティティが無い)章は「関連投稿 N件」の仮ラベルで
/// 出し、根拠が増えたら命名される — 遅延確定が UI 上の自然な挙動になる。
List<IndexEntry> indexFromConversationEvents(List<ConversationEvent> events, {DateTime? now, RelationalSettings settings = const RelationalSettings()}) {
  final clock = now ?? DateTime.now();
  final out = <IndexEntry>[];
  for (final e in events) {
    // 章ラベル = イベント内で最も多くの投稿に共通する実在語。
    final counts = <String, int>{};
    for (final p in e.posts) {
      for (final label in _labelCandidates(p).keys) {
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    String? best;
    var bestCount = 1;
    counts.forEach((label, c) {
      if (c > bestCount || (c == bestCount && best != null && label.length > best!.length)) {
        best = label;
        bestCount = c;
      }
    });
    final named = best != null && bestCount >= 2;
    final state = switch (e.stateAt(clock, settings)) {
      ConversationState.active => IndexEntryState.active,
      ConversationState.tentative => IndexEntryState.tentative,
      _ => IndexEntryState.dormant,
    };
    out.add(IndexEntry(
      id: e.id,
      label: named ? best! : '関連投稿 ${e.posts.length}件',
      labelSource: named ? 'event' : 'fallback',
      postKeys: [for (final p in e.posts) p.key],
      representativeKeys: [for (final p in e.anchorPosts) p.key],
      participantKeys: e.participants.keys.toSet(),
      startedAt: e.root.createdAt,
      lastActiveAt: e.lastActivityAt,
      confidence: named ? (bestCount / e.posts.length) : 0.3,
      state: state,
    ));
  }
  // 進行中 → 最近終了の順(D-036: リスト行)。
  out.sort((a, b) {
    final active = (b.state == IndexEntryState.active ? 1 : 0) - (a.state == IndexEntryState.active ? 1 : 0);
    return active != 0 ? active : b.lastActiveAt.compareTo(a.lastActiveAt);
  });
  return out;
}
