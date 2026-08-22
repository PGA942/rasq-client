import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/typography.dart';

/// Where a badge is anchored on its host (原典: 「右下/右上どちらにも配置可能」).
enum RasqBadgePosition { topRight, bottomRight, topLeft, bottomLeft }

/// Small count / dot badge. Doubles as notification badge and avatar overlay.
class RasqBadge extends StatelessWidget {
  const RasqBadge({super.key, this.count, this.color, this.textColor, this.dot = false, this.size = 16});

  /// Count; `null` or 0 renders nothing unless [dot] is true.
  final int? count;
  final Color? color;
  final Color? textColor;
  final bool dot;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = count ?? 0;
    if (c <= 0 && !dot) return const SizedBox.shrink();
    final bg = color ?? RasqColors.link;
    if (dot || c <= 0) {
      return Container(width: size * 0.6, height: size * 0.6, decoration: BoxDecoration(color: bg, shape: BoxShape.circle));
    }
    final label = c > 99 ? '99+' : '$c';
    return DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size)),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: size, minHeight: size),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.25),
            child: Text(label, style: RasqTypography.count.copyWith(color: textColor ?? RasqColors.white, fontSize: size * 0.62, height: 1)),
          ),
        ),
      ),
    );
  }
}

/// Overlays [badge] on [child] at [position]. Used for avatars and nav icons.
class RasqBadged extends StatelessWidget {
  const RasqBadged({super.key, required this.child, required this.badge, this.position = RasqBadgePosition.topRight, this.offset = const Offset(4, -4)});

  final Widget child;
  final Widget badge;
  final RasqBadgePosition position;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final top = position == RasqBadgePosition.topRight || position == RasqBadgePosition.topLeft;
    final right = position == RasqBadgePosition.topRight || position == RasqBadgePosition.bottomRight;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: top ? offset.dy : null,
          bottom: top ? null : offset.dy,
          right: right ? -offset.dx : null,
          left: right ? null : -offset.dx,
          child: badge,
        ),
      ],
    );
  }
}

/// Pill label such as「フォロー中」「ブロック中」「フォローされています」.
class RasqPill extends StatelessWidget {
  const RasqPill({super.key, required this.label, this.color, this.textColor, this.outlined = false, this.dense = true});

  final String label;
  final Color? color;
  final Color? textColor;
  final bool outlined;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : bg,
        border: outlined ? Border.all(color: bg) : null,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: outlined ? bg : (textColor ?? RasqColors.white), fontSize: dense ? 11 : 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
