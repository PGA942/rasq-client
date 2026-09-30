import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plugin_runtime/plugin_runtime.dart' show CustomTimelineSpec, WasmSnsSession;
import 'package:rrl_renderer/rrl_renderer.dart' show rrlIconFor;
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../backend/rasq_account_page_api.dart';
import '../profile/rasq_post_tile.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_shell.dart';
import '../settings/settings_dsl.dart';
import '../nodeprog/node_tabs.dart';
import '../nodeprog/timeline_temp_fow.dart';
import '../nodeprog/tl_config_store.dart';
import '../relational/relational_timeline_view.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import 'custom_tile_row.dart';
import 'create_fow.dart';
import 'home_header.dart';
import 'post_row.dart';
import 'timeline_providers.dart';
import 'timeline_search.dart';

/// タイムライン一時変更 FOW (D-338) を開いている間の、FOW のタブ(スコープ `tl.<id>`)。ホームのタブと揃える。
final homeTimelineFowScope = ValueNotifier<String?>(null);

/// ホームTL. Tabs = おすすめ(social) / フォロー中(home) + plugin timelines
/// (ローカル/グローバル…) + 関連(リレーショナルTL, 保留 D-011).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 総合表示 (D-088): アカウントバンドル選択中はヘッダーが RASQ アカウント、
    // TL は全アカウント合流の「総合」+ 関連(関連は元からバンドル供給)。
    final bundle = ref.watch(bundleViewProvider);
    final me = bundle ? ref.watch(rasqAccountProvider) : ref.watch(currentUserProvider);
    final session = ref.watch(currentSnsSessionProvider);
    // カスタム TL (M5e / D-080): TL プラグインの宣言をタブに足す。
    final customs = ref.watch(customTimelinesProvider).value ?? const <CustomTimelineSpec>[];
    // ノードTLタブ (D-101): ノードエディタの「+」で作ったタブ。総合表示では
    // **全アカウント分を集合表示** (D-108、… メニューの設定でオフにできる)。
    final nodeTabs = ref.watch(nodeTabsProvider);
    // チャイルドセーフ (D-307): 見守りの時間は、全アカウントのグローバル TL を 1 本に合流した TL だけ
    // (フォロー中 / AsTell もここへ畳む)。AsTell を止めていればヘッダーの AsTell も出さない。
    final gate = ref.watch(childGateProvider);
    final window = gate.inTimeWindow;
    // タブの並び (D-339): 「タイムラインをカスタマイズ」のタブ行で並べ替えた順。
    final order = ref.watch(tlTabOrderProvider);
    final kinds = window
        ? const [childSafeWindowKind]
        : applyTlTabOrder(
            bundle
                ? [
                    TimelineKind.bundle,
                    TimelineKind.relational,
                    if (ref.watch(bundleNodeTabsVisibleProvider))
                      for (final (_, t) in ref.watch(allNodeTabsProvider)) TimelineKind(t.id, t.label),
                  ]
                : _tabKinds(session, customs, nodeTabs),
            (k) => 'tl.${k.id}',
            order);
    // `↓{タイムライン名}` (D-338): 選んでいるタブをもう一度押すと、タイムライン一時変更 FOW。関連(ルールベースの別の画面)と
    // 見守りの時間の TL は構成を持たないので出さない。一時変更中 / 探している TL はタブの名前の右肩に点。
    final temporary = ref.watch(tlTemporaryConfigsProvider);
    final searching = ref.watch(timelineSearchProvider);
    final tabs = [
      for (final k in kinds)
        RasqTabItem(
          _label(k),
          id: k.id,
          chevron: _hasTempFow(k),
          dot: temporary.containsKey('tl.${k.id}') || searching.containsKey(k.id),
        ),
    ];
    final initial = kinds.indexOf(bundle ? TimelineKind.bundle : TimelineKind.home).clamp(0, kinds.length - 1);
    // ヘッダー (D-377): 右上の ↑ でしまう(バーとタブ行を無くし、アイコン・新着・↓ だけを浮かべる)。
    final collapsed = ref.watch(homeHeaderCollapsedProvider);
    final astellInHeader = !(settingValue(ref, 'astell.tiles', 'headerStrip', true) == false || window || !gate.featureAllowed('astell.join'));
    void openSidebar() => RasqShell.openSidebar(context, ref);

    return DefaultTabController(
      // タブの数が変わる(見守りの時間の出入り)と作り直す。
      key: ValueKey('home.tabs.$window'),
      length: tabs.length,
      initialIndex: initial,
      // 開いているタブを並べ替え / 一時変更 FOW と揃える。
      child: _TabFollower(ids: [for (final k in kinds) k.id], child: Scaffold(
        // フォロー中のホストの AsTell (D-163) と Swing (D-377) のバンドルをヘッダーに並べる。しまっていればバーは無し。
        appBar: collapsed
            ? null
            : RasqHomeHeader(
                me: me,
                onAvatarTap: openSidebar,
                // Tell タイル (D-238、設定 `astell.tiles`): 出す / 出さないと並べる数。
                vcWidget: HomeHeaderStrip(astell: astellInHeader, max: ((settingValue(ref, 'astell.tiles', 'headerMax', 4) as num).round()).clamp(1, 8)),
                trailingIcon: Icons.keyboard_arrow_up,
                trailingTooltip: 'ヘッダーをしまう',
                trailingKey: const ValueKey('home.header.collapse'),
                onTrailingTap: () => setHomeHeaderCollapsed(ref, true),
              ),
        body: Stack(children: [
          Column(children: [
          if (!collapsed) Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
            child: Row(children: [
              Expanded(
                child: RasqTabs(
                  items: tabs,
                  // RAi の案内が指す名前 (D-384): 選んでいるタブの ∨ = タイムラインを一時変更。
                  chevronTooltip: 'タイムラインを一時変更',
                  onSelectedTabTap: (i, _) => showTimelineTempFow(
                    ref,
                    tabs: [for (final k in kinds) if (_hasTempFow(k)) ('tl.${k.id}', _label(k))],
                    scope: 'tl.${kinds[i].id}',
                    scopeSync: homeTimelineFowScope,
                  ),
                ),
              ),
              // RAi は TL のタブ行では隠す (D-103 でユーザーが指定 —
              // ノードエディタのパレット側にだけ置く)。
              // タイムライン設定 (D-090/D-121): 簡略版のカスタマイズ画面へ
              // (SNSタイムライン + アルゴリズムのコンポーネント積み。
              // 自由形ノードキャンバスは一旦無効化)。
              if (!window) Builder(builder: (ctx) {
                return RasqIconButton(
                  icon: Icons.settings,
                  size: 20,
                  tooltip: 'タイムライン設定',
                  onPressed: () {
                    final i = DefaultTabController.of(ctx).index.clamp(0, kinds.length - 1);
                    ctx.push(Routes.tlConfig('tl.${kinds[i].id}'));
                  },
                );
              }),
            ]),
          ),
          Expanded(
            child: TabBarView(children: [
              for (final k in kinds)
                if (k == TimelineKind.relational)
                  const RelationalTimelineView(key: ValueKey('tl.view.relational')) // D-022 v0 (ルールベース段)
                else
                  // 並べ替え (D-339) で位置が変わっても、TL ごとの State(スクロール位置)を取り違えない。
                  _TimelineView(key: ValueKey('tl.view.${k.id}'), kind: k),
            ]),
          ),
          ]),
          // しまったヘッダー: TL の上に浮かべる。
          if (collapsed)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: RasqFloatingHomeHeader(
                key: const ValueKey('home.header.floating'),
                me: me,
                onAvatarTap: openSidebar,
                arrivals: HomeHeaderArrivals(astell: astellInHeader),
                onExpand: () => setHomeHeaderCollapsed(ref, false),
              ),
            ),
        ]),
        // ＋ (D-381): タップ = 投稿、上へスワイプ = Swing、下へスワイプ = AsTell(設定で変えられる)。
        // 画面ごとに違う Hero のタグ (D-374): 既定のタグは、タブの画面が同じルームに並ぶと重なる。
        floatingActionButton: RadialCreateFab(scope: 'home', heroTag: 'fab.home', onPosted: () => ref.read(timelineProvider(TimelineKind.home).notifier).prependNewer()),
      )),
    );
  }

  static bool _hasTempFow(TimelineKind k) => k != TimelineKind.relational && k != childSafeWindowKind;

  static List<TimelineKind> _tabKinds(SnsSession? session, List<CustomTimelineSpec> customs, List<NodeTab> nodeTabs) {
    final supported = session?.timelines ?? const [TimelineKind.home];
    final out = <TimelineKind>[];
    if (supported.contains(TimelineKind.social)) out.add(TimelineKind.social);
    if (supported.contains(TimelineKind.home)) out.add(TimelineKind.home);
    out.add(TimelineKind.relational);
    for (final k in supported) {
      if (!out.contains(k)) out.add(k);
    }
    // カスタム TL (M5e / D-080): TL プラグイン宣言のタブ。
    for (final c in customs) {
      if (c.id.startsWith('slot:')) continue; // スロットの TL プラグインはタブではなくアルゴリズム部品 (D-169)
      out.add(TimelineKind('custom:${c.id}', c.label));
    }
    // ノードTLタブ (D-101): 中身はノードグラフの実行結果。
    for (final t in nodeTabs) {
      out.add(TimelineKind(t.id, t.label));
    }
    return out.take(RasqTabs.maxExtensible).toList();
  }

  static String _label(TimelineKind k) => k == TimelineKind.social ? 'おすすめ' : k.label;
}

