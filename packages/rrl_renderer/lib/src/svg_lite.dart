import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 許可リストで消毒した SVG(契約 v0.22、rasq-client D-465 / rasq-central S-106)。
///
/// ページ型の落書き(slots.md §2.13 の `media.editor.open {format: "svg"}`)が返す SVG と、RRL の `Image.p.src` の
/// `data:image/svg+xml` を描くための**小さな部分集合**。外部のパッケージ(xml / flutter_svg)は使わず、ここで字句を読む。
///
/// - 残す要素は `svg` / `g` / `path` / `polyline` / `polygon` / `line` / `rect` / `circle` / `ellipse` だけ。ほかの要素
///   (`script` / `style` / `foreignObject` / `image` / `use` / `a` / `defs` / `text` …)は**中身ごと**捨てる。
///   コメント / CDATA / 処理命令 / DOCTYPE は読み飛ばす。入れ子の `svg` は `g` と同じに扱う(座標系は作らない)。
/// - 残す属性は形と描き方([_allowedAttrs])だけ。`href` / `on*` / `style` / `transform` / `class` / `id` は捨てる。
///   色は `#RGB` / `#RRGGBB` / `none` / 色の名前([_namedColors])。読めない値(`url(...)` / `currentColor` / `rgb()` …)は
///   **その属性が無いもの**として扱う(親から受け継ぐ。根なら SVG の既定 = `fill` は黒、`stroke` は無し)。
/// - `g` の描き方(`fill` / `stroke` / 太さ / 端 / 角 / 各不透明度)は子へ受け継ぎ、`opacity` は掛け合わせて、形 1 つずつに
///   平らにする([SvgLite.shapes] は文書の順)。重なった子の `g` 単位の不透明度は形ごとの近似になる。
/// - `path` の `d` は `M L H V C S Q T Z`(小文字の相対も、数字だけの繰り返しも)。円弧 `A` は描かず、終点へ移る
///   (書き戻すときは `M 終点`)。おかしな字が来たら、そこまでで止める(SVG の規則どおり)。
/// - 上限(契約): 入力 **64 KiB**([maxBytes]、超えたら null)、残す要素 **4,000 個**([maxElements])、`d` / `points` の数
///   **合計 40,000 個**([maxNumbers])。要素と数は、超えたところで読むのをやめ、それまでに読んだ分を残す。
@immutable
class SvgLite {
  const SvgLite({required this.viewBox, required this.shapes});

  /// 入力の大きさの上限(バイト、UTF-8)。
  static const maxBytes = 64 * 1024;

  /// 残す要素の数の上限(`g` も数える。根の `svg` は数えない)。
  static const maxElements = 4000;

  /// `d` / `points` の数の合計の上限。
  static const maxNumbers = 40000;

  /// `viewBox`。無ければ根の `width` / `height`、それも無ければ形の外接矩形(形も無ければ 300×150)。
  final Rect viewBox;

  /// 描く形(文書の順、`g` の描き方は受け継いで平らにしたもの)。
  final List<SvgLiteShape> shapes;

  /// SVG の文字列を読む。根が `svg` でない / 読めない / 64 KiB を超える → null。
  static SvgLite? parse(String source) => parseWithLimits(source);

  /// [parse] の上限を小さくして試す(テスト用。64 KiB の中では数 40,000 個にはほぼ届かないため)。
  @visibleForTesting
  static SvgLite? parseWithLimits(String source, {int maxElements = maxElements, int maxNumbers = maxNumbers}) {
    if (source.length > maxBytes) return null;
    if (source.length * 3 > maxBytes && utf8.encode(source).length > maxBytes) return null;
    try {
      return _SvgParser(source, maxElements: maxElements, maxNumbers: maxNumbers).run();
    } catch (_) {
      return null;
    }
  }

  /// `data:image/svg+xml;base64,…` / `data:image/svg+xml,<URL エンコード>`(`;utf8,` / `;charset=utf-8,` も)を読む。
  /// 同じ URI は小さな LRU から同じ文書を返す(描き直しのたびに読み直さない。描き手は同じ物なら塗り直さない)。
  static SvgLite? fromDataUri(String uri) {
    final cached = _cache.remove(uri);
    if (cached != null || _cacheMisses.contains(uri)) {
      if (cached != null) _cache[uri] = cached;
      return cached;
    }
    final doc = _fromDataUri(uri);
    if (doc == null) {
      _cacheMisses.add(uri);
      if (_cacheMisses.length > _cacheSize) _cacheMisses.remove(_cacheMisses.first);
    } else {
      _cache[uri] = doc;
      if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
    }
    return doc;
  }

  static const _cacheSize = 32;
  static final _cache = <String, SvgLite>{}; // 挿入順(LRU)
  static final _cacheMisses = <String>{};

