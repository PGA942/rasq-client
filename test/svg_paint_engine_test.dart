import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/plugins/svgpaint/eraser.dart';
import 'package:rasq_client/features/plugins/svgpaint/fill.dart';
import 'package:rasq_client/features/plugins/svgpaint/geometry.dart';
import 'package:rasq_client/features/plugins/svgpaint/lasso.dart';
import 'package:rasq_client/features/plugins/svgpaint/model.dart';
import 'package:rasq_client/features/plugins/svgpaint/nib.dart';
import 'package:rasq_client/features/plugins/svgpaint/spline.dart';
import 'package:rasq_client/features/plugins/svgpaint/stabilizer.dart';
import 'package:rasq_client/features/plugins/svgpaint/svg_io.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

/// 落書きのエンジン (D-473): 手ぶれ補正となめらかな曲線、ペン先、切る消しゴム、投げ輪、オート塗りつぶし、SVG の往復。
void main() {
  const vb = Size(300, 400);
  const ink = Color(0xFF212121);
  const red = Color(0xFFE53935);

  /// (x0, y) から (x1, y) へ、[n] 点の横線の入力(時刻は 16 ms ごと)。
  List<Offset> line(Offset a, Offset b, int n) => [for (var i = 0; i <= n; i++) Offset.lerp(a, b, i / n)!];

  /// 入力の点 → 描き終えた線(手ぶれ補正なし、速さ一定)。
  PaintStroke draw(List<Offset> pts, {PaintNib nib = PaintNib.mili, double size = 5, Color color = ink, double msPerPoint = 16}) {
    final dyn = NibDynamics(nib, size);
    final ws = [for (var i = 0; i < pts.length; i++) dyn.next(InkSample(pts[i], i * msPerPoint))];
    return buildStroke(nib: nib, color: color, size: size, points: pts, widths: ws);
  }

  /// 円の上の点。
  List<Offset> arc(Offset c, double r, double from, double to, int n) => [for (var i = 0; i <= n; i++) c + Offset.fromDirection(from + (to - from) * i / n, r)];

  /// 四角を 4 本の線で描く。
  List<PaintItem> square(Rect r, {double size = 2}) => [
        draw(line(r.topLeft, r.topRight, 40), size: size),
        draw(line(r.topRight, r.bottomRight, 40), size: size),
        draw(line(r.bottomRight, r.bottomLeft, 40), size: size),
        draw(line(r.bottomLeft, r.topLeft, 40), size: size),
      ];

  group('手ぶれ補正となめらかな曲線', () {
    test('糸で引く筆: 半径より小さな震えは伝わらず、離したら指の位置まで引き寄せる', () {
      final s = Stabilizer(3, Offset.zero);
      final rnd = math.Random(1);
      final out = <Offset>[];
      for (var i = 1; i <= 200; i++) {
        final p = Offset(i * 1.0, (rnd.nextDouble() - 0.5) * 4); // 横へ進みながら ±2 の震え
        final b = s.add(p);
        if (b != null) out.add(b);
      }
      // 筆の上下の揺れは入力(±2)よりずっと小さい。
      final ys = out.skip(10).map((p) => p.dy.abs());
      expect(ys.reduce(math.max), lessThan(1.5));
      expect(s.finish(const Offset(203, 1)), const Offset(203, 1));
      expect(Stabilizer.radiusFor(0, 1.5), 0);
      expect(Stabilizer.radiusFor(3, 1.2), closeTo(4, 1e-9));
    });

    test('曲線は節を通り、どの節でも接線が前後で同じ向き(角が出ない)', () {
      final rnd = math.Random(7);
      final nodes = [for (var i = 0; i < 30; i++) qp(Offset(i * (3 + rnd.nextDouble() * 20), 200 + (rnd.nextDouble() - 0.5) * 120))];
      final segs = splineSegments(nodes);
      expect(segs.first.cmd, 'M');
      expect(segs.skip(1).every((s) => s.cmd == 'C'), isTrue);
      for (var i = 1; i < segs.length - 1; i++) {
        final p = segs[i].end;
        expect(p, nodes[i]);
        final inT = p - segs[i].pts[1], outT = segs[i + 1].pts[0] - p;
        if (inT.distance < 0.3 || outT.distance < 0.3) continue; // 0.1 単位の丸めで向きが読めない短い腕
        final angle = (inT.direction - outT.direction).abs() % (2 * math.pi);
        expect(math.min(angle, 2 * math.pi - angle), lessThan(0.12), reason: 'node $i');
      }
      // 閉じた輪も同じ。
      final ring = splineSegments(arc(const Offset(150, 200), 50, 0, 2 * math.pi * 0.95, 12).map(qp).toList(), closed: true);
      expect(ring.last.cmd, 'Z');
      expect(ring[ring.length - 2].end, ring.first.end);
    });

    test('速くなぞった(点がまばらな)線も切れずに節を全部通る。まっすぐな線は 2 点(直線)', () {
      final fast = draw(arc(const Offset(150, 200), 80, 0, math.pi, 6), msPerPoint: 2);
      expect(fast.points.length, 7);
      final dense = fast.dense.$1;
      for (var i = 1; i < dense.length; i++) {
        expect((dense[i] - dense[i - 1]).distance, lessThan(1.5));
      }
      final straight = draw(line(const Offset(20, 50), const Offset(280, 50), 60));
      expect(straight.points, [const Offset(20, 50), const Offset(280, 50)]);
      expect(segmentsToD(straight.segments), 'M20 50h260');
      // ゆっくり描いた円は節を減らす(1 度ずつ 360 点 → 数十点)。
      final circle = draw(arc(const Offset(150, 200), 60, 0, 2 * math.pi, 360));
      expect(circle.points.length, inInclusiveRange(10, 40));
    });

    test('小さな d: 相対座標、s の省略、先頭の 0 と要らない区切りを落とす', () {
      final d = segmentsToD([
        moveTo(const Offset(10, 10)),
        cubicTo(const Offset(12, 10), const Offset(14.5, 12), const Offset(16, 14)),
        cubicTo(const Offset(17.5, 16), const Offset(20, 17.5), const Offset(22, 17.5)),
        lineTo(const Offset(22, 20.5)),
        lineTo(const Offset(21.5, 20)),
        closePath,
      ]);
      expect(d, 'M10 10c2 0 4.5 2 6 4s4 3.5 6 3.5v3l-.5-.5z');
      final back = SvgLite.parse('<svg viewBox="0 0 30 30"><path d="$d"/></svg>')!;
      final segs = parseCanonicalD(attrOf(back.shapes.single.toSvgElement(), 'd')!);
      expect(segs.map((s) => s.cmd).join(), 'MCCLLZ');
      expect(segs[2].pts[0], const Offset(17.5, 16)); // s の折り返し
    });
  });

  group('ペン先', () {
    final curve = [for (var i = 0; i <= 120; i++) Offset(30 + i * 2.0, 200 + 60 * math.sin(i / 20))];

    test('ミリペン: 太さ一定・丸い端の stroke', () {
      final s = draw(curve);
      expect(s.widths.toSet(), {5});
      final (style, body) = s.svgParts;
      expect(style, contains('stroke-width="5" stroke-linecap="round" stroke-linejoin="round"'));
      expect(body, startsWith('<path d="M30 200c'));
    });

    for (final nib in [PaintNib.kabura, PaintNib.brush]) {
      test('${nib.label}: 両端が細り(入り・抜き)、輪郭は中心線から太さの範囲に収まる', () {
        final s = draw(curve, nib: nib);
        final maxW = s.widths.reduce(math.max);
        expect(maxW, lessThanOrEqualTo(nibBaseWidth(nib, 5) + 1e-9));
        expect(s.widths.first, lessThan(maxW * 0.2));
        expect(s.widths.last, lessThan(maxW * 0.2));
        // 区間は 2n(左の側 + 終わりの半円 + 右の側 + 始まりの半円)で閉じる。
        expect(s.segments.length, 2 * s.points.length + 2);
        expect(s.segments.last.cmd, 'Z');
        // 輪郭が暴れない: 外接矩形は中心線の外接矩形 + 太さ(マイターで 2 倍まで)に収まる。
        final center = boundsOf(s.points);
        final b = s.path.getBounds();
        expect(center.inflate(maxW + 0.5).contains(b.topLeft) && center.inflate(maxW + 0.5).contains(b.bottomRight), isTrue);
        // 輪郭の点はどれも、一番近い中心線から太さの半分(×マイター 2)以内。
        final (dp, dw) = s.dense;
        for (final seg in s.segments.where((g) => g.cmd == 'C')) {
          var best = double.infinity;
          for (var i = 1; i < dp.length; i++) {
            best = math.min(best, segmentDistance(seg.end, dp[i - 1], dp[i]));
          }
          expect(best, lessThanOrEqualTo(maxW + 0.3));
        }
        // 塗りの印。
        expect(s.svgParts.$1, nib == PaintNib.kabura ? contains('stroke-linejoin="round"') : contains('stroke-linejoin="bevel"'));
      });
    }

    test('カプラペン: 速いほど細い、筆圧があれば筆圧', () {
      final slow = NibDynamics(PaintNib.kabura, 5, pxPerUnit: 1);
      final fast = NibDynamics(PaintNib.kabura, 5, pxPerUnit: 1);
      double run(NibDynamics d, double speed) {
        var w = 0.0;
        for (var i = 0; i < 30; i++) {
          w = d.next(InkSample(Offset(i * speed * 16, 0), i * 16.0));
        }
        return w;
      }

      expect(run(fast, 3), lessThan(run(slow, 0.2) * 0.6));
      final pen = NibDynamics(PaintNib.kabura, 5);
      var light = 0.0, heavy = 0.0;
      for (var i = 0; i < 30; i++) {
        light = pen.next(InkSample(Offset(i.toDouble(), 0), i * 16.0, 0.1));
      }
      final pen2 = NibDynamics(PaintNib.kabura, 5);
      for (var i = 0; i < 30; i++) {
        heavy = pen2.next(InkSample(Offset(i.toDouble(), 0), i * 16.0, 1));
      }
      expect(light, lessThan(heavy * 0.5));
    });

    test('ブラシニブ: 進む向きで太さが変わる(筆の角度)', () {
      double along(Offset dir) {
        final d = NibDynamics(PaintNib.brush, 5);
        var w = 0.0;
        for (var i = 0; i < 40; i++) {
          w = d.next(InkSample(dir * (i * 0.5), i * 16.0));
        }
        return w;
      }

      // 筆の向き(45°)に沿って動くと細く、直角に動くと太い。
      expect(along(Offset.fromDirection(math.pi / 4)), lessThan(along(Offset.fromDirection(-math.pi / 4)) * 0.85));
    });
  });

  group('切る消しゴム', () {
    test('ミリペンを途中で切る: 2 本に分かれ、切り口は消しゴムの円の外(丸い端の分)', () {
      final s = draw(line(const Offset(20, 100), const Offset(280, 100), 80));
      final e = EraseSession([s])..apply(const Offset(150, 100), 10);
      final out = e.finish()!;
      expect(out, hasLength(2));
      final a = out[0] as PaintStroke, b = out[1] as PaintStroke;
      expect(a.points.first, const Offset(20, 100));
      expect(b.points.last, const Offset(280, 100));
      // 切り口 = 半径 10 + 太さの半分 2.5。
      expect(a.points.last.dx, closeTo(150 - 12.5, 0.2));
      expect(b.points.first.dx, closeTo(150 + 12.5, 0.2));
      expect(a.nib, PaintNib.mili);
      expect(a.svgParts.$1, contains('stroke-linecap="round"'));
    });

    test('カプラペンを切る: 切り口だけ短く細って丸まり、元の入り・抜きはそのまま', () {
      final s = draw(line(const Offset(20, 100), const Offset(280, 100), 120), nib: PaintNib.kabura, size: 6);
      final mid = s.widths.reduce(math.max);
      final e = EraseSession([s])..apply(const Offset(150, 100), 8);
      final out = e.finish()!.cast<PaintStroke>();
      expect(out, hasLength(2));
      final left = out[0], right = out[1];
      // 元の端(入り・抜き)は細いまま。
      expect(left.widths.first, closeTo(s.widths.first, 0.15));
      expect(right.widths.last, closeTo(s.widths.last, 0.15));
      // 切り口は 70% まで細り(切り落としたままの太さではない)、丸い蓋で閉じる(尖らない)。
      expect(left.widths.last, inInclusiveRange(mid * 0.6, mid * 0.8));
      expect(right.widths.first, inInclusiveRange(mid * 0.6, mid * 0.8));
      final n = left.points.length;
      final cap = left.segments[n]; // 左の側の n−1 区間の次
      expect((cap.pts[0] - left.segments[n - 1].end).distance, closeTo(4 / 3 * left.widths.last / 2, 0.3)); // 蓋の腕 = 4/3·r(半円)
      // 切り口の近くで細りが始まる(1 つ手前の節は切り口より太い)。
      expect(left.widths[left.widths.length - 2], greaterThan(left.widths.last));
      // 輪郭は作り直されて閉じている。
      expect(left.segments.last.cmd, 'Z');
      // 曲がった線を切っても、残った線の形は元の線の上(簡略化の許し 0.35 + 丸め)。
      final wavy = draw([for (var i = 0; i <= 100; i++) Offset(30 + i * 2.4, 200 + 40 * math.sin(i / 12))]);
      final cut = (EraseSession([wavy])..apply(wavy.dense.$1[wavy.dense.$1.length ~/ 2], 6)).finish()!.cast<PaintStroke>();
      expect(cut, hasLength(2));
      for (final piece in cut) {
        for (final p in piece.dense.$1) {
          var best = double.infinity;
          final (dp, _) = wavy.dense;
          for (var i = 1; i < dp.length; i++) {
            best = math.min(best, segmentDistance(p, dp[i - 1], dp[i]));
          }
          expect(best, lessThan(0.9));
        }
      }
    });

    test('なぞりで何度切っても、途中の線は細かい点のまま(誤差が溜まらない)。全部なぞれば消える', () {
      final s = draw(line(const Offset(20, 100), const Offset(120, 100), 40), nib: PaintNib.brush);
      final e = EraseSession([s]);
      for (var x = 60.0; x <= 80; x += 2) {
        e.apply(Offset(x, 100), 4);
      }
      final out = e.finish()!.cast<PaintStroke>();
      expect(out, hasLength(2));
      expect(out[0].points.last.dx, lessThan(60));
      expect(out[1].points.first.dx, greaterThan(80));
      final all = EraseSession([s]);
      for (var x = 10.0; x <= 130; x += 3) {
        all.apply(Offset(x, 100), 6);
      }
      expect(all.finish(), isEmpty);
    });

    test('線ごと消す / 当たらなければ null / 塗りは線に触れなかったときだけ消える / 前の版の折れ線も切れる', () {
      final a = draw(line(const Offset(20, 100), const Offset(280, 100), 30));
      final b = draw(line(const Offset(20, 300), const Offset(280, 300), 30));
      expect((EraseSession([a, b], whole: true)..apply(const Offset(150, 102), 4)).finish(), [b]);
      expect((EraseSession([a, b])..apply(const Offset(150, 200), 4)).finish(), isNull);
      final fill = autoFill(square(const Rect.fromLTRB(50, 50, 250, 250)), vb, const Offset(150, 150), red).fill!;
      final items = [fill, ...square(const Rect.fromLTRB(50, 50, 250, 250))];
      // 塗りの上の線を消しても塗りは残る。
      final e1 = EraseSession(items)..apply(const Offset(150, 50), 4);
      expect(e1.finish()!.whereType<PaintFill>(), hasLength(1));
      // 線に触れずに塗りの中をなぞると塗りが消える。
      final e2 = EraseSession(items)..apply(const Offset(150, 150), 4);
      expect(e2.finish()!.whereType<PaintFill>(), isEmpty);
      // 前の版の線(折れ線)も切れて、折れ線のまま。
      final old = decodeSvg('<svg viewBox="0 0 300 400"><path d="M10 10L100 100 190 10" fill="none" stroke="#000" stroke-width="4"/></svg>', vb).single as PaintStroke;
      expect(old.curve, isFalse);
      final pieces = (EraseSession([old])..apply(const Offset(100, 100), 5)).finish()!.cast<PaintStroke>();
      expect(pieces, hasLength(2));
      expect(pieces.every((p) => !p.curve && p.points.length == 2), isTrue);
    });
  });

  group('投げ輪', () {
    test('半分以上が輪の中の線を選び、動かす / 拡大 / 回す / 複製 / 色を変える', () {
      final inside = draw(line(const Offset(60, 60), const Offset(140, 60), 30));
      final half = draw(line(const Offset(60, 120), const Offset(260, 120), 30)); // 輪の中は 4 割
      final outside = draw(line(const Offset(60, 300), const Offset(140, 300), 30));
      final items = <PaintItem>[inside, half, outside];
      final poly = [const Offset(40, 40), const Offset(160, 40), const Offset(160, 140), const Offset(40, 140)];
      final sel = lassoSelect(items, poly);
      expect(sel, {inside});
      expect(lassoSelect(items, [const Offset(40, 40), const Offset(41, 40), const Offset(41, 41)]), isEmpty);

      var (next, picked) = transformSelection(items, sel, Affine.translate(const Offset(10, 20)));
      expect((next[0] as PaintStroke).points, [const Offset(70, 80), const Offset(150, 80)]);
      expect(next.sublist(1), [half, outside]);
      (next, picked) = transformSelection(items, sel, Affine.around(const Offset(100, 60), scale: 2));
      final scaled = next[0] as PaintStroke;
      expect(scaled.points, [const Offset(20, 60), const Offset(180, 60)]);
      expect(scaled.widths.first, 10);
      (next, picked) = transformSelection(items, sel, Affine.around(const Offset(100, 60), angle: math.pi / 2));
      expect((next[0] as PaintStroke).points, [const Offset(100, 20), const Offset(100, 100)]);
      (next, picked) = duplicateSelection(items, sel);
      expect(next, hasLength(4));
      expect((picked.single as PaintStroke).points.first, const Offset(72, 72));
      (next, picked) = recolorSelection(items, sel, red);
      expect((next[0] as PaintStroke).color, red);
      expect(picked.single, same(next[0]));
    });
  });

  group('オート塗りつぶし', () {
    test('閉じた形の中: 線の下まで潜る塗り 1 つ(輪 1 本)', () {
      final r = autoFill(square(const Rect.fromLTRB(50, 50, 250, 250)), vb, const Offset(150, 150), red);
      final f = r.fill!;
      expect(f.contours, hasLength(1));
      expect(f.color, red);
      final b = f.bounds;
      // 線の中心(50 / 250)近くまで広がる(白い筋を残さない)。
      expect(b.left, inInclusiveRange(48, 52));
      expect(b.right, inInclusiveRange(248, 252));
      expect(f.path.contains(const Offset(150, 150)), isTrue);
      expect(f.path.contains(const Offset(150, 300)), isFalse);
      // 小さい: 四角は数個の節。
      expect(f.contours.single.length, lessThan(20));
    });

    test('閉じていない → 漏れる、線の上 → だめ、小さなすき間は閉じたものとみなす', () {
      final open = square(const Rect.fromLTRB(50, 50, 250, 250)).sublist(0, 3);
      expect(autoFill(open, vb, const Offset(150, 150), red).failure, FillFailure.leak);
      expect(autoFill(square(const Rect.fromLTRB(50, 50, 250, 250)), vb, const Offset(150, 50), red).failure, FillFailure.onLine);
      // 上の辺に 2 単位の切れ目。
      final gap = [
        draw(line(const Offset(50, 50), const Offset(149, 50), 30), size: 2),
        draw(line(const Offset(151, 50), const Offset(250, 50), 30), size: 2),
        ...square(const Rect.fromLTRB(50, 50, 250, 250)).sublist(1),
      ];
      expect(autoFill(gap, vb, const Offset(150, 150), red).fill, isNotNull);
    });

    test('ドーナツ: 内側の閉じた形は穴(向きが逆)、中に描いた線の下は穴にしない', () {
      final outer = draw(arc(const Offset(150, 200), 100, 0, 2 * math.pi, 120), size: 3);
      final inner = draw(arc(const Offset(150, 200), 40, 0, 2 * math.pi, 80), size: 3);
      final scribble = draw(line(const Offset(70, 200), const Offset(90, 200), 10), size: 3);
      final f = autoFill([outer, inner, scribble], vb, const Offset(150, 120), red).fill!;
      expect(f.contours, hasLength(2));
      expect(signedArea(f.contours[0]).sign, isNot(signedArea(f.contours[1]).sign));
      expect(f.path.contains(const Offset(150, 200)), isFalse); // 穴
      expect(f.path.contains(const Offset(150, 130)), isTrue);
      expect(f.path.contains(const Offset(80, 200)), isTrue); // 線の下も塗る
    });
  });

  group('SVG', () {
    List<PaintItem> sample() {
      final items = <PaintItem>[
        ...square(const Rect.fromLTRB(40, 40, 140, 140)),
        draw([for (var i = 0; i <= 80; i++) Offset(30 + i * 3.0, 250 + 40 * math.sin(i / 10))]),
        draw([for (var i = 0; i <= 80; i++) Offset(30 + i * 3.0, 320 + 30 * math.cos(i / 9))], nib: PaintNib.kabura, color: red),
        draw([for (var i = 0; i <= 60; i++) Offset(180 + i * 1.5, 60 + i * 2.0)], nib: PaintNib.brush, size: 4),
        draw([const Offset(200, 200)]),
        draw([const Offset(220, 200)], nib: PaintNib.kabura),
      ];
      final fill = autoFill(items, vb, const Offset(90, 90), const Color(0xFFFDD835)).fill!;
      return [fill, ...items];
    }

    test('書き出し → 読み込み → 書き出しで同じ文字列。どれも描き直せるもののまま', () {
      final items = sample();
      final svg = encodeSvg(vb, items);
      final back = decodeSvg(svg, vb);
      expect(back.map((i) => i.runtimeType), items.map((i) => i.runtimeType));
      expect(encodeSvg(vb, back), svg);
      for (var i = 0; i < items.length; i++) {
        final a = items[i], b = back[i];
        if (a is PaintStroke && b is PaintStroke) {
          expect(b.nib, a.nib);
          expect(b.color, a.color);
          expect(b.points, a.points);
          for (var k = 0; k < a.widths.length; k++) {
            expect(b.widths[k], closeTo(a.widths[k], 0.15));
          }
        }
        if (a is PaintFill && b is PaintFill) expect(b.contours, a.contours);
      }
      // 読み直したものを切っても、輪郭を作り直せる。
      final kab = back.whereType<PaintStroke>().firstWhere((s) => s.nib == PaintNib.kabura && s.points.length > 2);
      final cut = (EraseSession([kab])..apply(kab.points[kab.points.length ~/ 2], 5)).finish()!;
      expect(cut, hasLength(2));
    });

    test('許可リストの要素・属性だけ、SvgLite で読める、小さい', () {
      final svg = encodeSvg(vb, sample());
      final tags = RegExp(r'<(/?)([a-zA-Z]+)').allMatches(svg).map((m) => m[2]).toSet();
      expect(tags.difference({'svg', 'g', 'path'}), isEmpty);
      final attrs = RegExp(r'\s([a-zA-Z:-]+)="').allMatches(svg).map((m) => m[1]).toSet();
      expect(attrs.difference({'xmlns', 'viewBox', 'd', 'fill', 'stroke', 'stroke-width', 'stroke-linecap', 'stroke-linejoin'}), isEmpty);
      final doc = SvgLite.parse(svg)!;
      expect(doc.shapes, hasLength(sample().length));
      // まとめた g の描き方は子に受け継がれる。
      expect(doc.shapes.where((s) => s.stroke != null && s.fill == null && s.strokeCap == StrokeCap.round), hasLength(6));
      // 数は小数 1 桁まで。
      expect(RegExp(r'\d\.\d\d').hasMatch(svg), isFalse);
      expect(svg.length, lessThan(6000));
    });

    test('大きさ: 曲がりくねった長い線 32 本で 16 KiB 未満、前の版(整数の折れ線)と同じくらい', () {
      final rnd = math.Random(3);
      final items = <PaintItem>[];
      final old = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400">');
      for (var k = 0; k < 32; k++) {
        final c = Offset(40 + rnd.nextDouble() * 220, 40 + rnd.nextDouble() * 320);
        final r = 10 + rnd.nextDouble() * 40;
        final a0 = rnd.nextDouble() * math.pi * 2;
        final pts = [for (var i = 0; i <= 90; i++) c + Offset.fromDirection(a0 + i / 30, r * (1 + 0.3 * math.sin(i / 7)))];
        items.add(draw(pts, nib: PaintNib.values[k % 3], color: k.isEven ? ink : red));
        // 前の版: RDP(1)の整数の折れ線 + 線ごとの描き方。
        final o = [for (final i in rdpIndices(pts, 1)) '${pts[i].dx.round()} ${pts[i].dy.round()}'];
        old.write('<path d="M${o.first}L${o.skip(1).join(' ')}" fill="none" stroke="#212121" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>');
      }
      old.write('</svg>');
      final svg = encodeSvg(vb, items);
      final mili = encodeSvg(vb, [for (final i in items.cast<PaintStroke>()) if (i.nib == PaintNib.mili) i]).length;
      // 13 KB 前後(ミリペンだけなら前の版の 1.6 倍ほど: 0.1 単位と曲線の制御点の分。輪郭の線は両側を書くのでその倍)。
      expect(svg.length, lessThan(16 * 1024));
      expect(mili, lessThan(old.length / 32 * 11 * 2));
      expect(encodeSvg(vb, decodeSvg(svg, vb)), svg);
    });

    test('前の版の SVG(M / L の線)と、よその形の読み込み', () {
      const old = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400">'
          '<path d="M10 20L30 40 50 60" fill="none" stroke="#e53935" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>'
          '<path d="M100 100L100 100" fill="none" stroke="#212121" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
          '<path d="M0 0C10 0 20 30 40 40" fill="none" stroke="#000" stroke-width="3" stroke-linecap="round"/>'
          '<path d="M0 0L10 0 10 10Z" fill="#1e88e5" stroke-linejoin="round"/>'
          '<circle cx="250" cy="350" r="20" fill="#1e88e5"/>'
          '</svg>';
      final items = decodeSvg(old, vb);
      expect(items, hasLength(5));
      final a = items[0] as PaintStroke;
      expect(a.curve, isFalse);
      expect(a.points, [const Offset(10, 20), const Offset(30, 40), const Offset(50, 60)]);
      expect(a.color, red);
      expect((items[1] as PaintStroke).points, [const Offset(100, 100)]); // 点は 1 点に
      // よその曲線(節に戻して作り直しても合わない)/ 印はあるが輪郭の形でない塗り / 円 は動かない形。
      expect(items[2], isA<PaintShape>());
      expect(items[3], isA<PaintShape>());
      expect(items[4], isA<PaintShape>());
      final svg = encodeSvg(vb, items);
      expect(svg, contains('<circle cx="250" cy="350" r="20" fill="#1e88e5"/>'));
      expect(encodeSvg(vb, decodeSvg(svg, vb)), svg);
      // 動かない形も投げ輪で回せる(自前の区間に直る)。
      final moved = items[4].transformed(Affine.around(const Offset(250, 350), angle: 1));
      expect(moved, isA<PaintPath>());
      expect(moved.bounds.center.dx, closeTo(250, 0.2));
      expect(encodeSvg(vb, [moved]), contains('fill="#1e88e5"'));
    });

    test('違う viewBox の SVG は収めてから照合する(緩く)', () {
      final items = sample();
      final svg = encodeSvg(vb, items);
      final half = decodeSvg(svg.replaceFirst('viewBox="0 0 300 400"', 'viewBox="0 0 600 800"'), vb);
      // 半分に縮めても(0.1 の格子から外れても)、線と塗りは描き直せるものとして読める。
      expect(half.whereType<PaintShape>(), isEmpty);
      expect(half.map((i) => i.runtimeType), items.map((i) => i.runtimeType));
      final k = half.whereType<PaintStroke>().firstWhere((s) => s.nib == PaintNib.kabura && s.points.length > 2);
      expect(k.offsets, isNull); // 太さから作り直す
    });
  });
}
