import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../shell/headers.dart';
import 'discover_image_crop.dart';

/// 「囲って検索」の編集画面 (D-418)。画像の探したい部分を点線の四角(ドラッグ)か、点線でなぞった輪で囲む。
/// 2 本の指(ホイール)で拡大・移動。決定で [DiscoverEditorResult] を返す(囲まなければ selection は null = 画像全体)。閉じたら null。
@immutable
class DiscoverEditorResult {
  const DiscoverEditorResult(this.selection);
  final DiscoverSelection? selection;
}

/// 編集画面を開く。[step] は「1 / 3」のような、いくつ目かの表示。
Future<DiscoverEditorResult?> openDiscoverCircleEditor(BuildContext context, {required Uint8List image, required Size imageSize, DiscoverSelection? initial, String? step}) =>
    Navigator.of(context).push<DiscoverEditorResult>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => DiscoverCircleEditor(image: image, imageSize: imageSize, initial: initial, step: step),
    ));

class DiscoverCircleEditor extends StatefulWidget {
  const DiscoverCircleEditor({super.key, required this.image, required this.imageSize, this.initial, this.step});
  final Uint8List image;

  /// 画像の表示上の大きさ(画素)。囲みはこの座標で持つ。
  final Size imageSize;
  final DiscoverSelection? initial;
  final String? step;

  @override
  State<DiscoverCircleEditor> createState() => _DiscoverCircleEditorState();
}

class _DiscoverCircleEditorState extends State<DiscoverCircleEditor> {
  DiscoverSelectionKind _tool = DiscoverSelectionKind.rect;
  DiscoverSelection? _selection;

  /// なぞっている途中の点(画像の座標)。
  List<Offset>? _stroke;

  /// 表示の拡大と移動(画面の座標: q = p * _scale + _offset)。
  double _scale = 1;
  Offset _offset = Offset.zero;
  Size _box = Size.zero;

  /// 触れている指 / ポインタ。
  final _pointers = <int, Offset>{};