  static SvgLite? _fromDataUri(String uri) {
    if (!uri.startsWith('data:')) return null;
    final comma = uri.indexOf(',');
    if (comma < 0) return null;
    final meta = [for (final m in uri.substring(5, comma).split(';')) m.trim().toLowerCase()];
    if (meta.first != 'image/svg+xml') return null;
    final body = uri.substring(comma + 1);
    try {
      if (meta.contains('base64')) {
        // base64 は 4/3 倍。外れて大きいものは復号しない。
        if (body.length > maxBytes * 4 ~/ 3 + 1024) return null;
        final bytes = base64.decode(base64.normalize(body.replaceAll(RegExp(r'\s'), '')));
        if (bytes.length > maxBytes) return null;
        return parse(utf8.decode(bytes, allowMalformed: true));
      }
      // %XX は 1 バイトに 3 字。
      if (body.length > maxBytes * 3) return null;
      return parse(Uri.decodeComponent(body));
    } catch (_) {
      return null;
    }
  }

  /// 消毒した文書を書き戻す(`xmlns` + `viewBox` + 形。数は小数 3 桁まで、既定と同じ描き方は省く)。
  String toSvg() {
    final b = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" viewBox="')
      ..write('${svgLiteNum(viewBox.left)} ${svgLiteNum(viewBox.top)} ${svgLiteNum(viewBox.width)} ${svgLiteNum(viewBox.height)}">');
    for (final s in shapes) {
      b.write(s.toSvgElement());
    }
    b.write('</svg>');
    return b.toString();
  }
}

/// 形の種類(要素名)。
enum SvgLiteShapeKind { path, polyline, polygon, line, rect, circle, ellipse }

/// 消毒した形 1 つ(座標は viewBox の単位、描き方は `g` から受け継いだ後のもの)。
@immutable
class SvgLiteShape {
  const SvgLiteShape._({
    required this.kind,
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
    required this.strokeCap,
    required this.strokeJoin,
    required this.fillOpacity,
    required this.strokeOpacity,
    required this.opacity,
    this._segs = const [],
    this._points = const [],
    this._nums = const [],
  });

  final SvgLiteShapeKind kind;

  /// 塗り(不透明の色)。null = `none`。
  final Color? fill;

  /// 線(不透明の色)。null = `none`。
  final Color? stroke;
  final double strokeWidth;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;
  final double fillOpacity;
  final double strokeOpacity;

  /// 自分と祖先の `g` の `opacity` を掛けたもの。
  final double opacity;

  /// path: 絶対座標に直した区間(M L C Q Z)。
  final List<_Seg> _segs;

  /// polyline / polygon / line(2 点)の点。
  final List<Offset> _points;

  /// rect: x y w h rx ry / circle: cx cy r / ellipse: cx cy rx ry。
  final List<double> _nums;

  /// `dart:ui` の Path(viewBox の単位)。
  Path get path => _paths[this] ??= _buildPath();
  static final _paths = Expando<Path>('SvgLiteShape.path');

  /// 線の太さの半分まで含めた外接矩形(消しゴムの当たり判定などに)。
  Rect get bounds {
    final r = path.getBounds();
    return stroke != null && strokeWidth > 0 ? r.inflate(strokeWidth / 2) : r;
  }

  /// `M` / `L` だけの path(`H` / `V` も `L` に直したもの)、polyline、line の点の列(`M` ごとに 1 本)。
  /// 落書きの編集画面はこれを**描き直せる線**として読み込む。ほかの形は null。
  List<List<Offset>>? get polylines {
    switch (kind) {
      case SvgLiteShapeKind.polyline:
      case SvgLiteShapeKind.line:
        return _points.isEmpty ? null : [List.unmodifiable(_points)];
      case SvgLiteShapeKind.path:
        if (_segs.isEmpty || _segs.any((s) => s.cmd != 'M' && s.cmd != 'L')) return null;
        final out = <List<Offset>>[];
        for (final s in _segs) {
          if (s.cmd == 'M') out.add([]);
          out.last.add(Offset(s.v[0], s.v[1]));
        }
        return [for (final l in out) List.unmodifiable(l)];
      default:
        return null;
    }
  }

  /// [scale] 倍して [offset] だけずらした形(線の太さも [scale] 倍)。別の viewBox へ移すときに使う。
  SvgLiteShape transformed(double scale, Offset offset) {
    // rect: x y w h rx ry / circle: cx cy r / ellipse: cx cy rx ry — 先頭の 2 つが位置、残りは長さ。
    final nums = _nums.isEmpty ? _nums : [_nums[0] * scale + offset.dx, _nums[1] * scale + offset.dy, for (final v in _nums.skip(2)) v * scale];
    return SvgLiteShape._(
      kind: kind,
      fill: fill,
      stroke: stroke,
      strokeWidth: strokeWidth * scale,
      strokeCap: strokeCap,
      strokeJoin: strokeJoin,
      fillOpacity: fillOpacity,
      strokeOpacity: strokeOpacity,
      opacity: opacity,
      segs: [
        for (final s in _segs)
          _Seg(s.cmd, [for (var i = 0; i < s.v.length; i++) s.v[i] * scale + (i.isEven ? offset.dx : offset.dy)]),
      ],
      points: [for (final o in _points) o * scale + offset],
      nums: nums,
    );
  }

