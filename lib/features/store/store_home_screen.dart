import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../../shell/headers.dart';
import 'store_models.dart';
import 'store_providers.dart';

/// プラグインストアのホーム (M4 / D-120): 検索 + 今週のトレンド/最近の更新 +
/// インストール済み。掲載は審査済みのみ(D-004 ② — サイドロードは別導線)。
class StoreHomeScreen extends ConsumerStatefulWidget {
  const StoreHomeScreen({super.key});
  @override
  ConsumerState<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class _StoreHomeScreenState extends ConsumerState<StoreHomeScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      final q = _search.text.trim();
      if (q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final home = ref.watch(storeHomeProvider);
    final installed = ref.watch(installedPluginsProvider);
    final results = _query.isEmpty ? null : ref.watch(storeSearchProvider(_query));

    Widget tile(StorePluginCard c) => _StoreCardTile(card: c, installed: installed.any((p) => p.id == c.id), onTap: () => context.push(Routes.storePlugin(c.id)));

    return Scaffold(
      appBar: RasqPageHeader(title: 'プラグインストア', onMore: () {}),
      body: Column(children: [
        // 検索欄は検索ホームと同じ作法(入力欄 = RasqExpandableSearchBox)。
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.xs),
          child: RasqExpandableSearchBox(
            expanded: false,
            controller: _search,
            focusNode: _focus,
            hintText: 'プラグインを検索',
          ),
        ),
        Expanded(
          child: results != null
              ? results.when(
                  loading: () => const RasqLoading(),
                  error: (e, _) => RasqEmptyView(title: '検索できませんでした', hint: '$e'),
                  data: (items) => items.isEmpty
                      ? const RasqEmptyView(title: '見つかりませんでした', hint: 'ワードを変えてみてください')
                      : ListView(children: [for (final c in items) ...[tile(c), const Divider(height: 1)]]),
                )
              : home.when(
                  loading: () => const RasqLoading(),
                  error: (e, _) => RasqEmptyView(title: 'ストアに接続できませんでした', hint: '$e'),
                  data: (h) => ListView(children: [
                    if (installed.isNotEmpty) ...[
                      const RasqSectionHeader(title: 'インストール済み', topMargin: 0),
                      for (final p in installed)
                        RasqPluginTile(
                          icon: Icons.extension,
                          title: p.name,
                          subtitle: 'v${p.version} ・ 検証済み SHA-512',
                          onTap: () => context.push(Routes.storePlugin(p.id)),
                        ),
                      const Divider(height: 1),
                    ],
                    const RasqSectionHeader(title: '今週のトレンド', topMargin: 0),
                    for (final c in h.trending) ...[tile(c), const Divider(height: 1)],
                    const RasqSectionHeader(title: '最近の更新', topMargin: 0),
                    for (final c in h.recent) ...[tile(c), const Divider(height: 1)],
                    Padding(
                      padding: const EdgeInsets.all(RasqSpacing.page),
                      child: Text('掲載されるのは審査済みのプラグインだけです。開発中のプラグインは「WASMプラグイン試験」からインポートできます。',
                          style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                  ]),
                ),
        ),
      ]),
    );
  }
}

/// 一覧カードの共用タイル: RasqPluginTile(D-093 の使い回し先そのもの)。
class _StoreCardTile extends StatelessWidget {
  const _StoreCardTile({required this.card, required this.installed, required this.onTap});
  final StorePluginCard card;
  final bool installed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RasqTokens.of(context);
    final statusNote = card.status == PluginStatus.published ? null : card.status.label;
    return RasqPluginTile(
      icon: Icons.extension_outlined,
      title: card.name,
      subtitle: [card.origin.label, 'v${card.version}', ?statusNote, if (installed) 'インストール済み'].join(' ・ '),
      description: card.summary,
      detail: '★${card.rating.toStringAsFixed(1)} ・ ${_formatDownloads(card.downloads)} DL ・ ${card.sizeMb.toStringAsFixed(1)}MB ・ ${card.price == 0 ? '無料' : '¥${card.price.toStringAsFixed(0)}'}${card.hasAds ? ' ・ 広告あり' : ''}',
      detailColorDots: [if (card.status.isCaution) tokens.danger],
      onTap: onTap,
    );
  }
}

String _formatDownloads(int n) => n >= 10000 ? '${(n / 10000).toStringAsFixed(1)}万' : '$n';
