import 'dart:typed_data';
import 'dart:ui' as ui;

/// 絵(PNG / WebP / GIF …)→ [size]×[size] の RGBA。動く絵は 1 コマ目。読めなければ null。端末 / Web (D-302) 共通。
Future<Uint8List?> decodeEmojiRgba(Uint8List encoded, {required int size}) async {
  try {
    final codec = await ui.instantiateImageCodec(encoded, targetWidth: size, targetHeight: size, allowUpscaling: true);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    frame.image.dispose();
    codec.dispose();
    final bytes = data?.buffer.asUint8List();
    return bytes == null || bytes.length != size * size * 4 ? null : bytes;
  } catch (_) {
    return null;
  }
}