  /// [canvas] に描く(座標は viewBox の単位のまま。変換は呼ぶ側)。
  void paint(Canvas canvas) {
    final f = fill;
    if (f != null && kind != SvgLiteShapeKind.line) {
      canvas.drawPath(path, Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill
        ..color = f.withValues(alpha: (fillOpacity * opacity).clamp(0.0, 1.0)));
    }
    final s = stroke;
    // 太さ 0 は Flutter では「細線」になるので描かない(SVG では線無し)。
    if (s != null && strokeWidth > 0) {
      canvas.drawPath(path, Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = strokeCap
        ..strokeJoin = strokeJoin
        ..strokeMiterLimit = 4
        ..color = s.withValues(alpha: (strokeOpacity * opacity).clamp(0.0, 1.0)));
    }
  }

  Path _buildPath() {
    final path = Path();
    switch (kind) {
      case SvgLiteShapeKind.path:
        for (final s in _segs) {
          final v = s.v;
          switch (s.cmd) {
            case 'M':
              path.moveTo(v[0], v[1]);
            case 'L':
              path.lineTo(v[0], v[1]);
            case 'C':
              path.cubicTo(v[0], v[1], v[2], v[3], v[4], v[5]);
            case 'Q':
              path.quadraticBezierTo(v[0], v[1], v[2], v[3]);
            case 'Z':
              path.close();
          }
        }
      case SvgLiteShapeKind.polyline:
      case SvgLiteShapeKind.polygon:
      case SvgLiteShapeKind.line:
        if (_points.isNotEmpty) path.addPolygon(_points, kind == SvgLiteShapeKind.polygon);
      case SvgLiteShapeKind.rect:
        final r = Rect.fromLTWH(_nums[0], _nums[1], _nums[2], _nums[3]);
        final rx = _nums[4], ry = _nums[5];
        if (rx > 0 && ry > 0) {
          path.addRRect(RRect.fromRectXY(r, rx, ry));
        } else {
          path.addRect(r);
        }
      case SvgLiteShapeKind.circle:
        path.addOval(Rect.fromCircle(center: Offset(_nums[0], _nums[1]), radius: _nums[2]));
      case SvgLiteShapeKind.ellipse:
        path.addOval(Rect.fromCenter(center: Offset(_nums[0], _nums[1]), width: _nums[2] * 2, height: _nums[3] * 2));
    }
    return path;
  }

  /// 要素 1 つを書き戻す(`<path d="…" fill="none" stroke="#rrggbb" …/>`)。既定と同じ描き方は書かない。
  String toSvgElement() {
    final b = StringBuffer('<${kind.name}');
    void attr(String name, num v) => b.write(' $name="${svgLiteNum(v)}"');
    switch (kind) {
      case SvgLiteShapeKind.path:
        b.write(' d="${_pathData(_segs)}"');
      case SvgLiteShapeKind.polyline:
      case SvgLiteShapeKind.polygon:
        b.write(' points="${[for (final p in _points) '${svgLiteNum(p.dx)} ${svgLiteNum(p.dy)}'].join(' ')}"');
      case SvgLiteShapeKind.line:
        attr('x1', _points[0].dx);
        attr('y1', _points[0].dy);
        attr('x2', _points[1].dx);
        attr('y2', _points[1].dy);
      case SvgLiteShapeKind.rect:
        attr('x', _nums[0]);
        attr('y', _nums[1]);
        attr('width', _nums[2]);
        attr('height', _nums[3]);
        if (_nums[4] > 0) attr('rx', _nums[4]);
        if (_nums[5] > 0) attr('ry', _nums[5]);
      case SvgLiteShapeKind.circle:
        attr('cx', _nums[0]);
        attr('cy', _nums[1]);
        attr('r', _nums[2]);
      case SvgLiteShapeKind.ellipse:
        attr('cx', _nums[0]);
        attr('cy', _nums[1]);
        attr('rx', _nums[2]);
        attr('ry', _nums[3]);
    }
    final f = fill;
    if (f == null) {
      b.write(' fill="none"');
    } else if (f.toARGB32() != 0xFF000000) {
      b.write(' fill="${svgLiteHex(f)}"');
    }
    if (fillOpacity != 1) attr('fill-opacity', fillOpacity);
    // 線の描き方は線があるときだけ書く(無ければ意味が無い)。
    if (stroke case final s?) {
      b.write(' stroke="${svgLiteHex(s)}"');
      if (strokeOpacity != 1) attr('stroke-opacity', strokeOpacity);
      if (strokeWidth != 1) attr('stroke-width', strokeWidth);
      if (strokeCap != StrokeCap.butt) b.write(' stroke-linecap="${strokeCap.name}"');
      if (strokeJoin != StrokeJoin.miter) b.write(' stroke-linejoin="${strokeJoin.name}"');
    }
    if (opacity != 1) attr('opacity', opacity);
    b.write('/>');
    return b.toString();
  }