/// 開いているタブを揃える: 並べ替え (D-339) のあとも同じ TL を開いたまま、一時変更 FOW (D-338) のタブとホームのタブを
/// 行き来させる([homeTimelineFowScope])。タブが増減したとき(アカウントの読み込み、総合表示の出入り)は今までどおり
/// 位置のまま(DefaultTabController に任せる)。
class _TabFollower extends StatefulWidget {
  const _TabFollower({required this.ids, required this.child});
  final List<String> ids;
  final Widget child;
  @override
  State<_TabFollower> createState() => _TabFollowerState();
}

class _TabFollowerState extends State<_TabFollower> {
  TabController? _ctrl;
  String? _selected;

  @override
  void initState() {
    super.initState();
    homeTimelineFowScope.addListener(_onFowScope);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = DefaultTabController.of(context);
    if (c == _ctrl) return;
    _ctrl?.removeListener(_onTab);
    _ctrl = c..addListener(_onTab);
    _selected = c.index < widget.ids.length ? widget.ids[c.index] : null;
  }

  @override
  void didUpdateWidget(_TabFollower old) {
    super.didUpdateWidget(old);
    if (listEquals(old.ids, widget.ids)) return;
    // 並べ替えだけ(同じタブの組)なら、開いていた TL の新しい位置へ。増減は位置のまま。
    if (old.ids.length == widget.ids.length && old.ids.toSet().containsAll(widget.ids)) {
      _follow();
    } else {
      final ctrl = _ctrl!;
      _selected = ctrl.index < widget.ids.length ? widget.ids[ctrl.index] : null;
    }
  }

