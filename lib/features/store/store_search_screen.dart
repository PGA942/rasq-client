import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import 'store_models.dart';
import 'store_providers.dart';
import 'store_refresh.dart';
import 'store_tile.dart';

/// プラグインの検索画面 (D-353): 入力欄は他の検索画面と同じ部品(RasqExpandableSearchBox。∨ で絞り込みのチップ =
/// 無料 / 広告なし / 公式 / 認証済み / 30 日以内 / 軽量 / オフライン)、結果はプラグインタイル([StorePluginTile])のグリッド。
/// 語が空なら全部(ストアの並び)。検索ではインストール済みも出す(タイルに印)。
/// D-358: チップ「最近の投稿内容から選出」、スワイプで読み直すと並びを保ったまま新しく公開されたものを先頭に足す。
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

  /// 「最近の投稿内容から選出」(D-358): 自分の最近の投稿に近いものだけを近い順に(端末の中で計算)。
  bool _recentPick = false;

  // 非同期更新 (D-358): いま並んでいるもの(語と絞り込みが同じ間は位置を保つ)と、見たことのある id、足したもの。
  String? _shownKey;
  List<StorePluginCard> _shown = const [];
  List<StorePluginCard>? _lastData;
  final _known = <String>{};
  final _fresh = <String>{};

  void _sync(String key, List<StorePluginCard> data) {
    if (identical(data, _lastData) && key == _shownKey) return;
    _lastData = data;
    if (key != _shownKey) {
      _shownKey = key;
      _shown = data;
      _known
        ..clear()
        ..addAll(data.map((c) => c.id));
      _fresh.clear();
      return;
    }
    final m = mergeFreshCards(_shown, data, _known);
    _shown = m.cards;
    _known.addAll(m.added);
  }

  Future<void> _refresh(({String q, String filters}) key) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final List<StorePluginCard> next;
    try {
      next = await ref.read(storeClientProvider).search(key.q, filters: {for (final f in StoreFilter.values) if (_filters.contains(f)) f});
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(appL10n.storeReloadFailed('$e'))));
      return;
    }
    if (!mounted) return;
    final m = mergeFreshCards(_shown, next, _known);
    setState(() {
      _shown = m.cards;
      _known.addAll(m.added);
      _fresh.addAll(m.added);
    });
    messenger?.showSnackBar(SnackBar(content: Text(m.added.isEmpty ? appL10n.storeNoNewPlugins : appL10n.storeNewPluginsAdded(m.added.length))));
  }

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
    final installed = {for (final p in ref.watch(installedPluginsProvider)) p.id: p.version};
    final key = (q: _query, filters: [for (final f in StoreFilter.values) if (_filters.contains(f)) f.wire].join(','));
    final results = ref.watch(storeFilteredSearchProvider(key));
    return Scaffold(
      appBar: RasqPageHeader(title: context.l10n.storeSearchTitle, showMore: false),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.xs),
          child: RasqExpandableSearchBox(
            key: const ValueKey('store.search.box'),
            expanded: _filtersOpen || _filters.isNotEmpty,
            controller: _controller,
            focusNode: _focus,
            hintText: context.l10n.storeSearchTitle,
            onDropdownTap: () => setState(() => _filtersOpen = !_filtersOpen),
            filterChips: [
              RasqFilterChipItem(label: context.l10n.storeSearchRecentPick, selected: _recentPick, onTap: () => setState(() => _recentPick = !_recentPick)),
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
            error: (e, _) => RasqEmptyView(title: context.l10n.storeSearchFailed, hint: '$e'),
            data: (data) {
              _sync('${key.q}\u0000${key.filters}', data);
              var items = _shown;
              String? caption;
              if (_recentPick) {
                final posts = ref.watch(storeRecentPostTextsProvider);
                if (!posts.hasValue) return const RasqLoading();
                final texts = posts.value!;
                if (texts.isEmpty) {
                  return RasqEmptyView(key: const ValueKey('store.search.recent.noPosts'), title: context.l10n.storeSearchNoRecentPosts, hint: context.l10n.storeSearchNoRecentPostsHint);
                }
                items = pickByRecentPosts(items, texts);
                caption = context.l10n.storeSearchRecentCaption(texts.length);
              }
              return RefreshIndicator(
                onRefresh: () => _refresh(key),
                child: items.isEmpty
                    ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                        _recentPick
                            ? RasqEmptyView(title: context.l10n.storeSearchNoRecentMatches, hint: context.l10n.storeSearchNoResultsHint)
                            : RasqEmptyView(title: context.l10n.storeSearchNoResults, hint: context.l10n.storeSearchNoResultsHint),
                      ])
                    : CustomScrollView(
                        key: const ValueKey('store.search.grid'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          if (caption != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
                                child: Text(caption, key: const ValueKey('store.search.recent.caption'), style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.all(RasqSpacing.page),
                            sliver: SliverGrid.builder(
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: storeTileWidth + 20,
                                childAspectRatio: storeTileWidth / storeTileHeight,
                                mainAxisSpacing: RasqSpacing.sm,
                                crossAxisSpacing: RasqSpacing.sm,
                              ),
                              itemCount: items.length,
                              itemBuilder: (context, i) => StoreFreshMark(
                                key: ValueKey('store.slot.${items[i].id}'),
                                fresh: _fresh.contains(items[i].id),
                                child: LayoutBuilder(
                                  builder: (context, box) => StorePluginTile(
                                    card: items[i],
                                    installedVersion: installed[items[i].id],
                                    width: box.maxWidth,
                                    height: box.maxHeight,
                                    onTap: () => context.push(Routes.storePlugin(items[i].id)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
