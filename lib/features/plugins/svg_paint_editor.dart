import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

/// 完了したときの結果(`page.event {type: "edited", svg, width, height}` の中身)。
@immutable
class SvgPaintResult {
  const SvgPaintResult({required this.svg, required this.width, required this.height});
  final String svg;
  final int width;
  final int height;
}

/// `aspect`(`"<w>:<h>"`、1〜16 の整数)→ viewBox の大きさ。長い辺を 400 にし、短い辺は整数に丸める。読めなければ 3:4(300×400)。
Size svgPaintViewBox(String aspect) {
  final m = RegExp(r'^\s*(\d{1,2})\s*:\s*(\d{1,2})\s*$').firstMatch(aspect);
  var w = m == null ? 3 : int.parse(m[1]!);
  var h = m == null ? 4 : int.parse(m[2]!);
  if (w < 1 || w > 16 || h < 1 || h > 16) (w, h) = (3, 4);
  const long = 400.0;
  return w >= h ? Size(long, (long * h / w).roundToDouble()) : Size((long * w / h).roundToDouble(), long);
}

/// ペンの色(`svgpaint.color.<i>`)。
const svgPaintColors = <Color>[
  Color(0xFF212121),
  Color(0xFFE53935),
  Color(0xFFFB8C00),
  Color(0xFFFDD835),
  Color(0xFF43A047),
  Color(0xFF1E88E5),
  Color(0xFF8E24AA),
  Color(0xFF6D4C41), // 白はマスの地(白)に消えるので茶
];

/// ペンの太さ(viewBox の単位、`svgpaint.width.<i>`)。
const svgPaintWidths = <double>[2, 5, 10];

/// 簡略化の許し(viewBox の単位)。
const _epsilon = 1.0;

/// 取り消しで戻れる回数。
const _historyLimit = 100;

/// 落書きの編集画面 (D-465、rasq-central S-106、SDK 契約 v0.22 の `media.editor.open {format: "svg"}`)。
///
/// ページ型プラグイン(slots.md §2.13 の「落書き」)が開く、ホストの SVG の描き込み画面。画面いっぱいの部品で、
/// 狭い画面は全画面、広い画面は第 3 カラム(ページの横)に置く(置き方は呼ぶ側)。
/// - 紙は `aspect`(`"<w>:<h>"`、1〜16 の整数、既定 `"3:4"`)の縦横比で固定し、長い辺を 400 にした viewBox
///   ([svgPaintViewBox]、3:4 → 300×400)の単位で描く。
/// - 道具はペン / 消しゴム(なぞった線を 1 本まるごと消す)/ 8 色 / 3 つの太さ / 取り消し(描く・消す・全部消すを戻す)/ 全部消す。
/// - 完了で `<svg viewBox="0 0 W H">` に線ごとの `<path>`(Ramer–Douglas–Peucker で簡略化、整数の座標、
///   `fill="none"` / `stroke` / `stroke-width` / `stroke-linecap="round"` / `stroke-linejoin="round"`)を並べて返す。
///   [SvgLite] で読み直すと同じ線に戻る。キャンセルは `onDone(null)`。
/// - `initialSvg` は [SvgLite] で消毒して読み、`M` / `L` だけの path と polyline は**描き直せる線**に(色と太さはそのまま)、
///   ほかの形は**動かない形**として残す(消しゴムは外接矩形で当てて消せる。保存するときは [SvgLiteShape.toSvgElement] で書き戻す)。
///   viewBox が違えば、紙へ縦横比を保って収める。
class SvgPaintEditor extends StatefulWidget {
  const SvgPaintEditor({super.key, this.aspect = '3:4', this.initialSvg, this.title, required this.onDone});

  final String aspect;

  /// 続きから描く SVG(SVG の文字列か `data:image/svg+xml` の URI)。
  final String? initialSvg;
  final String? title;

  /// 完了 → 結果、キャンセル → null。
  final void Function(SvgPaintResult? result) onDone;

  @override
  State<SvgPaintEditor> createState() => _SvgPaintEditorState();
}

