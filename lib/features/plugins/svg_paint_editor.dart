import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../../l10n/l10n.dart';
import 'svgpaint/eraser.dart';
import 'svgpaint/fill.dart';
import 'svgpaint/geometry.dart';
import 'svgpaint/lasso.dart';
import 'svgpaint/model.dart';
import 'svgpaint/nib.dart';
import 'svgpaint/prefs.dart';
import 'svgpaint/stabilizer.dart';
import 'svgpaint/svg_io.dart';

export 'svgpaint/model.dart' show PaintNib;

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

/// ペンの太さ(viewBox の単位、`svgpaint.width.<i>`)。ミリペンはこの太さ、カプラペンは 1.5 倍、ブラシニブは 2.4 倍が一番太いところ。
const svgPaintWidths = <double>[2, 5, 10];

/// 取り消しで戻れる回数。
const _historyLimit = 100;

/// 落書きの編集画面 (D-465 / D-473、rasq-central S-106、SDK 契約 v0.22 の `media.editor.open {format: "svg"}`)。
///
/// ページ型プラグイン(slots.md §2.13 の「落書き」)が開く、ホストの SVG の描き込み画面。画面いっぱいの部品で、
/// 狭い画面は全画面、広い画面は第 3 カラム(ページの横)に置く(置き方は呼ぶ側)。**公開の API(コンストラクタの引数と
/// [SvgPaintResult])は D-465 から変えていない**(D-473 で足した引数は無い。道具の覚えは上の ProviderScope から自分で読む)。
/// - 紙は `aspect`(`"<w>:<h>"`、1〜16 の整数、既定 `"3:4"`)の縦横比で固定し、長い辺を 400 にした viewBox
///   ([svgPaintViewBox]、3:4 → 300×400)の単位で描く。
/// - 道具 (D-473、エンジンは `svgpaint/`):
///   - **ペン**: ペン先 = ミリペン(太さ一定)/ カプラペン(筆圧か速さで太さが変わり、入り・抜き)/ ブラシニブ(太く、強い入り・抜きと筆の角度)。
///     手ぶれ補正(糸で引く筆、強さ 0〜10、既定 3)→ 太さも見る RDP → 節を通るなめらかな 3 次ベジェ。
///   - **消しゴム**: 切る(線の途中で切り、切り口を丸め込む)/ 線ごと(触れた線をまるごと)。
///   - **投げ輪**: 囲んで選ぶ → ドラッグで移動、右下のつまみで拡大縮小、上のつまみで回転、削除 / 複製 / 色を変える / 解除。
///   - **塗る**: 線で閉じた形の中をタップ → 今の色で線の下に塗る(閉じていなければ短い案内を出して何もしない)。
///   - 8 色 / 3 つの太さ / 取り消し・やり直し(どの操作も)/ 全部消す。ペン先・太さ・色・消しゴム・手ぶれ補正はユーザーごとに覚える。
/// - 完了で `<svg viewBox="0 0 W H">`(許可リストの要素・属性だけ、座標は 0.1 単位、書き方は `svgpaint/svg_io.dart`)。
///   [SvgLite] で読み直すと同じ形。キャンセルは `onDone(null)`。
/// - `initialSvg` は [SvgLite] で消毒して読み、この画面が書いた線 / 塗りは描き直せるものに、前の版の `M` / `L` の線は折れ線の線に、
///   ほかの形は**動かない形**として残す(消しゴムは外接矩形で当てて丸ごと消す、線だけの形は切る消しゴムで折れ線に直して切る)。
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

/// 紙に載っている並び(静かな層: 並びが変わったときだけ塗り直す)。
class _Layer extends ChangeNotifier {
  List<PaintItem> items = const [];

  /// 上の層で描くもの(選んでいるもの)。
  Set<PaintItem> hidden = const {};
  void set(List<PaintItem> items, [Set<PaintItem>? hidden]) {
    this.items = items;
    if (hidden != null) this.hidden = hidden;
    notifyListeners();
  }
}

/// 動いている層: 描いている途中の線、消しゴム、投げ輪、選んだもの(指の動きのたびに塗り直すのはここだけ)。
class _Live extends ChangeNotifier {
  PaintStroke? stroke;
  Offset? eraser;
  double eraserRadius = 0;
  List<Offset>? lasso;
  Set<PaintItem> selection = const {};
  Affine xf = Affine.identity;
  void changed() => notifyListeners();
}