  static String _pathData(List<_Seg> segs) {
    final b = StringBuffer();
    String? last;
    for (final s in segs) {
      // 同じ命令が続くときは字を省く(`M10 20L30 40 50 60`)。M の後の M は省けない。
      if (s.cmd != last || s.cmd == 'M' || s.cmd == 'Z') {
        b.write(s.cmd);
      } else {
        b.write(' ');
      }
      b.write([for (final v in s.v) svgLiteNum(v)].join(' '));
      last = s.cmd;
    }
    return b.toString();
  }
}

/// SVG に書く数(整数なら小数点なし、ほかは小数 3 桁まで、末尾の 0 は落とす)。
String svgLiteNum(num v) {
  if (v.isNaN || v.isInfinite) return '0';
  if (v == v.roundToDouble() && v.abs() < 1e15) {
    final i = v.round();
    return i == 0 ? '0' : '$i';
  }
  var s = v.toStringAsFixed(3);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s == '-0' ? '0' : s;
}

/// `#rrggbb`(不透明度は捨てる)。
String svgLiteHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// path の区間 1 つ(絶対座標)。
@immutable
class _Seg {
  const _Seg(this.cmd, this.v);
  final String cmd;
  final List<double> v;
}

const _allowedElements = {'svg', 'g', 'path', 'polyline', 'polygon', 'line', 'rect', 'circle', 'ellipse'};
const _allowedAttrs = {
  'viewBox', 'width', 'height', 'd', 'points', 'x', 'y', 'cx', 'cy', 'r', 'rx', 'ry', 'x1', 'y1', 'x2', 'y2', //
  'fill', 'stroke', 'stroke-width', 'stroke-linecap', 'stroke-linejoin', 'opacity', 'fill-opacity', 'stroke-opacity',
};

/// CSS の基本の色の名前(小さな表)。
const _namedColors = {
  'black': 0x000000,
  'white': 0xFFFFFF,
  'red': 0xFF0000,
  'green': 0x008000,
  'blue': 0x0000FF,
  'yellow': 0xFFFF00,
  'orange': 0xFFA500,
  'purple': 0x800080,
  'pink': 0xFFC0CB,
  'gray': 0x808080,
  'grey': 0x808080,
  'brown': 0xA52A2A,
  'cyan': 0x00FFFF,
  'magenta': 0xFF00FF,
};

/// 色の値。`none` → (true, null)、色 → (true, 色)、読めない → (false, null)(= 属性が無いのと同じ)。
(bool, Color?) _parseColor(String raw) {
  final v = raw.trim().toLowerCase();
  if (v == 'none') return (true, null);
  if (v.startsWith('#')) {
    final hex = v.substring(1);
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(hex)) return (false, null);
    if (hex.length == 3) {
      final full = hex.split('').map((c) => '$c$c').join();
      return (true, Color(0xFF000000 | int.parse(full, radix: 16)));
    }
    if (hex.length == 6) return (true, Color(0xFF000000 | int.parse(hex, radix: 16)));
    return (false, null);
  }
  final named = _namedColors[v];
  return named == null ? (false, null) : (true, Color(0xFF000000 | named));
}

/// 長さ(数 + 任意の `px`)。% などの単位は読まない。
double? _len(String? raw) {
  if (raw == null) return null;
  var v = raw.trim();
  if (v.endsWith('px')) v = v.substring(0, v.length - 2).trimRight();
  final d = double.tryParse(v);
  return d != null && d.isFinite ? d : null;
}

/// 不透明度(数か %、0〜1 に丸める)。
double? _opacity(String? raw) {
  if (raw == null) return null;
  var v = raw.trim();
  var scale = 1.0;
  if (v.endsWith('%')) {
    v = v.substring(0, v.length - 1);
    scale = 0.01;
  }
  final d = double.tryParse(v);
  return d != null && d.isFinite ? (d * scale).clamp(0.0, 1.0) : null;
}

/// 受け継ぐ描き方。
@immutable
class _Style {
  const _Style({
    this.fill = const Color(0xFF000000),
    this.stroke,
    this.strokeWidth = 1,
    this.cap = StrokeCap.butt,
    this.join = StrokeJoin.miter,
    this.fillOpacity = 1,
    this.strokeOpacity = 1,
    this.opacity = 1,
  });
  final Color? fill;
  final Color? stroke;
  final double strokeWidth;
  final StrokeCap cap;
  final StrokeJoin join;
  final double fillOpacity;
  final double strokeOpacity;
  final double opacity;