/// 描いた線 1 本(viewBox の単位。描き終えたら簡略化した点)。
@immutable
class _Stroke {
  const _Stroke(this.points, this.color, this.width);
  final List<Offset> points;
  final Color color;
  final double width;
}

/// 紙に載っているもの: 描いた線か、読み込んだ動かない形。
@immutable
class _Item {
  const _Item.stroke(_Stroke this.stroke) : shape = null;
  const _Item.shape(SvgLiteShape this.shape) : stroke = null;
  final _Stroke? stroke;
  final SvgLiteShape? shape;
}

/// 紙の中身。描いている途中の線は通知だけで塗り直す(画面全体は組み直さない)。
class _Board extends ChangeNotifier {
  List<_Item> items = [];
  List<Offset>? live;
  Color liveColor = svgPaintColors.first;
  double liveWidth = svgPaintWidths[1];

  /// 消しゴムの位置と半径(viewBox の単位、見せるだけ)。
  Offset? eraser;
  double eraserRadius = 0;

  void changed() => notifyListeners();
}

enum _Tool { pen, eraser }

class _SvgPaintEditorState extends State<SvgPaintEditor> {
  late Size _vb = svgPaintViewBox(widget.aspect);
  final _board = _Board();
  final _history = <List<_Item>>[];
  var _tool = _Tool.pen;
  var _color = 0;
  var _width = 1;

  /// 紙の 1 単位あたりの画素(描くたびに LayoutBuilder が決める)。
  double _scale = 1;
  int? _pointer;

  /// 今の消しゴムのなぞりで、もう取り消しの段を積んだか。
  bool _erasedThisDrag = false;
  Offset? _lastEraser;

  @override
  void initState() {
    super.initState();
    _board.items = _import(widget.initialSvg);
  }

  @override
  void didUpdateWidget(SvgPaintEditor old) {
    super.didUpdateWidget(old);
    if (old.aspect != widget.aspect) _vb = svgPaintViewBox(widget.aspect);
  }

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  /// 続きの SVG を読む(消毒は SvgLite)。M/L だけの線は描き直せる線、ほかは動かない形。
  List<_Item> _import(String? source) {
    if (source == null || source.trim().isEmpty) return [];
    final doc = source.trimLeft().startsWith('data:') ? SvgLite.fromDataUri(source.trim()) : SvgLite.parse(source);
    if (doc == null) return [];
    final from = doc.viewBox;
    // 違う viewBox なら、縦横比を保って紙の真ん中へ収める。
    final s = math.min(_vb.width / from.width, _vb.height / from.height);
    final offset = Offset((_vb.width - from.width * s) / 2 - from.left * s, (_vb.height - from.height * s) / 2 - from.top * s);
    final same = s == 1 && offset == Offset.zero;
    final out = <_Item>[];
    for (final raw in doc.shapes) {
      final shape = same ? raw : raw.transformed(s, offset);
      final lines = shape.polylines;
      final stroke = shape.stroke;
      if (lines != null && shape.fill == null && stroke != null && shape.strokeWidth > 0 && shape.opacity == 1 && shape.strokeOpacity == 1) {
        for (final l in lines) {
          if (l.isNotEmpty) out.add(_Item.stroke(_Stroke(l, stroke, shape.strokeWidth)));
        }
      } else {
        out.add(_Item.shape(shape));
      }
    }
    return out;
  }

  // ---- 取り消し ----------------------------------------------------------

