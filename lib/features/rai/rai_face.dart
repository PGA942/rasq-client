import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// RAi の表情 (D-211): `assets/rai/face.png` の表情シート(1920×1080、黒い枠が 4 列 × 3 行)を切り出して
/// 頭の前面(glb の `Screen` メッシュ)に貼る。枠の位置はシートの割合で持つ(解像度が違っても同じ)。
///
/// 行 0: 目(0 = 既定, 1 = 目 2, 2 = 丸目, 3 = 細目) / 行 1: 4 = 閉じ目(まばたき), 5 = クリップ, 6 = カメラ, 7 = 地球 /
/// 行 2: 8〜10 = FOW が出るアニメーション(出現後は 10 を次の行程まで出す)。5〜7 はいまは未使用(画像だけ置く)。
class RaiFace {
  static const eyes = 0;
  static const eyes2 = 1;
  static const eyesRound = 2;
  static const eyesNarrow = 3;
  static const blink = 4;
  static const clip = 5;
  static const camera = 6;
  static const globe = 7;
  static const fow1 = 8;
  static const fow2 = 9;
  static const fow3 = 10;
  static const count = 11;

  /// FOW 出現のアニメーション(順に出す)。
  static const fowAppear = [fow1, fow2, fow3];
}

/// シートの枠(割合)。列 c、行 r の枠 = 左 (40 + 422c)/1920、上 (133 + 308.5r)/1080、幅 378/1920、高さ 252/1080。
ui.Rect raiFaceFrameRect(int index, {double width = 1, double height = 1}) {
  final c = index % 4;
  final r = index ~/ 4;
  return ui.Rect.fromLTWH((40 + 422 * c) / 1920 * width, (133 + 308.5 * r) / 1080 * height, 378 / 1920 * width, 252 / 1080 * height);
}

/// シートを読み、各枠を PNG に切り出す(テクスチャ用)。読めなければ空(表情は変えない)。
class RaiFaceSheet {
  RaiFaceSheet(this.frames);
  final List<Uint8List> frames;

  static const asset = 'assets/rai/face.png';

  static Future<RaiFaceSheet> load({int frameWidth = 256, int frameHeight = 171}) async {
    try {
      final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
      return await fromBytes(bytes, frameWidth: frameWidth, frameHeight: frameHeight);
    } catch (_) {
      return RaiFaceSheet(const []);
    }
  }

  static Future<RaiFaceSheet> fromBytes(Uint8List png, {int frameWidth = 256, int frameHeight = 171}) async {
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    final out = <Uint8List>[];
    for (var i = 0; i < RaiFace.count; i++) {
      final src = raiFaceFrameRect(i, width: image.width.toDouble(), height: image.height.toDouble());
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      canvas.drawImageRect(image, src, ui.Rect.fromLTWH(0, 0, frameWidth.toDouble(), frameHeight.toDouble()), ui.Paint()..filterQuality = ui.FilterQuality.high);
      final frame = await rec.endRecording().toImage(frameWidth, frameHeight);
      final data = await frame.toByteData(format: ui.ImageByteFormat.png);
      frame.dispose();
      if (data == null) continue;
      out.add(data.buffer.asUint8List());
    }
    image.dispose();
    return RaiFaceSheet(out);
  }
}
