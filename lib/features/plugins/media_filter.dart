import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// カスタムフィルター (D-255、スロット契約 v0.12 §2.2 の `output: "filter"`)。
///
/// プラグインの `filter.preview` が返す**描画リスト**を CustomPaint で描く。座標と長さは絵の幅・高さに対する 0..1、
/// `r` / `width` / `blur` は短辺に対する割合なので、プレビュー(画面の大きさ)でも焼き込み(絵の画素数)でも同じ絵になる。
const mediaFilterMaxOps = 2000;

enum MediaFilterMode {
  /// レイヤー重ね: 完了のときホストが描画リストをそのまま焼き込む。
  overlay,

  /// ピクセルの書き換え: 描画リストはプレビューだけ。完了のとき `filter.apply` でプラグインが合成する。
  pixels,
}

@immutable
class MediaFilterOp {
  const MediaFilterOp({required this.kind, required this.x, required this.y, this.w = 0, this.h = 0, this.x2 = 0, this.y2 = 0, this.r = 0, this.width = 0, this.radius = 0, this.blur = 0, required this.color, this.opacity = 1, this.blend = BlendMode.srcOver});

  /// `rect` / `circle` / `ring` / `line`。
  final String kind;
  final double x, y, w, h, x2, y2, r, width, radius, blur;
  final Color color;
  final double opacity;
  final BlendMode blend;
}

/// 調整できる値 1 つ(契約 v0.13。ホストがスライダーで出す)。
@immutable
class MediaFilterParam {
  const MediaFilterParam({required this.id, required this.label, required this.min, required this.max, required this.step, required this.value});
  final String id;
  final String label;
  final double min, max, step, value;

  int? get divisions => step <= 0 ? null : ((max - min) / step).round().clamp(1, 1000);
  String format(double v) => step >= 1 ? v.round().toString() : v.toStringAsFixed(step >= 0.1 ? 1 : 2);
}

/// 動かせるオブジェクトの初期の置き場所(契約 v0.13): 中心(絵に対する 0..1)と一辺(短辺に対する割合)の正方形。
@immutable
class MediaFilterObject {
  const MediaFilterObject({required this.x, required this.y, required this.size});
  final double x, y, size;
}

@immutable
class MediaFilterSpec {
  const MediaFilterSpec({required this.mode, required this.ops, this.matrix, this.dropped = 0, this.params = const [], this.object});

  /// 調整できる値(あればホストが FOW を出す)。
  final List<MediaFilterParam> params;

  /// あれば、描画リストは絵いっぱいではなく動かせるオブジェクト(`ops` の座標はその正方形に対する 0..1)。
  final MediaFilterObject? object;
  final MediaFilterMode mode;
  final List<MediaFilterOp> ops;

  /// 5×4 の色行列(あれば)。プレビューでは使わない(ホストは絵そのものを持っていない)。
  final List<double>? matrix;

  /// 上限を超えて捨てた op の数。
  final int dropped;
}

const _blends = <String, BlendMode>{
  'normal': BlendMode.srcOver,
  'multiply': BlendMode.multiply,
  'screen': BlendMode.screen,
  'overlay': BlendMode.overlay,
  'plus': BlendMode.plus,
  'softLight': BlendMode.softLight,
  'color': BlendMode.color,
};

/// `#RRGGBB` / `#AARRGGBB`。読めなければ null。
Color? parseFilterColor(Object? raw) {
  if (raw is! String || !raw.startsWith('#')) return null;
  final hex = raw.substring(1);
  final v = int.tryParse(hex, radix: 16);
  if (v == null) return null;
  return switch (hex.length) { 6 => Color(0xFF000000 | v), 8 => Color(v), _ => null };
}

