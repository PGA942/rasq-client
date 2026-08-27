import 'package:flutter/material.dart';

import '../tokens/sizes.dart';
import '../tokens/typography.dart';

/// One button of an action bar (L2 atomic `ActionButton`).
///
/// Variants (原典: ボタンコンポーネント): icon only / icon+count / text only /
/// icon+text. `done`/`count` are props fed from the store; when the plugin
/// has not declared a done-icon the button is disabled in the done state
/// (「済みアイコン未定義なら無効」).
class RasqActionButton extends StatelessWidget {
  const RasqActionButton.icon({
    super.key,
    required this.icon,
    this.doneIcon,
    this.done = false,
    this.doneColor,
    this.onTap,
    this.onLongPress,
    this.tooltip,
    this.enabled = true,
  })  : count = null,
        label = null;

  const RasqActionButton.iconCount({
    super.key,
    required this.icon,
    required this.count,
    this.doneIcon,
    this.done = false,
    this.doneColor,
    this.onTap,
    this.onLongPress,
    this.tooltip,
    this.enabled = true,
  }) : label = null;

  const RasqActionButton.text({
    super.key,
    required String this.label,
    this.done = false,
    this.doneColor,
    this.onTap,
    this.onLongPress,
    this.tooltip,
    this.enabled = true,
  })  : icon = null,
        doneIcon = null,
        count = null;

  const RasqActionButton.iconText({
    super.key,
    required this.icon,
    required String this.label,
    this.doneIcon,
    this.done = false,
    this.doneColor,
    this.onTap,
    this.onLongPress,
    this.tooltip,
    this.enabled = true,
  }) : count = null;

  final IconData? icon;
  final IconData? doneIcon;
  final int? count;
  final String? label;
  final bool done;
  final Color? doneColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Done state without a declared done-icon → disabled (spec).
    final effectiveEnabled = enabled && !(done && icon != null && doneIcon == null);
    final color = !effectiveEnabled
        ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
        : done
            ? (doneColor ?? scheme.primary)
            : scheme.onSurface;

    final children = <Widget>[];
    final shownIcon = done ? (doneIcon ?? icon) : icon;
    if (shownIcon != null) children.add(Icon(shownIcon, size: 20, color: color));
    if (count != null) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 4));
      children.add(Text(_formatCount(count!), style: RasqTypography.count.copyWith(color: color)));
    }
    if (label != null) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 6));
      children.add(Text(label!, style: RasqTypography.button.copyWith(color: color)));
    }

    final child = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: RasqSizes.minTap, minHeight: RasqSizes.minTap),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: children),
      ),
    );

    Widget result = InkResponse(
      onTap: effectiveEnabled ? onTap : null,
      onLongPress: effectiveEnabled ? onLongPress : null,
      radius: 24,
      containedInkWell: false,
      child: child,
    );
    if (tooltip != null) result = Tooltip(message: tooltip!, child: result);
    return Semantics(button: true, enabled: effectiveEnabled, selected: done, label: tooltip ?? label, child: result);
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    return n == 0 ? '' : '$n';
  }
}