  void _snapshot() {
    _history.add(List.of(_board.items));
    if (_history.length > _historyLimit) _history.removeAt(0);
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() => _board.items = _history.removeLast());
    _board.changed();
  }

  void _clear() {
    if (_board.items.isEmpty) return;
    _snapshot();
    setState(() => _board.items = []);
    _board.changed();
  }

  // ---- 指 / ペン ---------------------------------------------------------

  Offset _toVb(Offset local) => Offset((local.dx / _scale).clamp(0, _vb.width), (local.dy / _scale).clamp(0, _vb.height));

  void _down(PointerDownEvent e) {
    if (_pointer != null) return; // 2 本目の指は使わない
    if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryButton) return;
    _pointer = e.pointer;
    final p = _toVb(e.localPosition);
    if (_tool == _Tool.pen) {
      _board
        ..live = [p]
        ..liveColor = svgPaintColors[_color]
        ..liveWidth = svgPaintWidths[_width];
    } else {
      _erasedThisDrag = false;
      _lastEraser = null;
      _eraseAt(p);
    }
    _board.changed();
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final p = _toVb(e.localPosition);
    if (_tool == _Tool.pen) {
      final live = _board.live;
      if (live == null) return;
      // 近すぎる点は足さない(0.5 単位)。
      if ((live.last - p).distance < 0.5) return;
      live.add(p);
    } else {
      _eraseAt(p);
    }
    _board.changed();
  }

  void _up(PointerEvent e, {bool cancelled = false}) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_tool == _Tool.pen) {
      final live = _board.live;
      _board.live = null;
      if (live != null && !cancelled) _commit(live);
    } else {
      _board.eraser = null;
      _lastEraser = null;
      if (_erasedThisDrag) setState(() {});
    }
    _board.changed();
  }

  void _commit(List<Offset> raw) {
    _snapshot();
    setState(() => _board.items = [..._board.items, _Item.stroke(_Stroke(svgPaintSimplify(raw, _epsilon), _board.liveColor, _board.liveWidth))]);
  }

  /// 消しゴム: 前の位置からの間も半径の半分ずつ当てる(速くなぞっても抜けない)。当たった線 / 形はまるごと消す。
  void _eraseAt(Offset p) {
    final r = math.max(4.0, 12 / _scale);
    _board
      ..eraser = p
      ..eraserRadius = r;
    final from = _lastEraser ?? p;
    _lastEraser = p;
    final steps = math.max(1, ((p - from).distance / (r / 2)).ceil());
    final probes = [for (var k = 1; k <= steps; k++) Offset.lerp(from, p, k / steps)!];
    final keep = [
      for (final item in _board.items)
        if (!probes.any((q) => _hits(item, q, r))) item,
    ];
    if (keep.length == _board.items.length) return;
    if (!_erasedThisDrag) {
      _snapshot();
      _erasedThisDrag = true;
    }
    _board.items = keep;
  }

  static bool _hits(_Item item, Offset q, double r) {
    final s = item.stroke;
    if (s == null) return item.shape!.bounds.inflate(r).contains(q);
    final reach = r + s.width / 2;
    final pts = s.points;
    if (pts.length == 1) return (pts.first - q).distance <= reach;
    for (var i = 1; i < pts.length; i++) {
      if (_segmentDistance(q, pts[i - 1], pts[i]) <= reach) return true;
    }
    return false;
  }

  // ---- 完了 --------------------------------------------------------------

  void _done() {
    final live = _board.live;
    if (live != null) {
      _board.live = null;
      _pointer = null;
      _commit(live);
    }
    final b = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${svgLiteNum(_vb.width)} ${svgLiteNum(_vb.height)}">');
    for (final item in _board.items) {
      final s = item.stroke;
      b.write(s == null ? item.shape!.toSvgElement() : _strokeElement(s));
    }
    b.write('</svg>');
    widget.onDone(SvgPaintResult(svg: b.toString(), width: _vb.width.round(), height: _vb.height.round()));
  }

  /// `<path d="M10 20L30 40 50 60" fill="none" stroke="#rrggbb" stroke-width="N" stroke-linecap="round" stroke-linejoin="round"/>`。
  /// 座標は整数に丸め、続く同じ点は 1 つに。1 点だけ(タップ)は `M x yL x y` の点。
  static String _strokeElement(_Stroke s) {
    final pts = <(int, int)>[];
    for (final p in s.points) {
      final q = (p.dx.round(), p.dy.round());
      if (pts.isEmpty || pts.last != q) pts.add(q);
    }
    if (pts.length == 1) pts.add(pts.first);
    final d = StringBuffer('M${pts[0].$1} ${pts[0].$2}L');
    d.write([for (final (x, y) in pts.skip(1)) '$x $y'].join(' '));
    return '<path d="$d" fill="none" stroke="${svgLiteHex(s.color)}" stroke-width="${svgLiteNum(s.width)}" stroke-linecap="round" stroke-linejoin="round"/>';
  }

  // ---- 画面 --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(scheme),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(child: _canvasArea(scheme)),
        Divider(height: 1, color: scheme.outlineVariant),
        _toolbar(scheme),
      ]),
    );
  }

  Widget _header(ColorScheme scheme) => Material(
        color: scheme.surface,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: RasqSizes.headerHeight,
            child: Row(children: [
              Padding(
                padding: const EdgeInsets.only(left: RasqSpacing.xs),
                child: TextButton(key: const ValueKey('svgpaint.cancel'), onPressed: () => widget.onDone(null), child: const Text('キャンセル')),
              ),
              Expanded(child: Text(widget.title ?? '落書き', style: RasqTypography.title, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
              Padding(
                padding: const EdgeInsets.only(right: RasqSpacing.sm),
                child: FilledButton(key: const ValueKey('svgpaint.done'), onPressed: _done, child: const Text('完了')),
              ),
            ]),
          ),
        ),
      );

  Widget _canvasArea(ColorScheme scheme) => LayoutBuilder(builder: (context, c) {
        const pad = RasqSpacing.lg;
        final availW = math.max(0.0, c.maxWidth - pad * 2), availH = math.max(0.0, c.maxHeight - pad * 2);
        _scale = math.max(0.01, math.min(availW / _vb.width, availH / _vb.height));
        final size = _vb * _scale;
        return Center(
          child: Container(
            key: const ValueKey('svgpaint.canvas'),
            width: size.width,
            height: size.height,
            // 枠は前景に描く(中の座標をずらさない)。
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]),
            foregroundDecoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant)),
            child: Semantics(
              label: '落書きの紙',
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _down,
                onPointerMove: _move,
                onPointerUp: _up,
                onPointerCancel: (e) => _up(e, cancelled: true),
                child: ClipRect(child: CustomPaint(painter: _BoardPainter(_board, _vb), size: size)),
              ),
            ),
          ),
        );
      });

  Widget _toolbar(ColorScheme scheme) {
    final pen = _tool == _Tool.pen;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: RasqSpacing.xs),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _ToolButton(key: const ValueKey('svgpaint.tool.pen'), icon: Icons.draw, label: 'ペン', selected: pen, onTap: () => setState(() => _tool = _Tool.pen)),
                _ToolButton(key: const ValueKey('svgpaint.tool.eraser'), icon: Icons.auto_fix_normal, label: '消しゴム', selected: !pen, onTap: () => setState(() => _tool = _Tool.eraser)),
                const SizedBox(width: RasqSpacing.md),
                for (var i = 0; i < svgPaintWidths.length; i++)
                  _WidthButton(
                    key: ValueKey('svgpaint.width.$i'),
                    width: svgPaintWidths[i],
                    color: svgPaintColors[_color],
                    selected: pen && _width == i,
                    onTap: () => setState(() {
                      _width = i;
                      _tool = _Tool.pen;
                    }),
                  ),
                const SizedBox(width: RasqSpacing.md),
                IconButton(key: const ValueKey('svgpaint.undo'), icon: const Icon(Icons.undo), tooltip: '取り消し', onPressed: _history.isEmpty ? null : _undo),
                IconButton(key: const ValueKey('svgpaint.clear'), icon: const Icon(Icons.delete_sweep), tooltip: '全部消す', onPressed: _board.items.isEmpty ? null : _clear),
              ]),
            ),
            const SizedBox(height: RasqSpacing.xs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var i = 0; i < svgPaintColors.length; i++)
                  _ColorButton(
                    key: ValueKey('svgpaint.color.$i'),
                    color: svgPaintColors[i],
                    selected: pen && _color == i,
                    onTap: () => setState(() {
                      _color = i;
                      _tool = _Tool.pen;
                    }),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 点から線分までの距離。
double _segmentDistance(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// Ramer–Douglas–Peucker の簡略化([epsilon] より近い点は落とす。両端は残す)。
List<Offset> svgPaintSimplify(List<Offset> points, double epsilon) {
  if (points.length < 3) return List.of(points);
  final keep = List.filled(points.length, false);
  keep[0] = keep[points.length - 1] = true;
  // 再帰の代わりに区間の山(長い線でもスタックを使い切らない)。
  final stack = <(int, int)>[(0, points.length - 1)];
  while (stack.isNotEmpty) {
    final (a, b) = stack.removeLast();
    var far = -1;
    var farDist = epsilon;
    for (var i = a + 1; i < b; i++) {
      final d = _segmentDistance(points[i], points[a], points[b]);
      if (d > farDist) {
        far = i;
        farDist = d;
      }
    }
    if (far < 0) continue;
    keep[far] = true;
    stack
      ..add((a, far))
      ..add((far, b));
  }
  return [for (var i = 0; i < points.length; i++) if (keep[i]) points[i]];
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.board, this.vb) : super(repaint: board);
  final _Board board;
  final Size vb;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas
      ..save()
      ..scale(size.width / vb.width, size.height / vb.height);
    for (final item in board.items) {
      final s = item.stroke;
      if (s == null) {
        item.shape!.paint(canvas);
      } else {
        _paintStroke(canvas, s.points, s.color, s.width, smooth: false);
      }
    }
    final live = board.live;
    if (live != null) _paintStroke(canvas, live, board.liveColor, board.liveWidth, smooth: true);
    final e = board.eraser;
    if (e != null) {
      canvas.drawCircle(e, board.eraserRadius, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * vb.width / size.width
        ..color = const Color(0x99000000));
    }
    canvas.restore();
  }

  /// 線を描く。描いている途中は中点を結ぶ 2 次曲線でなめらかに、描き終えた線は保存する形(折れ線)のまま。
  static void _paintStroke(Canvas canvas, List<Offset> pts, Color color, double width, {required bool smooth}) {
    if (pts.isEmpty) return;
    if (pts.every((p) => p == pts.first)) {
      canvas.drawCircle(pts.first, width / 2, Paint()..color = color);
      return;
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (smooth && pts.length > 2) {
      for (var i = 1; i < pts.length - 1; i++) {
        final mid = (pts[i] + pts[i + 1]) / 2;
        path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(pts.last.dx, pts.last.dy);
    } else {
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color);
  }

  @override
  bool shouldRepaint(_BoardPainter old) => old.board != board || old.vb != vb;
}

/// ペン / 消しゴム。
class _ToolButton extends StatelessWidget {
  const _ToolButton({super.key, required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(right: RasqSpacing.xs),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected ? scheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(RasqSpacing.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(RasqSpacing.sm),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: RasqSpacing.xs),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 20, color: fg),
                ExcludeSemantics(child: Text(label, style: RasqTypography.caption.copyWith(color: fg))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 太さ(その太さの点を見せる)。
class _WidthButton extends StatelessWidget {
  const _WidthButton({super.key, required this.width, required this.color, required this.selected, required this.onTap});
  final double width;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 白いペンでも見えるように、点の色は白なら輪郭の色。
    final dot = color.toARGB32() == 0xFFFFFFFF ? scheme.outline : color;
    return Semantics(
      button: true,
      selected: selected,
      label: '太さ ${svgLiteNum(width)}',
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, border: selected ? Border.all(color: scheme.primary, width: 2) : null),
          child: Container(width: 4 + width * 1.6, height: 4 + width * 1.6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        ),
      ),
    );
  }
}

/// 色。
class _ColorButton extends StatelessWidget {
  const _ColorButton({super.key, required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '色 ${svgLiteHex(color)}',
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(RasqSpacing.xs),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 3 : 1),
            ),
          ),
        ),
      ),
    );
  }
}
