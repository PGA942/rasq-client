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
import '../compose/compose_target.dart';
import '../settings/settings_dsl.dart';
import '../compose/composer_sheet.dart';
import '../nodeprog/node_tabs.dart';
import '../relational/relational_timeline_view.dart';
import '../vc/astell_actions.dart';
import 'custom_tile_row.dart';
import 'post_row.dart';
import 'timeline_providers.dart';

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
    final kinds = bundle
        ? [
            TimelineKind.bundle,
            TimelineKind.relational,
            if (ref.watch(bundleNodeTabsVisibleProvider))
              for (final (_, t) in ref.watch(allNodeTabsProvider)) TimelineKind(t.id, t.label),
          ]
        : _tabKinds(session, customs, nodeTabs);
    final tabs = [for (final k in kinds) RasqTabItem(_label(k), id: k.id)];
    final initial = kinds.indexOf(bundle ? TimelineKind.bundle : TimelineKind.home).clamp(0, kinds.length - 1);

    return DefaultTabController(
      length: tabs.length,
      initialIndex: initial,
      child: Scaffold(
        // フォロー中のホストの AsTell (D-163): ヘッダーの角丸四角形にバンドルを並べる。
        appBar: RasqHomeHeader(me: me, onAvatarTap: () => RasqShell.openSidebar(context, ref), 
            // Tell タイル (D-238、設定 `astell.tiles`): 出す / 出さないと並べる数。
            vcWidget: settingValue(ref, 'astell.tiles', 'headerStrip', true) == false ? null : AstellHeaderStrip(max: ((settingValue(ref, 'astell.tiles', 'headerMax', 4) as num).round()).clamp(1, 8))),
        body: Column(children: [
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
            child: Row(children: [
              Expanded(child: RasqTabs(items: tabs, showChevron: false)),
              // RAi は TL のタブ行では隠す (D-103 でユーザーが指定 —
              // ノードエディタのパレット側にだけ置く)。
              // タイムライン設定 (D-090/D-121): 簡略版のカスタマイズ画面へ
              // (SNSタイムライン + アルゴリズムのコンポーネント積み。
              // 自由形ノードキャンバスは一旦無効化)。
              Builder(builder: (ctx) {
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
                  const RelationalTimelineView() // D-022 v0 (ルールベース段)
                else
                  _TimelineView(kind: k),
            ]),
          ),
        ]),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final created = await showComposer(ref, const ComposeNormal());
            if (created != null) await ref.read(timelineProvider(TimelineKind.home).notifier).refresh();
          },
          tooltip: '投稿',
          shape: const CircleBorder(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

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

class _TimelineView extends ConsumerStatefulWidget {
  const _TimelineView({required this.kind});
  final TimelineKind kind;
  @override
  ConsumerState<_TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<_TimelineView> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(timelineProvider(widget.kind));
    final session = ref.watch(currentSnsSessionProvider);
    final notifier = ref.read(timelineProvider(widget.kind).notifier);
    final actions = session?.actions ?? const <ActionDescriptor>[];

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
        Widget row(Post p) => Column(mainAxisSize: MainAxisSize.min, children: [_item(context, tl, p, notifier, session, actions), const Divider()]);
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
                      ? TimelineEdgeTile(key: const ValueKey('tl.edge.top'), scroll: _scroll, label: '新しい投稿を読み込む', busyLabel: '更新しています…', onLoad: notifier.refreshNewer)
                      : row(newer[newer.length - 1 - j]),
                  childCount: newer.length + 1,
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
  const TimelineEdgeTile({super.key, required this.scroll, required this.label, required this.busyLabel, required this.onLoad, this.busy = false, this.minInterval = const Duration(seconds: 8)});
  /// 一覧のスクロール(見えたかどうかを、動くたびに確かめる)。
  final Listenable scroll;
  final String label;
  final String busyLabel;
  final Future<void> Function() onLoad;
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
      await widget.onLoad();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _busy || widget.busy;
    return InkWell(
      onTap: busy ? null : _load,
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