  /// 2 本の指の拡大を始めたときの状態。指が全部離れるまで描かない。
  ({Offset focal, double distance, double scale, Offset offset})? _pinch;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _selection = widget.initial;
    if (widget.initial != null) _tool = widget.initial!.kind;
  }

  Rect get _fit {
    final s = widget.imageSize;
    if (_box.isEmpty || s.isEmpty) return Rect.zero;
    final fitted = applyBoxFit(BoxFit.contain, s, _box).destination;
    return Alignment.center.inscribe(fitted, Offset.zero & _box);
  }

  double get _k => widget.imageSize.width <= 0 ? 1 : _fit.width / widget.imageSize.width;

  Offset _toScreen(Offset p) => (_fit.topLeft + p * _k) * _scale + _offset;

  Offset _toImage(Offset q) {
    final p = ((q - _offset) / _scale - _fit.topLeft) / _k;
    return Offset(p.dx.clamp(0.0, widget.imageSize.width), p.dy.clamp(0.0, widget.imageSize.height));
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1 && !_locked) {
      setState(() => _stroke = [_toImage(e.localPosition)]);
    } else if (_pointers.length == 2) {
      // 2 本目: 描きかけはやめて、拡大・移動に切り替える。
      final pts = _pointers.values.toList();
      setState(() {
        _stroke = null;
        _locked = true;
        _pinch = (focal: (pts[0] + pts[1]) / 2, distance: math.max(1, (pts[0] - pts[1]).distance), scale: _scale, offset: _offset);
      });
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    final pinch = _pinch;
    if (pinch != null && _pointers.length >= 2) {
      final pts = _pointers.values.take(2).toList();
      final focal = (pts[0] + pts[1]) / 2;
      final s = (pinch.scale * (pts[0] - pts[1]).distance / pinch.distance).clamp(1.0, 8.0);
      setState(() {
        _offset = focal - (pinch.focal - pinch.offset) * (s / pinch.scale);
        _scale = s;
      });
      return;
    }
    final stroke = _stroke;
    if (stroke == null) return;
    final p = _toImage(e.localPosition);
    setState(() {
      if (_tool == DiscoverSelectionKind.rect) {
        _stroke = [stroke.first, p];
      } else if ((p - stroke.last).distance * _k * _scale >= 2) {
        _stroke = [...stroke, p];
      }
    });
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    final stroke = _stroke;
    if (stroke != null && _pointers.isEmpty) {
      final sel = _tool == DiscoverSelectionKind.rect ? DiscoverSelection.rect(stroke.first, stroke.last) : DiscoverSelection.lasso(stroke);
      // 小さすぎる囲み(タップ)は無視して、前の囲みを残す。目安は画面で 12 ピクセル。
      final ok = sel.usable(widget.imageSize, minSide: 12 / (_k * _scale));
      setState(() {
        _stroke = null;
        if (ok) _selection = sel;
      });
    }
    if (_pointers.length < 2) _pinch = null;
    if (_pointers.isEmpty) _locked = false;
  }

  void _wheel(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final s = (_scale * math.exp(-e.scrollDelta.dy / 400)).clamp(1.0, 8.0);
    final f = e.localPosition;
    setState(() {
      _offset = f - (f - _offset) * (s / _scale);
      _scale = s;
      if (s == 1) _offset = Offset.zero;
    });
  }

  void _resetView() => setState(() {
        _scale = 1;
        _offset = Offset.zero;
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final drawing = _stroke;
    final shown = drawing != null
        ? (_tool == DiscoverSelectionKind.rect ? DiscoverSelection.rect(drawing.first, drawing.last) : DiscoverSelection.lasso(drawing))
        : _selection;
    return Scaffold(
      key: const ValueKey('discover.editor'),
      appBar: RasqPageHeader(title: widget.step == null ? '囲って検索' : '囲って検索(${widget.step})', showMore: false, onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        top: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: LayoutBuilder(builder: (context, c) {
                _box = Size(c.maxWidth, c.maxHeight);
                final fit = _fit;
                return Listener(
                  key: const ValueKey('discover.editor.canvas'),
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _down,
                  onPointerMove: _move,
                  onPointerUp: _up,
                  onPointerCancel: _up,
                  onPointerSignal: _wheel,
                  child: ClipRect(
                    child: Stack(children: [
                      Positioned.fill(
                        child: Transform(
                          transform: Matrix4.identity()
                            ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
                            ..scaleByDouble(_scale, _scale, 1, 1),
                          child: Stack(children: [
                            Positioned.fromRect(
                              rect: fit,
                              child: Image.memory(widget.image, fit: BoxFit.fill, gaplessPlayback: true, errorBuilder: (_, _, _) => Center(child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant))),
                            ),
                          ]),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            key: const ValueKey('discover.editor.selection'),
                            painter: _SelectionPainter(
                              polygon: shown == null ? const [] : [for (final p in shown.polygon) _toScreen(p)],
                              closed: drawing == null || _tool == DiscoverSelectionKind.rect,
                              color: Colors.white,
                              halo: Colors.black.withValues(alpha: 0.55),
                              shade: Colors.black.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                );
              }),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    _selection == null ? '探したい部分を囲んでください。囲まずに決定すると、画像全体で探します。2 本の指で拡大・移動できます。' : '囲んだ部分だけを切り抜いて探します。描き直すと囲みを置き換えます。',
                    key: const ValueKey('discover.editor.hint'),
                    style: caption,
                  ),
                  const SizedBox(height: RasqSpacing.xs),
                  Row(children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SegmentedButton<DiscoverSelectionKind>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: DiscoverSelectionKind.rect, icon: Icon(Icons.crop_square, key: ValueKey('discover.editor.tool.rect')), label: Text('四角')),
                            ButtonSegment(value: DiscoverSelectionKind.lasso, icon: Icon(Icons.gesture, key: ValueKey('discover.editor.tool.lasso')), label: Text('なぞる')),
                          ],
                          selected: {_tool},
                          onSelectionChanged: (s) => setState(() => _tool = s.first),
                        ),
                      ),
                    ),
                    if (_scale != 1 || _offset != Offset.zero)
                      IconButton(key: const ValueKey('discover.editor.reset'), tooltip: '元の大きさに戻す', icon: const Icon(Icons.fit_screen), onPressed: _resetView),
                    IconButton(
                      key: const ValueKey('discover.editor.clear'),
                      tooltip: '囲みを消す',
                      icon: const Icon(Icons.layers_clear_outlined),
                      onPressed: _selection == null ? null : () => setState(() => _selection = null),
                    ),
                  ]),
                  const SizedBox(height: RasqSpacing.xs),
                  FilledButton(
                    key: const ValueKey('discover.editor.done'),
                    onPressed: () => Navigator.of(context).pop(DiscoverEditorResult(_selection)),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    child: Text(_selection == null ? '決定(画像全体)' : '決定'),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 囲みを点線で描き、閉じた囲みの外を少し暗くする(画面の座標)。
class _SelectionPainter extends CustomPainter {
  _SelectionPainter({required this.polygon, required this.closed, required this.color, required this.halo, required this.shade});
  final List<Offset> polygon;
  final bool closed;
  final Color color;
  final Color halo;
  final Color shade;

  @override
  void paint(Canvas canvas, Size size) {
    if (polygon.length < 2) return;
    final path = Path()..addPolygon(polygon, closed);
    if (closed && polygon.length >= 3) {
      canvas.drawPath(Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), path), Paint()..color = shade);
    }
    _dotted(canvas, path, Paint()
      ..color = halo
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke);
    _dotted(canvas, path, Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke);
  }

  /// 丸い点を 8 ピクセルおきに並べる。
  static void _dotted(Canvas canvas, Path path, Paint paint) {
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 8) {
        canvas.drawPath(m.extractPath(d, d + 0.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter old) => old.closed != closed || old.color != color || old.shade != shade || !_samePoints(old.polygon, polygon);

  static bool _samePoints(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