  @override
  void dispose() {
    homeTimelineFowScope.removeListener(_onFowScope);
    _ctrl?.removeListener(_onTab);
    super.dispose();
  }

  /// 開いていた TL の新しい位置へ(描いている最中には動かせないので、描き終えてから)。
  void _follow() {
    final ctrl = _ctrl!;
    final i = _selected == null ? -1 : widget.ids.indexOf(_selected!);
    if (i < 0 || i == ctrl.index) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ctrl == ctrl && i < ctrl.length) ctrl.index = i;
    });
  }

  void _onTab() {
    final ctrl = _ctrl!;
    if (ctrl.indexIsChanging || ctrl.index >= widget.ids.length) return;
    _selected = widget.ids[ctrl.index];
    if (homeTimelineFowScope.value != null) homeTimelineFowScope.value = 'tl.$_selected';
  }

  void _onFowScope() {
    final scope = homeTimelineFowScope.value;
    if (scope == null || !scope.startsWith('tl.')) return;
    final i = widget.ids.indexOf(scope.substring(3));
    if (i >= 0 && i != _ctrl?.index) _ctrl?.animateTo(i);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TimelineView extends ConsumerStatefulWidget {
  const _TimelineView({super.key, required this.kind});
  final TimelineKind kind;
  @override
  ConsumerState<_TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<_TimelineView> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();

  /// 探す語の ↑↓ で飛ぶ (D-341)。
  final _jumper = TimelineJumpController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) ref.read(timelineProvider(widget.kind).notifier).loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _jumper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(timelineProvider(widget.kind));
    final session = ref.watch(currentSnsSessionProvider);
    final notifier = ref.read(timelineProvider(widget.kind).notifier);
    final actions = session?.actions ?? const <ActionDescriptor>[];
    // 上下の「投稿を読み込む」(D-298)。電話のアプリは既定で出さない(引っ張って更新 / スクロールで続きを読む。D-316)。
    final edgeTiles = ref.watch(timelineEdgeTilesProvider);
    // タイムライン本体から探す (D-341): TL は絞らず、一時変更 FOW の ↑↓ で合う投稿へ飛ぶ。
    ref.listen(timelineSearchNavProvider, (prev, next) {
      if (next == null || next.timelineId != widget.kind.id || next.seq == prev?.seq) return;
      final posts = ref.read(timelineProvider(widget.kind)).value?.posts;
      if (posts != null) handleTimelineSearchNav(ref, next, jumper: _jumper, scroll: _scroll, posts: posts);
    });

    return state.when(
      loading: () => const RasqLoading(),
      error: (e, _) => _ErrorList(error: e, onRetry: notifier.refresh),
      data: (tl) {
        if (tl.posts.isEmpty) {
          return RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 120), RasqEmptyView(title: '投稿はありません', hint: '下に引っ張って更新')]),
          );
        }
        // 並びは 2 つの sliver (D-298): **中心 (center) より上に、あとから足された新しい投稿**、中心から下に、もとの投稿。
        // 上に足しても中心は動かないので、見ている位置はそのまま(上へスクロールすると、新しいぶんが出てくる)。
        // もとの先頭の投稿が一覧から消えた(置き換わった)ら、中心を作り直して先頭へ戻す。
        var split = _baseKey == null ? -1 : tl.posts.indexWhere((p) => p.key == _baseKey);
        if (split < 0) {
          split = 0;
          final reset = _baseKey != null;
          _baseKey = tl.posts.first.key;
          if (reset) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scroll.hasClients) _scroll.jumpTo(0);
            });
          }
        }
        final newer = tl.posts.sublist(0, split);
        final base = tl.posts.sublist(split);
        Widget row(Post p) => TimelineSearchRow(
              key: ValueKey('tl.row.${p.key}'),
              controller: _jumper,
              postKey: p.key,
              child: Column(mainAxisSize: MainAxisSize.min, children: [_item(context, tl, p, notifier, session, actions), const Divider()]),
            );
        return RefreshIndicator(
          onRefresh: notifier.refresh,
          child: CustomScrollView(
            controller: _scroll,
            center: _centerKey,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 中心より上は、中心から遠ざかる向きに並ぶ: 0 = 中心のすぐ上(いちばん古い「新しい投稿」)… 最後 = いちばん上の更新タイル。
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, j) => j == newer.length
                      ? TimelineEdgeTile(key: const ValueKey('tl.edge.top'), scroll: _scroll, label: '新しい投稿を読み込む', busyLabel: '更新しています…', onLoad: () => _reloadAll(notifier), onAutoLoad: notifier.prependNewer)
                      : row(newer[newer.length - 1 - j]),
                  childCount: newer.length + (edgeTiles ? 1 : 0),
                ),
              ),
              SliverList(
                key: _centerKey,
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i == base.length) {
                      // いちばん下の更新タイル: 見えたら続きを読む(スクロールでも読むが、届かなかった / 失敗したときの手がかり)。
                      if (tl.error != null) return Padding(padding: const EdgeInsets.all(16), child: Center(child: TextButton(onPressed: notifier.loadMore, child: const Text('読み込みに失敗しました。再試行'))));
                      if (!tl.hasMore) return const SizedBox(height: 80);
                      // タイルを出さないとき: 続きはスクロールで読む。読んでいるあいだだけ、くるくるを出す。
                      if (!edgeTiles) {
                        return SizedBox(
                          key: const ValueKey('tl.edge.bottom.plain'),
                          height: 80,
                          child: tl.loadingMore ? const Align(alignment: Alignment.topCenter, child: Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))) : null,
                        );
                      }
                      return Padding(padding: const EdgeInsets.only(bottom: 80), child: TimelineEdgeTile(key: const ValueKey('tl.edge.bottom'), scroll: _scroll, label: '続きを読み込む', busyLabel: '読み込んでいます…', busy: tl.loadingMore, onLoad: notifier.loadMore));
                    }
                    return row(base[i]);
                  },
                  childCount: base.length + 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  final _centerKey = GlobalKey();
  String? _baseKey;

  /// 「新しい投稿を読み込む」(D-379): 全体を取り直して先頭へ(自動更新は上に足すだけ)。
  Future<void> _reloadAll(TimelineNotifier notifier) async {
    await notifier.refresh();
    if (!mounted) return;
    setState(() => _baseKey = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  Widget _item(BuildContext context, TimelineState tl, Post p, TimelineNotifier notifier, SnsSession? session, List<ActionDescriptor> actions) {
    // RASQ の投稿 (D-283。TL のソース「RASQ の投稿」): SNS のアクションは効かないので、RASQ のタイルで描く。
    if (isRasqPost(p)) {
      final original = ref.watch(rasqFeedPostsProvider.select((m) => m[p.id]));
      if (original == null) return const SizedBox.shrink();
      return RasqPostTileView(key: ValueKey('tl.rasq.${p.id}'), post: original, onChanged: notifier.refresh, onOpen: () => context.pushPost(p));
    }
    // 投稿カスタマイザ (D-082): 置き換えタイルがあれば RRL で描く
    // (V5 検証済み。スレッドナビと可視性 lifecycle はホスト側)。
    final tile = tl.customTiles[p.id];
    if (tile != null && widget.kind.id.startsWith('custom:') && session is WasmSnsSession) {
      return CustomTileRow(timelineId: widget.kind.id.substring('custom:'.length), post: p, node: tile, plugin: session.timelinePlugin);
    }
    // 上付きバナー行 (D-085): TL プラグインのバッジ(RT 行と同スタイル)。
    final badge = tl.badges[p.id];
    return PostRow(
      // 投稿ごとのキー (D-282): TL に投稿が足されても、行の State(↓ の切り替え / 開いているピッカーの相手)が隣の投稿へずれない。
      key: ValueKey('tl.post.${p.key}'),
      post: p,
      actions: actions,
      onAction: (a, {args = const {}}) => notifier.perform(p, a, args: args),
      // アカウント選択 (D-110): ↓ で切り替えたコピーで実行(所属
      // アカウントへのルーティングは perform 側)。
      actionsFor: (shown) => (a, {args = const {}}) => notifier.perform(shown, a, args: args),
      onTap: () => context.pushPost(p),
      bannerIcon: badge == null ? null : rrlIconFor(badge.icon, Icons.label_outline),
      bannerText: badge?.text,
    );
  }
}

class _ErrorList extends StatelessWidget {
  const _ErrorList({required this.error, required this.onRetry});
  final Object error;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    final code = error is SnsApiException ? (error as SnsApiException).code : ErrorCode.internalServerError.copyWith(message: '$error');
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [const SizedBox(height: 80), RasqErrorView(code: code, onRetry: onRetry, retryLabel: '再読み込み')]),
    );
  }
}