  _Style apply(Map<String, String> a) {
    var fill = this.fill, stroke = this.stroke;
    if (a['fill'] case final v?) {
      final (ok, c) = _parseColor(v);
      if (ok) fill = c;
    }
    if (a['stroke'] case final v?) {
      final (ok, c) = _parseColor(v);
      if (ok) stroke = c;
    }
    final w = _len(a['stroke-width']);
    final cap = switch (a['stroke-linecap']?.trim()) { 'round' => StrokeCap.round, 'square' => StrokeCap.square, 'butt' => StrokeCap.butt, _ => this.cap };
    final join = switch (a['stroke-linejoin']?.trim()) { 'round' => StrokeJoin.round, 'bevel' => StrokeJoin.bevel, 'miter' => StrokeJoin.miter, _ => this.join };
    return _Style(
      fill: fill,
      stroke: stroke,
      strokeWidth: w != null && w >= 0 ? w : strokeWidth,
      cap: cap,
      join: join,
      fillOpacity: _opacity(a['fill-opacity']) ?? fillOpacity,
      strokeOpacity: _opacity(a['stroke-opacity']) ?? strokeOpacity,
      // opacity は受け継がず、祖先と掛け合わせる。
      opacity: opacity * (_opacity(a['opacity']) ?? 1),
    );
  }
}

class _Frame {
  _Frame(this.name, this.kept, this.style);
  final String name;

  /// 子を残してよいか(捨てた要素の下は全部捨てる)。
  final bool kept;
  final _Style style;
}

class _Tag {
  _Tag(this.name, this.attrs, this.selfClosing);
  final String name;
  final Map<String, String> attrs;
  final bool selfClosing;
}

/// 小さな字句読み(XML の部分集合)。
class _SvgParser {
  _SvgParser(this.src, {required this.maxElements, required this.maxNumbers});
  final String src;
  final int maxElements;
  final int maxNumbers;
  int i = 0;
  int elements = 0;
  int numbers = 0;

  /// 上限に届いた(以後は足さない)。
  bool full = false;
  final shapes = <SvgLiteShape>[];

  SvgLite? run() {
    final n = src.length;
    final stack = <_Frame>[];
    Rect? viewBox;
    var rootSeen = false;
    while (i < n && !full) {
      final lt = src.indexOf('<', i);
      if (lt < 0) break;
      i = lt;
      if (src.startsWith('<!--', i)) {
        final e = src.indexOf('-->', i + 4);
        if (e < 0) break;
        i = e + 3;
        continue;
      }
      if (src.startsWith('<![CDATA[', i)) {
        final e = src.indexOf(']]>', i + 9);
        if (e < 0) break;
        i = e + 3;
        continue;
      }
      if (src.startsWith('<?', i)) {
        final e = src.indexOf('?>', i + 2);
        if (e < 0) break;
        i = e + 2;
        continue;
      }
      if (src.startsWith('<!', i)) {
        // DOCTYPE(内部サブセット [ … ] も)は読み飛ばす。
        var depth = 0;
        var j = i + 2;
        for (; j < n; j++) {
          final c = src[j];
          if (c == '[') {
            depth++;
          } else if (c == ']') {
            depth--;
          } else if (c == '>' && depth <= 0) {
            break;
          }
        }
        if (j >= n) break;
        i = j + 1;
        continue;
      }
      if (src.startsWith('</', i)) {
        final e = src.indexOf('>', i);
        if (e < 0) break;
        final name = src.substring(i + 2, e).trim();
        i = e + 1;
        final at = stack.lastIndexWhere((f) => f.name == name);
        if (at < 0) continue;
        stack.removeRange(at, stack.length);
        if (stack.isEmpty) break; // 根が閉じた
        continue;
      }
      final tag = _readTag();
      if (tag == null) break; // 読めない → そこまで
      if (tag.name.isEmpty) continue;
      if (!rootSeen) {
        if (tag.name != 'svg') return null;
        rootSeen = true;
        viewBox = _viewBox(tag.attrs);
        final style = const _Style().apply(tag.attrs);
        if (tag.selfClosing) break;
        stack.add(_Frame('svg', true, style));
        continue;
      }
      final parent = stack.last;
      final allowed = parent.kept && _allowedElements.contains(tag.name);
      _Style style = parent.style;
      var keptChildren = false;
      if (allowed) {
        if (elements >= maxElements) {
          full = true;
          break;
        }
        elements++;
        style = parent.style.apply(tag.attrs);
        if (tag.name == 'g' || tag.name == 'svg') {
          keptChildren = true;
        } else {
          final shape = _shape(tag.name, tag.attrs, style);
          if (shape != null) shapes.add(shape);
        }
      }
      if (!tag.selfClosing) stack.add(_Frame(tag.name, keptChildren, style));
    }
    if (!rootSeen) return null;
    return SvgLite(viewBox: viewBox ?? _boundsViewBox(), shapes: List.unmodifiable(shapes));
  }

