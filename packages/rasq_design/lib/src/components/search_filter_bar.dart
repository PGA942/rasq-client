import 'package:flutter/material.dart';

import '../tokens/sizes.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// One chip of the search filter bar. Dropdown-style chips get the tap
/// anchor rect (for the Overlay-Manager dropdown); toggle chips just flip.
@immutable
class RasqFilterChipItem {
  const RasqFilterChipItem({
    required this.label,
    this.selected = false,
    this.dropdown = false,
    this.onTap,
    this.onAnchorTap,
  });

  final String label;

  /// Filled style (適用中のフィルタが常に見える).
  final bool selected;

  /// Appends a `∨` and reports the anchor rect via [onAnchorTap].
  final bool dropdown;
  final VoidCallback? onTap;
  final ValueChanged<Rect>? onAnchorTap;
}

/// 検索フィルタ行 (検索ソートUI, D-021):
///
/// 検索欄に**カーソルが当たっている(入力中)**か、いずれかのフィルタが適用済み
/// (dirty)のときだけ、検索バーの下方向に拡幅して現れるチップ行。誤タップ防止の
/// ため常設はしない(原典: 2026-08-25 レビュー)。
///
/// - 並び替え/期間はドロップダウンチップ(`∨`、小型ドロップダウン = D-015 部品)
/// - ジャンルは **3 個までボタン(トグル)形式で直置き**、4 個目以降は `∨` に畳む
/// - フィルタ適用中は末尾に「リセット」
///
/// Props-only: 状態(選択中ソート・ジャンル)はホスト側が持つ。
class RasqSearchFilterBar extends StatelessWidget {
  const RasqSearchFilterBar({
    super.key,
    required this.visible,
    this.chips = const [],
    this.onReset,
    this.trailing,
  });

  /// フォーカス中 or dirty のとき true。false は高さ 0 に畳む。
  final bool visible;
  final List<RasqFilterChipItem> chips;

  /// 非 null で「リセット」チップを末尾に出す(dirty のときだけ渡す)。
  final VoidCallback? onReset;

  /// 行末の固定ウィジェット(例: ⚙ 検索設定)。
  final Widget? trailing;

  /// ジャンルをボタン直置きにする上限(それ以降は `∨` へ)。
  static const int maxInlineGenres = 3;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.sm, RasqSpacing.sm),
              child: Row(children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final chip in chips) Padding(padding: const EdgeInsets.only(right: RasqSpacing.sm), child: _Chip(item: chip)),
                      ?switch (onReset) { null => null, final reset => _Chip(item: RasqFilterChipItem(label: 'リセット', onTap: reset)) },
                    ]),
                  ),
                ),
                ?trailing,
              ]),
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.item});
  final RasqFilterChipItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = item.selected;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Builder(
        builder: (ctx) => Material(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          shape: StadiumBorder(side: BorderSide(color: selected ? scheme.primary : scheme.outline)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () {
              if (item.onAnchorTap != null) {
                final box = ctx.findRenderObject() as RenderBox;
                item.onAnchorTap!(box.localToGlobal(Offset.zero) & box.size);
              } else {
                item.onTap?.call();
              }
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32, minWidth: RasqSizes.minTap),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(item.label, style: RasqTypography.count.copyWith(color: selected ? scheme.onPrimaryContainer : scheme.onSurface)),
                  if (item.dropdown) Icon(Icons.keyboard_arrow_down, size: 16, color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
