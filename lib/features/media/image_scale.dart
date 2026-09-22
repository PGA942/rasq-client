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

/// 長辺が [max] を超えていたら縮めて PNG で返す。超えていなければ入力を
/// そのまま返す。
///
/// 縮小は**デコード時**に行う (`targetWidth` / `targetHeight`)。フル解像度の
/// ビットマップを一度作ってから縮めるより、ピーク時のメモリが小さい。
Future<ScaledImage> fitWithin(Uint8List src, int max, {required String mimeType}) async {
  final probe = await ui.instantiateImageCodec(src);
  final probed = (await probe.getNextFrame()).image;
  final width = probed.width;
  final height = probed.height;
  probed.dispose();
  if (width <= max && height <= max) {
    return ScaledImage(bytes: src, mimeType: mimeType, width: width, height: height, scaled: false);
  }
  final wide = width >= height;
  final codec = await ui.instantiateImageCodec(src, targetWidth: wide ? max : null, targetHeight: wide ? null : max);
  final image = (await codec.getNextFrame()).image;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return ScaledImage(bytes: data!.buffer.asUint8List(), mimeType: 'image/png', width: image.width, height: image.height, scaled: true);
  } finally {
    image.dispose();
  }
}