/// TL のいちばん上 / いちばん下の更新タイル (D-298)。**見えたら自分で読み込む**(引っ張れない PC / Web でも更新できる)。押しても読み込む。
/// 同じタイルが出たままのあいだは、繰り返さない(いちど隠れて、また見えたら読む)。出てすぐの連打を避けるため、前回から [minInterval] は空ける。
class TimelineEdgeTile extends StatefulWidget {
  const TimelineEdgeTile({super.key, required this.scroll, required this.label, required this.busyLabel, required this.onLoad, this.onAutoLoad, this.busy = false, this.minInterval = const Duration(seconds: 8)});
  /// 一覧のスクロール(見えたかどうかを、動くたびに確かめる)。
  final Listenable scroll;
  final String label;
  final String busyLabel;
  final Future<void> Function() onLoad;

  /// 見えたときに自分で読むとき(D-379: 上のタイルは、見えただけなら上に足すだけ。押したら全体を取り直す)。null = [onLoad]。
  final Future<void> Function()? onAutoLoad;
  final bool busy;
  final Duration minInterval;

  static final Map<Key, DateTime> _last = {};

  @override
  State<TimelineEdgeTile> createState() => _TimelineEdgeTileState();
}

class _TimelineEdgeTileState extends State<TimelineEdgeTile> {
  bool _busy = false;

