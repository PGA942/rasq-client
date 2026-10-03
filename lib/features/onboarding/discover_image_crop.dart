import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

/// 「囲って検索」(D-418) の囲み(画像の画素の座標)と、端末での切り抜き。
///
/// 囲みは 1 枚に 1 つ。四角(ドラッグの 2 つの角)か、なぞった輪(閉じた折れ線)。切り抜きは囲みの外接の四角で、
/// 輪のときは輪の外を中間の灰色で塗る(OCR / 視覚の RAi が中だけを見るように)。長辺 [discoverPrepareMaxEdge] まで縮めて JPEG にする。

/// 送る画像の長辺の上限と JPEG の品質。
const discoverPrepareMaxEdge = 1600;
const discoverPrepareJpegQuality = 85;

/// 輪の外を塗る色(中間の灰色)。
const discoverMaskGray = 128;

enum DiscoverSelectionKind { rect, lasso }

/// 1 枚の画像の囲み。[points] は画像の画素の座標(四角は対角の 2 点、輪はなぞった順の点)。
@immutable
class DiscoverSelection {
  const DiscoverSelection._(this.kind, this.points);

  /// ドラッグの始点と終点からの四角。
  DiscoverSelection.rect(Offset a, Offset b) : this._(DiscoverSelectionKind.rect, List.unmodifiable([a, b]));

  /// なぞった輪(最初と最後の点は自動で結ぶ)。
  DiscoverSelection.lasso(List<Offset> points) : this._(DiscoverSelectionKind.lasso, List.unmodifiable(points));

  final DiscoverSelectionKind kind;
  final List<Offset> points;

  /// 囲みの外接の四角(画像の外も含みうる。切り抜きでは [discoverSelectionBounds] を使う)。
  Rect get rawBounds {
    if (points.isEmpty) return Rect.zero;
    var l = points.first.dx, t = points.first.dy, r = l, b = t;
    for (final p in points) {
      l = math.min(l, p.dx);
      t = math.min(t, p.dy);
      r = math.max(r, p.dx);
      b = math.max(b, p.dy);
    }
    return Rect.fromLTRB(l, t, r, b);
  }

  /// 輪の頂点(四角なら 4 隅)。
  List<Offset> get polygon {
    if (kind == DiscoverSelectionKind.lasso) return points;
    final r = rawBounds;
    return [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
  }

  /// 小さすぎる囲み(タップ・はみ出しだけ)は囲まなかったことにする。[minSide] は画像の画素。
  bool usable(Size image, {double minSide = 8}) {
    final b = discoverSelectionBounds(this, image);
    if (b == null || b.width < minSide || b.height < minSide) return false;
    return kind == DiscoverSelectionKind.rect || points.length >= 3;
  }
}

/// 切り抜く範囲: 囲みの外接の四角を画像に収め、整数の画素に外向きに丸めたもの。画像と重ならなければ null。
Rect? discoverSelectionBounds(DiscoverSelection s, Size image) {
  final r = s.rawBounds;
  final l = r.left.floorToDouble().clamp(0.0, image.width);
  final t = r.top.floorToDouble().clamp(0.0, image.height);
  final rr = r.right.ceilToDouble().clamp(0.0, image.width);
  final b = r.bottom.ceilToDouble().clamp(0.0, image.height);
  if (rr - l < 1 || b - t < 1) return null;
  return Rect.fromLTRB(l, t, rr, b);
}

/// 縮めたあとの大きさ(長辺が [maxEdge] を超えるときだけ縮める。縦横比は保つ)。
(int, int) discoverScaledSize(int w, int h, {int maxEdge = discoverPrepareMaxEdge}) {
  final long = math.max(w, h);
  if (long <= maxEdge) return (w, h);
  final k = maxEdge / long;
  return (math.max(1, (w * k).round()), math.max(1, (h * k).round()));
}

/// 画像の表示上の大きさ(EXIF の向きを含む)。ヘッダだけを読む。読めなければ null。
Size? discoverImageSizeOf(Uint8List bytes) {
  try {
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) return null;
    var w = info.width.toDouble(), h = info.height.toDouble();
    if (decoder is img.JpegDecoder) {
      final o = img.decodeJpgExif(bytes)?.imageIfd.orientation ?? 1;
      if (o >= 5 && o <= 8) (w, h) = (h, w);
    }
    return Size(w, h);
  } catch (_) {
    return null;
  }
}