  Rect? _viewBox(Map<String, String> a) {
    if (a['viewBox'] case final v?) {
      final r = _NumReader(v);
      final nums = [for (var k = 0; k < 4; k++) r.number()];
      if (nums.every((x) => x != null) && nums[2]! > 0 && nums[3]! > 0) return Rect.fromLTWH(nums[0]!, nums[1]!, nums[2]!, nums[3]!);
    }
    final w = _len(a['width']), h = _len(a['height']);
    if (w != null && h != null && w > 0 && h > 0) return Rect.fromLTWH(0, 0, w, h);
    return null;
  }

  Rect _boundsViewBox() {
    Rect? all;
    for (final s in shapes) {
      final b = s.bounds;
      if (!b.isFinite) continue;
      all = all == null ? b : all.expandToInclude(b);
    }
    if (all == null) return const Rect.fromLTWH(0, 0, 300, 150);
    return Rect.fromLTWH(all.left, all.top, math.max(all.width, 1), math.max(all.height, 1));
  }

  bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

  /// `<` から 1 つのタグを読む。閉じない引用符などで読めなければ null。名前の無い `<` は名前が空のタグ(読み飛ばす)。
  _Tag? _readTag() {
    final n = src.length;
    var j = i + 1;
    final nameStart = j;
    while (j < n && !_isSpace(src.codeUnitAt(j)) && src[j] != '/' && src[j] != '>' && src[j] != '<') {
      j++;
    }
    final name = src.substring(nameStart, j);
    if (name.isEmpty) {
      i = i + 1;
      return _Tag('', const {}, true);
    }
    final attrs = <String, String>{};
    while (true) {
      while (j < n && _isSpace(src.codeUnitAt(j))) {
        j++;
      }
      if (j >= n) return null;
      if (src[j] == '>') {
        i = j + 1;
        return _Tag(name, attrs, false);
      }
      if (src.startsWith('/>', j)) {
        i = j + 2;
        return _Tag(name, attrs, true);
      }
      if (src[j] == '/') {
        j++;
        continue;
      }
      final aStart = j;
      while (j < n && !_isSpace(src.codeUnitAt(j)) && src[j] != '=' && src[j] != '>' && !src.startsWith('/>', j)) {
        j++;
      }
      final aName = src.substring(aStart, j);
      while (j < n && _isSpace(src.codeUnitAt(j))) {
        j++;
      }
      var value = '';
      if (j < n && src[j] == '=') {
        j++;
        while (j < n && _isSpace(src.codeUnitAt(j))) {
          j++;
        }
        if (j >= n) return null;
        final q = src[j];
        if (q == '"' || q == "'") {
          final e = src.indexOf(q, j + 1);
          if (e < 0) return null;
          value = src.substring(j + 1, e);
          j = e + 1;
        } else {
          final vStart = j;
          while (j < n && !_isSpace(src.codeUnitAt(j)) && src[j] != '>') {
            j++;
          }
          value = src.substring(vStart, j);
        }
      }
      if (_allowedAttrs.contains(aName)) attrs[aName] = _entities(value);
    }
  }

