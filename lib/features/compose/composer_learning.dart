import 'dart:math' as math;

import '../relational/relational_engine.dart' show charNgramProfile, extractFeaturesText;

/// 運用時の学習ループ (D-132, 原典: 投稿コンポーザーの話.md 後半)。
///
/// - **確定ラベル**: 実際に投稿したアカウントを確定として、そのアカウントの
///   プロファイル(storage.safe スロット `learn:<アカウント>`)へ EMA 追加。
/// - **訂正は強く学習**: サジェストから手動で切り替えて投稿した場合は
///   重み 3 倍で選んだアカウントに学習する。
/// - **半減期**: 古い寄与は半減期 90 日で時間減衰(更新時にまとめて減衰)。
/// - **代表投稿は固定保存**: 最初の 5 件は減衰させず保持し、最近の一時的な
///   話題でアカウント像が崩れないようにする。
/// - **学習データの分離**: 連動(A→B)の正例/負例は主投稿先の学習とは
///   別に記録する(`composer.learn` 領域の `relations`)。
///
/// スロットの形は storage.safe の読み出しノード (D-104) 互換 —
/// `texts`(代表投稿 + 頻出特徴語 = ml.keyword の基準リスト)と
/// `vector`(n-gram プロファイル = ml.similar の基準ベクトル)。
const composerLearnHalfLifeDays = 90.0;
const composerLearnRepCount = 5;

/// 確定投稿 1 件をアカウントのプロファイルへ EMA 追加する。
/// [weight] は訂正の強い学習(手動切替 = 3.0)。
Map<String, Object?> composerLearnUpdate(Map<String, Object?>? existing, String text, {double weight = 1.0, DateTime? now}) {
  now ??= DateTime.now();
  final prevAt = DateTime.tryParse(existing?['updatedAt'] as String? ?? '');
  // 半減期 90 日の時間減衰(前回更新からの経過ぶんをまとめて掛ける)。
  final dtDays = prevAt == null ? 0.0 : now.difference(prevAt).inMinutes / (60.0 * 24.0);
  final decay = prevAt == null ? 1.0 : math.pow(0.5, dtDays / composerLearnHalfLifeDays).toDouble();

  Map<String, double> decayed(Object? raw) {
    final out = <String, double>{};
    if (raw is Map) {
      raw.forEach((k, v) => out['$k'] = ((v as num?) ?? 0).toDouble() * decay);
    }
    return out;
  }

  // n-gram プロファイル(類似性の基準ベクトル)。
  final p = decayed((existing?['vector'] as Map?)?['p']);
  charNgramProfile(text).forEach((k, v) => p[k] = (p[k] ?? 0) + v * weight);
  _prune(p, 400);

  // 特徴語カウント(キーワードの基準)。
  final kw = decayed(existing?['kw']);
  for (final f in extractFeaturesText(text)) {
    kw[f] = (kw[f] ?? 0) + weight;
  }
  _prune(kw, 120);

  // 代表投稿 (固定): 最初の N 件は入れ替えない。
  final reps = ((existing?['reps'] as List?)?.cast<String>() ?? const <String>[]);
  final nextReps = reps.length >= composerLearnRepCount ? reps : [...reps, text];

  final topKw = kw.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return {
    'texts': [...nextReps, for (final e in topKw.take(12)) e.key],
    'vector': {'kind': 'ngram', 'p': p},
    'kw': kw,
    'reps': nextReps,
    'count': ((existing?['count'] as num?)?.toInt() ?? 0) + 1,
    'updatedAt': now.toIso8601String(),
  };
}

void _prune(Map<String, double> m, int max) {
  m.removeWhere((_, v) => v < 0.02);
  if (m.length <= max) return;
  final sorted = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final keep = {for (final e in sorted.take(max)) e.key};
  m.removeWhere((k, _) => !keep.contains(k));
}

/// 連動 (A→B) の正例/負例を記録する (D-132: 学習データの分離)。
/// [positive] = 連動して送った/手動で追加した。false = 確認で解除した。
Map<String, Object?> composerRelationBump(Map<String, Object?> relations, String from, String to, {required bool positive}) {
  final key = '$from→$to';
  final cur = (relations[key] as Map?)?.cast<String, Object?>() ?? const <String, Object?>{};
  final pos = ((cur['pos'] as num?)?.toInt() ?? 0) + (positive ? 1 : 0);
  final neg = ((cur['neg'] as num?)?.toInt() ?? 0) + (positive ? 0 : 1);
  return {...relations, key: {'pos': pos, 'neg': neg}};
}

/// [to] へのリレーション実績の合計 (pos, neg)。表示用。
(int, int) composerRelationStats(Map<String, Object?> relations, String to) {
  var pos = 0, neg = 0;
  relations.forEach((k, v) {
    if (!k.endsWith('→$to') || v is! Map) return;
    pos += ((v['pos'] as num?)?.toInt() ?? 0);
    neg += ((v['neg'] as num?)?.toInt() ?? 0);
  });
  return (pos, neg);
}