/// `filter.preview` の戻り → [MediaFilterSpec]。形の違う op は捨てる(全部だめなら ops は空)。戻りが Map でなければ null。
MediaFilterSpec? parseMediaFilterSpec(Object? raw) {
  if (raw is! Map) return null;
  double n(Object? v, [double d = 0]) => v is num && v.isFinite ? v.toDouble() : d;
  final ops = <MediaFilterOp>[];
  var dropped = 0;
  for (final o in (raw['ops'] as List? ?? const [])) {
    if (o is! Map) continue;
    final kind = o['op'];
    final color = parseFilterColor(o['color']);
    if (kind is! String || !const {'rect', 'circle', 'ring', 'line'}.contains(kind) || color == null) continue;
    if (ops.length >= mediaFilterMaxOps) {
      dropped++;
      continue;
    }
    ops.add(MediaFilterOp(
      kind: kind,
      x: n(o['x']),
      y: n(o['y']),
      w: n(o['w']),
      h: n(o['h']),
      x2: n(o['x2']),
      y2: n(o['y2']),
      r: n(o['r']),
      width: n(o['width']),
      radius: n(o['radius']),
      blur: n(o['blur']).clamp(0.0, 1.0),
      color: color,
      opacity: n(o['opacity'], 1).clamp(0.0, 1.0),
      blend: _blends[o['blend']] ?? BlendMode.srcOver,
    ));
  }
  final params = <MediaFilterParam>[];
  for (final p in (raw['params'] as List? ?? const [])) {
    if (p is! Map || p['id'] is! String || p['min'] is! num || p['max'] is! num) continue;
    final min = n(p['min']), max = n(p['max']);
    if (max <= min || params.any((x) => x.id == p['id'])) continue;
    params.add(MediaFilterParam(id: p['id'] as String, label: p['label'] as String? ?? p['id'] as String, min: min, max: max, step: n(p['step']).clamp(0.0, max - min), value: n(p['value'], min).clamp(min, max)));
  }
  final o = raw['object'];
  final object = o is Map && o['size'] is num && n(o['size']) > 0 ? MediaFilterObject(x: n(o['x'], 0.5).clamp(0.0, 1.0), y: n(o['y'], 0.5).clamp(0.0, 1.0), size: n(o['size']).clamp(0.02, 4.0)) : null;
  final m = raw['matrix'];
  return MediaFilterSpec(
    params: params,
    object: object,
    // オブジェクトはレイヤーとして焼き込むしかない(pixels とは併用できない)。
    mode: raw['mode'] == 'pixels' && object == null ? MediaFilterMode.pixels : MediaFilterMode.overlay,
    ops: ops,
    matrix: m is List && m.length == 20 && m.every((v) => v is num) ? [for (final v in m) (v as num).toDouble()] : null,
    dropped: dropped,
  );
}

/// 描画リストを描く。
void paintMediaFilter(Canvas canvas, Size size, MediaFilterSpec spec) {
  final w = size.width, h = size.height, s = math.min(w, h);
  canvas.save();
  canvas.clipRect(Offset.zero & size);
  for (final op in spec.ops) {
    final paint = Paint()
      ..color = op.color.withValues(alpha: op.color.a * op.opacity)
      ..blendMode = op.blend
      ..isAntiAlias = true;
    if (op.blur > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, op.blur * s);
    switch (op.kind) {
      case 'rect':
        final r = Rect.fromLTWH(op.x * w, op.y * h, op.w * w, op.h * h);
        op.radius > 0 ? canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(op.radius * s)), paint) : canvas.drawRect(r, paint);
      case 'circle':
        canvas.drawCircle(Offset(op.x * w, op.y * h), op.r * s, paint);
      case 'ring':
        canvas.drawCircle(
            Offset(op.x * w, op.y * h),
            op.r * s,
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1, op.width * s));
      case 'line':
        canvas.drawLine(
            Offset(op.x * w, op.y * h),
            Offset(op.x2 * w, op.y2 * h),
            paint
              ..strokeWidth = math.max(1, op.width * s)
              ..strokeCap = StrokeCap.round);
    }
  }
  canvas.restore();
}

/// [spec] が差し替わるたびに描き直す(パラメーターの調整中も、レイヤーそのものは置いたまま)。
class MediaFilterPainter extends CustomPainter {
  MediaFilterPainter(this.spec) : super(repaint: spec);
  final ValueNotifier<MediaFilterSpec> spec;
  @override
  void paint(Canvas canvas, Size size) => paintMediaFilter(canvas, size, spec.value);
  @override
  bool shouldRepaint(MediaFilterPainter old) => old.spec != spec;
}

/// 描画リストを PNG に(テスト / 確認用)。
Future<ui.Image> renderMediaFilter(MediaFilterSpec spec, int width, int height, {Color? background}) {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  if (background != null) canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = background);
  paintMediaFilter(canvas, Size(width.toDouble(), height.toDouble()), spec);
  return rec.endRecording().toImage(width, height);
}
