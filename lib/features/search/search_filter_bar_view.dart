import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import 'search_filter.dart';

/// 検索フィルタ行の配線 (D-021): [RasqSearchFilterBar] に共有状態
/// ([searchFilterProvider]) とドロップダウン・⚙ 設定シートを繋ぐ。
/// 検索ホーム(フォーカス連動)とトレンドTL(∨ トグル連動)で共用。
class SearchFilterBarView extends ConsumerWidget {
  const SearchFilterBarView({super.key, required this.expanded, this.genreCandidates = const []});

  /// 呼び出し側の展開条件(検索欄フォーカス中 / ∨ トグル)。dirty なら常時表示。
  final bool expanded;
  final List<String> genreCandidates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchFilterProvider);
    final manager = ref.watch(overlayManagerProvider);
    void update(SearchFilterState next) => ref.read(searchFilterProvider.notifier).set(next);

    return RasqSearchFilterBar(
      visible: expanded || filter.dirty,
      chips: buildSearchFilterChips(
        filter: filter,
        genreCandidates: genreCandidates,
        onSortTap: (rect) async {
          final s = await showSearchSortMenu(manager, rect, filter.sort);
          if (s != null) update(ref.read(searchFilterProvider).copyWith(sort: s));
        },
        onPeriodTap: (rect) async {
          final p = await showSearchPeriodMenu(manager, rect, filter.period);
          if (p != null) update(ref.read(searchFilterProvider).copyWith(period: p));
        },
        onGenreToggle: (g) => update(ref.read(searchFilterProvider).toggleGenre(g)),
      ),
      onReset: filter.dirty ? () => update(SearchFilterState.initial) : null,
      trailing: RasqIconButton(
        icon: Icons.settings_outlined,
        size: 18,
        tooltip: '検索の設定',
        onPressed: () => manager.showBottomSheet(
          id: 'search.settings',
          title: '検索の設定',
          builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
            RasqWarningListTile(title: '検索結果の指向性/刺激性', onTap: () => _placeholder(manager, '検索結果の指向性/刺激性')),
            RasqListTile(title: 'トレンドプラグインの設定', onTap: () => _placeholder(manager, 'トレンドプラグインの設定')),
            RasqListTile(title: 'キャッシュネットワークの設定', onTap: () => _placeholder(manager, 'キャッシュネットワークの設定'), divider: false),
          ]),
        ),
      ),
    );
  }

  Future<void> _placeholder(dynamic manager, String title) =>
      manager.showAlert(id: 'search.settings.placeholder', title: title, message: 'トレンド設定(M5)/プラグイン設定(M4)の実装時にここへ繋ぎます。', confirmText: 'OK');
}
