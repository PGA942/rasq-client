import 'package:flutter/material.dart';

import '../tokens/sizes.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// One chip of the search filter area. Dropdown-style chips get the tap
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

/// スタジアム形(両端が丸い)フィルタチップ。展開タイルの中に**入れ子**で
/// 置かれる(角丸タイル内のさらに丸いボタン、2026-08-25 レビュー)。
class RasqFilterChip extends StatelessWidget {
  const RasqFilterChip({super.key, required this.item});
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

/// 検索ボックス一体型のフィルタ UI (D-021 改, 2026-08-25 レビュー反映)。
///
/// 折りたたみ時は丸い検索バー。**展開すると入力欄が下方向に伸び、同じ角丸
/// タイルの中に**ソート/期間チップと、入れ子のスタジアム形ジャンルボタンが
/// 入る(検索バーの下に別 UI がぶら下がる形はやめた)。展開条件はホスト側
/// (フォーカス中 / ∨ トグル / フィルタ適用中)。
class RasqExpandableSearchBox extends StatelessWidget {
  const RasqExpandableSearchBox({
    super.key,
    required this.expanded,
    this.controller,
    this.focusNode,
    this.hintText = '検索',
    this.readOnly = false,
    this.onSubmitted,
    this.onTap,
    this.onDropdownTap,
    this.filterChips = const [],
    this.genreChips = const [],
    this.onReset,
    this.trailing,
  });

  final bool expanded;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final bool readOnly;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  /// 先頭の `∨`(フィルタ部のトグル)。
  final VoidCallback? onDropdownTap;

  /// 並び替え/期間などのドロップダウンチップ。
  final List<RasqFilterChipItem> filterChips;

  /// ジャンルのトグルチップ(スタジアム形、Wrap で折り返し)。
  final List<RasqFilterChipItem> genreChips;

  /// フィルタ適用中のみ渡す(「リセット」を出す)。
  final VoidCallback? onReset;

  /// フィルタ行末尾の固定ウィジェット(⚙ など)。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const barHeight = RasqSizes.searchBarHeight;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        border: Border.all(color: scheme.onSurface, width: 1.2),
        borderRadius: BorderRadius.circular(expanded ? RasqSizes.radiusLg : barHeight),
        color: scheme.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: barHeight,
          child: Row(children: [
            SizedBox(
              width: RasqSizes.minTap,
              height: barHeight,
              child: InkWell(
                onTap: onDropdownTap,
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 160),
                  turns: expanded ? 0.5 : 0,
                  child: Icon(Icons.keyboard_arrow_down, size: 20, color: scheme.onSurface),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                readOnly: readOnly,
                onSubmitted: onSubmitted,
                onTap: onTap,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
                decoration: InputDecoration(
                  hintText: hintText,
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: RasqSizes.minTap),
          ]),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !expanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(RasqSpacing.md, 0, RasqSpacing.sm, RasqSpacing.sm),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Divider(height: 1, color: scheme.outlineVariant),
                    const SizedBox(height: RasqSpacing.sm),
                    Row(children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [
                            for (final chip in filterChips) Padding(padding: const EdgeInsets.only(right: RasqSpacing.sm), child: RasqFilterChip(item: chip)),
                            ?switch (onReset) { null => null, final reset => RasqFilterChip(item: RasqFilterChipItem(label: 'リセット', onTap: reset)) },
                          ]),
                        ),
                      ),
                      ?trailing,
                    ]),
                    if (genreChips.isNotEmpty) ...[
                      const SizedBox(height: RasqSpacing.sm),
                      Wrap(spacing: RasqSpacing.sm, runSpacing: RasqSpacing.xs, children: [
                        for (final g in genreChips) RasqFilterChip(item: g),
                      ]),
                    ],
                  ]),
                ),
        ),
      ]),
    );
  }
}
