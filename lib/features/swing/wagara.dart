import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Swing の背景の紋様 (D-386)。和柄を手続きで描く。
///
/// - 柄は 19 種([Wagara])。籠目 / 千鳥 / 松葉散らし / 笠松 / 梅 / 桐 / 杜若 / 秋草 / 菊 は入れない(ユーザー指定)。
/// - 背景 = **1 枚目の紋様**(地の色 + 柄 A)+ **2 枚目の紋様**(地の色 + 柄 B を、柄 A を大きく描いたものでマスクしたもの)。
///   どちらの層も「ランダムな色 + HSV の補色」の 2 色(D-387)。どの 2 つ([swingWagara] から)/ 色 / 大きさかは乱数で決める。
enum Wagara {
  seigaiha('青海波'),
  asanoha('麻の葉'),
  shippo('七宝'),
  sayagata('紗綾形'),
  higaki('檜垣'),
  yagasuri('矢絣'),
  ishidatami('石畳'),
  tatewaku('立涌'),
  kikko('亀甲'),
  uroko('鱗'),
  fundo('分銅繋ぎ'),
  sankuzushi('三崩し'),
  hishi('菱'),
  matsukawabishi('松皮菱'),
  take('竹'),
  shima('縞'),
  koshi('格子'),
  ryusui('流水'),
  nami('波');

  const Wagara(this.label);
  final String label;
}

/// Swing の背景に使う柄 (D-387): 七宝 / 檜垣 / 石畳 / 立涌 / 亀甲 / 鱗 / 菱 はそのまま、松皮菱(中を塗る・真ん中を大きく)と
/// 分銅繋ぎ(立涌の波線を ±45° に倒して重ねる)は描き直して使う。ほかの柄は描けるが、背景には選ばない。
const swingWagara = [Wagara.shippo, Wagara.higaki, Wagara.ishidatami, Wagara.tatewaku, Wagara.kikko, Wagara.uroko, Wagara.hishi, Wagara.matsukawabishi, Wagara.fundo];

/// HSV で色相を 180° 回した色(補色)。彩度と明るさはそのまま。
Color complementOf(Color c) {
  final h = HSVColor.fromColor(c);
  return h.withHue((h.hue + 180) % 360).toColor();
}

/// 1 枚の背景の決め方。
class SwingBackgroundSpec {
  const SwingBackgroundSpec({required this.first, required this.second, required this.base, required this.secondBase, required this.unit, required this.secondUnit, required this.maskScale});
  final Wagara first;
  final Wagara second;

  /// 1 枚目の地の色(柄 A はその補色)。
  final Color base;

  /// 2 枚目の地の色(柄 B はその補色)。
  final Color secondBase;

  /// 柄 A / 柄 B の 1 つ分の大きさ(px、1080 幅基準)。
  final double unit;
  final double secondUnit;

  /// マスクに使う柄 A の拡大率。
  final double maskScale;

  /// どちらの層も「ランダムな色 + その補色」の 2 色で埋める (D-387: 透けた所をなくして見やすく)。
  factory SwingBackgroundSpec.random(math.Random rng, {List<Wagara> from = swingWagara}) {
    final first = from[rng.nextInt(from.length)];
    var second = from[rng.nextInt(from.length - 1)];
    if (from.indexOf(second) >= from.indexOf(first)) second = from[from.indexOf(second) + 1];
    Color pick() => HSVColor.fromAHSV(1, rng.nextDouble() * 360, 0.35 + rng.nextDouble() * 0.4, 0.55 + rng.nextDouble() * 0.4).toColor();
    return SwingBackgroundSpec(
      first: first,
      second: second,
      base: pick(),
      secondBase: pick(),
      unit: 90 + rng.nextDouble() * 80,
      secondUnit: 60 + rng.nextDouble() * 50,
      maskScale: 1.8 + rng.nextDouble() * 0.9,
    );
  }

  String get label => '${first.label} × ${second.label}';
}