enum _Tool { pen, eraser, lasso, fill }

/// 選んだものをつかんだところ。
enum _Grab { move, scale, rotate }

class _SvgPaintEditorState extends State<SvgPaintEditor> {
  late Size _vb = svgPaintViewBox(widget.aspect);
  final _layer = _Layer();
  final _live = _Live();
  final _undo = <List<PaintItem>>[];
  final _redo = <List<PaintItem>>[];
  var _tool = _Tool.pen;
  var _prefs = const SvgPaintPrefs();
  SvgPaintPrefsStore? _store;
  bool _prefsLoaded = false;
  bool _prefsTouched = false;
  bool _showSettings = false;

  List<PaintItem> get _items => _layer.items;

  /// 紙の 1 単位あたりの画素(描くたびに LayoutBuilder が決める)。
  double _scale = 1;
  int? _pointer;

  // ペン。
  Stabilizer? _stab;
  NibDynamics? _dyn;
  final _pts = <Offset>[];
  final _ws = <double>[];
  PaintNib _liveNib = PaintNib.mili;
  Color _liveColor = svgPaintColors.first;
  double _liveSize = svgPaintWidths[1];

  // 消しゴム。
  EraseSession? _erase;
  Offset? _lastEraser;

  // 投げ輪。
  _Grab? _grab;
  Offset _grabStart = Offset.zero;
  Offset _grabCenter = Offset.zero;

  // 塗る。
  Offset? _fillDown;

  String? _toast;
  Timer? _toastTimer;

  Set<PaintItem> get _selection => _live.selection;