  static String _entities(String v) {
    if (!v.contains('&')) return v;
    return v.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos);'), (m) {
      final e = m[1]!;
      if (e.startsWith('#')) {
        final code = e.startsWith('#x') ? int.tryParse(e.substring(2), radix: 16) : int.tryParse(e.substring(1));
        return String.fromCharCode(code == null || code <= 0 || code > 0x10FFFF ? 0xFFFD : code);
      }
      return const {'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'"}[e]!;
    });
  }

  SvgLiteShape? _shape(String name, Map<String, String> a, _Style st) {
    double n(String k) => _len(a[k]) ?? 0;
    SvgLiteShape make(SvgLiteShapeKind kind, {List<_Seg> segs = const [], List<Offset> points = const [], List<double> nums = const []}) => SvgLiteShape._(
          kind: kind,
          fill: kind == SvgLiteShapeKind.line ? null : st.fill,
          stroke: st.stroke,
          strokeWidth: st.strokeWidth,
          strokeCap: st.cap,
          strokeJoin: st.join,
          fillOpacity: st.fillOpacity,
          strokeOpacity: st.strokeOpacity,
          opacity: st.opacity,
          segs: segs,
          points: points,
          nums: nums,
        );
    switch (name) {
      case 'path':
        final segs = _pathSegs(a['d'] ?? '');
        return segs.isEmpty ? null : make(SvgLiteShapeKind.path, segs: segs);
      case 'polyline':
      case 'polygon':
        final pts = _points(a['points'] ?? '');
        return pts.isEmpty ? null : make(name == 'polyline' ? SvgLiteShapeKind.polyline : SvgLiteShapeKind.polygon, points: pts);
      case 'line':
        return make(SvgLiteShapeKind.line, points: [Offset(n('x1'), n('y1')), Offset(n('x2'), n('y2'))]);
      case 'rect':
        final w = n('width'), h = n('height');
        if (w <= 0 || h <= 0) return null;
        var rx = _len(a['rx']), ry = _len(a['ry']);
        rx ??= ry;
        ry ??= rx;
        return make(SvgLiteShapeKind.rect, nums: [n('x'), n('y'), w, h, (rx ?? 0).clamp(0, w / 2), (ry ?? 0).clamp(0, h / 2)]);
      case 'circle':
        final r = n('r');
        return r <= 0 ? null : make(SvgLiteShapeKind.circle, nums: [n('cx'), n('cy'), r]);
      case 'ellipse':
        var rx = _len(a['rx']), ry = _len(a['ry']);
        rx ??= ry;
        ry ??= rx;
        if (rx == null || ry == null || rx <= 0 || ry <= 0) return null;
        return make(SvgLiteShapeKind.ellipse, nums: [n('cx'), n('cy'), rx, ry]);
    }
    return null;
  }

  /// 数を 1 つ使う(上限を超えたら false、以後は足さない)。
  bool _take(int count) {
    if (numbers + count > maxNumbers) {
      full = true;
      return false;
    }
    numbers += count;
    return true;
  }

  List<Offset> _points(String raw) {
    final r = _NumReader(raw);
    final out = <Offset>[];
    while (true) {
      final x = r.number();
      if (x == null) break;
      final y = r.number();
      if (y == null) break; // 奇数個なら最後を捨てる
      if (!_take(2)) break;
      out.add(Offset(x, y));
    }
    return out;
  }

  /// `d` を絶対座標の M / L / C / Q / Z に直す。おかしなところ・数の上限で止め、それまでの分を返す。
  List<_Seg> _pathSegs(String d) {
    final r = _NumReader(d);
    final segs = <_Seg>[];
    var cur = Offset.zero;
    var start = Offset.zero;
    Offset? lastCubic; // 直前の C / S の 2 つ目の制御点(S の反転用)
    Offset? lastQuad; // 直前の Q / T の制御点(T の反転用)
    String? cmd;
    const argc = {'M': 2, 'L': 2, 'H': 1, 'V': 1, 'C': 6, 'S': 4, 'Q': 4, 'T': 2, 'A': 7, 'Z': 0};
    while (!r.atEnd) {
      final c = r.peek();
      if (argc.containsKey(c.toUpperCase())) {
        cmd = c;
        r.i++;
        if (segs.isEmpty && cmd.toUpperCase() != 'M') break; // M から始まらない
        if (cmd.toUpperCase() == 'Z') {
          segs.add(const _Seg('Z', []));
          cur = start;
          lastCubic = lastQuad = null;
          continue;
        }
      } else if (cmd == null || cmd.toUpperCase() == 'Z') {
        break; // 命令の無い数 / 字
      }
      final up = cmd.toUpperCase();
      final rel = cmd != up;
      final count = argc[up]!;
      final v = <double>[];
      for (var k = 0; k < count; k++) {
        // 円弧の 4・5 個目は 0/1 の旗(区切り無しで続くことがある)。
        final x = up == 'A' && (k == 3 || k == 4) ? r.flag() : r.number();
        if (x == null) return segs;
        v.add(x);
      }
      if (!_take(count)) return segs;
      Offset pt(int k) => rel ? cur + Offset(v[k], v[k + 1]) : Offset(v[k], v[k + 1]);
      Offset? nextCubic, nextQuad;
      switch (up) {
        case 'M':
          cur = start = pt(0);
          segs.add(_Seg('M', [cur.dx, cur.dy]));
          cmd = rel ? 'l' : 'L'; // 続く数は線
        case 'L':
          cur = pt(0);
          segs.add(_Seg('L', [cur.dx, cur.dy]));
        case 'H':
          cur = Offset(rel ? cur.dx + v[0] : v[0], cur.dy);
          segs.add(_Seg('L', [cur.dx, cur.dy]));
        case 'V':
          cur = Offset(cur.dx, rel ? cur.dy + v[0] : v[0]);
          segs.add(_Seg('L', [cur.dx, cur.dy]));
        case 'C':
          final c1 = pt(0), c2 = pt(2), e = pt(4);
          segs.add(_Seg('C', [c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy]));
          nextCubic = c2;
          cur = e;
        case 'S':
          final c1 = lastCubic == null ? cur : cur * 2 - lastCubic;
          final c2 = pt(0), e = pt(2);
          segs.add(_Seg('C', [c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy]));
          nextCubic = c2;
          cur = e;
        case 'Q':
          final c1 = pt(0), e = pt(2);
          segs.add(_Seg('Q', [c1.dx, c1.dy, e.dx, e.dy]));
          nextQuad = c1;
          cur = e;
        case 'T':
          final c1 = lastQuad == null ? cur : cur * 2 - lastQuad;
          final e = pt(0);
          segs.add(_Seg('Q', [c1.dx, c1.dy, e.dx, e.dy]));
          nextQuad = c1;
          cur = e;
        case 'A':
          // 円弧は描かない。終点へ移るだけ(契約 v0.22)。
          cur = pt(5);
          segs.add(_Seg('M', [cur.dx, cur.dy]));
      }
      lastCubic = nextCubic;
      lastQuad = nextQuad;
    }
    return segs;
  }
}

