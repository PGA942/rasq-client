import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'overlay_entry.dart';
import 'overlay_layer.dart';
import 'overlay_manager.dart';

/// ボタンにつながったパネル (D-474: 2026-10-18 のスケッチ)。
///
/// パネルの外形の上辺(下に開くとき。上に開くときは下辺)が、開いたボタンのところで**スプライン(3 次ベジェ)の首**で
/// 立ち上がり、ボタンを丸く包む。パネルと元のボタンが 1 つの輪郭(しずくの首)に見える。
///
/// ```
///            .-○-.        ← 元のボタン(○)を [clearance] 空けて包む
///   ________/     \________
///  | キャンセル  タイトル  OK |  ← 外形は中身から [outlineOffset] 外側
///  |  …中身…                  |
///  |          ━━              |  ← ハンドル
///   ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
/// ```
///
/// - 形は [TetherOutline](純粋な幾何。テストもここ)、置き方と描画は [TetheredPanel]。オーバーレイに出すのは
///   [TetheredPanelPresets.showTetheredPanel]。
/// - 座標はオーバーレイ(画面全体)の座標 = グローバル座標(ドロップダウンの anchor と同じ前提)。
/// - **あとで足す長押しの操作のための作り**(絵文字ボタンを長押し → つながったクイックピッカー → 指を滑らせて離すと入力):
///   [TetheredPanel] は「anchor と中身」だけで決まり、ジェスチャーを持たない。長押しの始まりで [OverlayLayer.dropdown] ではなく
///   バリアの無いエントリとして出し、元のボタンの `onLongPressMoveUpdate` のグローバル座標で中身のマスを当てる
///   (中身の各マスの矩形は GlobalKey で取れる)ようにすれば、このウィジェットはそのまま使える。[anchorChild] は首の中
///   (= 指の下)に描くので、押している間のボタンの見た目に使う。
enum TetherSide {
  /// パネルがボタンの下(スケッチのとおり首は上辺)。
  below,

  /// パネルがボタンの上(首は下辺)。画面の下のほうのバー(コンポーザーのアクションバー)から開くとき。
  above,
}

/// 外形の幾何。[rect] = 外形(輪郭の線)の矩形、[button] = 元のボタンの中心、[buttonRadius] = 元のボタンの半径。
@immutable
class TetherOutline {
  const TetherOutline({
    required this.rect,
    required this.button,
    required this.buttonRadius,
    required this.side,
    this.clearance = 3,
    this.cornerRadius = 18,
  });

  final Rect rect;
  final Offset button;
  final double buttonRadius;
  final TetherSide side;

  /// 首がボタンを包むすき間(px)。
  final double clearance;
  final double cornerRadius;

  /// 首の丸(ボタン + すき間)の半径。
  double get headRadius => buttonRadius + clearance;

  /// 首が丸に付く角度(下に開くとき、真横から 30° 下)。ここで接線が丸と揃うので、つなぎ目に角が出ない。
  static const _join = 30 * math.pi / 180;

  /// 輪郭(閉じたパス)。下に開くときの形を作り、上に開くときは上下を裏返す。
  Path path() {
    if (side == TetherSide.below) return _topNeck(rect, button);
    final flipped = _topNeck(Rect.fromLTRB(rect.left, -rect.bottom, rect.right, -rect.top), Offset(button.dx, -button.dy));
    return flipped.transform((Matrix4.identity()..scaleByDouble(1.0, -1.0, 1.0, 1.0)).storage);
  }

