import 'package:flutter/material.dart';

import '../tokens/typography.dart';

/// 丸いアクションボタン(下に名前)(D-383)。ホーム / トレンド / AsTell の ＋ の展開、ボタンの並べ替えのプレビューで使う。
/// AsTell のプラグインのボタンもこの形にそろえる予定。
///
/// - [icon] か [child](アバターなど)を丸の中に。
/// - [faded] = 薄く出す(スライドの途中で、向かっていないボタン)。[selected] = 強調(向かっているボタン)。
class RasqActionCircle extends StatelessWidget {
  const RasqActionCircle({super.key, this.icon, this.child, required this.label, this.onTap, this.size = 52, this.faded = false, this.selected = false, this.labelColor, this.badge});

  final IconData? icon;
  final Widget? child;
  final String label;
  final VoidCallback? onTap;
  final double size;
  final bool faded;
  final bool selected;

  /// 名前の色(暗い背景の上では白)。
  final Color? labelColor;

  /// 丸の右下に重ねる小さいもの(SNS のアイコンなど)。
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final circle = Material(
      color: selected ? scheme.primary : scheme.surface,
      shape: CircleBorder(side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant)),
      elevation: selected ? 8 : 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child ?? Icon(icon, size: size * 0.46, color: selected ? scheme.onPrimary : scheme.onSurface)),
        ),
      ),
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: faded ? 0.35 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: selected ? 1.12 : 1,
        child: SizedBox(
          width: size + 28,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              circle,
              if (badge != null) Positioned(right: -2, bottom: -2, child: badge!),
            ]),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: RasqTypography.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: labelColor ?? scheme.onSurface, shadows: labelColor == null ? null : const [Shadow(blurRadius: 4)]),
            ),
          ]),
        ),
      ),
    );
  }
}