/// SVG の数の並び(`,` と空白で区切る。`1.5.5` は 1.5 と .5、`1-2` は 1 と -2)。
class _NumReader {
  _NumReader(this.s);
  final String s;
  int i = 0;

  void _skip() {
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x2C) {
        i++;
      } else {
        break;
      }
    }
  }

  bool get atEnd {
    _skip();
    return i >= s.length;
  }

  String peek() {
    _skip();
    return s[i];
  }

  static bool _digit(int c) => c >= 0x30 && c <= 0x39;

  double? number() {
    _skip();
    final st = i;
    var j = i;
    final n = s.length;
    if (j < n && (s[j] == '+' || s[j] == '-')) j++;
    var digits = 0;
    while (j < n && _digit(s.codeUnitAt(j))) {
      j++;
      digits++;
    }
    if (j < n && s[j] == '.') {
      j++;
      while (j < n && _digit(s.codeUnitAt(j))) {
        j++;
        digits++;
      }
    }
    if (digits == 0) return null;
    if (j < n && (s[j] == 'e' || s[j] == 'E')) {
      var k = j + 1;
      if (k < n && (s[k] == '+' || s[k] == '-')) k++;
      if (k < n && _digit(s.codeUnitAt(k))) {
        while (k < n && _digit(s.codeUnitAt(k))) {
          k++;
        }
        j = k;
      }
    }
    final v = double.tryParse(s.substring(st, j));
    if (v == null || !v.isFinite) return null;
    i = j;
    return v;
  }

  double? flag() {
    _skip();
    if (i < s.length && (s[i] == '0' || s[i] == '1')) return s[i++] == '1' ? 1 : 0;
    return null;
  }
}

/// [SvgLite] を描く (D-465)。viewBox を箱へ [fit] で合わせ、箱の外は切る。
/// - [width] と [height] があればその大きさ。片方だけなら viewBox の縦横比でもう片方を決める。
/// - どちらも無ければ: 親の幅と高さが両方決まっていれば(Grid のマスなど)いっぱいに、高さが決まらなければ
///   (Column の中など)幅に合わせて viewBox の縦横比で高さを決める。
class SvgLiteView extends StatelessWidget {
  const SvgLiteView({super.key, required this.doc, this.width, this.height, this.fit = BoxFit.contain});

  final SvgLite doc;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final vb = doc.viewBox;
    final aspect = vb.width > 0 && vb.height > 0 ? vb.width / vb.height : 1.0;
    final paint = CustomPaint(painter: _SvgLitePainter(doc, fit), size: Size.infinite);
    final w = width, h = height;
    if (w != null && h != null) return SizedBox(width: w, height: h, child: paint);
    if (w != null) return SizedBox(width: w, height: w / aspect, child: paint);
    if (h != null) return SizedBox(width: h * aspect, height: h, child: paint);
    return LayoutBuilder(builder: (context, c) {
      if (c.hasBoundedWidth && c.hasBoundedHeight) return SizedBox(width: c.maxWidth, height: c.maxHeight, child: paint);
      if (!c.hasBoundedWidth && !c.hasBoundedHeight) return SizedBox(width: vb.width, height: vb.height, child: paint);
      return AspectRatio(aspectRatio: aspect, child: paint);
    });
  }
}

class _SvgLitePainter extends CustomPainter {
  _SvgLitePainter(this.doc, this.fit);
  final SvgLite doc;
  final BoxFit fit;

  @override
  void paint(Canvas canvas, Size size) {
    final vb = doc.viewBox;
    if (vb.isEmpty || size.isEmpty) return;
    final fitted = applyBoxFit(fit, vb.size, size);
    if (fitted.source.isEmpty || fitted.destination.isEmpty) return;
    final src = Alignment.center.inscribe(fitted.source, vb);
    final dst = Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(dst.left, dst.top)
      ..scale(dst.width / src.width, dst.height / src.height)
      ..translate(-src.left, -src.top);
    for (final s in doc.shapes) {
      s.paint(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SvgLitePainter old) => !identical(old.doc, doc) || old.fit != fit;
}