  /// 首が上辺にある形。
  Path _topNeck(Rect r, Offset c) {
    final a = headRadius;
    final top = r.top;
    final cosJ = math.cos(_join), sinJ = math.sin(_join);
    // 丸に付く点(左は 150°、右は 30°。y は下向き)。
    final pl = Offset(c.dx - a * cosJ, c.dy + a * sinJ);
    final pr = Offset(c.dx + a * cosJ, c.dy + a * sinJ);
    // 首の高さ(上辺から付く点まで)と、上辺で首が始まる広がり。
    final rise = math.max(0.0, top - pl.dy);
    final spread = rise + 6;
    var x0 = pl.dx - spread;
    var x1 = pr.dx + spread;
    // 角に近いときは、その側の角の丸みを詰める(はみ出すなら首を角から始める)。
    var rl = cornerRadius, rr = cornerRadius;
    if (x0 < r.left + rl) {
      x0 = math.max(x0, r.left);
      rl = math.max(0.0, x0 - r.left);
    }
    if (x1 > r.right - rr) {
      x1 = math.min(x1, r.right);
      rr = math.max(0.0, r.right - x1);
    }
    final rb = math.min(cornerRadius, r.height / 2);
    // 制御点: 上辺側は水平の接線、丸側は丸の接線(進む向き = 左は左上、右は左下)。
    final t = rise * 0.5;
    // 首の始まりが丸の付く点より外にあるとき(画面の端のボタン)は、上辺側の接線を持たせない(折り返しにしない)。
    final h = math.max(0.0, pl.dx - x0) * 0.55;
    final h1 = math.max(0.0, x1 - pr.dx) * 0.55;
    final p = Path()..moveTo(r.left, top + rl);
    if (rl > 0) p.arcToPoint(Offset(r.left + rl, top), radius: Radius.circular(rl));
    p
      ..lineTo(x0, top)
      ..cubicTo(x0 + h, top, pl.dx + sinJ * t, pl.dy + cosJ * t, pl.dx, pl.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: a), math.pi - _join, math.pi + 2 * _join, false)
      ..cubicTo(pr.dx - sinJ * t, pr.dy + cosJ * t, x1 - h1, top, x1, top)
      ..lineTo(r.right - rr, top);
    if (rr > 0) p.arcToPoint(Offset(r.right, top + rr), radius: Radius.circular(rr));
    p
      ..lineTo(r.right, r.bottom - rb)
      ..arcToPoint(Offset(r.right - rb, r.bottom), radius: Radius.circular(rb))
      ..lineTo(r.left + rb, r.bottom)
      ..arcToPoint(Offset(r.left, r.bottom - rb), radius: Radius.circular(rb))
      ..close();
    return p;
  }

  @override
  bool operator ==(Object other) =>
      other is TetherOutline && other.rect == rect && other.button == button && other.buttonRadius == buttonRadius && other.side == side && other.clearance == clearance && other.cornerRadius == cornerRadius;

  @override
  int get hashCode => Object.hash(rect, button, buttonRadius, side, clearance, cornerRadius);
}

/// [TetheredPanel] の置き場所を決める(純粋な計算。テストもここ)。
/// [area] = 置いてよい範囲(画面からキーボード / ノッチ / 余白を除いたもの)。[panelHeight] は中身 + 外形のぶん。
@visibleForTesting
({TetherSide side, double left, double maxHeight}) tetherPlacement({required Rect anchor, required Rect area, required double width, required double neckGap, required double headRadius, required TetherSide preferred, double minHeight = 200}) {
  final c = anchor.center;
  final spaceBelow = area.bottom - (c.dy + headRadius + neckGap);
  final spaceAbove = (c.dy - headRadius - neckGap) - area.top;
  final pref = preferred == TetherSide.below ? spaceBelow : spaceAbove;
  final other = preferred == TetherSide.below ? spaceAbove : spaceBelow;
  final side = pref >= minHeight || pref >= other ? preferred : (preferred == TetherSide.below ? TetherSide.above : TetherSide.below);
  final w = math.min(width, area.width);
  final left = (c.dx - w / 2).clamp(area.left, area.right - w).toDouble();
  return (side: side, left: left, maxHeight: math.max(0.0, side == TetherSide.below ? spaceBelow : spaceAbove));
}

/// ボタンにつながったパネル本体(画面いっぱいに置く)。[anchor] = 元のボタンの矩形(グローバル座標)。
class TetheredPanel extends StatelessWidget {
  const TetheredPanel({
    super.key,
    required this.anchor,
    required this.child,
    this.anchorChild,
    this.onAnchorTap,
    this.width = 320,
    this.preferredSide = TetherSide.below,
    this.outlineOffset = 6,
    this.clearance = 3,
    this.neckGap = 10,
    this.strokeWidth = 1.5,
    this.margin = 8,
    this.progress = 1,
  });

