import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../app/providers.dart';
import '../nodeprog/node_tabs.dart';
import '../relational/relational_engine.dart';
import '../settings/settings_dsl.dart';
import 'example_match.dart';

/// トレンドの指向性 / 刺激性のプロファイル (D-153、ワイヤーフレーム p.2)。
///
/// - **指向性**: 好きなジャンル/方向性への近さのしきい値(狭い ⇄ 広い)。
///   ワイヤーの言う Sentence-FastText のしきい値設定。端末側の実働は
///   文字 n-gram + 特徴語一致(SFT は `embedTexts`(ml.infer)配線後に上書き)。
/// - **刺激性**: 8 感情(joy / trust / fear / surprise / sadness / disgust / anger /
///   anticipation = emotion8 と同じ軸)ごとの上限。レーダーで触って決める。
///   端末側の実働は語彙ルール(GRU/emotion8 は ml.infer 配線後)。
/// - **好きなジャンル/方向性**: チップ。SNS 側の設定に任せる / アクションから
///   自動抽出 / 最近のアクションから選ぶ (D-154)。
/// - **例** (D-314): 「好き」/「好きではない」にした投稿 / プラグイン / クリップ / リストの中身そのもの
///   ([ContentExamples])。語 1 つではなく、もの全体との近さで測る([exampleScoresOf])。
///
/// 保存先は storage.safe のスロット [slot](アカウント別領域、旧共有領域に
/// フォールバック) — **ノード(`ml.tendency`)と TL の既定適用が同じプロファイルを
/// 読む**ので、設定はここ 1 か所(他のノードからも使い回せる)。
@immutable
class TendencyProfile {
  const TendencyProfile({
    this.enabled = true,
    this.directionality = 0.5,
    this.stimulus = const {},
    this.genres = const [],
    this.disliked = const [],
    this.autoGenre = false,
    this.snsDefault = false,
    this.examples = ContentExamples.none,
    this.updatedAt,
  });

  static const slot = 'trend.profile';
  static const emotions = ['joy', 'trust', 'fear', 'surprise', 'sadness', 'disgust', 'anger', 'anticipation'];
  static const emotionLabels = {
    'joy': '喜び',
    'trust': '信頼',
    'fear': '恐れ',
    'surprise': '驚き',
    'sadness': '悲しみ',
    'disgust': '嫌悪',
    'anger': '怒り',
    'anticipation': '期待',
  };

  /// false なら TL に何も掛けない(ノードで明示的に使う分は効く)。
  final bool enabled;

  /// 指向性 0(狭い)〜1(広い)。好きなジャンルへの近さのしきい値になる。
  final double directionality;

  /// 刺激性: 感情 → 許容の上限 0〜1(未設定 = 1 = 制限なし)。
  final Map<String, double> stimulus;

  /// 好きなジャンル/方向性(タグやキーワード)。
  final List<String> genres;

  /// 好きではないジャンル(アクションからの選択で「好きではない」にしたもの)。
  final List<String> disliked;

  /// あなたのアクションから自動抽出(リアクション済みの投稿の特徴語)。
  final bool autoGenre;

  /// SNS 側の設定に任せる(= 端末側では掛けない)。
  final bool snsDefault;

  /// 好きな例(`allow`)/ 好きではない例(`deny`) (D-314)。
  final ContentExamples examples;
  final DateTime? updatedAt;

  static const none = TendencyProfile(enabled: false);

  double stimulusCap(String emotion) => (stimulus[emotion] ?? 1.0).clamp(0.0, 1.0);

  /// 指向性のしきい値: 狭い(0)で 0.5、広い(1)で 0(= 落とさない)。
  double get directionThreshold => (1 - directionality.clamp(0.0, 1.0)) * 0.5;

  /// 好きな方向(ジャンルか好きな例)があるか。無ければ指向性では落とさない。
  bool get hasDirection => genres.isNotEmpty || examples.allow.isNotEmpty;

  /// 何か効く設定があるか(TL に掛ける価値があるか)。
  bool get active => enabled && !snsDefault && (genres.isNotEmpty || disliked.isNotEmpty || examples.isNotEmpty || stimulus.values.any((v) => v < 1.0));

