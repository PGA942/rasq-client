import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../l10n/l10n.dart';
import '../../shell/column_layout.dart';
import '../../shell/headers.dart';
import 'settings_dsl.dart';

/// アプリの外観 → カラムの幅 (D-320): 幅の広い画面の小型 / 大型カラムのサイズ比を 5 種類から選ぶ。
/// 固定幅は px を入れる(正しい値だけ保存し、シェルにすぐ反映する)。KV `appearance.columns.v1`。
class ColumnLayoutScreen extends ConsumerStatefulWidget {
  const ColumnLayoutScreen({super.key});
  @override
  ConsumerState<ColumnLayoutScreen> createState() => _ColumnLayoutScreenState();
}

class _ColumnLayoutScreenState extends ConsumerState<ColumnLayoutScreen> {
  final _px = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _px.text = _pxOf(ref.read(columnLayoutProvider));
  }

  @override
  void dispose() {
    _px.dispose();
    _focus.dispose();
    super.dispose();
  }

  static String _pxOf(ColumnLayout l) => '${l.split == ColumnSplit.largeFixed ? l.largePx : l.smallPx}';

  SettingsAreaStore get _store => ref.read(settingsAreaProvider(columnLayoutArea).notifier);

  void _onPx(String text, ColumnSplit split) {
    final error = columnPxError(text);
    setState(() => _error = error);
    if (error != null) return;
    _store.set(split == ColumnSplit.largeFixed ? 'largePx' : 'smallPx', validColumnPx(text));
  }

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(columnLayoutProvider);
    // 保存値の読み込みや種類の切り替えで、入力欄を選んだ種類の幅に合わせる(入力中は触らない)。
    ref.listen(columnLayoutProvider, (prev, next) {
      if (prev?.split != next.split || !_focus.hasFocus) {
        _px.text = _pxOf(next);
        if (_error != null) setState(() => _error = null);
      }
    });
    final scheme = Theme.of(context).colorScheme;
    final screen = MediaQuery.sizeOf(context).width;
    final wide = screen >= RasqSizes.tabletBreakpoint;
    final split = splitColumns(screen - 72, layout);
    final l = context.l10n;
    return Scaffold(
      appBar: RasqPageHeader(title: l.settingsColumnsTitle),
      body: ListView(children: [
        RasqCaption(
          l.settingsColumnsIntroCaption,
          detail: l.settingsColumnsIntroDetail,
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
        ),
        RasqSectionHeader(title: l.settingsColumnsSplitHeader),
        for (final s in ColumnSplit.values)
          RasqRadioListTile<ColumnSplit>(
            key: ValueKey('columns.split.${s.name}'),
            title: s.label,
            subtitle: s == ColumnLayout.standard.split ? l.settingsColumnsSplitDefault(s.hint) : s.hint,
            value: s,
            groupValue: layout.split,
            onChanged: (v) => _store.set('split', v.name),
          ),
        if (layout.split.fixed)
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(layout.split == ColumnSplit.largeFixed ? l.settingsColumnsLargeWidthLabel : l.settingsColumnsSmallWidthLabel, style: RasqTypography.listTile),
              RasqInput(
                key: const ValueKey('columns.px'),
                controller: _px,
                focusNode: _focus,
                hintText: context.l10n.settingsCommonRange(kMinColumnWidth, kMaxColumnWidth),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                suffix: const Center(widthFactor: 1, child: Text('px')),
                onChanged: (t) => _onPx(t, layout.split),
                onSubmitted: (t) => _onPx(t, layout.split),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: RasqSpacing.xs),
                  child: Text(_error!, key: const ValueKey('columns.px.error'), style: RasqTypography.caption.copyWith(color: scheme.error)),
                ),
              RasqCaption(
                l.settingsColumnsShrinkCaption,
                detail: l.settingsColumnsShrinkDetail('$kMinColumnWidth'),
                padding: const EdgeInsets.only(top: RasqSpacing.xs),
              ),
            ]),
          ),
        const RasqSectionHeader(title: 'Swing'),
        RasqSwitchListTile(
          key: const ValueKey('columns.swingInColumn'),
          title: l.settingsColumnsSwingInColumnTitle,
          subtitle: l.settingsColumnsSwingInColumnSubtitle,
          value: ref.watch(swingInColumnProvider),
          onChanged: (v) => _store.set('swingInColumn', v),
        ),
        RasqSectionHeader(title: l.settingsColumnsCurrentHeader),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: wide
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _Preview(small: split.small, large: split.large),
                  const SizedBox(height: RasqSpacing.xs),
                  Text(l.settingsColumnsPreviewWidths('${split.small.round()}', '${split.large.round()}'), key: const ValueKey('columns.preview'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                ])
              : RasqCaption(
                  l.settingsColumnsNarrowCaption,
                  detail: l.settingsColumnsNarrowDetail('${RasqSizes.tabletBreakpoint.round()}'),
                  padding: EdgeInsets.zero,
                ),
        ),
      ]),
    );
  }
}

/// 小型 / 大型の比の見本(第3カラムにページを開いたときの並び: 左が小型)。
class _Preview extends StatelessWidget {
  const _Preview({required this.small, required this.large});
  final double small;
  final double large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget box(String label, double w) => Expanded(
          flex: w.round().clamp(1, 1 << 20),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(6), color: scheme.surfaceContainerHighest),
            child: Text(label, style: RasqTypography.caption, overflow: TextOverflow.ellipsis),
          ),
        );
    return Row(children: [box(context.l10n.settingsColumnsPreviewSmall, small), const SizedBox(width: RasqSpacing.xs), box(context.l10n.settingsColumnsPreviewLarge, large)]);
  }
}
