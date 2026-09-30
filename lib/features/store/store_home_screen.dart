import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../../backend/orgate_client.dart' show centralClientProvider;
import '../../shell/headers.dart';
import '../settings/settings_dsl.dart';
import 'store_client.dart' show StoreHomeSections;
import 'store_models.dart';
import 'store_providers.dart';
import 'store_refresh.dart';
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
class StoreHomeScreen extends ConsumerStatefulWidget {
  const StoreHomeScreen({super.key});

  @override
  ConsumerState<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

/// 非同期更新 (D-358): スワイプで読み直しても、並んでいるタイルは位置を変えない。開いてから新しく公開されたものだけを
/// 列の先頭に足す(「NEW」の札)。
class _StoreHomeScreenState extends ConsumerState<StoreHomeScreen> {
  List<StorePluginCard>? _trending;
  List<StorePluginCard>? _recent;
  final _known = <String>{};
  final _fresh = <String>{};

  StoreHomeSections? _seededFrom;

  /// 最初の読み込みで並べる。ほかの理由(アカウントの切り替えなど)で読み直されたら、同じく位置を保って足す(札は付けない)。
  void _seed(StoreHomeSections h) {
    if (identical(h, _seededFrom)) return;
    _seededFrom = h;
    if (_trending == null) {
      _trending = h.trending;
      _recent = h.recent;
    } else {
      final t = mergeFreshCards(_trending!, h.trending, _known);
      _trending = t.cards;
      _recent = mergeFreshCards(_recent!, h.recent, {..._known, ...t.added}).cards;
    }
    _known.addAll([for (final c in [...h.trending, ...h.recent, ...h.bookmarks]) c.id]);
  }

  Future<void> _refresh() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final StoreHomeSections next;
    try {
      next = await ref.read(storeClientProvider).home();
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('読み直せませんでした: $e')));
      return;
    }
    if (!mounted) return;
    final t = mergeFreshCards(_trending ?? const [], next.trending, _known);
    // トレンドで足したものは新着の列には重ねて足さない(同じものが 2 回「NEW」にならないように)。
    final r = mergeFreshCards(_recent ?? const [], next.recent, {..._known, ...t.added});
    setState(() {
      _trending = t.cards;
      _recent = r.cards;
      _fresh.addAll({...t.added, ...r.added});
      _known.addAll({...t.added, ...r.added, for (final c in next.bookmarks) c.id});
    });
    final n = t.added.length + r.added.length;
    messenger?.showSnackBar(SnackBar(content: Text(n == 0 ? '新しく公開されたプラグインはありません' : '新しく公開されたプラグインを $n 件追加しました')));
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(storeHomeProvider);
    final installed = {for (final p in ref.watch(installedPluginsProvider)) p.id: p.version};
    final showInstalled = ref.watch(storeHomeShowInstalledProvider);

    // 足したもの(NEW)は 7 個の枠の外(ぶんだけ列が伸びる)。
    List<StorePluginCard> pick(List<StorePluginCard> cards) {
      final visible = [for (final c in cards) if (showInstalled || !installed.containsKey(c.id)) c];
      final fresh = visible.where((c) => _fresh.contains(c.id)).length;
      return visible.take(storeHomeRowLength + fresh).toList();
    }

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
              _seed(h);
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                  // RASQ サーバーにつないでいない (D-393): アプリ同梱のプラグインだけを出していると伝える(作り物の掲載は出さない)。
                  if (ref.watch(centralClientProvider) == null)
                    const RasqNotice(
                      key: ValueKey('store.home.offline'),
                      margin: EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
                      text: 'RASQ サーバーにつながっていません。アプリに入っているプラグインだけを表示しています',
                      detail: 'Central 未接続: 同梱の実物(Misskey コネクタとスロットのサンプル)だけ。評価 / ダウンロード数 / レビュー / 購入はサーバーにつなぐと出ます。',
                    ),
                  if (_trending!.isNotEmpty) StoreTileRow(key: const ValueKey('store.home.trending'), title: '今週のトレンド', cards: pick(_trending!), installed: installed, fresh: _fresh),
                  StoreTileRow(key: const ValueKey('store.home.recent'), title: '新着', cards: pick(_recent!), installed: installed, fresh: _fresh),
                  const RasqNotice(
                    margin: EdgeInsets.all(RasqSpacing.page),
                    text: '掲載されるのは審査済みのプラグインだけです',
                    detail: '開発中のプラグインは、開発者モードで右上の歯車 → プラグインを管理 →「プラグインのインポート」から入れられます。',
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
  const StoreTileRow({super.key, required this.title, required this.cards, required this.installed, this.fresh = const {}});
  final String title;
  final List<StorePluginCard> cards;

  /// 入っているプラグインの id → 版(タイルのボタン: 開く / 更新)。
  final Map<String, String> installed;

  /// 読み直しで新しく足したもの(「NEW」の札、D-358)。
  final Set<String> fresh;

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
            itemBuilder: (context, i) => StoreFreshMark(
              key: ValueKey('store.slot.${cards[i].id}'),
              fresh: fresh.contains(cards[i].id),
              child: StorePluginTile(
                card: cards[i],
                installedVersion: installed[cards[i].id],
                width: width,
                height: height,
                onTap: () => context.push(Routes.storePlugin(cards[i].id)),
              ),
            ),
          ),
        ),
    ]);
  }
}
