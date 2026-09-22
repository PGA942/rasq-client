import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/emoji/emoji_index.dart';
import 'package:rasq_client/features/rai/rai_reference.dart';
import 'package:rasq_models/rasq_models.dart';

/// 決まった文に、決まったベクトルを返す埋め込み(何回・何を頼まれたかも覚える)。
class _FakeEmbedder implements RaiEmbedder {
  _FakeEmbedder(this.table, {this.name = 'fake-3'});
  final Map<String, List<double>> table;
  @override
  final String name;
  final asked = <String>[];
  @override
  Future<List<List<double>>> embed(List<String> texts) async {
    asked.addAll(texts);
    return [for (final t in texts) table[t] ?? const [0.0, 0.0, 1.0]];
  }
}

EmojiInfo emoji(String name, {List<String> aliases = const [], String? category}) => EmojiInfo(name: name, url: Uri.parse('https://e/$name.webp'), aliases: aliases, category: category);

/// 絵文字の意味検索の索引 (D-290)。
void main() {
  final cat = emoji('blob_cat', aliases: ['ねこ'], category: 'どうぶつ');
  final dog = emoji('doggo');
  final sad = emoji('pien');

  test('埋め込みに掛ける文: 区切りを空白に、別名(かなはローマ字も)とジャンルを添える', () {
    expect(EmojiEmbeddingIndex.textOf(cat), 'blob cat / ねこ / neko / どうぶつ');
    expect(EmojiEmbeddingIndex.textOf(dog), 'doggo');
  });

  test('索引: 近いものに高い点。保存して読み戻せる。モデルが同じなら、前のベクトルを使い回す', () async {
    final e = _FakeEmbedder({
      'blob cat / ねこ / neko / どうぶつ': [1, 0, 0],
      'doggo': [0.8, 0.6, 0],
      'pien': [0, 1, 0],
    });
    final index = (await EmojiEmbeddingIndex.build(emojis: [cat, dog, sad, cat], embedder: e))!;
    expect(index.names, ['blob_cat', 'doggo', 'pien']); // 同じ名前は 1 回
    final s = index.scores(const [1, 0, 0]);
    expect(s['blob_cat'], closeTo(1, 1e-6));
    expect(s['doggo'], closeTo(0.8, 1e-6));
    expect(index.scores(const [1, 0, 0], threshold: 0.5).keys, ['blob_cat', 'doggo']);
    expect(index.scores(const [1, 0]), isEmpty, reason: '次元が違う問い合わせ');

    final back = EmojiEmbeddingIndex.fromBytes(index.toBytes())!;
    expect((back.model, back.dims), ('fake-3', 3));
    expect(back.names, ['blob_cat', 'doggo', 'pien']);
    expect(back.scores(const [0, 1, 0])['pien'], closeTo(1, 1e-6));
    expect(EmojiEmbeddingIndex.fromBytes(Uint8List.fromList([1, 2, 3])), isNull);

    // 絵文字が 1 つ増えただけなら、増えたぶんだけ計算する。
    e.asked.clear();
    final grown = (await EmojiEmbeddingIndex.build(emojis: [cat, dog, sad, emoji('new_one')], embedder: e, reuse: back))!;
    expect(e.asked, ['new one']);
    expect(grown.length, 4);
    // モデルが変わったら、使い回さない。
    final other = _FakeEmbedder(const {}, name: 'other-3');
    await EmojiEmbeddingIndex.build(emojis: [cat, dog], embedder: other, reuse: back);
    expect(other.asked.length, 2);
  });

  test('途中でやめられる / Central が配るベクトルからも作れる', () async {
    final e = _FakeEmbedder(const {});
    expect(await EmojiEmbeddingIndex.build(emojis: [cat, dog, sad], embedder: e, chunk: 1, shouldStop: () => e.asked.isNotEmpty), isNull);
    final given = EmojiEmbeddingIndex.fromVectors(model: 'central-siglip', dims: 2, vectors: const {'a': [1, 0], 'b': [0, 1], 'bad': [1, 2, 3]});
    expect(given.names, ['a', 'b']);
  });

  test('並び: 部分一致は必ず先頭に残り、意味の近いものを点数順に後ろへ足す', () {
    final list = [cat, dog, sad];
    // 意味検索なし = これまでどおり。
    expect([for (final e in filterAndRankEmojis(list, 'dog', null)) e.name], ['doggo']);
    // かなで打っても、ローマ字の名前に当たる。別名にも当たる。
    expect([for (final e in filterAndRankEmojis([emoji('neko_punch'), dog], 'ねこ', null)) e.name], ['neko_punch']);
    expect([for (final e in filterAndRankEmojis(list, 'ねこ', null)) e.name], ['blob_cat']);
    // 意味検索あり: 「かなしい」は名前に無いが、点数の高い pien が出る。低いものは出ない。
    final ranked = filterAndRankEmojis(list, 'かなしい', const {'pien': 0.61, 'doggo': 0.30, 'blob_cat': 0.05});
    expect([for (final e in ranked) e.name], ['pien', 'doggo']);
    // 部分一致と意味の両方に掛かっても、1 回だけ(部分一致の位置で)。
    expect([for (final e in filterAndRankEmojis(list, 'dog', const {'doggo': 0.9, 'blob_cat': 0.5})) e.name], ['doggo', 'blob_cat']);
    expect(filterAndRankEmojis(list, '  ', null), list);
  });
}
