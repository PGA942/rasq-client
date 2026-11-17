import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../icon_theme/icon_theme_backdrop.dart';
import '../icon_theme/rasq_theme_spec.dart';
import '../icon_theme/theme_frames.dart';
import '../theme_display.dart';
import 'tag_themes.dart';

/// RASQ Atmos (D-584) とコミュハッシュタグのテーマ (D-583) の描き方。
///
/// - SVG はどれも [themeSvgProvider](同梱 → 置き場、`SvgLite.parseStrict` と上限で消毒)から引く。読めなければ何も描かない。
/// - アニメーションは**静止した SVG をアプリが動かす**([RasqThemeMotion])。SVG の中の `<animate>` / `<script>` / 外部参照は
///   消毒で捨てるので、配られた中身が勝手に動いたり外へ取りに行ったりはしない。
/// - 端末の「動きを減らす」のときは、アニメーションを再生しない(背景は止めた 1 枚、[IconThemeBackdrop])。

/// 投稿の名前の行に付ける SVG のアイコン(Atmos の `hashtagBadge`)。
class AtmosBadge extends ConsumerWidget {
  const AtmosBadge({super.key, required this.entry, this.size = 18});
  final TagThemeEntry entry;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badge = entry.badge;
    if (badge == null) return const SizedBox.shrink();
    final doc = ref.watch(themeSvgProvider(badge.svgId)).value;
    if (doc == null) return const SizedBox.shrink();
    return Tooltip(
      message: '#${entry.tag}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(key: ValueKey('atmos.badge.${entry.tag}'), width: size, height: size, child: SvgLiteView(doc: doc)),
      ),
    );
  }
}

/// アクションのボタンの上で SVG のアニメーションを 1 回再生する。[anchor] = ボタンの画面上の位置。
/// 押す操作の邪魔をしない(指を受けない・待たない)。
void playAtmosAnimation(BuildContext context, RasqThemeTrigger trigger, Rect anchor) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
  final overlay = Overlay.maybeOf(context);
  final box = overlay?.context.findRenderObject();
  if (overlay == null || box is! RenderBox || !box.hasSize) return;
  final center = box.globalToLocal(anchor.center);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: center.dx - AtmosBurst.extent / 2,
      top: center.dy - AtmosBurst.extent / 2,
      width: AtmosBurst.extent,
      height: AtmosBurst.extent,
      child: IgnorePointer(child: AtmosBurst(svgId: trigger.svgId, motion: trigger.motion, onDone: () => entry.remove())),
    ),
  );
  overlay.insert(entry);
}

/// 1 回分のアニメーション。
class AtmosBurst extends ConsumerStatefulWidget {
  const AtmosBurst({super.key, required this.svgId, required this.motion, this.onDone});
  final String svgId;
  final RasqThemeMotion motion;
  final VoidCallback? onDone;

  /// 描く枠の一辺。
  static const extent = 120.0;
  static const duration = Duration(milliseconds: 900);

  @override
  ConsumerState<AtmosBurst> createState() => _AtmosBurstState();
}

class _AtmosBurstState extends ConsumerState<AtmosBurst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: AtmosBurst.duration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(themeSvgProvider(widget.svgId)).value;
    return KeyedSubtree(
      key: ValueKey('atmos.burst.${widget.svgId}'),
      child: doc == null
          ? const SizedBox.expand()
          : AnimatedBuilder(
              animation: _c,
              builder: (context, _) => _frame(SvgLiteView(doc: doc), Curves.easeOut.transform(_c.value)),
            ),
    );
  }

  Widget _frame(Widget svg, double t) {
    const base = 36.0;
    final fade = (1 - t).clamp(0.0, 1.0);
    Widget one({double scale = 1, double angle = 0, Offset offset = Offset.zero, double opacity = 1}) => Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(scale: scale, child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: SizedBox(width: base, height: base, child: svg))),
          ),
        );
    return Center(
      child: switch (widget.motion) {
        RasqThemeMotion.pop => one(scale: 0.4 + 1.2 * t, opacity: fade),
        RasqThemeMotion.spin => one(scale: 0.6 + 0.6 * t, angle: t * 2 * math.pi, opacity: fade),
        RasqThemeMotion.float => one(offset: Offset(0, -40 * t), scale: 0.8 + 0.3 * t, opacity: fade),
        RasqThemeMotion.burst => Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            for (var i = 0; i < 6; i++)
              one(
                offset: Offset(math.cos(i * math.pi / 3) * 44 * t, math.sin(i * math.pi / 3) * 44 * t),
                scale: 0.5 + 0.2 * t,
                angle: i * math.pi / 3 * t,
                opacity: fade,
              ),
          ]),
      },
    );
  }
}

/// テーマを付けた面 (D-583 / D-584 → D-587): 着せ替えと同じ層(色の上書き + 一番下の背景)に、エフェクトは中身の上。
/// 出すかどうかは見ない(申請の画面の見本など)。ページに付けるものは [watchThemeVisible] を見てから [ThemedSurface] で。
class TagThemeSurface extends StatelessWidget {
  const TagThemeSurface({super.key, required this.spec, required this.child});
  final RasqThemeSpec spec;
  final Widget child;

  @override
  Widget build(BuildContext context) => ThemedSurface(spec: spec, child: child);
}

/// テーマの帯: タグの名前と一言を、テーマの背景の上にテーマの文字色で。
class TagThemeBanner extends StatelessWidget {
  const TagThemeBanner({super.key, required this.entry, required this.caption, this.height = 72});
  final TagThemeEntry entry;
  final String caption;
  final double height;

  @override
  Widget build(BuildContext context) {
    final text = themeColor(entry.spec.basic.text);
    return SizedBox(
      key: ValueKey('tagTheme.banner.${entry.kind.name}.${entry.tag}'),
      height: height,
      child: ClipRect(
        child: IconThemeBackdrop(
          spec: entry.spec,
          child: Padding(
            // 低い帯(一覧の 56)では上下の余白を詰める。
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: height < 64 ? 4 : 10),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#${entry.tag}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w700)),
              Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text.withValues(alpha: 0.85), fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}
