import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/media/image_scale.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';

/// [w]x[h] の PNG を作る(中身は問わない。見るのは画素数だけ)。
Future<Uint8List> makePng(int w, int h) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = const Color(0xFF3366CC))
    ..drawRect(Rect.fromLTWH(0, 0, w / 2, h / 2), Paint()..color = const Color(0xFFCC3366));
  final image = await recorder.endRecording().toImage(w, h);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _headerTests();
  _realJpegTest();

  test('上限以下ならそのまま返す(再エンコードしない)', () async {
    final src = await makePng(640, 480);
    final fitted = await fitWithin(src, 2048, mimeType: 'image/jpeg');
    expect(fitted.scaled, isFalse);
    expect(identical(fitted.bytes, src), isTrue, reason: '入力をそのまま返すこと');
    expect(fitted.mimeType, 'image/jpeg', reason: '縮めていないなら形式も変えない');
    expect((fitted.width, fitted.height), (640, 480));
  });

  test('横長が上限を超えたら長辺を上限に合わせ、縦横比を保つ', () async {
    final src = await makePng(3000, 1000);
    final fitted = await fitWithin(src, 2048, mimeType: 'image/png');
    expect(fitted.scaled, isTrue);
    expect(fitted.width, 2048);
    // 3000:1000 → 2048:683(丸めの 1px は許容)。
    expect((fitted.height - 683).abs(), lessThanOrEqualTo(1));
    expect(fitted.mimeType, 'image/png');
  });

  test('縦長は高さを上限に合わせる', () async {
    final src = await makePng(1000, 3000);
    final fitted = await fitWithin(src, 2048, mimeType: 'image/png');
    expect(fitted.scaled, isTrue);
    expect(fitted.height, 2048);
    expect((fitted.width - 683).abs(), lessThanOrEqualTo(1));
  });

  test('縮めた結果は実際に復号できる PNG になっている', () async {
    final src = await makePng(2600, 2600);
    final fitted = await fitWithin(src, 2048, mimeType: 'image/png');
    final codec = await ui.instantiateImageCodec(fitted.bytes);
    final image = (await codec.getNextFrame()).image;
    addTearDown(image.dispose);
    expect((image.width, image.height), (2048, 2048));
  });

  test('上限は fuel 予算の実測から決めている', () async {
    // 2048 は実測で 21.5 億 fuel(予算 60 億)。12MP は 84.6 億で E02。
    // ここを上げるならランタイム側の予算と一緒に見直すこと。
    expect(SlotPluginsNotifier.mediaEditMaxSide, 2048);
    final src = await makePng(4032, 3024); // 12MP 相当
    final fitted = await fitWithin(src, SlotPluginsNotifier.mediaEditMaxSide, mimeType: 'image/png');
    expect(fitted.scaled, isTrue);
    expect(fitted.width, lessThanOrEqualTo(2048));
    expect(fitted.height, lessThanOrEqualTo(2048));
  });
}

void _headerTests() {
  group('ヘッダーから画素数を読む(復号しない)', () {
    test('PNG の寸法を読む', () async {
      final png = await makePng(1234, 567);
      expect(imageSizeFromHeader(png), (1234, 567));
    });

    test('12MP の PNG も復号せず読める', () async {
      final png = await makePng(4032, 3024);
      expect(imageSizeFromHeader(png), (4032, 3024));
    });

    test('JPEG の SOF から読む', () {
      // SOI + APP0(長さ付き)+ SOF0(高さ 0x0300=768、幅 0x0400=1024)。
      final jpeg = Uint8List.fromList([
        0xFF, 0xD8,
        0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00,
        0xFF, 0xC0, 0x00, 0x11, 0x08, 0x03, 0x00, 0x04, 0x00, 0x03, 0x01, 0x22, 0x00,
      ]);
      expect(imageSizeFromHeader(jpeg), (1024, 768));
    });

    test('読めないものは null(素通しさせる)', () {
      expect(imageSizeFromHeader(Uint8List.fromList([1, 2, 3])), isNull);
      expect(imageSizeFromHeader(Uint8List.fromList(List.filled(64, 0))), isNull);
      // テストが media.edit に渡すようなダミーもここに来る。
      expect(imageSizeFromHeader(Uint8List.fromList('not an image'.codeUnits)), isNull);
    });

    test('壊れた JPEG で無限ループしない', () {
      // 長さ 0 のセグメント(不正)。抜けて null になること。
      final broken = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x00, 0, 0, 0, 0, 0, 0]);
      expect(imageSizeFromHeader(broken), isNull);
    });
  });
}

void _realJpegTest() {
  // 実物の JPEG(412x412)の先頭 761 バイト = Exif + ICC + SOF0 まで。
  // 手で組んだバイト列だと自分の思い違いをそのまま検証してしまうので、
  // 実ファイルから切り出したものを置く。寸法は Pillow と一致を確認済み。
  const realJpegHead =
      '/9j/4QB2RXhpZgAATU0AKgAAAAgABAEAAAMAAAABBdwAAAEBAAMAAAABBGUAAIdpAAQAAAABAAAAPgESAAQAAAABAAAAAAAAAAAAAZIIAAMAAAABAAAAAAAAAAAAAgEAAAMAAAABBdwAAAEBAAMAAAABBGUAAAAAAAD/4AAQSkZJRgABAQAAAQABAAD/4gHYSUNDX1BST0ZJTEUAAQEAAAHIAAAAAAQwAABtbnRyUkdCIFhZWiAH4AABAAEAAAAAAABhY3NwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAA9tYAAQAAAADTLQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAlkZXNjAAAA8AAAACRyWFlaAAABFAAAABRnWFlaAAABKAAAABRiWFlaAAABPAAAABR3dHB0AAABUAAAABRyVFJDAAABZAAAAChnVFJDAAABZAAAAChiVFJDAAABZAAAAChjcHJ0AAABjAAAADxtbHVjAAAAAAAAAAEAAAAMZW5VUwAAAAgAAAAcAHMAUgBHAEJYWVogAAAAAAAAb6IAADj1AAADkFhZWiAAAAAAAABimQAAt4UAABjaWFlaIAAAAAAAACSgAAAPhAAAts9YWVogAAAAAAAA9tYAAQAAAADTLXBhcmEAAAAAAAQAAAACZmYAAPKnAAANWQAAE9AAAApbAAAAAAAAAABtbHVjAAAAAAAAAAEAAAAMZW5VUwAAACAAAAAcAEcAbwBvAGcAbABlACAASQBuAGMALgAgADIAMAAxADb/2wBDAAIBAQEBAQIBAQECAgICAgQDAgICAgUEBAMEBgUGBgYFBgYGBwkIBgcJBwYGCAsICQoKCgoKBggLDAsKDAkKCgr/2wBDAQICAgICAgUDAwUKBwYHCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgr/wAARCAGcAZw=';

  test('実物の JPEG ヘッダーから寸法を読む', () {
    final bytes = base64Decode(realJpegHead);
    expect(imageSizeFromHeader(bytes), (412, 412));
  });

  test('Exif / ICC の長いセグメントを読み飛ばして SOF に着く', () {
    // 上のヘッダーは SOF まで 752 バイトある。素朴に先頭だけ見る実装なら通らない。
    expect(base64Decode(realJpegHead).length, greaterThan(700));
  });
}