  @override
  void initState() {
    super.initState();
    _layer.items = decodeSvg(widget.initialSvg, _vb);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefsLoaded) return;
    _prefsLoaded = true;
    final store = _store = SvgPaintPrefsStore.of(context);
    if (store == null) return;
    store.load(sizes: svgPaintWidths.length, colors: svgPaintColors.length).then((p) {
      if (!mounted || p == null || _prefsTouched) return;
      setState(() => _prefs = p);
    });
  }

  @override
  void didUpdateWidget(SvgPaintEditor old) {
    super.didUpdateWidget(old);
    if (old.aspect != widget.aspect) _vb = svgPaintViewBox(widget.aspect);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _layer.dispose();
    _live.dispose();
    super.dispose();
  }

  void _setPrefs(SvgPaintPrefs p) {
    _prefsTouched = true;
    if (p == _prefs) return;
    setState(() => _prefs = p);
    _store?.save(p);
  }

  // ---- 取り消し / やり直し ------------------------------------------------

  /// 並びを変える(取り消しの段を 1 つ積む)。
  void _commit(List<PaintItem> next, {Set<PaintItem> selection = const {}}) {
    _undo.add(_items);
    if (_undo.length > _historyLimit) _undo.removeAt(0);
    _redo.clear();
    _select(selection, items: next);
  }

  void _select(Set<PaintItem> sel, {List<PaintItem>? items}) {
    _live
      ..selection = sel
      ..xf = Affine.identity
      ..changed();
    _layer.set(items ?? _items, sel);
    setState(() {});
  }

  void _undoStep() {
    if (_undo.isEmpty) return;
    _redo.add(_items);
    _select(const {}, items: _undo.removeLast());
  }

  void _redoStep() {
    if (_redo.isEmpty) return;
    _undo.add(_items);
    _select(const {}, items: _redo.removeLast());
  }

  void _clear() {
    if (_items.isEmpty) return;
    _commit(const []);
  }

  // ---- 指 / ペン ---------------------------------------------------------

  Offset _toVb(Offset local) => Offset((local.dx / _scale).clamp(0, _vb.width), (local.dy / _scale).clamp(0, _vb.height));

  static double? _pressureOf(PointerEvent e) {
    final stylus = e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.invertedStylus;
    if (!stylus || e.pressureMax <= e.pressureMin) return null;
    return ((e.pressure - e.pressureMin) / (e.pressureMax - e.pressureMin)).clamp(0.0, 1.0);
  }

  static double _ms(PointerEvent e) => e.timeStamp.inMicroseconds / 1000;

  void _down(PointerDownEvent e) {
    if (_pointer != null) return; // 2 本目の指は使わない
    if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryButton) return;
    _pointer = e.pointer;
    final p = _toVb(e.localPosition);
    switch (_tool) {
      case _Tool.pen:
        _liveNib = _prefs.nib;
        _liveColor = svgPaintColors[_prefs.color];
        _liveSize = svgPaintWidths[_prefs.size];
        _stab = Stabilizer(Stabilizer.radiusFor(_prefs.stabilizer, _scale), p);
        _dyn = NibDynamics(_liveNib, _liveSize, pxPerUnit: _scale);
        _pts
          ..clear()
          ..add(p);
        _ws
          ..clear()
          ..add(_dyn!.next(InkSample(p, _ms(e), _pressureOf(e))));
        _updateLive();
      case _Tool.eraser:
        _erase = EraseSession(_items, whole: _prefs.wholeEraser);
        _lastEraser = null;
        _eraseAt(p);
      case _Tool.lasso:
        _lassoDown(p);
      case _Tool.fill:
        _fillDown = e.localPosition;
    }
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final p = _toVb(e.localPosition);
    switch (_tool) {
      case _Tool.pen:
        final b = _stab?.add(p);
        if (b == null || (b - _pts.last).distance < 0.35) return;
        _pts.add(b);
        _ws.add(_dyn!.next(InkSample(b, _ms(e), _pressureOf(e))));
        _updateLive();
      case _Tool.eraser:
        _eraseAt(p);
      case _Tool.lasso:
        _lassoMove(p);
      case _Tool.fill:
        break;
    }
  }

  void _up(PointerEvent e, {bool cancelled = false}) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final p = _toVb(e.localPosition);
    switch (_tool) {
      case _Tool.pen:
        if (!cancelled) {
          final b = _stab?.finish(p);
          if (b != null) {
            _pts.add(b);
            _ws.add(_dyn!.next(InkSample(b, _ms(e), _pressureOf(e))));
          }
        }
        _finishStroke(commit: !cancelled);
      case _Tool.eraser:
        _finishErase(cancelled: cancelled);
      case _Tool.lasso:
        _lassoUp(cancelled: cancelled);
      case _Tool.fill:
        final down = _fillDown;
        _fillDown = null;
        if (!cancelled && down != null && (e.localPosition - down).distance < 12) _fillAt(p);
    }
  }

  void _updateLive() {
    _live
      ..stroke = liveStroke(nib: _liveNib, color: _liveColor, size: _liveSize, points: _pts, widths: _ws)
      ..changed();
  }

  void _finishStroke({required bool commit}) {
    final had = _live.stroke != null;
    _live
      ..stroke = null
      ..changed();
    _stab = null;
    if (!commit || !had || _pts.isEmpty) return;
    final s = buildStroke(nib: _liveNib, color: _liveColor, size: _liveSize, points: List.of(_pts), widths: List.of(_ws));
    _commit([..._items, s]);
  }

  // ---- 消しゴム ----------------------------------------------------------

  double get _eraserRadius => math.max(4.0, 12 / _scale);

  /// 前の位置からの間も半径の半分ずつ当てる(速くなぞっても抜けない)。
  void _eraseAt(Offset p) {
    final session = _erase;
    if (session == null) return;
    final r = _eraserRadius;
    _live
      ..eraser = p
      ..eraserRadius = r;
    final from = _lastEraser ?? p;
    _lastEraser = p;
    final steps = math.max(1, ((p - from).distance / (r / 2)).ceil());
    final was = session.changed;
    for (var k = 1; k <= steps; k++) {
      session.apply(Offset.lerp(from, p, k / steps)!, r);
    }
    if (session.changed || was) _layer.set(session.preview);
    _live.changed();
  }

  void _finishErase({required bool cancelled}) {
    final session = _erase;
    _erase = null;
    _lastEraser = null;
    _live
      ..eraser = null
      ..changed();
    if (session == null) return;
    final next = cancelled ? null : session.finish();
    // なぞりの間は層に途中の並びを置いていたので、なぞる前に戻してから(取り消しの段はなぞる前)。
    _layer.items = session.before;
    if (next == null) {
      _layer.set(session.before);
      return;
    }
    _commit(next);
  }

  // ---- 投げ輪 ------------------------------------------------------------

  /// 選んだものの枠(今の変換を掛けた 4 隅、左上から時計回り)。
  List<Offset> get _selCorners {
    final r = selectionBounds(_selection);
    final xf = _live.xf;
    return [xf.apply(r.topLeft), xf.apply(r.topRight), xf.apply(r.bottomRight), xf.apply(r.bottomLeft)];
  }

  Offset get _rotateHandle {
    final c = _selCorners;
    final top = (c[0] + c[1]) / 2;
    final center = (c[0] + c[2]) / 2;
    return top + unit(top - center, const Offset(0, -1)) * (26 / _scale);
  }

  void _lassoDown(Offset p) {
    if (_selection.isNotEmpty) {
      final hit = 22 / _scale;
      final c = _selCorners;
      final center = (c[0] + c[2]) / 2;
      _grabStart = p;
      _grabCenter = center;
      if ((p - _rotateHandle).distance <= hit) {
        _grab = _Grab.rotate;
        return;
      }
      if ((p - c[2]).distance <= hit) {
        _grab = _Grab.scale;
        return;
      }
      // つかむ前の変換はいつも単位(離したときに確定する)なので、枠は選んだものの外接矩形。
      if (selectionBounds(_selection).inflate(8 / _scale).contains(p)) {
        _grab = _Grab.move;
        return;
      }
      _select(const {});
    }
    _grab = null;
    _live
      ..lasso = [p]
      ..changed();
  }

  void _lassoMove(Offset p) {
    final g = _grab;
    if (g != null) {
      final xf = switch (g) {
        _Grab.move => Affine.translate(p - _grabStart),
        _Grab.scale => Affine.around(_grabCenter, scale: ((p - _grabCenter).distance / math.max(1e-3, (_grabStart - _grabCenter).distance)).clamp(0.1, 10.0)),
        _Grab.rotate => Affine.around(_grabCenter, angle: (p - _grabCenter).direction - (_grabStart - _grabCenter).direction),
      };
      _live
        ..xf = xf
        ..changed();
      return;
    }
    final l = _live.lasso;
    if (l == null) return;
    if ((l.last - p).distance * _scale < 2) return;
    l.add(p);
    _live.changed();
  }

  void _lassoUp({required bool cancelled}) {
    if (_grab != null) {
      _grab = null;
      final xf = _live.xf;
      if (cancelled || xf.isIdentity) {
        _live
          ..xf = Affine.identity
          ..changed();
        return;
      }
      final (next, sel) = transformSelection(_items, _selection, xf);
      _commit(next, selection: sel);
      return;
    }
    final poly = _live.lasso;
    _live
      ..lasso = null
      ..changed();
    if (poly == null || cancelled) return;
    _select(lassoSelect(_items, poly));
  }

  void _deleteSelection() {
    if (_selection.isEmpty) return;
    _commit([
      for (final i in _items)
        if (!_selection.contains(i)) i,
    ]);
  }

  void _duplicateSelection() {
    if (_selection.isEmpty) return;
    final (next, sel) = duplicateSelection(_items, _selection);
    _commit(next, selection: sel);
  }

  void _recolorSelection(Color c) {
    if (_selection.isEmpty) return;
    final (next, sel) = recolorSelection(_items, _selection, c);
    _commit(next, selection: sel);
  }

  // ---- 塗る --------------------------------------------------------------

  void _fillAt(Offset p) {
    final color = svgPaintColors[_prefs.color];
    final r = autoFill(_items, _vb, p, color);
    final fill = r.fill;
    if (fill == null) {
      _showToast(switch (r.failure!) {
        FillFailure.leak => context.l10n.pluginsPaintFillLeak,
        FillFailure.onLine => context.l10n.pluginsPaintFillOnLine,
        FillFailure.empty => context.l10n.pluginsPaintFillEmpty,
      });
      return;
    }
    // 塗りは線の下(先頭の塗りの並びの一番上)。同じところの前の塗りは置き換える。
    final next = <PaintItem>[];
    var at = 0;
    var leading = true;
    for (final i in _items) {
      if (leading && i is! PaintFill) leading = false;
      if (i is PaintFill && _sameRegion(i, fill, p)) continue;
      next.add(i);
      if (leading) at = next.length;
    }
    next.insert(at, fill);
    _commit(next);
  }

  static bool _sameRegion(PaintFill a, PaintFill b, Offset tap) {
    if (!a.path.contains(tap)) return false;
    final ra = a.bounds, rb = b.bounds;
    return (ra.left - rb.left).abs() < 3 && (ra.top - rb.top).abs() < 3 && (ra.right - rb.right).abs() < 3 && (ra.bottom - rb.bottom).abs() < 3;
  }

  void _showToast(String text) {
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ---- 完了 --------------------------------------------------------------

  void _done() {
    if (_pointer != null) {
      _pointer = null;
      if (_tool == _Tool.pen) _finishStroke(commit: true);
      if (_tool == _Tool.eraser) _finishErase(cancelled: false);
    }
    final svg = encodeSvg(_vb, _items);
    widget.onDone(SvgPaintResult(svg: svg, width: _vb.width.round(), height: _vb.height.round()));
  }

  // ---- 画面 --------------------------------------------------------------

  void _setTool(_Tool t) {
    if (_tool == t) return;
    if (_selection.isNotEmpty) _select(const {});
    setState(() => _tool = t);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(scheme),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(child: Stack(children: [Positioned.fill(child: _canvasArea(scheme)), if (_toast != null) _toastView(scheme)])),
        Divider(height: 1, color: scheme.outlineVariant),
        _toolbar(scheme),
      ]),
    );
  }

  Widget _toastView(ColorScheme scheme) => Positioned(
        left: RasqSpacing.lg,
        right: RasqSpacing.lg,
        bottom: RasqSpacing.lg,
        child: IgnorePointer(
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Container(
                key: const ValueKey('svgpaint.toast'),
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: RasqSpacing.sm),
                decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(RasqSpacing.sm)),
                child: Text(_toast!, style: RasqTypography.caption.copyWith(color: scheme.onInverseSurface)),
              ),
            ),
          ),
        ),
      );

  Widget _header(ColorScheme scheme) => Material(
        color: scheme.surface,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: RasqSizes.headerHeight,
            child: Row(children: [
              Padding(
                padding: const EdgeInsets.only(left: RasqSpacing.xs),
                child: TextButton(key: const ValueKey('svgpaint.cancel'), onPressed: () => widget.onDone(null), child: Text(context.l10n.pluginsPaintCancel)),
              ),
              Expanded(child: Text(widget.title ?? context.l10n.pluginsPaintTitle, style: RasqTypography.title, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
              Padding(
                padding: const EdgeInsets.only(right: RasqSpacing.sm),
                child: FilledButton(key: const ValueKey('svgpaint.done'), onPressed: _done, child: Text(context.l10n.pluginsPaintDone)),
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
              label: context.l10n.pluginsPaintCanvasSemantics,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _down,
                onPointerMove: _move,
                onPointerUp: _up,
                onPointerCancel: (e) => _up(e, cancelled: true),
                child: ClipRect(
                  child: Stack(children: [
                    // 描き終えたものの層は並びが変わったときだけ塗り直す(描いている線は上の層だけ)。
                    RepaintBoundary(child: CustomPaint(painter: _LayerPainter(_layer, _vb), size: size)),
                    CustomPaint(painter: _LivePainter(_live, _vb, scheme.primary), size: size),
                  ]),
                ),
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
                _ToolButton(key: const ValueKey('svgpaint.tool.pen'), icon: Icons.draw, label: context.l10n.pluginsPaintToolPen, selected: pen, onTap: () => _setTool(_Tool.pen)),
                _ToolButton(key: const ValueKey('svgpaint.tool.eraser'), icon: Icons.auto_fix_normal, label: context.l10n.pluginsPaintToolEraser, selected: _tool == _Tool.eraser, onTap: () => _setTool(_Tool.eraser)),
                _ToolButton(key: const ValueKey('svgpaint.tool.lasso'), icon: Icons.highlight_alt, label: context.l10n.pluginsPaintToolLasso, selected: _tool == _Tool.lasso, onTap: () => _setTool(_Tool.lasso)),
                _ToolButton(key: const ValueKey('svgpaint.tool.fill'), icon: Icons.format_color_fill, label: context.l10n.pluginsPaintToolFill, selected: _tool == _Tool.fill, onTap: () => _setTool(_Tool.fill)),
                const SizedBox(width: RasqSpacing.sm),
                IconButton(key: const ValueKey('svgpaint.undo'), icon: const Icon(Icons.undo), tooltip: context.l10n.pluginsPaintUndo, onPressed: _undo.isEmpty ? null : _undoStep),
                IconButton(key: const ValueKey('svgpaint.redo'), icon: const Icon(Icons.redo), tooltip: context.l10n.pluginsPaintRedo, onPressed: _redo.isEmpty ? null : _redoStep),
                IconButton(key: const ValueKey('svgpaint.clear'), icon: const Icon(Icons.delete_sweep), tooltip: context.l10n.pluginsPaintClear, onPressed: _items.isEmpty ? null : _clear),
              ]),
            ),
            if (_showSettings && pen) _stabilizerRow(),
            const SizedBox(height: RasqSpacing.xs),
            SizedBox(height: 48, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: _contextRow(scheme))),
            const SizedBox(height: RasqSpacing.xs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var i = 0; i < svgPaintColors.length; i++)
                  _ColorButton(
                    key: ValueKey('svgpaint.color.$i'),
                    color: svgPaintColors[i],
                    selected: (pen || _tool == _Tool.fill) && _prefs.color == i,
                    onTap: () => _tapColor(i),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _tapColor(int i) {
    _setPrefs(_prefs.copyWith(color: i));
    if (_tool == _Tool.lasso && _selection.isNotEmpty) {
      _recolorSelection(svgPaintColors[i]);
      return;
    }
    if (_tool != _Tool.fill) _setTool(_Tool.pen);
  }

  Widget _stabilizerRow() => Row(children: [
        const SizedBox(width: RasqSpacing.sm),
        Text(context.l10n.pluginsPaintStabilizer, style: RasqTypography.caption),
        Expanded(
          child: Slider(
            key: const ValueKey('svgpaint.stabilizer'),
            value: _prefs.stabilizer.toDouble(),
            max: SvgPaintPrefs.maxStabilizer.toDouble(),
            divisions: SvgPaintPrefs.maxStabilizer,
            label: _prefs.stabilizer == 0 ? context.l10n.pluginsPaintStabilizerOff : '${_prefs.stabilizer}',
            onChanged: (v) => _setPrefs(_prefs.copyWith(stabilizer: v.round())),
          ),
        ),
        SizedBox(width: 28, child: Text(_prefs.stabilizer == 0 ? context.l10n.pluginsPaintStabilizerOff : '${_prefs.stabilizer}', style: RasqTypography.caption)),
      ]);

  Widget _contextRow(ColorScheme scheme) {
    switch (_tool) {
      case _Tool.pen:
        return Row(children: [
          for (final n in PaintNib.values)
            _ToolButton(
              key: ValueKey('svgpaint.nib.${n.name}'),
              icon: switch (n) {
                PaintNib.mili => Icons.create,
                PaintNib.kabura => Icons.edit,
                PaintNib.brush => Icons.brush,
              },
              label: n.label,
              selected: _prefs.nib == n,
              onTap: () => _setPrefs(_prefs.copyWith(nib: n)),
            ),
          const SizedBox(width: RasqSpacing.sm),
          for (var i = 0; i < svgPaintWidths.length; i++) _widthButton(i),
          IconButton(
            key: const ValueKey('svgpaint.settings'),
            icon: const Icon(Icons.tune),
            tooltip: context.l10n.pluginsPaintStabilizer,
            isSelected: _showSettings,
            onPressed: () => setState(() => _showSettings = !_showSettings),
          ),
        ]);
      case _Tool.eraser:
        return Row(children: [
          _ToolButton(
            key: const ValueKey('svgpaint.eraser.cut'),
            icon: Icons.content_cut,
            label: context.l10n.pluginsPaintEraserCut,
            selected: !_prefs.wholeEraser,
            onTap: () => _setPrefs(_prefs.copyWith(wholeEraser: false)),
          ),
          _ToolButton(
            key: const ValueKey('svgpaint.eraser.whole'),
            icon: Icons.layers_clear,
            label: context.l10n.pluginsPaintEraserWhole,
            selected: _prefs.wholeEraser,
            onTap: () => _setPrefs(_prefs.copyWith(wholeEraser: true)),
          ),
        ]);
      case _Tool.lasso:
        if (_selection.isEmpty) return _hint(context.l10n.pluginsPaintLassoHint);
        return Row(children: [
          _ToolButton(key: const ValueKey('svgpaint.sel.delete'), icon: Icons.delete_outline, label: context.l10n.pluginsPaintSelectionDelete, selected: false, onTap: _deleteSelection),
          _ToolButton(key: const ValueKey('svgpaint.sel.duplicate'), icon: Icons.copy_all, label: context.l10n.pluginsPaintSelectionDuplicate, selected: false, onTap: _duplicateSelection),
          _ToolButton(
            key: const ValueKey('svgpaint.sel.recolor'),
            icon: Icons.palette_outlined,
            label: context.l10n.pluginsPaintSelectionRecolor,
            selected: false,
            onTap: () => _recolorSelection(svgPaintColors[_prefs.color]),
          ),
          _ToolButton(key: const ValueKey('svgpaint.sel.deselect'), icon: Icons.deselect, label: context.l10n.pluginsPaintSelectionDeselect, selected: false, onTap: () => _select(const {})),
        ]);
      case _Tool.fill:
        return _hint(context.l10n.pluginsPaintFillHint);
    }
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
        child: Align(alignment: Alignment.centerLeft, child: Text(text, style: RasqTypography.caption)),
      );

  Widget _widthButton(int i) => _WidthButton(
        key: ValueKey('svgpaint.width.$i'),
        width: svgPaintWidths[i],
        color: svgPaintColors[_prefs.color],
        selected: _tool == _Tool.pen && _prefs.size == i,
        onTap: () {
          _setPrefs(_prefs.copyWith(size: i));
          _setTool(_Tool.pen);
        },
      );
}

/// Ramer–Douglas–Peucker の簡略化([epsilon] より近い点は落とす。両端は残す)。
List<Offset> svgPaintSimplify(List<Offset> points, double epsilon) => [for (final i in rdpIndices(points, epsilon)) points[i]];

/// 描き終えたものの層。
class _LayerPainter extends CustomPainter {
  _LayerPainter(this.layer, this.vb) : super(repaint: layer);
  final _Layer layer;
  final Size vb;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas
      ..save()
      ..scale(size.width / vb.width, size.height / vb.height);
    final hidden = layer.hidden;
    for (final item in layer.items) {
      if (hidden.isNotEmpty && hidden.contains(item)) continue;
      item.paint(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LayerPainter old) => old.layer != layer || old.vb != vb;
}

/// 動いている層。
class _LivePainter extends CustomPainter {
  _LivePainter(this.live, this.vb, this.accent) : super(repaint: live);
  final _Live live;
  final Size vb;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final k = vb.width / size.width; // 1 px の viewBox の単位
    canvas
      ..save()
      ..scale(size.width / vb.width, size.height / vb.height);
    final sel = live.selection;
    if (sel.isNotEmpty) {
      canvas
        ..save()
        ..transform(live.xf.matrix4);
      for (final i in sel) {
        i.paint(canvas);
      }
      canvas.restore();
      final r = selectionBounds(sel);
      final c = [live.xf.apply(r.topLeft), live.xf.apply(r.topRight), live.xf.apply(r.bottomRight), live.xf.apply(r.bottomLeft)];
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * k
        ..color = accent;
      canvas.drawPath(Path()..addPolygon(c, true), line);
      final top = (c[0] + c[1]) / 2, center = (c[0] + c[2]) / 2;
      final rot = top + unit(top - center, const Offset(0, -1)) * (26 * k);
      canvas
        ..drawLine(top, rot, line)
        ..drawCircle(rot, 7 * k, Paint()..color = Colors.white)
        ..drawCircle(rot, 7 * k, line)
        ..drawRect(Rect.fromCenter(center: c[2], width: 12 * k, height: 12 * k), Paint()..color = Colors.white)
        ..drawRect(Rect.fromCenter(center: c[2], width: 12 * k, height: 12 * k), line);
    }
    final s = live.stroke;
    if (s != null) s.paint(canvas);
    final lasso = live.lasso;
    if (lasso != null && lasso.length > 1) {
      final path = Path()..addPolygon(lasso, true);
      canvas
        ..drawPath(path, Paint()..color = accent.withValues(alpha: 0.08))
        ..drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * k
          ..color = accent);
    }
    final e = live.eraser;
    if (e != null) {
      canvas.drawCircle(e, live.eraserRadius, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * k
        ..color = const Color(0x99000000));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LivePainter old) => old.live != live || old.vb != vb || old.accent != accent;
}

/// ペン / 消しゴム / 投げ輪 / 塗る、ペン先、消しゴムの種類、選んだものの操作。
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
      label: context.l10n.pluginsPaintWidthSemantics(svgLiteNum(width)),
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
      label: context.l10n.pluginsPaintColorSemantics(svgLiteHex(color)),
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