/// 輪の外を [discoverMaskGray] で塗る(走査線ごとに輪の辺との交点を求め、偶奇で内外を決める)。[polygon] は [image] の座標。
void discoverMaskOutside(img.Image image, List<Offset> polygon) {
  final n = polygon.length;
  if (n < 3) return;
  final xs = <double>[];
  for (var y = 0; y < image.height; y++) {
    final cy = y + 0.5;
    xs.clear();
    for (var i = 0; i < n; i++) {
      final a = polygon[i], b = polygon[(i + 1) % n];
      if ((a.dy <= cy && b.dy > cy) || (b.dy <= cy && a.dy > cy)) {
        xs.add(a.dx + (cy - a.dy) / (b.dy - a.dy) * (b.dx - a.dx));
      }
    }
    xs.sort();
    // 内側の区間 [xs[0], xs[1]), [xs[2], xs[3]), … の外を塗る。画素の中心 x + 0.5 で判定する。
    var inside = 0;
    for (var x = 0; x < image.width; x++) {
      final cx = x + 0.5;
      while (inside < xs.length && xs[inside] <= cx) {
        inside++;
      }
      if (inside.isEven) image.setPixelRgb(x, y, discoverMaskGray, discoverMaskGray, discoverMaskGray);
    }
  }
}

/// 送る画像を作る: 向きを直す → 囲みの外接の四角で切り抜く → 長辺 [maxEdge] まで縮める → 輪なら外を灰色に → JPEG。
/// [selection] が null(または使えない囲み)なら画像全体。読めない画像は null。
Uint8List? prepareDiscoverImage(Uint8List bytes, DiscoverSelection? selection, {int maxEdge = discoverPrepareMaxEdge, int quality = discoverPrepareJpegQuality}) {
  img.Image? src;
  try {
    src = img.decodeImage(bytes);
  } catch (_) {
    src = null;
  }
  if (src == null) return null;
  var im = img.bakeOrientation(src);
  final size = Size(im.width.toDouble(), im.height.toDouble());
  final sel = selection != null && selection.usable(size) ? selection : null;
  var origin = Offset.zero;
  if (sel != null) {
    final b = discoverSelectionBounds(sel, size)!;
    origin = b.topLeft;
    im = img.copyCrop(im, x: b.left.toInt(), y: b.top.toInt(), width: b.width.toInt(), height: b.height.toInt());
  }
  final (w, h) = discoverScaledSize(im.width, im.height, maxEdge: maxEdge);
  final k = w / im.width;
  if (w != im.width || h != im.height) im = img.copyResize(im, width: w, height: h, interpolation: img.Interpolation.average);
  if (im.hasAlpha) {
    // JPEG は透過を持てない: 白の上に重ねる。
    final bg = img.Image(width: im.width, height: im.height)..clear(img.ColorRgb8(255, 255, 255));
    im = img.compositeImage(bg, im);
  }
  if (sel != null && sel.kind == DiscoverSelectionKind.lasso) {
    discoverMaskOutside(im, [for (final p in sel.points) (p - origin) * k]);
  }
  return img.encodeJpg(im, quality: quality);
}

/// 画像の道具(テストで差し替える)。既定は大きさを端末のデコーダで測り、切り抜きは別の isolate で。
class DiscoverImageTools {
  const DiscoverImageTools();

  /// その場で(同じ isolate で)全部やる。テストや Web 向け。
  const factory DiscoverImageTools.inline() = _InlineDiscoverImageTools;

  /// 画像の表示上の大きさ。
  Future<Size?> measure(Uint8List bytes) async {
    final header = discoverImageSizeOf(bytes);
    if (header != null) return header;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  /// 送る画像(切り抜き + 縮小 + JPEG)。
  Future<Uint8List?> prepare(Uint8List bytes, DiscoverSelection? selection) => compute(_prepareEntry, (bytes, selection));
}

Uint8List? _prepareEntry((Uint8List, DiscoverSelection?) a) => prepareDiscoverImage(a.$1, a.$2);

class _InlineDiscoverImageTools extends DiscoverImageTools {
  const _InlineDiscoverImageTools();
  @override
  Future<Size?> measure(Uint8List bytes) async => discoverImageSizeOf(bytes);
  @override
  Future<Uint8List?> prepare(Uint8List bytes, DiscoverSelection? selection) async => prepareDiscoverImage(bytes, selection);
}

final discoverImageToolsProvider = Provider<DiscoverImageTools>((ref) => kIsWeb ? const DiscoverImageTools.inline() : const DiscoverImageTools());
