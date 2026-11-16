import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'icon_theme_codec.dart';

/// テーマ編集の画素の処理 (D-565)。どれも素の Dart で、別の isolate(`compute`)で動かす。

/// 選んだ画像 → 400×400 の RGBA(真ん中で正方形に切って縮める)。読めなければ null。
Uint8List? iconThemePrepareSource(Uint8List bytes) {
  img.Image? im;
  try {
    im = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (im == null) return null;
  final m = im.width < im.height ? im.width : im.height;
  final square = img.copyCrop(im, x: (im.width - m) ~/ 2, y: (im.height - m) ~/ 2, width: m, height: m);
  final sized = img.copyResize(square, width: iconThemeSize, height: iconThemeSize, interpolation: img.Interpolation.cubic);
  return Uint8List.fromList(sized.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba));
}

/// 見本のアイコン(仮組みの drawSample: 夕焼けの空・月・山)。
Uint8List iconThemeSampleSource() {
  final im = img.Image(width: iconThemeSize, height: iconThemeSize, numChannels: 4);
  for (var y = 0; y < iconThemeSize; y++) {
    final t = y / iconThemeSize;
    final (r, g, b) = t < 0.55 ? _lerp((255, 184, 107), (255, 125, 125), t / 0.55) : _lerp((255, 125, 125), (124, 79, 168), (t - 0.55) / 0.45);
    for (var x = 0; x < iconThemeSize; x++) {
      im.setPixelRgba(x, y, r, g, b, 255);
    }
  }
  img.fillCircle(im, x: 200, y: 190, radius: 62, color: img.ColorRgba8(255, 243, 201, 255));
  for (var x = 0; x < iconThemeSize; x++) {
    final hill = 300 - 60 * _bump(x / 230) + (x > 230 ? 40 * _bump((x - 230) / 170) - 30 : 0);
    for (var y = hill.round(); y < iconThemeSize; y++) {
      im.setPixelRgba(x, y, 90, 60, 140, 255);
    }
    final low = 345 - 40 * _bump(x / 280);
    for (var y = low.round(); y < iconThemeSize; y++) {
      im.setPixelRgba(x, y, 59, 42, 102, 255);
    }
  }
  return Uint8List.fromList(im.getBytes(order: img.ChannelOrder.rgba));
}

double _bump(double t) => t <= 0 || t >= 1 ? 0 : 4 * t * (1 - t);
(int, int, int) _lerp((int, int, int) a, (int, int, int) b, double t) => ((a.$1 + (b.$1 - a.$1) * t).round(), (a.$2 + (b.$2 - a.$2) * t).round(), (a.$3 + (b.$3 - a.$3) * t).round());

/// 書き込みと「サーバーに上げて戻ってきた」見本の結果。
class IconThemeRun {
  const IconThemeRun({this.png, this.info, this.capacity, this.served, this.servedSize = 0, this.servedBytes = 0, this.decoded = IconThemeDecoded.none, this.error});

  /// テーマを書き込んだアイコン(PNG)。
  final Uint8List? png;
  final IconThemeEncodeInfo? info;

  /// 拡張の中身が容量を超えたとき。
  final IconThemeCapacityError? capacity;

  /// 再圧縮 / リサイズしたもの(JPEG)と、その一辺・大きさ。
  final Uint8List? served;
  final int servedSize;
  final int servedBytes;

  /// そこから読み戻したもの。
  final IconThemeDecoded decoded;
  final String? error;
}

/// [iconThemeRunPipeline] に渡すもの。
class IconThemeJob {
  const IconThemeJob({required this.source, required this.theme, this.ext, required this.ramp, required this.quality, required this.size, this.external});
  final Uint8List source;
  final IconThemeBasic theme;
  final IconThemeExt? ext;
  final List<List<int>> ramp;
  final int quality;
  final int size;

  /// 実際の SNS から保存した画像(あれば、再圧縮の見本の代わりにこれを読む)。
  final Uint8List? external;
}

/// 書き込む → PNG → (見本の)再圧縮 → 読み戻す。
IconThemeRun iconThemeRunPipeline(IconThemeJob job) {
  final d = Uint8List.fromList(job.source);
  final IconThemeEncodeInfo info;
  try {
    info = iconThemeEncode(d, job.theme, ext: job.ext, ramp: job.ramp);
  } on IconThemeCapacityError catch (e) {
    return IconThemeRun(capacity: e);
  } catch (e) {
    return IconThemeRun(error: '$e');
  }
  final encoded = img.Image.fromBytes(width: iconThemeSize, height: iconThemeSize, bytes: d.buffer, numChannels: 4);
  final png = Uint8List.fromList(img.encodePng(encoded));
  final Uint8List served;
  if (job.external != null) {
    served = job.external!;
  } else {
    final resized = job.size == iconThemeSize ? encoded : img.copyResize(encoded, width: job.size, height: job.size, interpolation: img.Interpolation.average);
    served = Uint8List.fromList(img.encodeJpg(resized, quality: job.quality));
  }
  final back = img.decodeImage(served);
  if (back == null) return IconThemeRun(png: png, info: info, served: served, error: 'decode');
  final rgba = back.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
  return IconThemeRun(png: png, info: info, served: served, servedSize: back.width, servedBytes: served.length, decoded: iconThemeDecode(rgba, back.width, back.height));
}

/// 400×400 の RGBA → PNG(元のアイコンの見本に)。
Uint8List iconThemePngEncode(Uint8List rgba) =>
    Uint8List.fromList(img.encodePng(img.Image.fromBytes(width: iconThemeSize, height: iconThemeSize, bytes: rgba.buffer, numChannels: 4)));