  final Rect anchor;
  final Widget child;

  /// 首の中(元のボタンの位置)に描くもの。null なら空の丸。
  final Widget? anchorChild;
  final VoidCallback? onAnchorTap;
  final double width;
  final TetherSide preferredSide;

  /// 外形の線を中身からどれだけ外に出すか(px。スケッチの「6px」)。外形と中身の間はふちの色。
  final double outlineOffset;

  /// 首がボタンを包むすき間(px。スケッチの「3px」)。
  final double clearance;

  /// ボタンの丸の下端からパネルの外形までの首の長さ。
  final double neckGap;
  final double strokeWidth;
  final double margin;

  /// 出てくる途中(0〜1)。ボタンの中心から広がる。
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final holder = _TetherHolder();
    final layout = CustomMultiChildLayout(
      delegate: _TetherDelegate(
        holder: holder,
        anchor: anchor,
        width: width,
        preferred: preferredSide,
        offset: outlineOffset,
        clearance: clearance,
        neckGap: neckGap,
        insets: EdgeInsets.fromLTRB(mq.padding.left + margin, mq.padding.top + margin, mq.padding.right + margin, math.max(mq.padding.bottom, mq.viewInsets.bottom) + margin),
      ),
      children: [
        LayoutId(
          id: _TetherSlot.paint,
          child: IgnorePointer(
            child: CustomPaint(
              painter: _TetherPainter(holder: holder, rim: scheme.surfaceContainerHighest, outline: scheme.primary.withValues(alpha: 0.7), card: scheme.surface, head: scheme.surface, shadow: Colors.black, strokeWidth: strokeWidth, offset: outlineOffset),
            ),
          ),
        ),
        LayoutId(
          id: _TetherSlot.panel,
          child: Material(type: MaterialType.transparency, child: child),
        ),
        LayoutId(
          id: _TetherSlot.head,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onAnchorTap, child: Center(child: anchorChild)),
        ),
      ],
    );
    if (progress >= 1) return layout;
    final c = anchor.center;
    final s = 0.6 + 0.4 * progress;
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Transform(
        transform: Matrix4.identity()
          ..translateByDouble(c.dx, c.dy, 0, 1)
          ..scaleByDouble(s, s, 1, 1)
          ..translateByDouble(-c.dx, -c.dy, 0, 1),
        child: layout,
      ),
    );
  }
}

enum _TetherSlot { paint, panel, head }

/// レイアウトで決まった形を、描画へ渡す入れ物(描画はレイアウトのあと)。
class _TetherHolder {
  TetherOutline? outline;
}

class _TetherDelegate extends MultiChildLayoutDelegate {
  _TetherDelegate({required this.holder, required this.anchor, required this.width, required this.preferred, required this.offset, required this.clearance, required this.neckGap, required this.insets});
  final _TetherHolder holder;
  final Rect anchor;
  final double width;
  final TetherSide preferred;
  final double offset;
  final double clearance;
  final double neckGap;
  final EdgeInsets insets;

  @override
  void performLayout(Size size) {
    final buttonRadius = math.min(anchor.width, anchor.height) / 2;
    final headRadius = buttonRadius + clearance;
    final area = insets.deflateRect(Offset.zero & size);
    final place = tetherPlacement(anchor: anchor, area: area, width: width, neckGap: neckGap, headRadius: headRadius, preferred: preferred);
    final w = math.min(width, area.width);
    final panel = layoutChild(_TetherSlot.panel, BoxConstraints(minWidth: w - 2 * offset, maxWidth: w - 2 * offset, maxHeight: math.max(0.0, place.maxHeight - 2 * offset)));
    final h = panel.height + 2 * offset;
    final c = anchor.center;
    final top = place.side == TetherSide.below ? c.dy + headRadius + neckGap : c.dy - headRadius - neckGap - h;
    final rect = Rect.fromLTWH(place.left, top, w, h);
    positionChild(_TetherSlot.panel, rect.topLeft + Offset(offset, offset));
    holder.outline = TetherOutline(rect: rect, button: c, buttonRadius: buttonRadius, side: place.side, clearance: clearance);
    layoutChild(_TetherSlot.paint, BoxConstraints.tight(size));
    positionChild(_TetherSlot.paint, Offset.zero);
    layoutChild(_TetherSlot.head, BoxConstraints.tight(Size.square(buttonRadius * 2)));
    positionChild(_TetherSlot.head, c - Offset(buttonRadius, buttonRadius));
  }

