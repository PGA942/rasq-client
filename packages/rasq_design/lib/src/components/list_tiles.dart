import 'package:flutter/material.dart';

import '../theme/rasq_tokens_extension.dart';
import '../tokens/sizes.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Base row used by every ListTile variant (設定 / ミュート・ブロック / フォロー申請 …).
/// Layout tokens (height, padding, divider) are host-fixed.
class RasqListTile extends StatelessWidget {
  const RasqListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.chevron = true,
    this.titleColor,
    this.enabled = true,
    this.divider = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Show `>` at the end (default for navigation rows).
  final bool chevron;
  final Color? titleColor;
  final bool enabled;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = enabled ? (titleColor ?? scheme.onSurface) : scheme.onSurfaceVariant;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
        child: Row(children: [
          if (leading != null) ...[IconTheme(data: IconThemeData(color: color, size: 22), child: leading!), const SizedBox(width: RasqSpacing.md)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: RasqTypography.listTile.copyWith(color: color)),
              if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: RasqSpacing.sm), trailing!],
          if (chevron) ...[const SizedBox(width: RasqSpacing.sm), Icon(Icons.chevron_right, color: color)],
        ]),
      ),
    );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      InkWell(onTap: enabled ? onTap : null, child: row),
      if (divider) const Divider(),
    ]);
  }
}

/// Title + toggle switch.
class RasqSwitchListTile extends StatelessWidget {
  const RasqSwitchListTile({super.key, required this.title, required this.value, this.onChanged, this.subtitle, this.leading, this.enabled = true});

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => RasqListTile(
        title: title,
        subtitle: subtitle,
        leading: leading,
        chevron: false,
        enabled: enabled,
        onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
        trailing: Switch(value: value, onChanged: enabled ? onChanged : null),
      );
}

/// Title + radio button.
class RasqRadioListTile<T> extends StatelessWidget {
  const RasqRadioListTile({super.key, required this.title, required this.value, required this.groupValue, this.onChanged, this.subtitle, this.enabled = true});

  final String title;
  final String? subtitle;
  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = value == groupValue;
    return RasqListTile(
      title: title,
      subtitle: subtitle,
      chevron: false,
      enabled: enabled,
      onTap: enabled && onChanged != null ? () => onChanged!(value) : null,
      trailing: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? scheme.surface : scheme.outline,
            border: Border.all(color: selected ? scheme.primary : scheme.outline, width: selected ? 6 : 0),
          ),
        ),
      ),
    );
  }
}

/// Title + current value + `>`.
class RasqValueListTile extends StatelessWidget {
  const RasqValueListTile({super.key, required this.title, required this.value, this.onTap, this.leading, this.enabled = true});

  final String title;
  final String value;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool enabled;

  @override
  Widget build(BuildContext context) => RasqListTile(
        title: title,
        leading: leading,
        onTap: onTap,
        enabled: enabled,
        trailing: Text(value, style: RasqTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

/// Title prefixed by a warning icon + `>` (e.g.「⚠ トレンドの指向性/刺激性」).
class RasqWarningListTile extends StatelessWidget {
  const RasqWarningListTile({super.key, required this.title, this.onTap, this.subtitle});

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => RasqListTile(
        title: title,
        subtitle: subtitle,
        onTap: onTap,
        leading: Icon(Icons.warning_amber_rounded, color: RasqTokens.of(context).warning),
      );
}

/// Red destructive row (ログアウト / ブロック / 削除).
class RasqDestructiveListTile extends StatelessWidget {
  const RasqDestructiveListTile({super.key, required this.title, this.onTap, this.leading, this.chevron = true});

  final String title;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool chevron;

  @override
  Widget build(BuildContext context) => RasqListTile(title: title, onTap: onTap, leading: leading, chevron: chevron, titleColor: RasqTokens.of(context).danger);
}

/// Group heading for ListTile sections (独立コンポーネント).
class RasqSectionHeader extends StatelessWidget {
  const RasqSectionHeader({super.key, required this.title, this.trailing, this.topMargin = RasqSpacing.sectionMargin});

  final String title;
  final Widget? trailing;
  final double topMargin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: topMargin),
      child: Container(
        constraints: const BoxConstraints(minHeight: RasqSizes.minTap),
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.onSurface, width: 1.5))),
        child: Row(children: [
          Expanded(child: Text(title, style: RasqTypography.sectionHeader.copyWith(color: scheme.onSurface))),
          ?trailing,
        ]),
      ),
    );
  }
}
