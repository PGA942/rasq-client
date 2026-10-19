import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fow.dart';
import 'overlay_entry.dart';
import 'overlay_layer.dart';
import 'overlay_manager.dart';
import 'presets.dart';
import 'tethered_panel.dart';

/// 長押しして、指を滑らせて、離して選ぶ (D-512)。
///
/// ボタンを長押しすると、ボタンにつながったパネル([TetheredPanel]、D-474)に候補が並ぶ。**指を離さずに**上下左右へ滑らせると、
/// 指の下の候補が光り(見出しにその名前。変わるたびに軽い振動)、**離したところの候補を選ぶ**。候補の外で離すと何もしない(閉じる)。
/// 滑らせずに離すと、パネルは開いたまま(ふつうにタップで選べる。ジェスチャーが苦手でも使える)。
///
/// - 押している指の動きは、元のボタンの認識器から取らずに、**ポインターの全体の経路**(`PointerRouter.addGlobalRoute`)で見る。
///   ボタンの側(`InkResponse.onLongPress` / [RasqActionBarItem.onAnchorLongPress])は何も変えなくてよい。パネルはあとから出るので、
///   押している指はボタンが掴んだまま(パネルのバリアにもタップにもならない)。
/// - 候補の当たり判定は、各候補の矩形(GlobalKey)を指のグローバル座標で引く。格子のすき間も近い候補に当たるよう、少し広げる。
/// - モーションの抑制中は、光る候補の拡大と出てくる動きを止める。
@immutable
class HoldSlideItem<T> {
  const HoldSlideItem({required this.value, required this.label, required this.builder, this.key, this.semanticsLabel});

  final T value;

  /// 見出しに出す名前(光っている間)。
  final String label;

  /// 候補の見た目。[highlighted] = いま指の下(またはマウスの下)にある。
  final Widget Function(BuildContext context, bool highlighted) builder;

  /// 候補のキー(テストが探す口)。
  final Key? key;
  final String? semanticsLabel;
}

/// 候補の並べ方。
enum HoldSlideLayout {
  /// 縦に 1 列(アクションのバンドル: アイコン + 名前)。
  list,

  /// 格子(絵文字)。
  grid,
}

/// パネルの中身(見出し + 候補)。[showHoldSlidePicker] がボタンにつながった FOW に入れる。単体でも置ける(テスト・プレビュー)。
class HoldSlidePicker<T> extends StatefulWidget {
  const HoldSlidePicker({
    super.key,
    required this.items,
    required this.onSelect,
    required this.onCancel,
    this.anchor,
    this.title,
    this.holding = true,
    this.layout = HoldSlideLayout.list,
    this.headerBuilder,
    this.cellExtent = 44,
    this.rowExtent = 44,
    this.footer,
    this.idPrefix = 'holdSlide',
  });

  final List<HoldSlideItem<T>> items;
  final ValueChanged<T> onSelect;
  final VoidCallback onCancel;

  /// 元のボタンの矩形(グローバル座標)。指がここから出たら「滑らせた」とみなす(離したときに閉じるか、開いたままにするか)。
  final Rect? anchor;

  /// 何も光っていないときの見出し。
  final String? title;

  /// 長押しのまま開いたか(false = タップで開いた。指の動きは見ない)。
  final bool holding;
  final HoldSlideLayout layout;

  /// 見出しの中身を差し替える(絵文字は `:name:` を薄く)。[highlighted] = 光っている候補(無ければ null)。
  final Widget Function(BuildContext context, HoldSlideItem<T>? highlighted)? headerBuilder;

  /// 格子のマスの大きさ。
  final double cellExtent;

  /// 縦の列の 1 行の高さ。
  final double rowExtent;

  /// 候補の下に置くもの(「設定」への入り口など)。指で選ぶ対象ではない(タップだけ)。
  final Widget? footer;

  /// 見出しなどのキーの頭。
  final String idPrefix;

  @override
  State<HoldSlidePicker<T>> createState() => HoldSlidePickerState<T>();
}