  @override
  bool shouldRelayout(_TetherDelegate old) =>
      old.anchor != anchor || old.width != width || old.preferred != preferred || old.offset != offset || old.clearance != clearance || old.neckGap != neckGap || old.insets != insets || old.holder != holder;
}

class _TetherPainter extends CustomPainter {
  _TetherPainter({required this.holder, required this.rim, required this.outline, required this.card, required this.head, required this.shadow, required this.strokeWidth, required this.offset});
  final _TetherHolder holder;
  final Color rim;
  final Color outline;
  final Color card;
  final Color head;
  final Color shadow;
  final double strokeWidth;
  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    final o = holder.outline;
    if (o == null) return;
    final path = o.path();
    canvas.drawShadow(path, shadow.withValues(alpha: 0.5), 6, false);
    canvas.drawPath(path, Paint()..color = rim);
    // 中身の面(外形から [offset] 内側)と、首の中のボタンの面。
    canvas.drawRRect(RRect.fromRectAndRadius(o.rect.deflate(offset), Radius.circular(math.max(0.0, o.cornerRadius - offset))), Paint()..color = card);
    canvas.drawCircle(o.button, o.buttonRadius, Paint()..color = head);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..color = outline,
    );
  }

  @override
  bool shouldRepaint(_TetherPainter old) => true;
}

/// オーバーレイに出す形。中身は キャンセル / タイトル / OK の見出し + [builder] + 下のハンドル(スケッチのとおり)。
extension TetheredPanelPresets on OverlayManager {
  /// [anchor] のボタンにつながったパネルを出す。OK で [onConfirm] の値を返す(キャンセル / 外のタップは null)。
  /// [anchorChild] = 首の中に描く元のボタンの見た目(アイコンなど)。首を押しても閉じる。
  Future<T?> showTetheredPanel<T>({
    required String id,
    required Rect anchor,
    required WidgetBuilder builder,
    String? title,
    String? cancelText = 'キャンセル',
    String? confirmText = 'OK',
    T? Function()? onConfirm,
    Widget? anchorChild,
    String? ownerId,
    double width = 320,
    TetherSide preferredSide = TetherSide.below,
  }) async {
    final result = await show(RasqOverlayEntry(
      id: id,
      layer: OverlayLayer.dropdown,
      ownerId: ownerId,
      semanticsLabel: title,
      builder: (context, handle) {
        final scheme = Theme.of(context).colorScheme;
        final header = SizedBox(
          height: 40,
          child: Row(children: [
            if (cancelText != null)
              TextButton(key: ValueKey('$id.cancel'), onPressed: handle.cancel, child: Text(cancelText, style: TextStyle(color: scheme.onSurfaceVariant)))
            else
              const SizedBox(width: 64),
            Expanded(child: Center(child: Text(title ?? '', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis))),
            if (confirmText != null)
              TextButton(key: ValueKey('$id.ok'), onPressed: () => handle.close(result: onConfirm?.call()), child: Text(confirmText, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)))
            else
              const SizedBox(width: 64),
          ]),
        );
        return SizedBox.expand(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => TetheredPanel(
              key: ValueKey('$id.panel'),
              anchor: anchor,
              width: width,
              preferredSide: preferredSide,
              progress: t,
              anchorChild: anchorChild,
              onAnchorTap: handle.cancel,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                header,
                Flexible(child: SingleChildScrollView(child: builder(context))),
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 6, bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: scheme.onSurfaceVariant.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    ));
    return result as T?;
  }
}
