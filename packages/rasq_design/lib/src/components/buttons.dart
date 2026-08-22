import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/sizes.dart';
import '../tokens/typography.dart';

/// Follow / block style toggle pill: filled when active (「フォロー中」),
/// outlined when inactive (「フォロー」).
class RasqTogglePillButton extends StatelessWidget {
  const RasqTogglePillButton({
    super.key,
    required this.label,
    required this.active,
    this.activeLabel,
    this.onPressed,
    this.activeColor,
    this.dense = true,
  });

  final String label;
  final String? activeLabel;
  final bool active;
  final VoidCallback? onPressed;
  final Color? activeColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = activeColor ?? scheme.primary;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, dense ? 32 : 40)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: dense ? 14 : 20)),
      textStyle: const WidgetStatePropertyAll(RasqTypography.button),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    return active
        ? FilledButton(onPressed: onPressed, style: style.copyWith(backgroundColor: WidgetStatePropertyAll(color)), child: Text(activeLabel ?? label))
        : OutlinedButton(onPressed: onPressed, style: style.copyWith(side: WidgetStatePropertyAll(BorderSide(color: color)), foregroundColor: WidgetStatePropertyAll(color)), child: Text(label));
  }
}

/// Wide gradient CTA (「見てみる」「参加」「作成」).
class RasqGradientButton extends StatelessWidget {
  const RasqGradientButton({super.key, required this.label, this.onPressed, this.gradient, this.height = RasqSizes.minTap, this.enabled = true});

  final String label;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final double height;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: enabled ? (gradient ?? RasqColors.ctaGradient) : null,
            color: enabled ? null : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(RasqSizes.radiusPill),
          ),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(RasqSizes.radiusPill),
            child: Center(
              child: Text(label, style: RasqTypography.title.copyWith(color: enabled ? RasqColors.white : scheme.onSurfaceVariant, fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular icon button with guaranteed 44dp target (header `…`, back, etc.).
class RasqIconButton extends StatelessWidget {
  const RasqIconButton({super.key, required this.icon, this.onPressed, this.tooltip, this.color, this.size = 22, this.badge});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon, size: size, color: color);
    if (badge != null) {
      iconWidget = Stack(clipBehavior: Clip.none, children: [iconWidget, Positioned(right: -6, top: -4, child: badge!)]);
    }
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: iconWidget,
      constraints: const BoxConstraints(minWidth: RasqSizes.minTap, minHeight: RasqSizes.minTap),
    );
  }
}
