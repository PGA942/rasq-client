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
    // 枠の位置はシートから検出する (D-213: 固定の割合だと本物のシートで上段がずれた)。検出できなければ割合。
    List<ui.Rect>? detected;
    try {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba != null) detected = raiFaceDetectFrames(rgba.buffer.asUint8List(), image.width, image.height);
    } catch (_) {
      detected = null;
    }
    final out = <Uint8List>[];
    for (var i = 0; i < RaiFace.count; i++) {
      final src = detected != null && i < detected.length ? detected[i] : raiFaceFrameRect(i, width: image.width.toDouble(), height: image.height.toDouble());
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

/// シートの黒い枠を検出する (D-213): 暗くて不透明な画素の行 / 列の分布から 3 段 × 4 列の帯を取り、
/// その交差を枠にする(行 = 段の順、列 = 左から)。3 段 × 4 列にならなければ null(割合の配置に戻す)。
List<ui.Rect>? raiFaceDetectFrames(Uint8List rgba, int width, int height) {
  if (width < 8 || height < 8) return null;
  bool dark(int x, int y) {
    final i = (y * width + x) * 4;
    return rgba[i + 3] > 200 && rgba[i] < 80 && rgba[i + 1] < 80 && rgba[i + 2] < 80;
  }

  List<(int, int)> bands(List<int> counts, int threshold, int minLen) {
    final out = <(int, int)>[];
    int? start;
    for (var i = 0; i <= counts.length; i++) {
      final on = i < counts.length && counts[i] >= threshold;
      if (on && start == null) start = i;
      if (!on && start != null) {
        if (i - start >= minLen) out.add((start, i));
        start = null;
      }
    }
    return out;
  }

  final rows = List<int>.filled(height, 0);
  final cols = List<int>.filled(width, 0);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (dark(x, y)) {
        rows[y]++;
        cols[x]++;
      }
    }
  }
  // 段: その行に幅の 15% 以上の暗い画素。列: その列に高さの 8% 以上(下段は 3 枠なので少なめ)。
  final rowBands = bands(rows, (width * 0.15).round(), (height * 0.05).round());
  final colBands = bands(cols, (height * 0.08).round(), (width * 0.05).round());
  if (rowBands.length != 3 || colBands.length != 4) return null;
  return [
    for (final (y0, y1) in rowBands)
      for (final (x0, x1) in colBands) ui.Rect.fromLTRB(x0.toDouble(), y0.toDouble(), x1.toDouble(), y1.toDouble()),
  ];
}
