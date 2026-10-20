import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

import '../ads/export_ad.dart';
import '../settings/settings_dsl.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../nodeprog/tl_components.dart' show trendPageConfig, trendTilesScope;
import '../nodeprog/tl_config_store.dart' show tlViewConfigProvider;
import '../nodeprog/tl_sections_view.dart' show TlBlocks, tlSectionsRefreshProvider;
import '../../shell/rasq_shell.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../child_safe/child_safe_screens.dart' show ChildSafeBlockedView, ChildSafeGreyed;
import '../trend/tendency_fows.dart';
import '../servers/server_badge.dart';
import '../trend/trend_menu.dart';
import '../trend/trend_reports.dart' show hiddenTrendKeysProvider;
import '../trend/trend_restrictions.dart' show trendRestrictionFilterProvider, trendRestrictionsProvider;
import '../trend/trend_providers.dart';
import 'search_filter.dart';
import 'search_history.dart';
import 'search_filter_bar_view.dart';
import '../../l10n/l10n.dart';

/// 検索欄へのフォーカスの頼み (D-483: ホーム画面のショートカット「検索」)。検索タブ(第2カラム / 狭い画面)の [SearchScreen] が受ける
/// (第3カラムの検索は受けない)。まだ作られていなければ(起動直後)、作られたときに 1 度だけ受ける。
class SearchFocusRequests extends ChangeNotifier {
  bool _pending = false;

  /// 受けていない頼みがあれば true を返して消す。
  bool take() {
    final p = _pending;
    _pending = false;
    return p;
  }

  void request() {
    _pending = true;
    notifyListeners();
  }
}

final searchFocusRequestsProvider = Provider<SearchFocusRequests>((ref) {
  final r = SearchFocusRequests();
  ref.onDispose(r.dispose);
  return r;
});