/// 背景を描く: 1 枚目 = 地の色 + 柄 A(補色)。2 枚目 = 地の色 + 柄 B(補色)を、柄 A(大)でマスクしたもの。
void paintSwingBackground(Canvas canvas, Size size, SwingBackgroundSpec spec) {
  final rect = Offset.zero & size;
  canvas.drawRect(rect, Paint()..color = spec.base);
  paintWagara(canvas, size, spec.first, color: complementOf(spec.base), ground: spec.base, unit: spec.unit);
  canvas.saveLayer(rect, Paint());
  canvas.drawRect(rect, Paint()..color = spec.secondBase);
  paintWagara(canvas, size, spec.second, color: complementOf(spec.secondBase), ground: spec.secondBase, unit: spec.secondUnit);
  canvas.saveLayer(rect, Paint()..blendMode = BlendMode.dstIn);
  paintWagara(canvas, size, spec.first, color: const Color(0xFF000000), ground: const Color(0x00000000), unit: spec.unit * spec.maskScale, mask: true);
  canvas.restore();
  canvas.restore();
}

/// 背景を PNG にする(Swing の画面は縦長 1080×1920)。
Future<Uint8List> renderSwingBackground(SwingBackgroundSpec spec, {int width = 1080, int height = 1920}) async {
  final rec = ui.PictureRecorder();
  paintSwingBackground(Canvas(rec), Size(width.toDouble(), height.toDouble()), spec);
  final img = await rec.endRecording().toImage(width, height);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

/// 立涌の波線の対を [r] いっぱいに敷く(列は u ごと、腹は y = u/2 + 2k·u、節は y = u/2 + (2k+1)·u)。
void _waku(Canvas canvas, Rect r, double u, Paint stroke) {
  final i0 = (r.left / u).floor() - 1;
  final i1 = (r.right / u).ceil() + 1;
  for (var i = i0; i < i1; i++) {
    final x = i * u;
    for (final side in [-1.0, 1.0]) {
      final path = Path()..moveTo(x + u / 2 + side * u * 0.1, r.top - u);
      for (var y = r.top - u; y < r.bottom + u; y += 4) {
        final dx = side * (u * 0.1 + u * 0.28 * (0.5 + 0.5 * math.sin(y / u * math.pi)));
        path.lineTo(x + u / 2 + dx, y);
      }
      canvas.drawPath(path, stroke);
    }
  }
}

/// 柄を 1 つ敷き詰める。[mask] = マスク用(線の柄も太く / 塗りで描く)。[ground] = 重なりを消すための地の色(透明なら消さない)。
void paintWagara(Canvas canvas, Size size, Wagara w, {required Color color, required Color ground, required double unit, bool mask = false}) {
  final u = unit;
  final stroke = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = mask ? u * 0.22 : math.max(2.0, u * 0.045)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  final fill = Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  final erase = Paint()
    ..color = ground
    ..style = PaintingStyle.fill;
  final eraseOn = ground.a > 0 && !mask;
  final cols = (size.width / u).ceil() + 2;
  final rows = (size.height / u).ceil() + 2;

  switch (w) {
    case Wagara.seigaiha:
      // 半円を重ねて上の段から下へ(下の段が上に重なる)。
      final r = u / 2;
      for (var j = -1; j < (size.height / (r / 2)).ceil() + 3; j++) {
        final y = j * r / 2;
        final off = j.isOdd ? r : 0.0;
        for (var i = -1; i < cols; i++) {
          final c = Offset(i * u + off, y);
          for (var k = 4; k >= 1; k--) {
            final rr = r * k / 4;
            if (mask) {
              if (k.isEven) canvas.drawCircle(c, rr, fill);
              if (k.isOdd) canvas.drawCircle(c, rr, Paint()..blendMode = BlendMode.clear);
            } else {
              if (eraseOn) canvas.drawCircle(c, rr, erase);
              canvas.drawCircle(c, rr, stroke);
            }
          }
        }
      }
    case Wagara.asanoha:
      // 正三角形の格子 + 各三角形の重心へ向かう線。
      final h = u * math.sqrt(3) / 2;
      for (var j = -1; j < (size.height / h).ceil() + 1; j++) {
        for (var i = -2; i < cols; i++) {
          final x0 = i * u + (j.isOdd ? u / 2 : 0);
          final y0 = j * h;
          final up = [Offset(x0, y0 + h), Offset(x0 + u, y0 + h), Offset(x0 + u / 2, y0)];
          final down = [Offset(x0 + u / 2, y0), Offset(x0 + u * 1.5, y0), Offset(x0 + u, y0 + h)];
          for (final t in [up, down]) {
            final g = Offset((t[0].dx + t[1].dx + t[2].dx) / 3, (t[0].dy + t[1].dy + t[2].dy) / 3);
            final path = Path()..addPolygon(t, true);
            canvas.drawPath(path, stroke);
            for (final p in t) {
              canvas.drawLine(p, g, stroke);
            }
          }
        }
      }
    case Wagara.shippo:
      final r = u / math.sqrt2;
      for (var j = -1; j < rows; j++) {
        for (var i = -1; i < cols; i++) {
          canvas.drawCircle(Offset(i * u, j * u), r, mask ? (stroke..strokeWidth = u * 0.18) : stroke);
        }
      }
    case Wagara.fundo:
      // 分銅繋ぎ (D-387): 立涌の波線を、腹と節(傾きが 0 の所)の位置をそろえたまま ±45° に倒して 2 組重ねる。
      // 2 組の腹と節が同じ所で出会い、その間が分銅の形になる。
      final d = math.sqrt(size.width * size.width + size.height * size.height);
      for (final a in [math.pi / 4, -math.pi / 4]) {
        canvas.save();
        canvas.translate(size.width / 2, size.height / 2);
        canvas.rotate(a);
        // 腹 / 節の位置(y = u/2 + k·u)が 2 組でそろうよう、原点を格子にのせる。
        final half = (d / 2 / u).ceil() * u + u;
        _waku(canvas, Rect.fromLTRB(-half, -half, half, half), u, mask ? (stroke..strokeWidth = u * 0.16) : stroke);
        canvas.restore();
      }
    case Wagara.sayagata:
      // 卍を斜めの格子((3,1) / (-1,3))に並べ、腕の先を隣の卍へつなぐ(紗綾形)。
      final c = u / 3.2;
      final n = (math.max(size.width, size.height) / c / 3).ceil() + 3;
      final path = Path();
      void seg(Offset a, Offset b) => path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
      for (var j = -n; j <= n * 2; j++) {
        for (var i = -n; i <= n * 2; i++) {
          final o = Offset((3 * i - j) * c, (i + 3 * j) * c);
          if (o.dx < -3 * c || o.dy < -3 * c || o.dx > size.width + 3 * c || o.dy > size.height + 3 * c) continue;
          Offset p(double x, double y) => o + Offset(x * c, y * c);
          // 腕(中心から上下左右へ 1)と、曲げ(1)。曲げの先から隣の卍の腕までを 1 つなぐ。
          seg(p(0, -1), p(0, 1));
          seg(p(-1, 0), p(1, 0));
          seg(p(0, -1), p(-1, -1)); // 上 → 左
          seg(p(1, 0), p(1, -1)); // 右 → 上
          seg(p(0, 1), p(1, 1)); // 下 → 右
          seg(p(-1, 0), p(-1, 1)); // 左 → 下
          seg(p(1, -1), p(1, -2)); // つなぎ
          seg(p(-1, 1), p(-1, 2));
        }
      }
      canvas.drawPath(path, stroke);
    case Wagara.higaki:
      // 網代(檜垣): 斜めの市松に、向きを変えた 3 本線。
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(math.pi / 4);
      final span = math.sqrt(size.width * size.width + size.height * size.height) / 2 + u;
      final n = (span / u).ceil();
      for (var j = -n; j < n; j++) {
        for (var i = -n; i < n; i++) {
          final r = Rect.fromLTWH(i * u, j * u, u, u);
          if (mask) {
            if ((i + j).isEven) canvas.drawRect(r, fill);
            continue;
          }
          canvas.drawRect(r, stroke);
          for (var k = 1; k < 3; k++) {
            if ((i + j).isEven) {
              canvas.drawLine(Offset(r.left, r.top + u * k / 3), Offset(r.right, r.top + u * k / 3), stroke);
            } else {
              canvas.drawLine(Offset(r.left + u * k / 3, r.top), Offset(r.left + u * k / 3, r.bottom), stroke);
            }
          }
        }
      }
      canvas.restore();
    case Wagara.sankuzushi:
      for (var j = -1; j < rows; j++) {
        for (var i = -1; i < cols; i++) {
          final r = Rect.fromLTWH(i * u, j * u, u, u);
          if (mask) {
            if ((i + j).isEven) canvas.drawRect(r.deflate(u * 0.08), fill);
            continue;
          }
          for (var k = 0; k < 3; k++) {
            final t = u * (k + 0.5) / 3;
            if ((i + j).isEven) {
              canvas.drawLine(Offset(r.left + u * 0.1, r.top + t), Offset(r.right - u * 0.1, r.top + t), stroke);
            } else {
              canvas.drawLine(Offset(r.left + t, r.top + u * 0.1), Offset(r.left + t, r.bottom - u * 0.1), stroke);
            }
          }
        }
      }
    case Wagara.yagasuri:
      // 矢羽根: 列ごとに向きを変えた平行四辺形を段違いに塗る。
      final cw = u / 2;
      for (var i = -1; i < cols * 2; i++) {
        final x = i * cw;
        final dir = i.isEven ? 1.0 : -1.0;
        for (var j = -2; j < rows * 2; j++) {
          if ((j + (i ~/ 2)).isOdd) continue;
          final y = j * u / 2;
          final a = dir > 0 ? Offset(x, y) : Offset(x + cw, y);
          final b = dir > 0 ? Offset(x + cw, y + u / 4) : Offset(x, y + u / 4);
          final path = Path()..addPolygon([a, b, b + Offset(0, u / 2), a + Offset(0, u / 2)], true);
          canvas.drawPath(path, fill);
        }
      }
    case Wagara.ishidatami:
      for (var j = -1; j < rows; j++) {
        for (var i = -1; i < cols; i++) {
          if ((i + j).isEven) canvas.drawRect(Rect.fromLTWH(i * u, j * u, u, u), fill);
        }
      }
    case Wagara.tatewaku:
      // 向かい合う波線の対(膨らみ = 腹 / すぼまり = 節が交互)。
      _waku(canvas, Rect.fromLTWH(0, 0, size.width, size.height), u, stroke);
    case Wagara.kikko:
      final r = u / 2;
      final h = r * math.sqrt(3);
      for (var i = -1; i < (size.width / (r * 1.5)).ceil() + 1; i++) {
        for (var j = -1; j < (size.height / h).ceil() + 1; j++) {
          final c = Offset(i * r * 1.5, j * h + (i.isOdd ? h / 2 : 0));
          Path hex(double rr) => Path()..addPolygon([for (var k = 0; k < 6; k++) c + Offset(rr * math.cos(k * math.pi / 3), rr * math.sin(k * math.pi / 3))], true);
          if (mask) {
            canvas.drawPath(hex(r * 0.8), fill);
          } else {
            canvas.drawPath(hex(r), stroke);
            canvas.drawPath(hex(r * 0.72), stroke);
          }
        }
      }
    case Wagara.uroko:
      final h = u * math.sqrt(3) / 2;
      for (var j = -1; j < (size.height / h).ceil() + 1; j++) {
        for (var i = -1; i < cols; i++) {
          final x0 = i * u + (j.isOdd ? u / 2 : 0);
          final y0 = j * h;
          canvas.drawPath(Path()..addPolygon([Offset(x0, y0 + h), Offset(x0 + u, y0 + h), Offset(x0 + u / 2, y0)], true), fill);
        }
      }
    case Wagara.hishi:
      for (var j = -1; j < (size.height / (u * 0.35)).ceil() + 2; j++) {
        for (var i = -1; i < cols; i++) {
          final c = Offset(i * u + (j.isOdd ? u / 2 : 0), j * u * 0.35);
          // マスクでは外の菱で埋め尽くさないよう、中の菱だけ(少し大きく)。
          final k = mask ? 0.6 : 1.0;
          final path = Path()..addPolygon([c + Offset(0, -u * 0.35 * k), c + Offset(u / 2 * k, 0), c + Offset(0, u * 0.35 * k), c + Offset(-u / 2 * k, 0)], true);
          canvas.drawPath(path, mask ? fill : stroke);
          if (!mask) canvas.drawPath(Path()..addPolygon([c + Offset(0, -u * 0.15), c + Offset(u * 0.21, 0), c + Offset(0, u * 0.15), c + Offset(-u * 0.21, 0)], true), fill);
        }
      }
    case Wagara.matsukawabishi:
      // 大きな菱の上下に小さな菱を重ねた段の形。
      for (var j = -1; j < rows; j++) {
        for (var i = -1; i < cols; i++) {
          final c = Offset(i * u + (j.isOdd ? u / 2 : 0), j * u * 0.8);
          Path dia(Offset cc, double hw, double hh) => Path()..addPolygon([cc + Offset(0, -hh), cc + Offset(hw, 0), cc + Offset(0, hh), cc + Offset(-hw, 0)], true);
          // D-387: 中を塗り、真ん中の菱を 2 割大きく(0.32 × 0.2 → 0.384 × 0.24)。
          for (final (o, hw, hh) in [(Offset.zero, u * 0.384, u * 0.24), (Offset(0, -u * 0.28), u * 0.18, u * 0.11), (Offset(0, u * 0.28), u * 0.18, u * 0.11)]) {
            canvas.drawPath(dia(c + o, hw, hh), fill);
          }
        }
      }
    case Wagara.take:
      // 竹: 幹(節つき)と、ところどころの葉。
      final rng = math.Random(7);
      for (var i = -1; i < cols; i++) {
        final x = i * u + u * 0.3;
        final wdt = u * 0.18;
        final shift = rng.nextDouble() * u;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, -u, wdt, size.height + 2 * u), Radius.circular(wdt / 2)), mask ? fill : stroke);
        if (mask) continue;
        for (var y = -u + shift; y < size.height + u; y += u * 1.1) {
          canvas.drawLine(Offset(x - wdt * 0.2, y), Offset(x + wdt * 1.2, y), stroke);
          if (rng.nextBool()) {
            canvas.save();
            canvas.translate(x + wdt, y);
            canvas.rotate(-0.5 - rng.nextDouble() * 0.4);
            canvas.drawOval(Rect.fromLTWH(0, -u * 0.06, u * 0.45, u * 0.12), fill);
            canvas.restore();
          }
        }
      }
    case Wagara.shima:
      for (var i = -1; i < cols * 3; i++) {
        final x = i * u / 3;
        if (i % 3 == 0 || (!mask && i % 3 == 1 && i.isEven)) canvas.drawRect(Rect.fromLTWH(x, 0, i % 3 == 0 ? u / 6 : u / 18, size.height), fill);
      }
    case Wagara.koshi:
      final s = stroke..strokeWidth = mask ? u * 0.25 : math.max(3.0, u * 0.09);
      for (var i = -1; i < cols; i++) {
        canvas.drawLine(Offset(i * u, 0), Offset(i * u, size.height), s);
      }
      for (var j = -1; j < rows; j++) {
        canvas.drawLine(Offset(0, j * u), Offset(size.width, j * u), s);
      }
    case Wagara.ryusui:
      // 流水: ゆったり揺れる横の流れ(振れ幅と周期を線ごとに変える)。
      for (var j = -1; j < rows * 2; j++) {
        final y0 = j * u / 2;
        final amp = u * (0.12 + 0.1 * math.sin(j * 1.7));
        final per = u * (2.2 + math.cos(j * 0.9));
        final path = Path()..moveTo(-u, y0);
        for (var x = -u; x < size.width + u; x += 6) {
          path.lineTo(x, y0 + amp * math.sin(x / per * 2 * math.pi + j));
        }
        canvas.drawPath(path, stroke);
      }
    case Wagara.nami:
      // 波: 段ごとにずらした弧の連なり(先が巻く)。
      final r = u / 2;
      for (var j = -1; j < rows * 2; j++) {
        final y = j * r;
        final off = j.isOdd ? r : 0.0;
        final path = Path();
        for (var i = -1; i < cols; i++) {
          final x = i * u + off;
          path.moveTo(x, y);
          path.cubicTo(x + r * 0.3, y - r * 0.9, x + r * 1.5, y - r * 0.9, x + u, y);
          path.moveTo(x + r * 1.2, y - r * 0.55);
          path.quadraticBezierTo(x + r * 1.45, y - r * 0.2, x + r * 1.2, y - r * 0.1);
        }
        canvas.drawPath(path, mask ? (stroke..strokeWidth = u * 0.3) : stroke);
      }
  }
}
