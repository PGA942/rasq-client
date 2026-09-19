import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/compose/post_video.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

/// 投稿タイルの動画化 (D-260): どの投稿をどう動画にするかの判定と、寸法 / メディアの枠の計算(端末ネイティブの書き出しは実機)。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  const author = UserSummary(id: 'u1', account: acc, displayName: 'テスター');
  MediaItem media(String name, MediaType type) => MediaItem(id: name, type: type, url: Uri.parse('https://files.example.test/$name'), fileName: name);
  Post post(String body, [List<MediaItem> m = const []]) => Post(id: 'p', account: acc, author: author, createdAt: DateTime(2026, 9, 19), body: body, media: m);

  test('判定: 動画 1 本 = 重ねる、音声ファイル = 音を重ねる、GIF / 動く MFM = コマ撮り、それ以外は静止画', () {
    expect(postMotionOf(post('ふつうの投稿')), PostMotion.none);
    expect(postMotionOf(post('写真', [media('a.png', MediaType.image)])), PostMotion.none);
    expect(postMotionOf(post('動画', [media('v.mp4', MediaType.video)])), PostMotion.video);
    // 動画 + ほかのメディア: 枠の位置が分からないので重ねない(GIF があればコマ撮り、無ければ静止画)。
    expect(postMotionOf(post('動画と写真', [media('v.mp4', MediaType.video), media('a.png', MediaType.image)])), PostMotion.none);
    expect(postMotionOf(post('音声', [media('voice.m4a', MediaType.file)])), PostMotion.audio);
    expect(postMotionOf(post('書類', [media('doc.pdf', MediaType.file)])), PostMotion.none);
    expect(postMotionOf(post('GIF', [media('a.gif', MediaType.gif)])), PostMotion.animated);
    expect(postMotionOf(post(r'$[spin 🌀] まわる')), PostMotion.animated);
    expect(postMotionOf(post(r'$[x2 大きいだけ] $[fg.color=f00 色だけ]')), PostMotion.none);
    expect(hasAnimatedMfm(r'$[rainbow にじ]'), isTrue);
    for (final m in [PostMotion.video, PostMotion.audio, PostMotion.animated]) {
      expect(postMotionLabel(m), startsWith('動画にする'));
    }
  });

  test('寸法: 偶数の画素に丸める', () {
    expect(evenPixelSize(const ui.Size(360.4, 201.3), 2), const ui.Size(720, 402));
    expect(evenPixelSize(const ui.Size(100.75, 50.25), 1), const ui.Size(100, 50));
    expect(evenPixelSize(const ui.Size(0.2, 0.2), 1), const ui.Size(2, 2));
  });

  testWidgets('メディアの枠: タイルの中の RasqMediaGrid の位置(タイルの左上が原点、画素)', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(30), // タイルの外の余白は枠の座標に入らない
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 300,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 40, child: Text('本文')),
                Padding(padding: const EdgeInsets.only(left: 20), child: SizedBox(width: 200, child: RasqMediaGrid(items: [media('v.mp4', MediaType.video)]))),
              ]),
            ),
          ),
        ),
      ),
    ));
    final rect = mediaRectInTile(key, 2)!;
    expect((rect.left, rect.top, rect.width), (40.0, 80.0, 400.0));
    expect(rect.height, closeTo(400 / (16 / 9), 1)); // 1 枚のときは 16:9
    expect(mediaRectInTile(GlobalKey(), 2), isNull);
  });
}