@visibleForTesting
class HoldSlidePickerState<T> extends State<HoldSlidePicker<T>> {
  late List<GlobalKey> _keys = [for (final _ in widget.items) GlobalKey()];
  int? _highlight;
  late bool _holding = widget.holding;
  bool _moved = false;
  int? _pointer;
  bool _routed = false;
  bool _done = false;

  /// いま光っている候補(テスト用)。
  @visibleForTesting
  int? get highlighted => _highlight;

  /// まだ指で押したままか(テスト用)。
  @visibleForTesting
  bool get holding => _holding;

  @override
  void initState() {
    super.initState();
    if (_holding) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
      _routed = true;
    }
  }

  @override
  void didUpdateWidget(HoldSlidePicker<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) _keys = [for (final _ in widget.items) GlobalKey()];
  }

  @override
  void dispose() {
    _unroute();
    super.dispose();
  }

  void _unroute() {
    if (!_routed) return;
    _routed = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
  }

  /// 指の下の候補。格子のすき間 / 行の境目でも、近い候補に当たるよう少し広げる。
  int? _hit(Offset global) {
    final pad = widget.layout == HoldSlideLayout.grid ? 3.0 : 0.0;
    for (var i = 0; i < _keys.length; i++) {
      final box = _keys[i].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      // 出てくる途中は拡大の途中(Transform)なので、大きさも変換して見る(localToGlobal & size では位置だけ縮んで、ずれる)。
      final rect = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size).inflate(pad);
      if (rect.contains(global)) return i;
    }
    return null;
  }

  void _setHighlight(int? i) {
    if (i == _highlight) return;
    setState(() => _highlight = i);
    if (i != null) HapticFeedback.selectionClick();
  }

  void _onPointer(PointerEvent e) {
    if (!_holding || !mounted) return;
    if (e is! PointerMoveEvent && e is! PointerUpEvent && e is! PointerCancelEvent) return;
    // 押している指は 1 本: 最初に動いた / 離れたものを掴む。
    _pointer ??= e.pointer;
    if (e.pointer != _pointer) return;
    if (e is PointerCancelEvent) {
      _finish(null, cancel: true);
      return;
    }
    if (e is PointerMoveEvent) {
      // 滑らせた = ボタンの外へ出た / 候補に乗った。パネルが出てくる途中(ボタンの中心から広がる)でも、指の下を引く。
      final a = widget.anchor;
      final hit = _hit(e.position);
      if (!_moved && (hit != null || a == null || !a.inflate(8).contains(e.position))) _moved = true;
      _setHighlight(hit);
      return;
    }
    // 離した: 滑らせていなければ、指の下に何があっても選ばない(開いたまま。出てくる途中のパネルの候補を誤って拾わない)。
    _finish(_moved ? _hit(e.position) : null);
  }

  /// 離した: 候補の上なら選ぶ / 滑らせて外で離したら閉じる / 滑らせていなければ開いたまま(タップで選ぶ)。
  void _finish(int? hit, {bool cancel = false}) {
    _unroute();
    if (hit != null) {
      _select(hit);
      return;
    }
    if (cancel || _moved) {
      _done = true;
      widget.onCancel();
      return;
    }
    setState(() {
      _holding = false;
      _highlight = null;
    });
  }

  void _select(int i) {
    if (_done) return;
    _done = true;
    widget.onSelect(widget.items[i].value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final hi = _highlight == null || _highlight! >= widget.items.length ? null : widget.items[_highlight!];
    final header = SizedBox(
      key: ValueKey('${widget.idPrefix}.header'),
      height: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: widget.headerBuilder?.call(context, hi) ??
              Text(
                hi?.label ?? widget.title ?? '',
                key: ValueKey('${widget.idPrefix}.header.text'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: hi == null ? scheme.onSurfaceVariant : scheme.onSurface),
              ),
        ),
      ),
    );
    Widget cell(int i) {
      final item = widget.items[i];
      final on = _highlight == i;
      final child = item.builder(context, on);
      final box = AnimatedContainer(
        duration: still ? Duration.zero : const Duration(milliseconds: 90),
        decoration: BoxDecoration(color: on ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: widget.layout == HoldSlideLayout.grid
            ? SizedBox.square(
                dimension: widget.cellExtent,
                child: Center(child: AnimatedScale(scale: on && !still ? 1.25 : 1, duration: still ? Duration.zero : const Duration(milliseconds: 90), child: child)),
              )
            : SizedBox(height: widget.rowExtent, child: child),
      );
      return Semantics(
        button: true,
        selected: on,
        label: item.semanticsLabel ?? item.label,
        child: MouseRegion(
          // マウス: 乗せると見出しに名前(押したままのときは指の側で決める)。
          onEnter: (_) {
            if (!_holding) _setHighlight(i);
          },
          onExit: (_) {
            if (!_holding && _highlight == i) _setHighlight(null);
          },
          child: GestureDetector(
            key: item.key,
            behavior: HitTestBehavior.opaque,
            onTap: () => _select(i),
            child: KeyedSubtree(key: _keys[i], child: box),
          ),
        ),
      );
    }

    final body = widget.layout == HoldSlideLayout.grid
        ? Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(alignment: WrapAlignment.center, spacing: 2, runSpacing: 2, children: [for (var i = 0; i < widget.items.length; i++) cell(i)]),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < widget.items.length; i++) cell(i)]),
          );
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      Flexible(child: SingleChildScrollView(child: body)),
      ?widget.footer,
    ]);
  }
}

