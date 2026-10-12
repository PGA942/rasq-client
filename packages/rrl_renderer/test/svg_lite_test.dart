import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

/// 許可リストの SVG (契約 v0.22、D-465)。
void main() {
  List<List<Offset>> lines(SvgLiteShape s) => s.polylines!;

  group('消毒', () {
    test('script / foreignObject / image / use / style / a / text は中身ごと捨てる', () {
      final doc = SvgLite.parse('''<?xml version="1.0"?>
<!DOCTYPE svg [ <!ENTITY x "y"> ]>
<!-- コメント <path d="M0 0L9 9"/> -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" onload="alert(1)">
  <script><![CDATA[ if (a<b) { document.write('<path d="M0 0"/>') } ]]></script>
  <style>path { fill: red }</style>
  <foreignObject><div><path d="M1 1L2 2"/></div></foreignObject>
  <image href="https://evil.invalid/x.png"/>
  <use xlink:href="#p"/>
  <a href="https://evil.invalid"><rect x="0" y="0" width="5" height="5"/></a>
  <defs><circle cx="1" cy="1" r="1"/></defs>
  <text x="1" y="1">1 &lt; 2 <tspan>x</tspan></text>
  <path id="p" class="c" d="M10 10L20 20" stroke="red" onclick="x()" style="stroke:blue" transform="scale(9)" href="#a"/>
</svg>''')!;
      expect(doc.shapes, hasLength(1));
      final s = doc.shapes.single;
      expect(s.kind, SvgLiteShapeKind.path);
      expect(s.stroke, const Color(0xFFFF0000));
      final out = doc.toSvg();
      for (final bad in ['script', 'style', 'onclick', 'onload', 'href', 'transform', 'class', 'id=', 'foreignObject', 'evil']) {
        expect(out, isNot(contains(bad)), reason: bad);
      }
    });

    test('根が svg でない / 読めない / 64 KiB を超える → null', () {
      expect(SvgLite.parse('<html><svg viewBox="0 0 1 1"/></html>'), isNull);
      expect(SvgLite.parse('ただの文字'), isNull);
      expect(SvgLite.parse(''), isNull);
      final big = '<svg viewBox="0 0 1 1">${' ' * SvgLite.maxBytes}</svg>';
      expect(SvgLite.parse(big), isNull);
      // 途中で切れていても、根まで読めていれば読めた分は残す。
      final cut = SvgLite.parse('<svg viewBox="0 0 10 10"><path d="M0 0L1 1"/><path d="M0 0')!;
      expect(cut.shapes, hasLength(1));
    });

    test('url() / currentColor / rgb() は無いのと同じ(親か既定)', () {
      final doc = SvgLite.parse('<svg viewBox="0 0 10 10">'
          '<rect width="1" height="1" fill="url(#g)"/>'
          '<rect width="1" height="1" fill="currentColor" stroke="rgb(1,2,3)"/>'
          '<g fill="#00f"><rect width="1" height="1" fill="url(https://evil.invalid/x)"/></g>'
          '</svg>')!;
      expect(doc.shapes[0].fill, const Color(0xFF000000));
      expect(doc.shapes[1].fill, const Color(0xFF000000));
      expect(doc.shapes[1].stroke, isNull);
      expect(doc.shapes[2].fill, const Color(0xFF0000FF));
      expect(doc.toSvg(), isNot(contains('url')));
    });
  });

  group('色', () {
    test('#RGB / #RRGGBB / none / 名前', () {
      Color? fillOf(String v) => SvgLite.parse('<svg viewBox="0 0 1 1"><rect width="1" height="1" fill="$v"/></svg>')!.shapes.single.fill;
      expect(fillOf('#f80'), const Color(0xFFFF8800));
      expect(fillOf('#12AbEf'), const Color(0xFF12ABEF));
      expect(fillOf('none'), isNull);
      expect(fillOf(' Orange '), const Color(0xFFFFA500));
      expect(fillOf('grey'), const Color(0xFF808080));
      expect(fillOf('magenta'), const Color(0xFFFF00FF));
      expect(fillOf('#12345'), const Color(0xFF000000)); // 読めない → 既定
      expect(fillOf('chartreuse'), const Color(0xFF000000)); // 表に無い名前
    });
  });

  group('path', () {
    SvgLiteShape one(String d) => SvgLite.parse('<svg viewBox="0 0 100 100"><path d="$d" fill="none" stroke="#000"/></svg>')!.shapes.single;

    test('相対 + 数だけの繰り返し(m の後は l)', () {
      final s = one('m10 10 5 0 0 5l-5 0 0-5');
      expect(lines(s), [
        [const Offset(10, 10), const Offset(15, 10), const Offset(15, 15), const Offset(10, 15), const Offset(10, 10)],
      ]);
      expect(s.toSvgElement(), contains('d="M10 10L15 10 15 15 10 15 10 10"'));
    });

    test('H / V は L に直す、M ごとに別の線', () {
      final s = one('M0 0H10V10M20 20h5v5');
      expect(lines(s), [
        [Offset.zero, const Offset(10, 0), const Offset(10, 10)],
        [const Offset(20, 20), const Offset(25, 20), const Offset(25, 25)],
      ]);
    });

    test('Z は始点へ戻る(線としては読まない)、続く相対は始点から', () {
      final s = one('M10 10L20 10L20 20Zl5 5');
      expect(s.polylines, isNull);
      expect(s.toSvgElement(), contains('d="M10 10L20 10 20 20ZL15 15"'));
    });

    test('C / S / Q / T(反転した制御点)', () {
      final s = one('M0 0C0 10 10 10 10 0S20-10 20 0Q25 10 30 0T40 0');
      expect(s.polylines, isNull);
      // S の 1 つ目の制御点 = (10,0)*2 - (10,10) = (10,-10)、T の制御点 = (30,0)*2 - (25,10) = (35,-10)
      expect(s.toSvgElement(), contains('d="M0 0C0 10 10 10 10 0 10 -10 20 -10 20 0Q25 10 30 0 35 -10 40 0"'));
      final b = s.path.getBounds();
      expect(b.left, 0);
      expect(b.right, 40);
    });

    test('1.5.5 / 1e1 / 1-2 の数の区切り', () {
      final s = one('M1.5.5L1e1-2');
      expect(lines(s), [
        [const Offset(1.5, 0.5), const Offset(10, -2)],
      ]);
    });

    test('円弧 A は描かず終点へ移る(旗は区切り無しでも読む)', () {
      final s = one('M10 10L20 10A5 5 0 0110 30L40 40a5 5 0 1 0 10 0');
      expect(lines(s), [
        [const Offset(10, 10), const Offset(20, 10)],
        [const Offset(10, 30), const Offset(40, 40)],
        [const Offset(50, 40)],
      ]);
    });

    test('おかしな字が来たらそこまで、M で始まらなければ何も無い', () {
      expect(lines(one('M0 0L1 1L2 x3 3')), [
        [Offset.zero, const Offset(1, 1)],
      ]);
      expect(SvgLite.parse('<svg viewBox="0 0 1 1"><path d="L1 1"/></svg>')!.shapes, isEmpty);
    });
  });

  group('形と g', () {
    test('rect / circle / ellipse / line / polygon / polyline', () {
      final doc = SvgLite.parse('<svg viewBox="0 0 100 100">'
          '<rect x="1" y="2" width="10" height="20" rx="3"/>'
          '<circle cx="50" cy="50" r="5"/>'
          '<ellipse cx="50" cy="50" rx="10"/>'
          '<line x1="0" y1="0" x2="10" y2="10" stroke="red"/>'
          '<polygon points="0,0 10,0 10,10"/>'
          '<polyline points="0 0, 5 5, 10 0, 7"/>'
          '<rect width="0" height="5"/>'
          '</svg>')!;
      expect(doc.shapes.map((s) => s.kind), [
        SvgLiteShapeKind.rect, SvgLiteShapeKind.circle, SvgLiteShapeKind.ellipse, //
        SvgLiteShapeKind.line, SvgLiteShapeKind.polygon, SvgLiteShapeKind.polyline,
      ]);
      expect(doc.shapes[0].toSvgElement(), '<rect x="1" y="2" width="10" height="20" rx="3" ry="3"/>');
      expect(doc.shapes[1].path.getBounds(), const Rect.fromLTRB(45, 45, 55, 55));
      expect(doc.shapes[2].path.getBounds(), const Rect.fromLTRB(40, 40, 60, 60)); // ry は rx と同じ
      expect(doc.shapes[3].fill, isNull);
      expect(doc.shapes[5].polylines!.single, [Offset.zero, const Offset(5, 5), const Offset(10, 0)]); // 奇数個の最後は捨てる
    });

    test('g の描き方は受け継ぎ、opacity は掛け合わせる', () {
      final doc = SvgLite.parse('<svg viewBox="0 0 10 10" stroke-width="3">'
          '<g fill="none" stroke="#00ff00" stroke-linecap="round" opacity="0.5">'
          '<g opacity="50%" stroke-width="4"><path d="M0 0L1 1" opacity=".5"/></g>'
          '<path d="M0 0L2 2" stroke="blue" stroke-linejoin="bevel"/>'
          '</g>'
          '<path d="M0 0L3 3"/>'
          '</svg>')!;
      final [a, b, c] = doc.shapes;
      expect(a.fill, isNull);
      expect(a.stroke, const Color(0xFF00FF00));
      expect(a.strokeWidth, 4);
      expect(a.strokeCap, StrokeCap.round);
      expect(a.opacity, closeTo(0.125, 1e-9));
      expect(b.stroke, const Color(0xFF0000FF));
      expect(b.strokeWidth, 3);
      expect(b.strokeJoin, StrokeJoin.bevel);
      expect(b.opacity, 0.5);
      expect(c.fill, const Color(0xFF000000));
      expect(c.stroke, isNull);
      expect(c.opacity, 1);
    });

    test('viewBox → 根の width/height → 形の外接矩形', () {
      expect(SvgLite.parse('<svg viewBox="-1 -2 30 40"/>')!.viewBox, const Rect.fromLTWH(-1, -2, 30, 40));
      expect(SvgLite.parse('<svg width="30px" height="40"></svg>')!.viewBox, const Rect.fromLTWH(0, 0, 30, 40));
      expect(SvgLite.parse('<svg viewBox="0 0 0 10" width="3" height="4"></svg>')!.viewBox, const Rect.fromLTWH(0, 0, 3, 4));
      expect(SvgLite.parse('<svg><rect x="5" y="6" width="10" height="20"/></svg>')!.viewBox, const Rect.fromLTWH(5, 6, 10, 20));
      expect(SvgLite.parse('<svg></svg>')!.viewBox, const Rect.fromLTWH(0, 0, 300, 150));
    });

    test('transformed: 位置と長さと線の太さを移す', () {
      final doc = SvgLite.parse('<svg viewBox="0 0 10 10"><path d="M1 1L2 2" stroke="#000" stroke-width="2"/><circle cx="5" cy="5" r="1"/></svg>')!;
      final p = doc.shapes[0].transformed(2, const Offset(10, 0));
      expect(p.polylines, [
        [const Offset(12, 2), const Offset(14, 4)],
      ]);
      expect(p.strokeWidth, 4);
      expect(doc.shapes[1].transformed(2, const Offset(10, 0)).toSvgElement(), '<circle cx="20" cy="10" r="2"/>');
    });
  });

  group('上限', () {
    test('要素 4,000 個まで(g も数える)', () {
      final s = StringBuffer('<svg viewBox="0 0 1 1">');
      for (var i = 0; i < SvgLite.maxElements + 50; i++) {
        s.write(i.isEven ? '<g/>' : '<line/>');
      }
      s.write('</svg>');
      expect(s.length, lessThan(SvgLite.maxBytes));
      final doc = SvgLite.parse(s.toString())!;
      expect(doc.shapes, hasLength(SvgLite.maxElements ~/ 2));
    });

    test('d / points の数は合計まで(超えた区間から先は捨て、読めた分は残す)', () {
      const s = '<svg viewBox="0 0 10 10"><polyline points="0 0 1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8 9 9"/>'
          '<path d="M0 0L1 1L2 2L3 3"/><circle cx="1" cy="1" r="1"/></svg>';
      final doc = SvgLite.parseWithLimits(s, maxNumbers: 25)!;
      expect(doc.shapes, hasLength(2));
      expect(doc.shapes[0].polylines!.single, hasLength(10));
      expect(doc.shapes[1].polylines!.single, [Offset.zero, const Offset(1, 1)]); // 20 + 4 = 24、次の 2 個で 26 > 25
      expect(SvgLite.parseWithLimits(s, maxNumbers: 40)!.shapes, hasLength(3));
    });
  });

  group('data URI と書き戻し', () {
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400"><path d="M10 20L30 40 50 60" fill="none" stroke="#e53935" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/></svg>';

    test('base64 / URL エンコード / ;utf8,', () {
      final a = SvgLite.fromDataUri('data:image/svg+xml;base64,${base64.encode(utf8.encode(svg))}')!;
      final b = SvgLite.fromDataUri('data:image/svg+xml,${Uri.encodeComponent(svg)}')!;
      final c = SvgLite.fromDataUri('data:image/svg+xml;utf8,${svg.replaceAll('#', '%23')}')!;
      final d = SvgLite.fromDataUri('data:image/svg+xml;charset=utf-8;base64,${base64.encode(utf8.encode(svg)).replaceAll('=', '')}')!;
      for (final doc in [a, b, c, d]) {
        expect(doc.viewBox, const Rect.fromLTWH(0, 0, 300, 400));
        expect(doc.shapes.single.stroke, const Color(0xFFE53935));
      }
      expect(SvgLite.fromDataUri('data:image/png;base64,AAAA'), isNull);
      expect(SvgLite.fromDataUri('data:image/svg+xml;base64,!!!'), isNull);
      expect(SvgLite.fromDataUri('data:image/svg+xml,%E0%A4%A'), isNull);
      // 同じ URI は同じ文書(描き直しで読み直さない)。
      expect(identical(SvgLite.fromDataUri('data:image/svg+xml,${Uri.encodeComponent(svg)}'), b), isTrue);
    });

    test('toSvg: 落書きの出力はそのまま書き戻り、2 回目も変わらない', () {
      final doc = SvgLite.parse(svg)!;
      expect(doc.toSvg(), svg);
      final messy = SvgLite.parse('<svg viewBox="0 0 10.5 10" xmlns:x="u"><g opacity=".5" fill="#abc"><path d="m1 1 .25 .125c1 1 2 2 3 3"/></g><rect x="1" y="1" width="2" height="2" stroke="pink" stroke-width="0.333333"/></svg>')!;
      final once = messy.toSvg();
      expect(once, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10.5 10">'
          '<path d="M1 1L1.25 1.125C2.25 2.125 3.25 3.125 4.25 4.125" fill="#aabbcc" opacity="0.5"/>'
          '<rect x="1" y="1" width="2" height="2" stroke="#ffc0cb" stroke-width="0.333"/></svg>');
      expect(SvgLite.parse(once)!.toSvg(), once);
    });
  });

  testWidgets('SvgLiteView: 箱の大きさと縦横比で描く(画素の比較はしない)', (tester) async {
    final doc = SvgLite.parse('<svg viewBox="0 0 300 400"><path d="M0 0L300 400" stroke="#000" stroke-width="5"/><circle cx="150" cy="200" r="50" fill="red"/></svg>')!;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SizedBox(width: 120, height: 90, child: SvgLiteView(doc: doc, fit: BoxFit.cover))),
    ));
    expect(tester.getSize(find.byType(SvgLiteView)), const Size(120, 90));
    expect(tester.takeException(), isNull);

    // 高さが決まらない(Column の中)→ 幅に合わせて viewBox の縦横比。
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 150, child: Column(children: [SvgLiteView(doc: doc)]))),
    ));
    expect(tester.getSize(find.byType(SvgLiteView)), const Size(150, 200));

    // 片方だけ指定。
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Center(child: SvgLiteView(doc: doc, height: 80))));
    expect(tester.getSize(find.byType(SvgLiteView)), const Size(60, 80));
    expect(tester.takeException(), isNull);
  });
}