  bool _wasVisible = false;

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didUpdateWidget(TimelineEdgeTile old) {
    super.didUpdateWidget(old);
    if (old.scroll != widget.scroll) {
      old.scroll.removeListener(_onScroll);
      widget.scroll.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_onScroll);
    super.dispose();
  }

  /// スクロールの通知は、配置の前に来る(その時点の位置は古い)。配置が済んだあとで確かめる。
  void _onScroll() => WidgetsBinding.instance.addPostFrameCallback((_) => _check());

  /// 画面に**見えた**ときに読む(一覧は画面の外も先に組み立てるので、組み立てられただけでは読まない)。
  void _check() {
    if (!mounted) return;
    final box = context.findRenderObject();
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox || viewport is! RenderBox || !box.attached || !box.hasSize || !viewport.hasSize) return;
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final visible = top < viewport.size.height && top + box.size.height > 0;
    if (visible && !_wasVisible) _load(auto: true);
    _wasVisible = visible;
  }

  Future<void> _load({bool auto = false}) async {
    if (!mounted || _busy || widget.busy) return;
    final key = widget.key;
    final last = key == null ? null : TimelineEdgeTile._last[key];
    if (auto && last != null && DateTime.now().difference(last) < widget.minInterval) return;
    if (key != null) TimelineEdgeTile._last[key] = DateTime.now();
    setState(() => _busy = true);
    try {
      await (auto ? (widget.onAutoLoad ?? widget.onLoad) : widget.onLoad)();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _busy || widget.busy;
    return InkWell(
      onTap: busy ? null : () => _load(),
      child: Container(
        height: RasqSizes.minTap,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (busy) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) else Icon(Icons.refresh, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: RasqSpacing.sm),
          Text(busy ? widget.busyLabel : widget.label, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
