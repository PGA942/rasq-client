import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

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
    return Scaffold(
      appBar: const RasqPageHeader(title: 'カラムの幅'),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
          child: Text(
            '幅の広い画面(タブレット / デスクトップ / Web)で、小型カラム(検索や、ページを開いた側)と大型カラム(開いたページ)の幅の比を決めます。',
            style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const RasqSectionHeader(title: '小型 / 大型カラムの比'),
        for (final s in ColumnSplit.values)
          RasqRadioListTile<ColumnSplit>(
            key: ValueKey('columns.split.${s.name}'),
            title: s.label,
            subtitle: s == ColumnLayout.standard.split ? '${s.hint}(既定)' : s.hint,
            value: s,
            groupValue: layout.split,
            onChanged: (v) => _store.set('split', v.name),
          ),
        if (layout.split.fixed)
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(layout.split == ColumnSplit.largeFixed ? '大型カラムの幅' : '小型カラムの幅', style: RasqTypography.listTile),
              RasqInput(
                key: const ValueKey('columns.px'),
                controller: _px,
                focusNode: _focus,
                hintText: '$kMinColumnWidth〜$kMaxColumnWidth',
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
              Padding(
                padding: const EdgeInsets.only(top: RasqSpacing.xs),
                child: Text(
                  '画面が狭くて入らないときは、もう片方のカラムを $kMinColumnWidth px 以上残し、小型カラムが大型カラムより広くならないように縮めます。',
                  style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ]),
          ),
        const RasqSectionHeader(title: 'いまの画面での幅'),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: wide
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _Preview(small: split.small, large: split.large),
                  const SizedBox(height: RasqSpacing.xs),
                  Text('小型 ${split.small.round()} px / 大型 ${split.large.round()} px', key: const ValueKey('columns.preview'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                ])
              : Text(
                  'いまの画面は幅が狭いので、カラムを 1 つだけ出しています(${RasqSizes.tabletBreakpoint.round()} px 以上で小型 / 大型のカラムに分かれます)。',
                  style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
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
    return Row(children: [box('小型', small), const SizedBox(width: RasqSpacing.xs), box('大型', large)]);
  }
}