  TendencyProfile copyWith({
    bool? enabled,
    double? directionality,
    Map<String, double>? stimulus,
    List<String>? genres,
    List<String>? disliked,
    bool? autoGenre,
    bool? snsDefault,
    ContentExamples? examples,
    DateTime? updatedAt,
  }) =>
      TendencyProfile(
        enabled: enabled ?? this.enabled,
        directionality: directionality ?? this.directionality,
        stimulus: stimulus ?? this.stimulus,
        genres: genres ?? this.genres,
        disliked: disliked ?? this.disliked,
        autoGenre: autoGenre ?? this.autoGenre,
        snsDefault: snsDefault ?? this.snsDefault,
        examples: examples ?? this.examples,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'directionality': directionality,
        'stimulus': stimulus,
        'genres': genres,
        'disliked': disliked,
        'autoGenre': autoGenre,
        'snsDefault': snsDefault,
        if (examples.isNotEmpty) 'examples': examples.toJson(),
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory TendencyProfile.fromJson(Map<String, Object?> j) => TendencyProfile(
        enabled: j['enabled'] != false,
        directionality: ((j['directionality'] as num?) ?? 0.5).toDouble().clamp(0.0, 1.0),
        stimulus: {for (final e in ((j['stimulus'] as Map?) ?? const {}).entries) '${e.key}': ((e.value as num?) ?? 1).toDouble().clamp(0.0, 1.0)},
        genres: [for (final g in (j['genres'] as List? ?? const [])) if (g is String && g.trim().isNotEmpty) g.trim()],
        disliked: [for (final g in (j['disliked'] as List? ?? const [])) if (g is String && g.trim().isNotEmpty) g.trim()],
        autoGenre: j['autoGenre'] == true,
        snsDefault: j['snsDefault'] == true,
        examples: ContentExamples.fromJson(j['examples']),
        updatedAt: j['updatedAt'] is String ? DateTime.tryParse(j['updatedAt'] as String) : null,
      );

  static TendencyProfile? tryParse(Object? raw) {
    if (raw is Map) {
      try {
        return TendencyProfile.fromJson(raw.cast<String, Object?>());
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

// ── 刺激性: 語彙ルール(emotion8 と同じ 8 軸)──────────────────────

const _emotionLexicon = <String, List<String>>{
  'joy': ['嬉し', 'うれし', '楽し', 'たのし', '最高', 'やった', '幸せ', 'しあわせ', '笑', 'www', 'ｗｗ', 'happy', 'joy', 'lol', 'yay', '🎉', '😂', '😆', '🥳', '😊'],
  'trust': ['ありがと', '感謝', '安心', '信頼', '助か', 'おかげ', '頼り', 'thanks', 'thank you', 'trust', 'reliable', '🙏', '🤝'],
  'fear': ['怖', 'こわ', '不安', '恐', 'ヤバい', 'やばい', '危な', 'パニック', '震え', 'scary', 'afraid', 'fear', 'terrif', 'panic', '😱', '😨', '😰'],
  'surprise': ['驚', 'おどろ', 'びっくり', 'まさか', 'えっ', 'え？', '!?', '！？', '衝撃', 'wow', 'omg', 'surpris', 'whoa', '😮', '😲', '🤯'],
  'sadness': ['悲し', 'かなし', '辛', 'つら', '泣', '寂し', 'さみし', '残念', '落ち込', 'しんど', 'sad', 'cry', 'lonely', 'miss you', 'depress', '😢', '😭', '😞'],
  'disgust': ['気持ち悪', 'きもい', 'キモ', '嫌', 'いや', '最悪', 'うざ', 'ウザ', '不快', 'ゴミ', 'クズ', 'disgust', 'gross', 'awful', 'trash', 'garbage', '🤮', '🤢', '😒'],
  'anger': ['怒', 'むかつ', 'ムカ', '許せ', 'ふざけ', '死ね', '殺', '黙れ', 'くたばれ', 'バカ', '馬鹿', 'アホ', 'angry', 'furious', 'hate', 'shut up', 'idiot', 'stupid', 'wtf', '😡', '🤬', '💢'],
  'anticipation': ['楽しみ', 'たのしみ', 'ワクワク', 'わくわく', '待ち', '期待', '予定', '明日', '来週', '近日', 'soon', 'excited', "can't wait", 'looking forward', 'upcoming', '👀', '✨', '🔜'],
};

/// 8 感情の強さ 0〜1(語彙の当たり数で飽和)。emotion8(ml.infer)配線後は
/// [TendencyScorer.emotionOf] を差し替える。
Map<String, double> emotionLexiconOf(String text) {
  final lower = text.toLowerCase();
  final out = <String, double>{};
  for (final e in TendencyProfile.emotions) {
    var hits = 0;
    for (final w in _emotionLexicon[e]!) {
      var idx = lower.indexOf(w.toLowerCase());
      while (idx >= 0 && hits < 6) {
        hits++;
        idx = lower.indexOf(w.toLowerCase(), idx + w.length);
      }
    }
    out[e] = hits == 0 ? 0.0 : (1 - math.pow(0.5, hits)).toDouble(); // 1 回 0.5、2 回 0.75、3 回 0.875
  }
  return out;
}

/// 語彙ルールに当たった箇所(チャイルドセーフのコンポーザーの判定が、止めた範囲に印を付けるため。D-307)。
/// 位置は [text] の中の添字(小文字にしても長さが変わらない字の範囲で正しい)。先頭から順。
List<({String emotion, int start, int end})> emotionLexiconMatches(String text) {
  final lower = text.toLowerCase();
  final out = <({String emotion, int start, int end})>[];
  for (final e in TendencyProfile.emotions) {
    for (final w in _emotionLexicon[e]!) {
      final key = w.toLowerCase();
      var idx = lower.indexOf(key);
      while (idx >= 0) {
        out.add((emotion: e, start: idx, end: idx + key.length));
        idx = lower.indexOf(key, idx + key.length);
      }
    }
  }
  out.sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : b.end.compareTo(a.end));
  return out;
}

/// プロファイルへの適合度 (0〜1) と、その内訳。
@immutable
class TendencyScore {
  const TendencyScore({required this.direction, required this.stimulusPenalty, required this.disliked});
  final double direction;
  final double stimulusPenalty;
  final bool disliked;
  double get value => disliked ? 0 : (direction * (1 - stimulusPenalty)).clamp(0.0, 1.0);
}

/// 採点(純関数)。ノード(`ml.tendency`)と TL の既定適用が共用する。
class TendencyScorer {
  const TendencyScorer({this.emotionOf = emotionLexiconOf});

  /// 感情推定の差し替え口(emotion8 の ml.infer が入ったらここに刺す)。
  final Map<String, double> Function(String text) emotionOf;

  /// 指向性: 好きなジャンル / 好きな例への近さ。タグ/特徴語の一致は 1、それ以外は
  /// 文字 n-gram の cos(ジャンル語は短いので語ごとに最大値)。好きな例は、例との類似度を
  /// [exampleNearThreshold] で 1 に揃えた値(近い例があれば 1)。
  double directionOf(Post p, TendencyProfile profile) {
    if (!profile.hasDirection) return 1.0;
    final text = _textOf(p);
    final lower = text.toLowerCase();
    final features = extractFeatures(p);
    var best = 0.0;
    final bodyProfile = charNgramProfile(text);
    for (final g in profile.genres) {
      final key = g.replaceFirst(RegExp(r'^#'), '').toLowerCase();
      if (key.isEmpty) continue;
      if (features.contains(key) || lower.contains(key)) return 1.0;
      best = math.max(best, cosineOfProfiles(charNgramProfile(key), bodyProfile));
    }
    if (profile.examples.allow.isNotEmpty) {
      final s = exampleScoresOf([text], ContentExamples(allow: profile.examples.allow)).allow;
      best = math.max(best, math.min(1.0, s / exampleNearThreshold));
    }
    return best;
  }

  /// 好きではない: 嫌いなジャンルの語(特徴語か本文に含まれる)、または好きではない例に近く、好きな例よりもそちらに近い。
  bool isDisliked(Post p, TendencyProfile profile) {
    if (profile.disliked.isEmpty && profile.examples.deny.isEmpty) return false;
    final lower = _textOf(p).toLowerCase();
    final features = extractFeatures(p);
    for (final g in profile.disliked) {
      final key = g.replaceFirst(RegExp(r'^#'), '').toLowerCase();
      if (key.isNotEmpty && (features.contains(key) || lower.contains(key))) return true;
    }
    return profile.examples.deny.isNotEmpty && exampleScoresOf([_textOf(p)], profile.examples).leansDeny;
  }

  static String _textOf(Post p) => '${p.body} ${p.quote?.body ?? ''}';

  /// 刺激性の超過: 各感情の(推定 − 上限)の正の部分の合計(最大 1)。
  double stimulusPenaltyOf(Post p, TendencyProfile profile) {
    if (profile.stimulus.isEmpty) return 0;
    final emo = emotionOf('${p.body} ${p.quote?.body ?? ''}');
    var penalty = 0.0;
    for (final e in TendencyProfile.emotions) {
      penalty += math.max(0.0, (emo[e] ?? 0) - profile.stimulusCap(e));
    }
    return penalty.clamp(0.0, 1.0);
  }

  TendencyScore score(Post p, TendencyProfile profile) =>
      TendencyScore(direction: directionOf(p, profile), stimulusPenalty: stimulusPenaltyOf(p, profile), disliked: isDisliked(p, profile));

  /// TL への適用: 指向性のしきい値未満 / 嫌いなジャンル / 刺激性の超過が
  /// 大きい(≥ 0.75)ものを落とし、残りを適合度の降順(安定)に。
  List<Post> apply(List<Post> posts, TendencyProfile profile) {
    if (!profile.active) return posts;
    final scored = <(Post, double)>[];
    for (final p in posts) {
      final s = score(p, profile);
      if (s.disliked) continue;
      if (profile.hasDirection && s.direction < profile.directionThreshold) continue;
      if (s.stimulusPenalty >= 0.75) continue;
      scored.add((p, s.value));
    }
    final indexed = scored.indexed.toList()..sort((a, b) => b.$2.$2.compareTo(a.$2.$2) != 0 ? b.$2.$2.compareTo(a.$2.$2) : a.$1.compareTo(b.$1));
    return [for (final e in indexed) e.$2.$1];
  }
}

const tendencyScorer = TendencyScorer();

// ── 保存(storage.safe のスロット)────────────────────────────────

/// 現在のアカウントのプロファイル(アカウント別領域 → 旧共有領域の順)。
final tendencyProfileProvider = FutureProvider<TendencyProfile>((ref) async {
  final accKey = ref.watch(currentAccountProvider)?.key;
  final own = (await ref.watch(settingsAreaProvider(storageSafeAreaFor(accKey)).future))[TendencyProfile.slot];
  final raw = own ?? (await ref.watch(settingsAreaProvider('storage.safe').future))[TendencyProfile.slot];
  return TendencyProfile.tryParse(raw) ?? const TendencyProfile();
});

Future<void> saveTendencyProfile(Ref ref, TendencyProfile profile) async {
  final accKey = ref.read(currentAccountProvider)?.key;
  await ref.read(settingsAreaProvider(storageSafeAreaFor(accKey)).notifier).set(TendencyProfile.slot, profile.copyWith(updatedAt: DateTime.now()).toJson());
  ref.invalidate(tendencyProfileProvider);
}

/// WidgetRef からの保存(FOW 用)。
Future<void> saveTendencyProfileFrom(WidgetRef ref, TendencyProfile profile) async {
  final accKey = ref.read(currentAccountProvider)?.key;
  await ref.read(settingsAreaProvider(storageSafeAreaFor(accKey)).notifier).set(TendencyProfile.slot, profile.copyWith(updatedAt: DateTime.now()).toJson());
  ref.invalidate(tendencyProfileProvider);
}

/// トレンドタイル(タグの並び)への適用 (D-431): 好きではないジャンルに当たるタグを除き、残りは指向性の高い順(安定)。
/// タグは短い語なので、指向性のしきい値では落とさない(落とすと、好きなジャンルの語そのもの以外が全部消える)。
List<T> applyTendencyToTags<T>(List<T> items, String Function(T item) tagOf, TendencyProfile? profile) {
  if (profile == null || !profile.active) return items;
  const nobody = AccountId(kind: SnsKind.other, instance: '', handle: '');
  Post asPost(String tag) => Post(id: tag, account: nobody, author: const UserSummary(id: '', account: nobody, displayName: ''), createdAt: DateTime(2000), body: tag);
  final scored = <(int, T, double)>[];
  for (final (i, t) in items.indexed) {
    final p = asPost(tagOf(t));
    if (tendencyScorer.isDisliked(p, profile)) continue;
    scored.add((i, t, tendencyScorer.directionOf(p, profile)));
  }
  scored.sort((a, b) => b.$3 != a.$3 ? b.$3.compareTo(a.$3) : a.$1.compareTo(b.$1));
  return [for (final s in scored) s.$2];
}

/// TL への既定適用 (D-153): おすすめ(social)/ トレンド(tag:)/ 関連の入力に掛ける。
/// プロファイルが効かない設定なら素通し。
List<Post> applyTendencyProfile(List<Post> posts, TendencyProfile? profile) => profile == null ? posts : tendencyScorer.apply(posts, profile);