/// 検索ホーム / トレンドホーム = トレンドページ (D-443): 広告枠(AdSlot) → トレンドページの構成の並び(既定は「トレンド」
/// (ワード一覧)と「Today」のセクション → 「検索の候補」= トレンドプラグインのノード)。
/// トレンドプラグインのサジェストは D-470 から並びのノード(`trendplugin:`、[trendPageConfig] が前の構成にも足す)。前は並びの後ろの固定の置き場だった。
/// Phase-1 sample sources trends from the SNS (`hashtags/trend`) and Today
/// from `notes/featured` until the trend provider / server exists.
///
/// 検索欄にフォーカスが当たると下方向に拡幅して検索フィルタ行が現れる
/// (D-021。設定後は常時表示、結果画面のトレンドTLへ引き継がれる)。
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.inThirdColumn = false, this.searchTrailing, this.showAccountIcon = true});

  /// 第3カラムの検索 (D-397): 左カラムと同じアカウントで動く。個別の SNS アカウントを選んでいる間は、アイコンも
  /// トレンドもその SNS アカウントのもの(総合表示 = RASQ アカウントのときは D-388 のとおり全部から集める)。
  final bool inThirdColumn;

  /// 検索欄の横に置く部品(第3カラムの設定ボタン、D-397)。
  final Widget? searchTrailing;

  /// 検索欄の左にアカウントのアイコンを出すか (D-411)。第3カラムの検索では出さない(左カラムのヘッダーに同じアイコンがある)。
  final bool showAccountIcon;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// 運営の制限 (D-404) を 10 分おきに読み直す。
  Timer? _restrictionsTimer;

  /// ショートカットの「検索」(D-483)。第3カラムの検索では null(受けない)。
  SearchFocusRequests? _focusRequests;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _restrictionsTimer = Timer.periodic(const Duration(minutes: 10), (_) => ref.invalidate(trendRestrictionsProvider));
    if (!widget.inThirdColumn) {
      final requests = ref.read(searchFocusRequestsProvider);
      _focusRequests = requests;
      requests.addListener(_onFocusRequest);
      if (requests.take()) WidgetsBinding.instance.addPostFrameCallback((_) => _focusField());
    }
  }

  void _onFocusRequest() {
    if (_focusRequests?.take() ?? false) WidgetsBinding.instance.addPostFrameCallback((_) => _focusField());
  }

  void _focusField() {
    if (mounted) _focus.requestFocus();
  }

  @override
  void dispose() {
    _focusRequests?.removeListener(_onFocusRequest);
    _restrictionsTimer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 第3カラムでは左カラム(ホームのヘッダー)と同じ: 総合表示なら RASQ アカウント、個別なら SNS アカウント (D-397)。
    final single = widget.inThirdColumn && !ref.watch(bundleViewProvider);
    final me = single ? ref.watch(currentUserProvider) : ref.watch(rasqAccountProvider);
    var trends = ref.watch(trendFrameTagsProvider); // トレンド枠ノード対応 (D-113)
    if (single) {
      // 個別の SNS アカウントのときは、そのアカウントが出したトレンドだけ(出どころの分からない枠の語は残す)。
      final current = ref.watch(currentAccountProvider);
      final sources = ref.watch(sourcedTrendsProvider).value?.sources;
      if (sources != null) trends = trends.whenData((list) => [for (final t in list) if (sources[trendKey(t.tag)]?.contains(current) ?? true) t]);
    }
    // 通報したトレンドは出さない (D-402)。通報の直後のスナックバーで戻せる。
    final hidden = ref.watch(hiddenTrendKeysProvider);
    if (hidden.isNotEmpty) trends = trends.whenData((list) => [for (final t in list) if (!hidden.contains(trendKey(t.tag))) t]);
    // 運営が制限したトレンド (D-404): 点数がこの端末の EmoM の閾値より大きい(オーバーフローは常に)ものは並べない。
    // 出どころのサーバー(D-388)ごとの制限と、サーバーを限らない制限を見る。印は出さない。
    final restricted = ref.watch(trendRestrictionFilterProvider);
    final allSources = ref.watch(sourcedTrendsProvider).value?.sources;
    final here = ref.watch(currentAccountProvider);
    trends = trends.whenData((list) => [
          for (final t in list)
            if (!restricted(t.tag, [for (final a in allSources?[trendKey(t.tag)] ?? [?here]) a.instance])) t,
        ]);
    final genreCandidates = trends.value?.map((t) => t.tag).take(maxGenreChips).toList() ?? const <String>[];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // 検索ボックス一体型(D-021 改): フォーカスで下方向に拡幅する角丸タイル。
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.xs),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.showAccountIcon) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  // 検索は RASQ アカウントでまとめる (D-388): トレンドは中の SNS アカウント全部から集めるので、アイコンも RASQ アカウント。
                  child: RasqAvatar(key: const ValueKey('search.account'), imageUrl: me.avatarUrl, size: RasqSizes.avatarSm, fallbackLabel: me.displayName, onTap: () => RasqShell.openSidebar(context, ref)),
                ),
                const SizedBox(width: RasqSpacing.sm),
              ],
              Expanded(
                // チャイルドセーフ (D-307): 保護者が投稿の検索を止めていれば、入力欄を薄くして理由を出す。
                child: ChildSafeGreyed(
                  reason: ref.watch(childGateProvider).searchAllowed('posts') ? null : context.l10n.searchChildSafePostsBlocked,
                  child: SearchFilterBox(
                  controller: _controller,
                  focusNode: _focus,
                  genreCandidates: genreCandidates,
                  onSubmitted: (q) {
                    final tag = q.trim().replaceFirst(RegExp(r'^#'), '');
                    if (tag.isEmpty) return;
                    // 最近の検索 (D-259): 掛けていたジャンルの絞り込みも一緒に控える。
                    ref.read(searchHistoryProvider.notifier).record(tag, chips: ref.read(searchFilterProvider).genres);
                    context.pushTrend(tag);
                  },
                ),
                ),
              ),
              // 第3カラムの設定 (D-397): 検索欄の横。
              if (widget.searchTrailing case final trailing?) Padding(padding: const EdgeInsets.only(left: 4, top: 2), child: trailing),
            ]),
          ),
          Expanded(child: _home(context, trends)),
        ]),
      ),
    );
  }

  Widget _home(BuildContext context, AsyncValue<List<TrendTag>> trends) {
    // チャイルドセーフ (D-307): トレンドを止めていれば、トレンドと Today を出さない。
    if (!ref.watch(childGateProvider).searchAllowed('trend')) return ChildSafeBlockedView(message: context.l10n.searchChildSafeTrendBlocked);
    // トレンドページの並び (D-443): トレンドページのカスタマイズの「SNSタイムライン」の順。
    final page = trendPageConfig(ref.watch(tlViewConfigProvider(trendTilesScope)));
    final nodes = [for (final s in page.sources) if (s.enabled) s];
    // トレンドプロファイル設定 (D-153、傾向 FOW): ジャンル / 指向性・刺激性 / プラグイン / キャッシュ / ノード編集。
    // 歯車 = トレンドページのカスタマイズ (D-431 → D-443、TL のカスタマイズと同じ画面。傾向はトレンドのタイルの一番最後に固定で掛かる)。
    final settings = Row(mainAxisSize: MainAxisSize.min, children: [
      RasqIconButton(key: const ValueKey('trend.tendency'), icon: Icons.tune, size: 20, onPressed: () => showTrendProfileSheet(context, ref), tooltip: context.l10n.searchTrendSettings),
      RasqIconButton(key: const ValueKey('trend.customize'), icon: Icons.settings, size: 20, onPressed: () => context.push(Routes.tlConfig(trendTilesScope)), tooltip: context.l10n.searchTrendCustomize),
    ]);
    return RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(trendingTagsProvider);
          ref.invalidate(trendFrameTagsProvider);
          ref.invalidate(trendRestrictionsProvider);
          ref.read(tlSectionsRefreshProvider.notifier).bump(); // Today などのセクションの TL も
        },
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          // 広告の枠 (検索ホームの固定の位置、D-433: 前は灰色の「広告」の箱だけだった)。AdMob のバナー(テストの ID)。設定「リソースと広告」(D-238)
          // で消せる。子のアカウントと、出せない端末(デスクトップ / AdSense の ID の無い Web)では何も出さない。
          if (settingValue(ref, 'resources', 'showAds', true) != false) const Center(key: ValueKey('search.ad'), child: ExportAdSlot()),
          if (nodes.isEmpty) RasqSectionHeader(title: context.l10n.searchTrendPage, trailing: settings),
          TlBlocks(key: const ValueKey('search.blocks'), nodes: nodes, trends: trends, headerTrailing: (i) => i == 0 ? settings : null),
          const SizedBox(height: 80),
        ]),
      );
  }
}

