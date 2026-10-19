import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fow.dart';
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
///  | キャンセル  タイトル  OK |  ← 外形は中身から [outlineOffset](= 細い線 [kFowRimWidth])外側
///  |  …中身…                  |
///  |          ━━              |  ← ハンドル
///   ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
/// ```
///
/// - D-477 (2026-10-19): パネルの辺をボタンの丸の端まで寄せ(D-479 でアイコンの範囲まで)、首は丸の真横より**パネルと反対の側**
///   ([kTetherNeckAngle])で丸を離れ、横に長い裾([kTetherNeckFlare])でパネルの辺へなだらかに着く。画面の端で上辺に裾の
///   場所が無いときは、首を横の辺へ流す。
/// - D-479 (2026-10-19): パネルの辺はボタンの丸ではなく**アイコンの範囲**([kTetherIconExtent] + [kTetherIconGap])まで寄せる
///   (ボタンがパネルに埋まって見える。首は丸のうちパネルの辺より外の部分だけを包む)。ボタンの押せる範囲はパネルの辺から
///   反対側へずらし([TetheredPanel] の首のタップ)、中身のタップとぶつけない。ふちは灰色の帯と青い線をやめ、FOW と同じ
///   細い線([kFowRimWidth] / [fowRimColor])と浅い影([kFowElevation])。
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

/// 形の調整値の既定 (D-477: 2026-10-19 のユーザーの指摘)。ここを変えれば形をすぐ詰められる。
///
/// 首がボタンの丸を離れる角度(度)。真横から**パネルと反対の側**へ測る(下に開くときは真横より上)。
/// 大きいほど首が丸の高いところから始まり、丸の横を包まずに裾が広がる。
const double kTetherNeckAngle = 20;

/// 首の裾の横の長さ(px)。首が丸を離れる点から、パネルの辺に着く点まで。長いほど肩がなだらか。
const double kTetherNeckFlare = 44;

/// ボタンのアイコンの大きさ(px)。パネルの外形の辺はボタンの中心からこの半分 + [kTetherIconGap] のところ(D-479)。
/// コンポーザーのアクションバーのアイコンは 20px。
const double kTetherIconExtent = 20;

/// パネルの外形の辺とアイコンの範囲の端のすき間(px)。0 = 外形の線がアイコンの範囲の端に接する。
/// 以前(D-477)は辺をボタンの丸の端から 3px 内側までしか寄せていなかった。
const double kTetherIconGap = 1;

/// ボタンの中心からパネルの外形の辺まで(px)。
double tetherReach({double iconExtent = kTetherIconExtent, double iconGap = kTetherIconGap}) => iconExtent / 2 + iconGap;

