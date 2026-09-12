import 'dart:convert';
import 'dart:typed_data';

/// SigLIP2 のテキストトークナイザー (D-190): Gemma の SentencePiece **BPE**(byte fallback)を
/// `tokenizer.model`(SentencePiece の ModelProto)から読む。HF の `tokenizer.json`(34 MB)ではなく
/// 4 MB の .model を同梱する。flutter 非依存。
///
/// 手順(HF GemmaTokenizerFast と同じ結果になることを test/fixtures/siglip2_reference.json で照合):
/// 1. 正規化: 空白 → `▁`(小文字化はしない。dummy prefix も付けない)
/// 2. 事前分割なし(空白は ▁ に置き換わっているので 1 語として扱う)
/// 3. BPE: 隣り合う 2 片を結合した piece が語彙にあるうち **スコアが最大**のものから順に結合
///    (SentencePiece BPE。tokenizer.json の merges と同じ順)
/// 4. 語彙に無い片はバイト列 `<0xNN>` に落とす(byte fallback)
/// 5. 末尾に `<eos>`(1)、`<pad>`(0)で固定長 64 に右詰め
class SentencePieceBpe {
  SentencePieceBpe._(this._ids, this._scores);

  /// piece → id
  final Map<String, int> _ids;

  /// id → score
  final List<double> _scores;

  int get vocabSize => _scores.length;
  int idOf(String piece) => _ids[piece] ?? -1;

  static const padId = 0;
  static const eosId = 1;
  static const unkId = 3;
  static const space = '▁';

  /// ModelProto(protobuf)を手で読む: field 1 = repeated SentencePiece{1: piece, 2: score(float), 3: type}。
  factory SentencePieceBpe.fromModelBytes(Uint8List bytes) {
    final ids = <String, int>{};
    final scores = <double>[];
    var i = 0;
    (int, int) varint(Uint8List b, int at) {
      var r = 0, s = 0;
      while (true) {
        final c = b[at++];
        r |= (c & 0x7f) << s;
        s += 7;
        if (c & 0x80 == 0) return (r, at);
      }
    }
    while (i < bytes.length) {
      final (tag, i1) = varint(bytes, i);
      i = i1;
      final field = tag >> 3, wire = tag & 7;
      if (wire == 2) {
        final (len, i2) = varint(bytes, i);
        i = i2;
        if (field == 1) {
          // SentencePiece
          var j = i;
          final end = i + len;
          String? piece;
          var score = 0.0;
          while (j < end) {
            final (t, j1) = varint(bytes, j);
            j = j1;
            final f = t >> 3, w = t & 7;
            if (w == 2) {
              final (l, j2) = varint(bytes, j);
              j = j2;
              if (f == 1) piece = utf8.decode(bytes.sublist(j, j + l), allowMalformed: true);
              j += l;
            } else if (w == 5) {
              if (f == 2) score = ByteData.sublistView(bytes, j, j + 4).getFloat32(0, Endian.little);
              j += 4;
            } else if (w == 0) {
              final (v, j2) = varint(bytes, j);
              j = j2;
              if (f == 3) {} // type(1 normal / 2 unk / 3 control / 4 user / 6 byte)は使わない
            } else if (w == 1) {
              j += 8;
            } else {
              throw FormatException('tokenizer.model: unknown wire type $w');
            }
          }
          final id = scores.length;
          scores.add(score);
          if (piece != null) ids[piece] = id; // type 6 = <0xNN>(byte fallback 用。piece 名でそのまま引ける)
        }
        i += len;
      } else if (wire == 0) {
        i = varint(bytes, i).$2;
      } else if (wire == 5) {
        i += 4;
      } else if (wire == 1) {
        i += 8;
      } else {
        throw FormatException('tokenizer.model: unknown wire type $wire');
      }
    }
    if (scores.isEmpty) throw const FormatException('tokenizer.model: no pieces');
    return SentencePieceBpe._(ids, scores);
  }

  /// 文 → piece 列(特殊トークン無し)。
  List<String> tokenize(String text) {
    final norm = text.replaceAll(' ', space);
    if (norm.isEmpty) return const [];
    // 文字(コードポイント)単位の片から始める。
    final symbols = <String>[for (final r in norm.runes) String.fromCharCode(r)];
    // 隣接ペアの結合を、スコア最大のものから順に(SentencePiece BPE)。
    while (symbols.length > 1) {
      var bestScore = double.negativeInfinity;
      var bestAt = -1;
      for (var k = 0; k + 1 < symbols.length; k++) {
        final id = _ids[symbols[k] + symbols[k + 1]];
        if (id == null) continue;
        final s = _scores[id];
        if (s > bestScore) {
          bestScore = s;
          bestAt = k;
        }
      }
      if (bestAt < 0) break;
      symbols[bestAt] = symbols[bestAt] + symbols[bestAt + 1];
      symbols.removeAt(bestAt + 1);
    }
    // 語彙に無い片はバイトに落とす。
    final out = <String>[];
    for (final s in symbols) {
      if (_ids.containsKey(s)) {
        out.add(s);
      } else {
        for (final b in utf8.encode(s)) {
          out.add('<0x${b.toRadixString(16).toUpperCase().padLeft(2, '0')}>');
        }
      }
    }
    return out;
  }

  /// 文 → id 列(末尾 eos、pad で [maxLen] に右詰め。長ければ eos が入るよう切り詰め)。
  List<int> encode(String text, {int maxLen = 64}) {
    final ids = <int>[for (final p in tokenize(text)) _ids[p] ?? unkId];
    if (ids.length > maxLen - 1) ids.length = maxLen - 1;
    ids.add(eosId);
    while (ids.length < maxLen) {
      ids.add(padId);
    }
    return ids;
  }
}
