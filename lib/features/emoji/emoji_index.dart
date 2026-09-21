import 'dart:convert';
import 'dart:typed_data';

import 'package:rasq_models/rasq_models.dart';

import '../compose/kana_romaji.dart';
import '../rai/rai_reference.dart' show RaiEmbedder;

/// 絵文字の意味検索の索引 (D-290)。
///
/// サーバーごとのカスタム絵文字を、**端末内の埋め込みモデル**(いまは SigLIP2 のテキスト塔。第二期に MiniLM 蒸留の
/// CNN 系へ置き換える予定)でベクトルにしておき、検索欄に打った文と近いものを引く。
///
/// ベクトルの出どころは 2 つを想定して、索引は**外から渡されたベクトル**も受ける:
/// - 端末がバックグラウンドで埋め込む([build])。
/// - Central が計算して配る(公開 API のトークンを取ったサーバー。[EmojiEmbeddingIndex.fromVectors])。
///
/// 索引は、埋め込みモデルの名前と次元を持つ。モデルが変わったら(名前 / 次元が違えば)、古い索引は使わない。
class EmojiEmbeddingIndex {
  EmojiEmbeddingIndex._(this.model, this.dims, this.names, this._vectors);

  /// 埋め込みモデルの名前([RaiEmbedder.name])。
  final String model;
  final int dims;

  /// 絵文字の名前(ベクトルと同じ並び)。
  final List<String> names;
  final Float32List _vectors;

  int get length => names.length;

  /// 絵文字 1 つを、埋め込みに掛ける文に。名前の区切り(`_` `-`)は空白にして、別名とジャンルも添える。
  /// かなの別名には、ローマ字の読みも足す(逆に、ローマ字の名前に日本語で当てるのはモデルの仕事)。
  static String textOf(EmojiInfo e) {
    final parts = <String>[e.name.replaceAll(RegExp(r'[_\-]+'), ' ').trim()];
    for (final a in e.aliases) {
      if (a.trim().isEmpty) continue;
      parts.add(a.trim());
      final r = kanaToRomaji(a);
      if (r != null) parts.add(r);
    }
    if (e.category != null && e.category!.trim().isNotEmpty) parts.add(e.category!.trim());
    return parts.join(' / ');
  }

  /// 端末で埋め込む。[chunk] 件ずつ投げて、間で [onProgress] と [shouldStop] を見る(長い仕事を、途中でやめられるように)。
  /// [reuse] に同じモデルの古い索引があれば、**名前が同じ絵文字のベクトルは使い回す**(絵文字が少し増えただけなら、増えたぶんだけ計算する)。
  static Future<EmojiEmbeddingIndex?> build({
    required List<EmojiInfo> emojis,
    required RaiEmbedder embedder,
    EmojiEmbeddingIndex? reuse,
    int chunk = 32,
    void Function(int done, int total)? onProgress,
    bool Function()? shouldStop,
  }) async {
    final old = reuse != null && reuse.model == embedder.name ? {for (var i = 0; i < reuse.names.length; i++) reuse.names[i]: i} : const <String, int>{};
    final names = <String>[];
    final rows = <List<double>>[];
    var dims = reuse != null && old.isNotEmpty ? reuse.dims : 0;
    final todo = <EmojiInfo>[];
    final seen = <String>{};
    for (final e in emojis) {
      if (!seen.add(e.name)) continue;
      final hit = old[e.name];
      if (hit != null) {
        names.add(e.name);
        rows.add(reuse!._row(hit));
      } else {
        todo.add(e);
      }
    }
    var done = names.length;
    final total = done + todo.length;
    onProgress?.call(done, total);
    for (var i = 0; i < todo.length; i += chunk) {
      if (shouldStop?.call() ?? false) return null;
      final part = todo.sublist(i, (i + chunk).clamp(0, todo.length));
      final vectors = await embedder.embed([for (final e in part) textOf(e)]);
      for (var k = 0; k < part.length && k < vectors.length; k++) {
        if (dims == 0) dims = vectors[k].length;
        if (vectors[k].length != dims) continue;
        names.add(part[k].name);
        rows.add(vectors[k]);
      }
      done += part.length;
      onProgress?.call(done, total);
    }
    if (names.isEmpty || dims == 0) return EmojiEmbeddingIndex._(embedder.name, dims, const [], Float32List(0));
    final flat = Float32List(names.length * dims);
    for (var i = 0; i < rows.length; i++) {
      flat.setRange(i * dims, (i + 1) * dims, rows[i]);
    }
    return EmojiEmbeddingIndex._(embedder.name, dims, names, flat);
  }