/// 首のタップの範囲(D-479): ボタンの丸と同じ大きさ(少なくとも [kMinInteractiveDimension] の正方形)を、パネルの辺から
/// **パネルと反対の側**へずらして置く(下に開くなら、範囲の下端 = パネルの辺)。中身(見出しのボタンなど)のタップと
/// ぶつからず、パネルの外へ出ている首のふくらみはそのまま押せる。
Rect tetherHitRect({required Offset button, required double buttonRadius, required double reach, required TetherSide side}) {
  final s = math.max(kMinInteractiveDimension, buttonRadius * 2);
  final edge = side == TetherSide.below ? button.dy + reach : button.dy - reach;
  return Rect.fromLTWH(button.dx - s / 2, side == TetherSide.below ? edge - s : edge, s, s);
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
    this.neckAngle = kTetherNeckAngle,
    this.neckFlare = kTetherNeckFlare,
  });

  final Rect rect;
  final Offset button;
  final double buttonRadius;
  final TetherSide side;

  /// 首がボタンを包むすき間(px)。
  final double clearance;
  final double cornerRadius;

  /// [kTetherNeckAngle](度)。
  final double neckAngle;

  /// [kTetherNeckFlare](px)。
  final double neckFlare;

  /// 首の丸(ボタン + すき間)の半径。
  double get headRadius => buttonRadius + clearance;

  /// 角を詰めるときの最小の丸み(これより詰まるなら首を横の辺へ流す)。
  static const _minCorner = 6.0;

  /// 輪郭(閉じたパス)。下に開くときの形を作り、上に開くときは上下を裏返す。
  Path path() {
    if (side == TetherSide.below) return _topNeck(rect, button);
    final flipped = _topNeck(Rect.fromLTRB(rect.left, -rect.bottom, rect.right, -rect.top), Offset(button.dx, -button.dy));
    return flipped.transform((Matrix4.identity()..scaleByDouble(1.0, -1.0, 1.0, 1.0)).storage);
  }

  /// 首の右半分(丸を離れる点 → パネルの辺)。左半分は左右を裏返して同じ計算をする([edge] = その側の横の辺の x)。
  /// 返すのは 3 次ベジェの 4 点と、その側の角の丸み(0 = 首を横の辺へ流した)。
  ({Offset p0, Offset p1, Offset p2, Offset p3, double corner}) _half(Offset c, double top, double edge, double maxDrop) {
    final a = headRadius;
    final th = neckAngle * math.pi / 180;
    final cosT = math.cos(th), sinT = math.sin(th);
    // 丸を離れる点(右上。y は下向き)と、そこでの進む向き(時計回りの接線 = 右下)。
    final p0 = Offset(c.dx + a * cosT, c.dy - a * sinT);
    final dir = Offset(sinT, cosT);
    final rise = math.max(0.0, top - p0.dy);
    final room = edge - p0.dx; // 丸を離れる点から横の辺まで。
    final flare = room - neckFlare >= _minCorner ? neckFlare : room - _minCorner;
    if (flare >= neckFlare * 0.5) {
      // ふつう: 首は上辺に水平に着く。角に近ければ角の丸みを詰める。
      final corner = math.min(cornerRadius, room - flare);
      final p3 = Offset(p0.dx + flare, top);
      return (p0: p0, p1: p0 + dir * (rise * 0.6), p2: Offset(p3.dx - flare * 0.55, top), p3: p3, corner: corner);
    }
    // 画面の端のボタン: 上辺に着く場所が無いので、首を横の辺へ流す(縦の接線で横の辺に着く)。
    // 横の辺に着く深さは、足りなかった裾の長さのぶん(上辺の代わりに横の辺で裾を伸ばす)。
    final drop = math.min(maxDrop, math.min(neckFlare * 0.6, math.max(16.0, neckFlare - math.max(0.0, room)) * 0.8));
    final p3 = Offset(edge, top + drop);
    final reach = math.max(8.0, (p3 - p0).distance);
    return (p0: p0, p1: p0 + dir * (reach * 0.4), p2: Offset(edge, p3.dy - reach * 0.5), p3: p3, corner: 0);
  }

  /// 首が上辺にある形。
  Path _topNeck(Rect r, Offset c) {
    final top = r.top;
    final rb = math.min(cornerRadius, r.height / 2);
    final maxDrop = math.max(0.0, r.height - rb - 1);
    final rh = _half(c, top, r.right, maxDrop);
    // 左半分: x を c.dx で裏返して右半分と同じ計算をし、戻す(向きも逆になる)。
    Offset m(Offset p) => Offset(2 * c.dx - p.dx, p.dy);
    final lh = _half(c, top, 2 * c.dx - r.left, maxDrop);
    final rl = lh.corner, rr = rh.corner;
    final a = headRadius;
    final th = neckAngle * math.pi / 180;
    final p = Path()..moveTo(r.left, r.bottom - rb);
    // 左の辺 → 左上の角 → 上辺 → 首(左)。角が 0 なら首を横の辺から始める。
    if (rl > 0) {
      p
        ..lineTo(r.left, top + rl)
        ..arcToPoint(Offset(r.left + rl, top), radius: Radius.circular(rl))
        ..lineTo(m(lh.p3).dx, top);
    } else {
      p.lineTo(m(lh.p3).dx, m(lh.p3).dy);
    }
    final l2 = m(lh.p2), l1 = m(lh.p1), l0 = m(lh.p0);
    p
      ..cubicTo(l2.dx, l2.dy, l1.dx, l1.dy, l0.dx, l0.dy)
      // 丸の上側を時計回りに(左の離れる点 → 右の離れる点)。
      ..arcTo(Rect.fromCircle(center: c, radius: a), math.pi + th, math.pi - 2 * th, false)
      ..cubicTo(rh.p1.dx, rh.p1.dy, rh.p2.dx, rh.p2.dy, rh.p3.dx, rh.p3.dy);
    if (rr > 0) {
      p
        ..lineTo(r.right - rr, top)
        ..arcToPoint(Offset(r.right, top + rr), radius: Radius.circular(rr));
    }
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
      other is TetherOutline &&
      other.rect == rect &&
      other.button == button &&
      other.buttonRadius == buttonRadius &&
      other.side == side &&
      other.clearance == clearance &&
      other.cornerRadius == cornerRadius &&
      other.neckAngle == neckAngle &&
      other.neckFlare == neckFlare;

  @override
  int get hashCode => Object.hash(rect, button, buttonRadius, side, clearance, cornerRadius, neckAngle, neckFlare);
}

