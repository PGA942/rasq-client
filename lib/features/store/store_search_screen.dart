import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../../shell/headers.dart';
import 'store_models.dart';
import 'store_providers.dart';
import 'store_tile.dart';

/// プラグインの検索画面 (D-353): 入力欄は他の検索画面と同じ部品(RasqExpandableSearchBox。∨ で絞り込みのチップ =
/// 無料 / 広告なし / 公式 / 認証済み / 30 日以内 / 軽量 / オフライン)、結果はプラグインタイル([StorePluginTile])のグリッド。
/// 語が空なら全部(ストアの並び)。検索ではインストール済みも出す(タイルに印)。
class StoreSearchScreen extends ConsumerStatefulWidget {
  const StoreSearchScreen({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  ConsumerState<StoreSearchScreen> createState() => _StoreSearchScreenState();
}

class _StoreSearchScreenState extends ConsumerState<StoreSearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  final _focus = FocusNode();
  late String _query = widget.initialQuery.trim();
  final _filters = <StoreFilter>{};
  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final q = _controller.text.trim();
      if (q != _query) setState(() => _query = q);
    });
    // ホームの欄から来たら、すぐ打てるように。
    if (widget.initialQuery.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _focus.requestFocus() : null);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final installed = {for (final p in ref.watch(installedPluginsProvider)) p.id};
    final key = (q: _query, filters: [for (final f in StoreFilter.values) if (_filters.contains(f)) f.wire].join(','));
    final results = ref.watch(storeFilteredSearchProvider(key));
    return Scaffold(
      appBar: const RasqPageHeader(title: 'プラグインを検索', showMore: false),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.xs),
          child: RasqExpandableSearchBox(
            key: const ValueKey('store.search.box'),
            expanded: _filtersOpen || _filters.isNotEmpty,
            controller: _controller,
            focusNode: _focus,
            hintText: 'プラグインを検索',
            onDropdownTap: () => setState(() => _filtersOpen = !_filtersOpen),
            filterChips: [
              for (final f in StoreFilter.values)
                RasqFilterChipItem(
                  label: f.label,
                  selected: _filters.contains(f),
                  onTap: () => setState(() => _filters.contains(f) ? _filters.remove(f) : _filters.add(f)),
                ),
            ],
          ),
        ),
        Expanded(
          child: results.when(
            loading: () => const RasqLoading(),
            error: (e, _) => RasqEmptyView(title: '検索できませんでした', hint: '$e'),
            data: (items) => items.isEmpty
                ? const RasqEmptyView(title: '見つかりませんでした', hint: 'ワードや絞り込みを変えてみてください')
                : GridView.builder(
                    key: const ValueKey('store.search.grid'),
                    padding: const EdgeInsets.all(RasqSpacing.page),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: storeTileWidth + 20,
                      childAspectRatio: storeTileWidth / storeTileHeight,
                      mainAxisSpacing: RasqSpacing.sm,
                      crossAxisSpacing: RasqSpacing.sm,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => LayoutBuilder(
                      builder: (context, box) => StorePluginTile(
                        card: items[i],
                        installed: installed.contains(items[i].id),
                        width: box.maxWidth,
                        height: box.maxHeight,
                        onTap: () => context.push(Routes.storePlugin(items[i].id)),
                      ),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}