  /// 外で計算されたベクトルから(Central が配るもの)。次元が合わない行は捨てる。
  factory EmojiEmbeddingIndex.fromVectors({required String model, required int dims, required Map<String, List<double>> vectors}) {
    final names = [for (final e in vectors.entries) if (e.value.length == dims) e.key];
    final flat = Float32List(names.length * dims);
    for (var i = 0; i < names.length; i++) {
      flat.setRange(i * dims, (i + 1) * dims, vectors[names[i]]!);
    }
    return EmojiEmbeddingIndex._(model, dims, names, flat);
  }

  List<double> _row(int i) => _vectors.sublist(i * dims, (i + 1) * dims);

  /// 文 [queryVector] に近い絵文字の点数(名前 → コサイン)。[threshold] 未満は入れない。
  Map<String, double> scores(List<double> queryVector, {double threshold = 0.0}) {
    if (queryVector.length != dims) return const {};
    final out = <String, double>{};
    for (var i = 0; i < names.length; i++) {
      var s = 0.0;
      final base = i * dims;
      for (var d = 0; d < dims; d++) {
        s += _vectors[base + d] * queryVector[d];
      }
      if (s >= threshold) out[names[i]] = s;
    }
    return out;
  }

  // ── 保存の形: 先頭 4 バイト = ヘッダー(JSON)の長さ、ヘッダー、そのあと float32 の並び ──
  static const _version = 1;

  Uint8List toBytes() {
    final header = utf8.encode(jsonEncode({'v': _version, 'model': model, 'dims': dims, 'names': names}));
    final out = BytesBuilder(copy: false)
      ..add((ByteData(4)..setUint32(0, header.length, Endian.little)).buffer.asUint8List())
      ..add(header)
      ..add(_vectors.buffer.asUint8List(_vectors.offsetInBytes, _vectors.lengthInBytes));
    return out.toBytes();
  }

  /// 壊れている / 形が古いものは null(作り直す)。
  static EmojiEmbeddingIndex? fromBytes(Uint8List bytes) {
    try {
      if (bytes.length < 4) return null;
      final n = ByteData.sublistView(bytes, 0, 4).getUint32(0, Endian.little);
      if (n <= 0 || 4 + n > bytes.length) return null;
      final h = (jsonDecode(utf8.decode(bytes.sublist(4, 4 + n))) as Map).cast<String, Object?>();
      if (h['v'] != _version) return null;
      final dims = (h['dims'] as num).toInt();
      final names = [for (final x in h['names'] as List) '$x'];
      final body = bytes.sublist(4 + n); // コピー(float32 の境界に揃える)
      if (body.length != names.length * dims * 4) return null;
      return EmojiEmbeddingIndex._('${h['model']}', dims, names, body.buffer.asFloat32List(0, names.length * dims));
    } catch (_) {
      return null;
    }
  }
}

/// 検索欄の絞り込みと並び (D-290)。
/// - **これまでの部分一致(名前 / 別名)は、必ず入る**(意味検索が無い / 準備中でも、動きは変わらない)。先頭に並ぶ。
/// - かなで打っていたら、ローマ字に読み替えた部分一致も入る(「ねこ」→ `neko`)。
/// - [semantic](名前 → 点数)があれば、部分一致に掛からなかった絵文字のうち、点数が [threshold] 以上のものを、点数の高い順に後ろへ足す。
List<EmojiInfo> filterAndRankEmojis(List<EmojiInfo> list, String query, Map<String, double>? semantic, {double threshold = 0.28, int maxSemantic = 60}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return list;
  final romaji = kanaToRomaji(q);
  bool lexical(EmojiInfo e) {
    final name = e.name.toLowerCase();
    if (name.contains(q) || (romaji != null && romaji.length >= 2 && name.contains(romaji))) return true;
    return e.aliases.any((a) => a.toLowerCase().contains(q));
  }

  final hits = [for (final e in list) if (lexical(e)) e];
  if (semantic == null || semantic.isEmpty) return hits;
  final taken = {for (final e in hits) e.name};
  final extra = [for (final e in list) if (!taken.contains(e.name) && (semantic[e.name] ?? -1) >= threshold) e]
    ..sort((a, b) => semantic[b.name]!.compareTo(semantic[a.name]!));
  return [...hits, ...extra.take(maxSemantic)];
}

/// 1 行の点数(索引が無い / 次元が違えば空)。
Map<String, double> emojiScoresOf(EmojiEmbeddingIndex? index, List<double>? queryVector) => index == null || queryVector == null ? const {} : index.scores(queryVector);