/// [TetheredPanel] の置き場所を決める(純粋な計算。テストもここ)。
/// [area] = 置いてよい範囲(画面からキーボード / ノッチ / 余白を除いたもの)。
/// [reach] = ボタンの中心からパネルの外形の辺まで(= [tetherReach]。アイコンの範囲の半分 + すき間)。
@visibleForTesting
({TetherSide side, double left, double maxHeight}) tetherPlacement({required Rect anchor, required Rect area, required double width, required double reach, required TetherSide preferred, double minHeight = 200}) {
  final c = anchor.center;
  final spaceBelow = area.bottom - (c.dy + reach);
  final spaceAbove = (c.dy - reach) - area.top;
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
    this.outlineOffset = kFowRimWidth,
    this.clearance = 3,
    this.iconExtent = kTetherIconExtent,
    this.iconGap = kTetherIconGap,
    this.neckAngle = kTetherNeckAngle,
    this.neckFlare = kTetherNeckFlare,
    this.strokeWidth = kFowRimWidth,
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

  /// 外形の線を中身からどれだけ外に出すか(px)。D-479 で スケッチの「6px」の灰色の帯をやめ、細い線([kFowRimWidth])だけ。
  final double outlineOffset;

  /// 首がボタンを包むすき間(px。スケッチの「3px」)。
  final double clearance;

  /// [kTetherIconExtent]。外形の辺はボタンの中心から この半分 + [iconGap](D-479。D-477 ではボタンの丸の端から 3px 内側)。
  final double iconExtent;

  /// [kTetherIconGap]。
  final double iconGap;

  /// [kTetherNeckAngle](度)。
  final double neckAngle;

  /// [kTetherNeckFlare](px)。
  final double neckFlare;
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
        reach: tetherReach(iconExtent: iconExtent, iconGap: iconGap),
        neckAngle: neckAngle,
        neckFlare: neckFlare,
        insets: EdgeInsets.fromLTRB(mq.padding.left + margin, mq.padding.top + margin, mq.padding.right + margin, math.max(mq.padding.bottom, mq.viewInsets.bottom) + margin),
      ),
      children: [
        LayoutId(
          id: _TetherSlot.paint,
          child: IgnorePointer(
            child: CustomPaint(
              painter: _TetherPainter(holder: holder, rim: fowRimColor(scheme), card: scheme.surface, shadow: Colors.black, strokeWidth: strokeWidth),
            ),
          ),
        ),
        LayoutId(
          id: _TetherSlot.panel,
          child: Material(type: MaterialType.transparency, child: child),
        ),
        // 首の中のボタンの見た目(ボタンの中心)と、押せる範囲(パネルと反対の側へずらす、[tetherHitRect])は別に置く。
        LayoutId(id: _TetherSlot.head, child: IgnorePointer(child: Center(child: anchorChild))),
        LayoutId(
          id: _TetherSlot.hit,
          child: GestureDetector(key: const ValueKey('rasqOverlay.tether.hit'), behavior: HitTestBehavior.opaque, onTap: onAnchorTap),
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

enum _TetherSlot { paint, panel, head, hit }

/// レイアウトで決まった形を、描画へ渡す入れ物(描画はレイアウトのあと)。
class _TetherHolder {
  TetherOutline? outline;
}

class _TetherDelegate extends MultiChildLayoutDelegate {
  _TetherDelegate({required this.holder, required this.anchor, required this.width, required this.preferred, required this.offset, required this.clearance, required this.reach, required this.neckAngle, required this.neckFlare, required this.insets});
  final _TetherHolder holder;
  final Rect anchor;
  final double width;
  final TetherSide preferred;
  final double offset;
  final double clearance;
  final double reach;
  final double neckAngle;
  final double neckFlare;
  final EdgeInsets insets;

  @override
  void performLayout(Size size) {
    final buttonRadius = math.min(anchor.width, anchor.height) / 2;
    final area = insets.deflateRect(Offset.zero & size);
    final place = tetherPlacement(anchor: anchor, area: area, width: width, reach: reach, preferred: preferred);
    final w = math.min(width, area.width);
    final panel = layoutChild(_TetherSlot.panel, BoxConstraints(minWidth: w - 2 * offset, maxWidth: w - 2 * offset, maxHeight: math.max(0.0, place.maxHeight - 2 * offset)));
    final h = panel.height + 2 * offset;
    final c = anchor.center;
    final top = place.side == TetherSide.below ? c.dy + reach : c.dy - reach - h;
    final rect = Rect.fromLTWH(place.left, top, w, h);
    positionChild(_TetherSlot.panel, rect.topLeft + Offset(offset, offset));
    holder.outline = TetherOutline(rect: rect, button: c, buttonRadius: buttonRadius, side: place.side, clearance: clearance, neckAngle: neckAngle, neckFlare: neckFlare);
    layoutChild(_TetherSlot.paint, BoxConstraints.tight(size));
    positionChild(_TetherSlot.paint, Offset.zero);
    layoutChild(_TetherSlot.head, BoxConstraints.tight(Size.square(buttonRadius * 2)));
    positionChild(_TetherSlot.head, c - Offset(buttonRadius, buttonRadius));
    final hit = tetherHitRect(button: c, buttonRadius: buttonRadius, reach: reach, side: place.side);
    layoutChild(_TetherSlot.hit, BoxConstraints.tight(hit.size));
    positionChild(_TetherSlot.hit, hit.topLeft);
  }

  @override
  bool shouldRelayout(_TetherDelegate old) =>
      old.anchor != anchor || old.width != width || old.preferred != preferred || old.offset != offset || old.clearance != clearance ||
      old.reach != reach ||
      old.neckAngle != neckAngle ||
      old.neckFlare != neckFlare || old.insets != insets || old.holder != holder;
}

class _TetherPainter extends CustomPainter {
  _TetherPainter({required this.holder, required this.rim, required this.card, required this.shadow, required this.strokeWidth});
  final _TetherHolder holder;
  final Color rim;
  final Color card;
  final Color shadow;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final o = holder.outline;
    if (o == null) return;
    final path = o.path();
    // D-479: 面は首ごと 1 枚(灰色の帯は無し)、ふちは FOW と同じ細い線と浅い影。
    canvas.drawShadow(path, shadow, kFowElevation, false);
    canvas.drawPath(path, Paint()..color = card);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..color = rim,
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
    double iconExtent = kTetherIconExtent,
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
              iconExtent: iconExtent,
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