/// オーバーレイに出す形。
extension HoldSlidePickerPresets on OverlayManager {
  /// [anchor] のボタンにつながった、長押しして滑らせて選ぶパネル (D-512)。戻り = 選んだ候補の値(閉じたら null)。
  ///
  /// [holding] = 長押しのまま開いた(指の動きで選ぶ)。false = タップで開いた(タップで選ぶ。同じ見た目のメニュー)。
  /// 同じ [id] が開いていれば、閉じるだけ(ボタンをもう一度押すと閉じる)。
  /// FOW の層に置く([FowSpec.tether]): 子の FOW / ドロップダウンはこの上に出る。パネルはボタンのカラム([column])の中に収める。
  Future<T?> showHoldSlidePicker<T>({
    required String id,
    required Rect anchor,
    required List<HoldSlideItem<T>> items,
    String? title,
    bool holding = true,
    HoldSlideLayout layout = HoldSlideLayout.list,
    Widget? anchorChild,
    TetherSide preferredSide = TetherSide.below,
    double width = 280,
    int column = 0,
    String? ownerId,
    Widget Function(BuildContext context, HoldSlideItem<T>? highlighted)? headerBuilder,
    Widget? Function(OverlayHandle handle)? footer,
    double iconExtent = kTetherIconExtent,
    double rowExtent = 44,
    double cellExtent = 44,
  }) async {
    if (contains(id)) {
      close(id);
      return null;
    }
    final spec = FowSpec(
      anchor: anchor,
      columnIndex: column,
      resizable: false,
      showHandle: false,
      bodyMove: false,
      tether: FowTether(anchorChild: anchorChild, preferredSide: preferredSide, width: width, fitContent: true, iconExtent: iconExtent),
    );
    return showFow<T>(
      id: id,
      spec: spec,
      ownerId: ownerId,
      semanticsLabel: title,
      barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
      builder: (context, handle) => HoldSlidePicker<T>(
        key: ValueKey('$id.picker'),
        idPrefix: id,
        items: items,
        anchor: anchor,
        title: title,
        holding: holding,
        layout: layout,
        headerBuilder: headerBuilder,
        rowExtent: rowExtent,
        cellExtent: cellExtent,
        footer: footer?.call(handle),
        onSelect: (v) => handle.close(result: v),
        onCancel: handle.cancel,
      ),
    );
  }
}
