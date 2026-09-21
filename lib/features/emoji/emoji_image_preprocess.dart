import 'dart:typed_data';

/// 絵文字の絵を、SigLIP2 の画像側の入力に (D-293)。
///
/// 入力 = RGBA(8 bit、そのままのアルファ)の [size]×[size]。出力 = `pixel_values` の 1 枚ぶん(CHW、float32、長さ 3×size×size)。
/// - **透明なところは白に重ねる**(絵文字は背景が透明。モデルは RGB の写真で学習しているので、黒つぶれさせない)。
/// - 正規化は SigLIP と同じ `(x / 255 - 0.5) / 0.5` = `x / 127.5 - 1`。
Float32List emojiPixelValues(Uint8List rgba, {int size = 224}) {
  final n = size * size;
  if (rgba.length != n * 4) throw ArgumentError('rgba must be $size x $size x 4 bytes (got ${rgba.length})');
  final out = Float32List(3 * n);
  for (var i = 0; i < n; i++) {
    final a = rgba[i * 4 + 3] / 255.0;
    for (var c = 0; c < 3; c++) {
      final v = rgba[i * 4 + c] * a + 255.0 * (1 - a);
      out[c * n + i] = v / 127.5 - 1.0;
    }
  }
  return out;
}
