import 'dart:math' as math;
import 'dart:typed_data';

/// フォロイー毎の SigLIP 特徴量の**指数移動平均**(D-024)。
///
/// 投稿ごとに全ペア類似度を取ると O(投稿²) になるため、著者単位に埋め込みを
/// EMA で畳み込み(`ema = α·new + (1-α)·ema` → L2 正規化)、著者間の類似
/// グラフを作って Louvain でコミュニティ分割する。クラスタリングの類似判定は
/// 同一コミュニティ内に限定され、計算量が「コミュニティ内の投稿²」に落ちる。
class FolloweeEmbeddingStore {
  FolloweeEmbeddingStore({this.alpha = 0.3});

  /// 新しい投稿の寄与率(0..1)。大きいほど直近の話題に追従する。
  final double alpha;

  final Map<String, Float32List> _ema = {};

  Iterable<String> get authorKeys => _ema.keys;

  Float32List? emaOf(String authorKey) => _ema[authorKey];

  /// 著者の新しい投稿埋め込みを畳み込む。
  void update(String authorKey, List<double> embedding) {
    final incoming = _normalized(embedding);
    final current = _ema[authorKey];
    if (current == null) {
      _ema[authorKey] = incoming;
      return;
    }
    final mixed = List<double>.generate(current.length, (i) => alpha * incoming[i] + (1 - alpha) * current[i]);
    _ema[authorKey] = _normalized(mixed);
  }

  /// 2 著者の EMA cos 類似度(0..1 に写像済み: `(cos+1)/2`)。未知は 0.5。
  double similarity(String a, String b) {
    final ea = _ema[a];
    final eb = _ema[b];
    if (ea == null || eb == null || ea.length != eb.length) return 0.5;
    var dot = 0.0;
    for (var i = 0; i < ea.length; i++) {
      dot += ea[i] * eb[i];
    }
    return (dot.clamp(-1.0, 1.0) + 1) / 2;
  }

  /// 著者間の重み付き類似グラフ([minSimilarity] 未満の辺は落とす)。
  /// Louvain の入力(隣接マップ)になる。
  Map<String, Map<String, double>> graph({double minSimilarity = 0.6}) {
    final keys = _ema.keys.toList();
    final out = <String, Map<String, double>>{for (final k in keys) k: {}};
    for (var i = 0; i < keys.length; i++) {
      for (var j = i + 1; j < keys.length; j++) {
        final s = similarity(keys[i], keys[j]);
        if (s >= minSimilarity) {
          out[keys[i]]![keys[j]] = s;
          out[keys[j]]![keys[i]] = s;
        }
      }
    }
    return out;
  }

  static Float32List _normalized(List<double> v) {
    var norm = 0.0;
    for (final x in v) {
      norm += x * x;
    }
    final n = norm == 0 ? 1.0 : math.sqrt(norm);
    return Float32List.fromList([for (final x in v) x / n]);
  }
}
