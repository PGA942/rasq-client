import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart' show rasqZstdCompress, rasqZstdDecompress;
import 'package:rasq_client/features/plugins/svgz.dart';
import 'package:rrl_renderer/rrl_renderer.dart' show SvgLite;

/// 落書きの圧縮 (D-472、契約 v0.23 の `svgz`): 編集画面の SVG → zstd + base64 → サーバー変数の値 → `data:image/svg+xml;zstd;base64,…`
/// → 展開して消毒 → 同じ形。素の SVG(古いプラグイン / 古いホスト)も今までどおり読める。
void main() {
  /// 編集画面が出す形の落書き(整数の座標の折れ線 `<path d="M…L…">` を線ごとに)。
  String drawing({int strokes = 60, int points = 24, int seed = 7}) {
    final r = math.Random(seed);
    const colors = ['#1D2939', '#E53935', '#1E88E5', '#43A047'];
    final b = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400">');
    for (var s = 0; s < strokes; s++) {
      var x = r.nextInt(300), y = r.nextInt(400);
      final pts = <String>[];
      for (var i = 0; i < points; i++) {
        x = (x + r.nextInt(21) - 10).clamp(0, 300);
        y = (y + r.nextInt(21) - 10).clamp(0, 400);
        pts.add('$x $y');
      }
      b.write('<path d="M${pts.first}L${pts.skip(1).join(' ')}" fill="none" stroke="${colors[s % colors.length]}" stroke-width="${const [2, 5, 10][s % 3]}" stroke-linecap="round" stroke-linejoin="round"/>');
    }
    b.write('</svg>');
    return b.toString();
  }

  setUpAll(installSvgzDecoder);

  test('圧縮 → サーバー変数の値 → zstd の data URI → 同じ形(サンプルの落書きの大きさ)', () {
    final svg = drawing();
    final svgz = encodeSvgz(svg, rasqZstdCompress)!;
    final plain = jsonEncode({'svg': svg, 'updatedAt': 1791000000000, 'ttl': 86400, 'name': '花子'});
    final packed = jsonEncode({'svgz': svgz, 'updatedAt': 1791000000000, 'ttl': 86400, 'name': '花子'});
    // ignore: avoid_print
    print('D-472 サンプル(60 本 × 24 点): SVG ${utf8.encode(svg).length} B → zstd ${base64.decode(svgz).length} B → base64 ${svgz.length} B / 値の JSON ${utf8.encode(plain).length} B → ${utf8.encode(packed).length} B');
    expect(utf8.encode(plain).length, greaterThan(16384), reason: '素の SVG では 16 KiB の上限を超える絵');
    expect(utf8.encode(packed).length, lessThan(16384), reason: '縮めれば置ける');
    expect(svgz.length * 2, lessThan(svg.length), reason: 'base64 にしても半分より小さい');
    expect(utf8.decode(rasqZstdDecompress(base64.decode(svgz))), svg);

    final viaZstd = SvgLite.fromDataUri('$svgzDataUriPrefix$svgz')!;
    final viaPlain = SvgLite.parse(svg)!;
    expect(viaZstd.toSvg(), viaPlain.toSvg());
    expect(viaZstd.shapes, hasLength(60));
  });

  test('互換: 素の SVG の data URI はそのまま。zstd の復号が無いホストは zstd を読まない(箱)。展開して 64 KiB を超えるものは読まない', () {
    const small = '<svg viewBox="0 0 10 10"><path d="M1 1L9 9" fill="none" stroke="#000" stroke-width="1"/></svg>';
    expect(SvgLite.fromDataUri('data:image/svg+xml;base64,${base64.encode(utf8.encode(small))}')!.shapes, hasLength(1));
    final z = encodeSvgz(small, rasqZstdCompress)!;
    final saved = SvgLite.zstdDecompress;
    SvgLite.zstdDecompress = null;
    expect(SvgLite.fromDataUri('data:image/svg+xml;zstd;base64,$z'), isNull);
    SvgLite.zstdDecompress = saved;
    expect(SvgLite.fromDataUri('data:image/svg+xml;zstd;base64,$z')!.shapes, hasLength(1), reason: '復号を入れたあとは読める(失敗を覚えていない)');
    // 展開爆弾: 縮めると小さいが、展開すると 64 KiB を超える。
    final bomb = '<svg viewBox="0 0 10 10">${'<g>' * 25000}</svg>';
    final zb = base64.encode(rasqZstdCompress(Uint8List.fromList(utf8.encode(bomb))));
    expect(zb.length, lessThan(4096));
    expect(SvgLite.fromDataUri('data:image/svg+xml;zstd;base64,$zb'), isNull);
    // zstd でないもの / base64 でないもの。
    expect(SvgLite.fromDataUri('data:image/svg+xml;zstd;base64,${base64.encode(utf8.encode(small))}'), isNull);
    expect(SvgLite.fromDataUri('data:image/svg+xml;zstd,$z'), isNull);
  });

  test('圧縮できないとき(復号器の失敗)は svgz を付けない', () {
    expect(encodeSvgz('<svg/>', (_) => throw StateError('x')), isNull);
  });
}
