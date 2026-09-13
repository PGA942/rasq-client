import 'dart:convert';

import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// paraphrase-multilingual-MiniLM-L12-v2 のトークナイザー (D-193): XLM-R の SentencePiece **Unigram**。
/// 語彙(id 順の `piece \t score`、250002 行)をアセットから読む。flutter 非依存。
///
/// 手順(HF の PreTrainedTokenizerFast と同じ結果になることを test/fixtures/minilm_reference.json で照合):
/// 1. 正規化: NFKC(`？`→`?`、`ＡＢＣ`→`ABC`、`㍿`→`株式会社`)。小文字化はしない
/// 2. 空白で分割し、各語の先頭に `▁`(Metaspace, add_prefix_space)
/// 3. 語ごとに Unigram の Viterbi(スコアの和が最大の分割)。語彙に無い文字は `<unk>`(3)
/// 4. `<s>`(0) + … + `</s>`(2)、pad は `<pad>`(1)
class UnigramTokenizer {
  UnigramTokenizer._(this._ids, this._scores, this._maxPieceLen, this._minScore);
  final Map<String, int> _ids;
  final List<double> _scores;
  final int _maxPieceLen;
  final double _minScore;

  static const bosId = 0;
  static const padId = 1;
  static const eosId = 2;
  static const unkId = 3;
  static const space = '▁';

  /// 未知文字のスコア(HF Unigram: min_score − 10)。
  static const unkPenalty = 10.0;

  int get vocabSize => _scores.length;
  int idOf(String piece) => _ids[piece] ?? -1;

  factory UnigramTokenizer.fromTsv(String tsv) {
    final ids = <String, int>{};
    final scores = <double>[];
    var maxLen = 1;
    var minScore = 0.0;
    for (final line in const LineSplitter().convert(tsv)) {
      if (line.isEmpty) continue;
      final tab = line.lastIndexOf('\t');
      final piece = tab < 0 ? line : line.substring(0, tab);
      final score = tab < 0 ? 0.0 : (double.tryParse(line.substring(tab + 1)) ?? 0.0);
      ids[piece] = scores.length;
      scores.add(score);
      if (piece.length > maxLen) maxLen = piece.length;
      if (score < minScore) minScore = score;
    }
    if (scores.isEmpty) throw const FormatException('unigram vocab: empty');
    return UnigramTokenizer._(ids, scores, maxLen, minScore);
  }

  /// 文 → piece 列(特殊トークン無し)。
  List<String> tokenize(String text) {
    final norm = unorm.nfkc(text);
    final out = <String>[];
    for (final word in norm.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      out.addAll(_viterbi('$space$word'));
    }
    return out;
  }

  /// Unigram の Viterbi: 各位置までの最良スコアと、そこへ来る piece の長さ。
  List<String> _viterbi(String w) {
    final chars = w.runes.map(String.fromCharCode).toList();
    final n = chars.length;
    // 文字境界のオフセット(サロゲートペアを piece 長で扱えるよう、文字単位で連結する)。
    final best = List<double>.filled(n + 1, double.negativeInfinity);
    final back = List<int>.filled(n + 1, 0); // その位置へ来る piece の文字数(0 = unk 1 文字)
    best[0] = 0;
    final unkScore = _minScore - unkPenalty;
    for (var i = 0; i < n; i++) {
      if (best[i] == double.negativeInfinity) continue;
      var matched = false;
      final sb = StringBuffer();
      for (var len = 1; len <= n - i; len++) {
        sb.write(chars[i + len - 1]);
        final piece = sb.toString();
        if (piece.length > _maxPieceLen) break;
        final id = _ids[piece];
        if (id == null) continue;
        matched = true;
        final sc = best[i] + _scores[id];
        if (sc > best[i + len]) {
          best[i + len] = sc;
          back[i + len] = len;
        }
      }
      if (!matched || best[i + 1] < best[i] + unkScore) {
        // 1 文字を unk として進む(語彙にあっても unk の方が良いことは無いが、無い文字は必ずこれで進む)。
        final sc = best[i] + unkScore;
        if (sc > best[i + 1]) {
          best[i + 1] = sc;
          back[i + 1] = 0;
        }
      }
    }
    // 復元(unk は連続をまとめる = fuse_unk)。
    final pieces = <String>[];
    var pos = n;
    while (pos > 0) {
      final len = back[pos];
      if (len == 0) {
        pieces.add('<unk>');
        pos -= 1;
      } else {
        pieces.add(chars.sublist(pos - len, pos).join());
        pos -= len;
      }
    }
    final rev = pieces.reversed.toList();
    final fused = <String>[];
    for (final p in rev) {
      if (p == '<unk>' && fused.isNotEmpty && fused.last == '<unk>') continue;
      fused.add(p);
    }
    return fused;
  }

  /// 文 → id 列(`<s>` … `</s>`、[maxLen] を超えれば `</s>` を残して切り詰め)。pad は呼び出し側で。
  List<int> encode(String text, {int maxLen = 128}) {
    final ids = <int>[bosId, for (final p in tokenize(text)) _ids[p] ?? unkId];
    if (ids.length > maxLen - 1) ids.length = maxLen - 1;
    ids.add(eosId);
    return ids;
  }
}
