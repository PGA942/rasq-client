import 'package:flutter/material.dart';

import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// スライダー設定行 (L2)。トレンドの指向性/刺激性、リレーショナルTLの
/// 類似度しきい値(50〜100 正規化, D-022)などの数値設定に使う独立部品。
class RasqSliderListTile extends StatelessWidget {
  const RasqSliderListTile({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.onChanged,
    this.subtitle,
    this.valueLabel,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final String? subtitle;

  /// 右側の現在値表示(省略時は整数丸め)。
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: RasqTypography.listTile)),
          Text(valueLabel ?? '${value.round()}', style: RasqTypography.count.copyWith(color: scheme.onSurfaceVariant)),
        ]),
        if (subtitle != null) Text(subtitle!, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
      ]),
    );
  }
}
