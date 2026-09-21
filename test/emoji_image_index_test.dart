import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/emoji/emoji_image_preprocess.dart';
import 'package:rasq_client/features/emoji/emoji_index.dart';
import 'package:rasq_models/rasq_models.dart';

EmojiInfo emoji(String name) => EmojiInfo(name: name, url: Uri.parse('https://e/$name.webp'));

/// 絵文字の画像検索 (D-293)。
void main() {
  test('前処理: 透明は白に重ね、(x/127.5 - 1) で CHW に並べる', () {
    // 2×2: 赤(不透明)/ 完全に透明 / 半透明の黒 / 白
    final rgba = Uint8List.fromList([255, 0, 0, 255, 9, 9, 9, 0, 0, 0, 0, 128, 255, 255, 255, 255]);
    final v = emojiPixelValues(rgba, size: 2);
    expect(v.length, 12);
    // R チャンネル: 赤 = 1、透明 = 白 = 1、半透明の黒 ≒ 0(白と半々)、白 = 1
    expect(v[0], closeTo(1, 1e-6));
    expect(v[1], closeTo(1, 1e-6));
    expect(v[2], closeTo(0, 0.01));
    expect(v[3], closeTo(1, 1e-6));
    // G チャンネル: 赤 = -1、透明 = 白 = 1
    expect(v[4], closeTo(-1, 1e-6));
    expect(v[5], closeTo(1, 1e-6));
    expect(() => emojiPixelValues(Uint8List(3), size: 2), throwsArgumentError);
  });

  test('絵から索引を作る: 取れない / 読めない絵は入らない。同じモデルなら使い回し、絵を取り直さない', () async {
    final fetched = <String>[];
    Future<Uint8List?> fetch(EmojiInfo e) async {
      fetched.add(e.name);
      return e.name == 'gone' ? null : Uint8List.fromList(e.name.codeUnits);
    }

    // 絵の「中身」= 名前の先頭の文字で、決まったベクトルを返す偽物。'x…' は読めない絵。
    Future<List<List<double>?>> embed(List<Uint8List> images) async => [
          for (final i in images)
            switch (String.fromCharCodes(i)[0]) { 'c' => [1.0, 0.0], 'd' => [0.0, 1.0], _ => null },
        ];

    final index = (await EmojiEmbeddingIndex.buildFromImages(emojis: [emoji('cat1'), emoji('dog1'), emoji('gone'), emoji('xbroken')], model: 'vision-2', fetch: fetch, embed: embed))!;
    expect(index.names, ['cat1', 'dog1']);
    expect(index.scores(const [1, 0])['cat1'], closeTo(1, 1e-6));

    fetched.clear();
    final grown = (await EmojiEmbeddingIndex.buildFromImages(emojis: [emoji('cat1'), emoji('dog1'), emoji('cat2')], model: 'vision-2', fetch: fetch, embed: embed, reuse: index))!;
    expect(fetched, ['cat2']);
    expect(grown.names.toSet(), {'cat1', 'dog1', 'cat2'});
    // 途中でやめられる。
    expect(await EmojiEmbeddingIndex.buildFromImages(emojis: [emoji('cat9')], model: 'vision-2', fetch: fetch, embed: embed, shouldStop: () => true), isNull);
  });

  test('文と絵のコサインは小さいので、その検索の中での上位だけを、並びを保って足せる点数へ写す', () {
    final s = rescaleImageScores(const {'a': 0.12, 'b': 0.10, 'c': 0.06, 'd': 0.01});
    expect(s.keys, ['a', 'b']); // c は、いちばん上との差が開きすぎ / d は低すぎ
    expect(s['a']! > s['b']! && s['b']! >= imageScoreFloor, isTrue);
    expect(rescaleImageScores(const {'a': 0.02}), isEmpty, reason: 'どれも合っていない');
    // 文の点数と合わせる: 同じ絵文字は高いほう。
    expect(mergeEmojiScores(const {'a': 0.5, 'x': 0.3}, const {'a': 0.31, 'b': 0.29}), {'a': 0.5, 'x': 0.3, 'b': 0.29});
    // 合わせた点数で、部分一致のうしろに並ぶ。
    final ranked = filterAndRankEmojis([emoji('blob123'), emoji('zzz')], 'ねこ', s.map((k, v) => MapEntry(k == 'a' ? 'blob123' : k, v)));
    expect([for (final e in ranked) e.name], ['blob123']);
  });
}
