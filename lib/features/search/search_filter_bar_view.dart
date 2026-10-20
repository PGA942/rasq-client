import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import 'search_filter.dart';
import '../../l10n/l10n.dart';

/// 検索ボックス(一体型展開タイル, D-021 改)の配線。
///
/// 展開条件: 入力欄フォーカス中 / 先頭 ∨ トグル / フィルタ適用中(常時)。
/// 展開部はソート・期間チップ + 入れ子のスタジアム形ジャンルボタン + ⚙。
/// 検索ホーム(avatar 横)とトレンドTL(← 横、編集可で検索を続けられる)で共用。
class SearchFilterBox extends ConsumerStatefulWidget {
  const SearchFilterBox({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.onSubmitted,
    this.genreCandidates = const [],
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  /// null = 「検索」。
  final String? hintText;
  final ValueChanged<String>? onSubmitted;
  final List<String> genreCandidates;

  @override
  ConsumerState<SearchFilterBox> createState() => _SearchFilterBoxState();
}

class _SearchFilterBoxState extends ConsumerState<SearchFilterBox> {
  bool _toggled = false;
  FocusNode? _ownedFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownedFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownedFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(searchFilterProvider);
    final manager = ref.watch(overlayManagerProvider);
    void update(SearchFilterState next) => ref.read(searchFilterProvider.notifier).set(next);

    return RasqExpandableSearchBox(
      expanded: _toggled || _focus.hasFocus || filter.dirty,
      controller: widget.controller,
      focusNode: _focus,
      hintText: widget.hintText ?? context.l10n.searchHint,
      onSubmitted: widget.onSubmitted,
      onDropdownTap: () => setState(() => _toggled = !_toggled),
      filterChips: buildSortPeriodChips(
        filter: filter,
        onSortTap: (rect) async {
          final s = await showSearchSortMenu(manager, rect, filter.sort);
          if (s != null) update(ref.read(searchFilterProvider).copyWith(sort: s));
        },
        onPeriodTap: (rect) async {
          final p = await showSearchPeriodMenu(manager, rect, filter.period);
          if (p != null) update(ref.read(searchFilterProvider).copyWith(period: p));
        },
      ),
      genreChips: buildGenreChips(
        filter: filter,
        genreCandidates: widget.genreCandidates,
        onGenreToggle: (g) => update(ref.read(searchFilterProvider).toggleGenre(g)),
      ),
      onReset: filter.dirty ? () => update(SearchFilterState.initial) : null,
      trailing: RasqIconButton(
        icon: Icons.settings_outlined,
        size: 18,
        tooltip: context.l10n.searchSettings,
        onPressed: () => manager.showBottomSheet(
          id: 'search.settings',
          title: context.l10n.searchSettings,
          builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
            RasqWarningListTile(title: ctx.l10n.searchSettingsTendency, onTap: () => _placeholder(manager, ctx.l10n.searchSettingsTendency)),
            RasqListTile(title: ctx.l10n.searchSettingsTrendPlugins, onTap: () => _placeholder(manager, ctx.l10n.searchSettingsTrendPlugins)),
            RasqListTile(title: ctx.l10n.searchSettingsCacheNetwork, onTap: () => _placeholder(manager, ctx.l10n.searchSettingsCacheNetwork), divider: false),
          ]),
        ),
      ),
    );
  }

  Future<void> _placeholder(OverlayManager manager, String title) =>
      manager.showAlert(id: 'search.settings.placeholder', title: title, message: appL10n.searchSettingsComingSoon, confirmText: 'OK');
}
