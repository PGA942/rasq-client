import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../../shell/headers.dart';
import '../settings/settings_dsl.dart';
import 'store_models.dart';
import 'store_providers.dart';
import 'store_tile.dart';

/// ストアホームの表示設定(KV `store.home.v1`)。`showInstalled` = インストール済みもタイルの列に出す(既定は出さない)。
const storeHomeArea = 'store.home';

/// インストール済みもホームに出すか (D-353)。
final storeHomeShowInstalledProvider = Provider<bool>((ref) => ref.watch(settingsAreaProvider(storeHomeArea)).value?['showInstalled'] == true);

/// 1 つの列に並べる数(ユーザー指定: 7 個くらい)。
const storeHomeRowLength = 7;

/// プラグインストアのホーム (M4 / D-120 → D-353): 検索欄(タップで検索画面へ)+ **今週のトレンド / 新着** の横の列
/// (AsTell のホームと同じ並べ方、1 列 7 個まで)。タイル = [StorePluginTile]。インストール済みは既定で出さない
/// (設定 = 右上の歯車 → プラグインを管理 →「インストール済みもホームに出す」)。掲載は審査済みのみ(D-004 ②)。
class StoreHomeScreen extends ConsumerWidget {
  const StoreHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final home = ref.watch(storeHomeProvider);
    final installed = {for (final p in ref.watch(installedPluginsProvider)) p.id};
    final showInstalled = ref.watch(storeHomeShowInstalledProvider);

    List<StorePluginCard> pick(List<StorePluginCard> cards) => [for (final c in cards) if (showInstalled || !installed.contains(c.id)) c].take(storeHomeRowLength).toList();

    return Scaffold(
      appBar: RasqPageHeader(
        title: 'プラグインストア',
        // … の代わりに歯車 (D-353)。
        showMore: false,
        actions: [
          RasqIconButton(key: const ValueKey('store.home.manage'), icon: Icons.settings_outlined, tooltip: 'プラグインを管理', onPressed: () => context.push(Routes.storeManage)),
        ],
      ),
      body: Column(children: [
        // 検索欄は他の検索画面と同じ部品(RasqExpandableSearchBox)。ここでは押すと検索画面へ。
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.xs),
          child: RasqExpandableSearchBox(
            key: const ValueKey('store.home.search'),
            expanded: false,
            readOnly: true,
            hintText: 'プラグインを検索',
            onTap: () => context.push(Routes.storeSearch()),
          ),
        ),
        Expanded(
          child: home.when(
            loading: () => const RasqLoading(),
            error: (e, _) => RasqEmptyView(title: 'ストアに接続できませんでした', hint: '$e'),
            data: (h) {
              final trending = pick(h.trending);
              final recent = pick(h.recent);
              return RefreshIndicator(
                onRefresh: () => ref.refresh(storeHomeProvider.future),
                child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                  StoreTileRow(key: const ValueKey('store.home.trending'), title: '今週のトレンド', cards: trending, installed: installed),
                  StoreTileRow(key: const ValueKey('store.home.recent'), title: '新着', cards: recent, installed: installed),
                  Padding(
                    padding: const EdgeInsets.all(RasqSpacing.page),
                    child: Text('掲載されるのは審査済みのプラグインだけです。開発中のプラグインは、右上の歯車 → プラグインを管理 →「プラグインのインポート」から入れられます。',
                        style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// 見出し + タイルの横の列。空なら案内だけ。
class StoreTileRow extends StatelessWidget {
  const StoreTileRow({super.key, required this.title, required this.cards, required this.installed});
  final String title;
  final List<StorePluginCard> cards;
  final Set<String> installed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 狭い画面(スマホ)ではタイルを画面幅に合わせて縮める(横は少し先が見えるように)。
    final width = (MediaQuery.sizeOf(context).width - RasqSpacing.page * 2 - 24).clamp(260.0, storeTileWidth);
    final height = width * storeTileHeight / storeTileWidth;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RasqSectionHeader(title: title, topMargin: RasqSpacing.sm),
      if (cards.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
          child: Text('いまは表示できるプラグインがありません', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        )
      else
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: RasqSpacing.sm),
            itemBuilder: (context, i) => StorePluginTile(
              card: cards[i],
              installed: installed.contains(cards[i].id),
              width: width,
              height: height,
              onTap: () => context.push(Routes.storePlugin(cards[i].id)),
            ),
          ),
        ),
    ]);
  }
}
