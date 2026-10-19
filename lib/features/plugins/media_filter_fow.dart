import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../l10n/l10n.dart';
import 'media_filter.dart';

/// カスタムフィルターの調整 FOW (D-257、スロット契約 v0.13): `filter.preview` の `params` をスライダーで出す。
/// 値を動かすたびに [onChanged] → 呼び出し側が `filter.preview` を呼び直して [spec] を差し替える(絵は加工画面のレイヤーが描く)。
/// スライダーの位置は手元の値で動かし、プラグインが返した値(丸めたもの)が来たらそれに合わせ直す。
/// 戻り: true = 「外す」、それ以外 = 閉じただけ。
const mediaFilterFowId = 'media.pro.filter';

Future<bool?> showMediaFilterFow(OverlayManager manager, {required String title, required ValueNotifier<MediaFilterSpec> spec, required Future<void> Function(String id, double value) onChanged}) {
  if (manager.contains(mediaFilterFowId)) manager.close(mediaFilterFowId);
  return manager.showFow<bool>(
    id: mediaFilterFowId,
    spec: FowSpec(title: title, cancelText: appL10n.pluginsMediaClose, initialHeightFactor: 0.38, minHeightFactor: 0.2, maxHeightFactor: 0.7, maxWidth: 560),
    semanticsLabel: appL10n.pluginsMediaFilterAdjustSemantics(title),
    builder: (_, _) => _Body(spec: spec, onChanged: onChanged, onRemove: () => manager.close(mediaFilterFowId, result: true)),
  );
}

class _Body extends StatefulWidget {
  const _Body({required this.spec, required this.onChanged, required this.onRemove});
  final ValueNotifier<MediaFilterSpec> spec;
  final Future<void> Function(String id, double value) onChanged;
  final VoidCallback onRemove;
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// 動かしている最中の手元の値(プラグインの返事を待たずにスライダーを動かす)。
  final Map<String, double> _local = {};

  @override
  void initState() {
    super.initState();
    widget.spec.addListener(_onSpec);
  }

  @override
  void dispose() {
    widget.spec.removeListener(_onSpec);
    super.dispose();
  }

  void _onSpec() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spec = widget.spec.value;
    return ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.md), children: [
      for (final p in spec.params)
        RasqSliderListTile(
          key: ValueKey('filter.param.${p.id}'),
          title: p.label,
          value: (_local[p.id] ?? p.value).clamp(p.min, p.max),
          min: p.min,
          max: p.max,
          divisions: p.divisions,
          valueLabel: p.format(_local[p.id] ?? p.value),
          onChanged: (v) {
            setState(() => _local[p.id] = v);
            widget.onChanged(p.id, v);
          },
        ),
      if (spec.object != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0),
          child: Text(context.l10n.pluginsMediaFilterObjectHint, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(key: const ValueKey('filter.remove'), onPressed: widget.onRemove, icon: const Icon(Icons.layers_clear_outlined, size: 18), label: Text(context.l10n.pluginsMediaFilterRemove), style: OutlinedButton.styleFrom(foregroundColor: scheme.error)),
        ),
      ),
    ]);
  }
}
