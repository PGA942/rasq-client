import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugin_runtime/plugin_runtime.dart' show CustomTimelineSpec, WasmSnsSession;
import 'package:rrl_renderer/rrl_renderer.dart' show rrlIconFor;
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_shell.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../relational/relational_timeline_view.dart';
import 'custom_tile_row.dart';
import 'post_row.dart';
import 'timeline_providers.dart';

/// ホームTL. Tabs = おすすめ(social) / フォロー中(home) + plugin timelines
/// (ローカル/グローバル…) + 関連(リレーショナルTL, 保留 D-011).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final session = ref.watch(currentSnsSessionProvider);
    // カスタム TL (M5e / D-080): TL プラグインの宣言をタブに足す。
    final customs = ref.watch(customTimelinesProvider).value ?? const <CustomTimelineSpec>[];
    final kinds = _tabKinds(session, customs);
    final tabs = [for (final k in kinds) RasqTabItem(_label(k), id: k.id)];
    final initial = kinds.indexOf(TimelineKind.home).clamp(0, kinds.length - 1);

    return DefaultTabController(
      length: tabs.length,
      initialIndex: initial,
      child: Scaffold(
        appBar: RasqHomeHeader(me: me, onAvatarTap: () => RasqShell.openSidebar(context, ref)),
        body: Column(children: [
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
            child: Row(children: [
              Expanded(child: RasqTabs(items: tabs, showChevron: false)),
              RasqIconButton(icon: Icons.settings, size: 20, onPressed: () {}, tooltip: 'タイムライン設定'),
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

  static List<TimelineKind> _tabKinds(SnsSession? session, List<CustomTimelineSpec> customs) {
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
      out.add(TimelineKind('custom:${c.id}', c.label));
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
        return RefreshIndicator(
          onRefresh: notifier.refresh,
          child: ListView.separated(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: tl.posts.length + 1,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, i) {
              if (i == tl.posts.length) {
                if (tl.loadingMore) return const RasqLoading();
                if (tl.error != null) return Padding(padding: const EdgeInsets.all(16), child: Center(child: TextButton(onPressed: notifier.loadMore, child: const Text('読み込みに失敗しました。再試行'))));
                return const SizedBox(height: 80);
              }
              final p = tl.posts[i];
              // 投稿カスタマイザ (D-082): 置き換えタイルがあれば RRL で描く
              // (V5 検証済み。スレッドナビと可視性 lifecycle はホスト側)。
              final tile = tl.customTiles[p.id];
              if (tile != null && widget.kind.id.startsWith('custom:') && session is WasmSnsSession) {
                return CustomTileRow(timelineId: widget.kind.id.substring('custom:'.length), post: p, node: tile, plugin: session.timelinePlugin);
              }
              // 上付きバナー行 (D-085): TL プラグインのバッジ(RT 行と同スタイル)。
              final badge = tl.badges[p.id];
              return PostRow(
                post: p,
                actions: actions,
                onAction: (a, {args = const {}}) => notifier.perform(p, a, args: args),
                onTap: () => context.pushPost(p),
                bannerIcon: badge == null ? null : rrlIconFor(badge.icon, Icons.label_outline),
                bannerText: badge?.text,
              );
            },
          ),
        );
      },
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