/// 検索ホームのトレンドの行。タップ = **そのトレンドを出したアカウント**で開く (D-397)。「…」= 別のアカウントで開く / 通報。
class TrendTile extends ConsumerWidget {
  const TrendTile({super.key, required this.trend});
  final TrendTag trend;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final count = trend.postsCount ?? trend.usersCount;
    // どのサーバーのトレンドか (D-388): 以前の波形の代わりに「{サーバーのアイコン} サーバー名」(全部の SNS で)。
    final current = ref.watch(currentAccountProvider);
    final found = ref.watch(sourcedTrendsProvider).value?.sources[trendKey(trend.tag)];
    final sources = found ?? [?current];
    // 開くアカウント (D-397)。印もそのアカウントを先に出す。
    final openAs = trendOpenAccount(sources, current);
    final shown = [?openAs, for (final a in sources) if (a != openAs) a];
    return InkWell(
      key: ValueKey('trend.tile.${trend.tag}'),
      onTap: () => openTrendAs(context, ref, trend.tag, found == null ? null : openAs),
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trend.tag, style: RasqTypography.title.copyWith(fontSize: 16)),
              const SizedBox(height: 2),
              Row(children: [
                if (count != null) Flexible(child: Text('$count ${trend.postsCount != null ? 'Post' : 'Users'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))),
                const SizedBox(width: 12),
                // サーバーの印に場所を譲るので、関連ワードは入るだけ(はみ出したら …)。
                if (trend.related.isNotEmpty) Flexible(child: Text(trend.related.take(3).join('   '), maxLines: 1, overflow: TextOverflow.ellipsis, style: RasqTypography.bodySmall.copyWith(color: tokens.link))),
              ]),
            ]),
          ),
          // サーバーの印と「…」は右に詰める (D-430)。前は Flexible で、余った幅を左の列と半分ずつ分け、「…」の右に空きが残っていた。
          if (shown.isNotEmpty) ConstrainedBox(constraints: const BoxConstraints(maxWidth: 120), child: ServerBadge(key: ValueKey('trend.server.${trend.tag}'), account: shown.first, more: shown.length - 1)),
          Builder(builder: (bctx) {
            return RasqIconButton(
              key: ValueKey('trend.more.${trend.tag}'),
              icon: Icons.more_horiz,
              size: 18,
              tooltip: context.l10n.searchTrendMenu,
              onPressed: () {
                final box = bctx.findRenderObject() as RenderBox;
                showTrendMenu(context, ref, trend: trend, sources: sources, anchor: box.localToGlobal(Offset.zero) & box.size);
              },
            );
          }),
        ]),
      ),
    );
  }
}
