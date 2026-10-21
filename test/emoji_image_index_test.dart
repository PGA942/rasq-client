import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/features/emoji/emoji_image_preprocess.dart';
import 'package:rasq_client/features/emoji/emoji_index.dart';
import 'package:rasq_client/features/emoji/emoji_index_providers.dart';
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

  // セキュリティ確認 2026-10-21 の #22 (D-546): 絵は上限までしか読まず、読み途中の合計にも上限がある。
  group('絵の取得', () {
    const chunk = 64 * 1024;

    test('Content-Length の無い / 嘘の巨大な応答は、512 KiB を超えたところで読むのをやめて null', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final fetch = c.read(emojiImageFetcherProvider);
      for (final length in [null, 100]) {
        var sent = 0;
        var cancelled = false;
        Stream<List<int>> body() async* {
          try {
            while (true) {
              sent++;
              yield Uint8List(chunk);
              await Future<void>.delayed(Duration.zero);
            }
          } finally {
            cancelled = true;
          }
        }

        final client = MockClient.streaming((req, _) async => http.StreamedResponse(body(), 200, contentLength: length));
        final got = await http.runWithClient(() => fetch(emoji('big')), () => client);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(got, isNull);
        expect(cancelled, isTrue);
        expect(sent * chunk, lessThanOrEqualTo(emojiImageMaxBytes + 2 * chunk), reason: '上限の先は受け取らない(全部貯めてから大きさを見ない)');
        expect(c.read(emojiImageFetchBudgetProvider).inFlight, 0);
      }
    });

    test('ふつうの絵は届く。200 以外・空は null', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final fetch = c.read(emojiImageFetcherProvider);
      final client = MockClient((req) async => switch (req.url.path) {
            '/ok.webp' => http.Response.bytes(Uint8List(1000), 200),
            '/max.webp' => http.Response.bytes(Uint8List(emojiImageMaxBytes), 200),
            '/empty.webp' => http.Response.bytes(Uint8List(0), 200),
            _ => http.Response('', 404),
          });
      Future<Uint8List?> get(String name) => http.runWithClient(() => fetch(emoji(name)), () => client);
      expect((await get('ok'))?.length, 1000);
      expect((await get('max'))?.length, emojiImageMaxBytes);
      expect(await get('empty'), isNull);
      expect(await get('gone'), isNull);
    });

    test('読み途中は(アカウントをまたいでも)合わせて 8 枚 = 4 MiB まで。終わった順に次へ進み、全部届く', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final fetch = c.read(emojiImageFetcherProvider);
      final budget = c.read(emojiImageFetchBudgetProvider);
      final gate = Completer<void>();
      var open = 0, peak = 0;
      final client = MockClient.streaming((req, _) async {
        open++;
        peak = open > peak ? open : peak;
        Stream<List<int>> body() async* {
          await gate.future;
          yield Uint8List(chunk);
          open--;
        }

        return http.StreamedResponse(body(), 200);
      });
      // 2 つのアカウントの索引づくりが 8 枚ずつ同時に取りに行く。
      final all = http.runWithClient(() => Future.wait([for (var i = 0; i < 16; i++) fetch(emoji('e$i'))]), () => client);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(open, 8);
      expect(budget.inFlight, emojiImageInFlightBytes);
      gate.complete();
      final got = await all;
      expect(got.every((b) => b?.length == chunk), isTrue);
      expect(peak, 8);
      expect(budget.inFlight, 0);
    });
  });
}
