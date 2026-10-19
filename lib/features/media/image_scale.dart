import 'dart:typed_data';
import 'dart:ui' as ui;

/// 画素数を測り、必要なら長辺を縮めた結果。
class ScaledImage {
  const ScaledImage({required this.bytes, required this.mimeType, required this.width, required this.height, required this.scaled});

  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;

  /// 縮めたか。false なら [bytes] は入力そのまま(再エンコードしていない)。
  final bool scaled;
}

/// PNG / JPEG のヘッダーから画素数を読む(**復号しない**)。読めなければ null。
///
/// 復号 (`instantiateImageCodec`) は背景スレッドへ出るため、ウィジェット
/// テストの疑似非同期では完了しない。UI の経路で毎回それを待つ作りにすると、
/// 画面が進まなくなる。ここは同期で済ませ、**大きいと分かったときだけ**
/// 縮小(= 実際の復号)へ進む。
///
/// 読めない形式は null を返して素通しする。その場合の歯止めはランタイム側の
/// fuel 上限(超過は E02)で、縮小前と同じ状態に戻るだけ。
(int, int)? imageSizeFromHeader(Uint8List b) {
  // PNG: 8 バイトのシグネチャ + IHDR(幅・高さは big-endian 32bit)。
  const pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (b.length >= 24) {
    var isPng = true;
    for (var i = 0; i < pngMagic.length; i++) {
      if (b[i] != pngMagic[i]) {
        isPng = false;
        break;
      }
    }
    if (isPng) return (_be32(b, 16), _be32(b, 20));
  }
  // JPEG: SOI のあとセグメントを辿り、SOFn の中の高さ・幅を読む。
  if (b.length >= 4 && b[0] == 0xFF && b[1] == 0xD8) {
    var i = 2;
    // i+5..i+8 を読むので、境界は <= で取る(< にすると SOF がちょうど
    // 末尾で終わるヘッダーを読み落とす)。
    while (i + 9 <= b.length) {
      if (b[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = b[i + 1];
      // 単独マーカー(長さを持たない)。
      if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        i += 2;
        continue;
      }
      if (marker == 0xD9) break; // EOI
      const sof = {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF};
      if (sof.contains(marker)) {
        return (_be16(b, i + 7), _be16(b, i + 5)); // (幅, 高さ)
      }
      final length = _be16(b, i + 2);
      if (length < 2) break;
      i += 2 + length;
    }
  }
  return null;
}

int _be16(Uint8List b, int i) => (b[i] << 8) | b[i + 1];
int _be32(Uint8List b, int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

/// JPEG の Exif の向き(タグ 0x0112、1〜8)。無い / 読めない / JPEG でなければ null。**復号しない**。
///
/// Flutter の復号(`instantiateImageCodec` / `ImageDescriptor`)はこの向きを当てた縦横で返すが、ヘッダーの SOF の
/// 幅・高さ([imageSizeFromHeader])は当てる前のまま。5〜8 は縦横が入れ替わる (D-511)。プラグインの多くは Exif を
/// 見ずに復号する(Rust の `image` など)ので、向きのある JPEG はそのまま渡すと、ホストの見た目と縦横が食い違う。
int? jpegExifOrientation(Uint8List b) {
  if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;
  var i = 2;
  while (i + 4 <= b.length) {
    if (b[i] != 0xFF) return null;
    final marker = b[i + 1];
    if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    // SOS / EOI の先に Exif は無い。
    if (marker == 0xDA || marker == 0xD9) return null;
    final length = _be16(b, i + 2);
    if (length < 2 || i + 2 + length > b.length) return null;
    // APP1 "Exif\0\0"
    if (marker == 0xE1 && length >= 16 && b[i + 4] == 0x45 && b[i + 5] == 0x78 && b[i + 6] == 0x69 && b[i + 7] == 0x66 && b[i + 8] == 0 && b[i + 9] == 0) {
      return _tiffOrientation(b, i + 10, i + 2 + length);
    }
    i += 2 + length;
  }
  return null;
}

/// TIFF(Exif の中身)の 0 番目の IFD から向きを読む。[start]〜[end] の外は読まない。
int? _tiffOrientation(Uint8List b, int start, int end) {
  if (start + 8 > end) return null;
  final little = b[start] == 0x49 && b[start + 1] == 0x49; // "II"
  final big = b[start] == 0x4D && b[start + 1] == 0x4D; // "MM"
  if (!little && !big) return null;
  int u16(int at) => little ? b[at] | (b[at + 1] << 8) : (b[at] << 8) | b[at + 1];
  int u32(int at) => little ? b[at] | (b[at + 1] << 8) | (b[at + 2] << 16) | (b[at + 3] << 24) : (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];
  if (u16(start + 2) != 42) return null;
  final ifd = start + u32(start + 4);
  if (ifd < start + 8 || ifd + 2 > end) return null;
  final count = u16(ifd);
  for (var n = 0; n < count; n++) {
    final e = ifd + 2 + n * 12;
    if (e + 12 > end) return null;
    if (u16(e) == 0x0112) {
      final v = u16(e + 8);
      return v >= 1 && v <= 8 ? v : null;
    }
  }
  return null;
}

/// 向きを当てた(見たままの)画素数 (D-511)。PNG はそのまま、JPEG は Exif の向き 5〜8 で縦横を入れ替える。
(int, int)? orientedImageSizeFromHeader(Uint8List b) {
  final size = imageSizeFromHeader(b);
  if (size == null) return null;
  final o = jpegExifOrientation(b);
  return o != null && o >= 5 ? (size.$2, size.$1) : size;
}

/// 長辺を [max] に収める縦横(縦横比を保つ。収まっていれば null = 縮めない)。
(int, int)? fitDimensions(int width, int height, int max) {
  if (width <= 0 || height <= 0 || (width <= max && height <= max)) return null;
  if (width >= height) return (max, (height * max / width).round().clamp(1, max));
  return ((width * max / height).round().clamp(1, max), max);
}

/// [src] を長辺 [max] 以内で復号して PNG にする (D-511)。
///
/// 画素数は `ImageDescriptor`(ヘッダーだけ読む)から取り、**縮める大きさで 1 回だけ復号する**。以前はまず原寸で
/// 復号して大きさを見ていたので、数千万画素の写真やパノラマでは原寸のビットマップ(数百 MB)を作ってから縮めることになり、
/// 端末によってはそこで失敗していた(全画面表示プラグインのトグルに「画像を取得できませんでした」)。縦横は向き(Exif)を
/// 当てたあとのもの。
Future<(Uint8List, int, int)> decodeToPngWithin(Uint8List src, int max) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(src);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final target = fitDimensions(descriptor.width, descriptor.height, max);
    codec = await descriptor.instantiateCodec(targetWidth: target?.$1, targetHeight: target?.$2);
    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return (data!.buffer.asUint8List(), image.width, image.height);
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

/// 長辺が [max] を超えていたら縮めて PNG で返す。超えていなければ入力を
/// そのまま返す。[normalize] = 超えていなくても PNG に焼き直す(Exif の向きを画素に当てる、D-511)。
///
/// 縮小は**デコード時**に行う (`targetWidth` / `targetHeight`)。フル解像度の
/// ビットマップを一度作ってから縮めるより、ピーク時のメモリが小さい。大きさを見るための原寸の復号もしない
/// (`ImageDescriptor` でヘッダーだけ読む)。縦横は向きを当てたあとのもの。
Future<ScaledImage> fitWithin(Uint8List src, int max, {required String mimeType, bool normalize = false}) async {
  if (!normalize) {
    final buffer = await ui.ImmutableBuffer.fromUint8List(src);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final (width, height) = (descriptor.width, descriptor.height);
    descriptor.dispose();
    buffer.dispose();
    if (width <= max && height <= max) {
      return ScaledImage(bytes: src, mimeType: mimeType, width: width, height: height, scaled: false);
    }
  }
  final (bytes, width, height) = await decodeToPngWithin(src, max);
  return ScaledImage(bytes: bytes, mimeType: 'image/png', width: width, height: height, scaled: true);
}
