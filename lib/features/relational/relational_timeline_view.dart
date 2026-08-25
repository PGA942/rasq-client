import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../text/inline_spans.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import 'relational_engine.dart';
import 'relational_providers.dart';

/// 「関連」タブ = リレーショナルTL v0 (D-022)。
/// フォロイーの投稿を特徴語で束ね、LTL の類似投稿を取り込んだ**クラスタカード**を
/// 活動が新しい順に並べる。カードをタップすると中の投稿(PostRow)を展開する。
/// しきい値(50〜100)と浮上タイムアウトは右上 ⚙ のスライダーで調整。
class RelationalTimelineView extends ConsumerWidget {
  const RelationalTimelineView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clusters = ref.watch(relationalClustersProvider);
    final settings = ref.watch(relationalSettingsProvider);
    final manager = ref.watch(overlayManagerProvider);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
        child: Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: RasqSpacing.sm),
              child: Text('類似度 ${settings.threshold} / ${settings.staleMinutes}分で沈む', style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ),
          RasqIconButton(icon: Icons.tune, size: 20, tooltip: 'リレーショナルTL設定', onPressed: () => _openSettings(context, ref, manager)),
        ]),
      ),
      Expanded(
        child: clusters.when(
          loading: () => const RasqLoading(),
          error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.relationalTimelineBroken, onRetry: () => ref.invalidate(timelineProvider(TimelineKind.home)), retryLabel: '再読み込み'),
          data: (list) => list.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => ref.read(timelineProvider(TimelineKind.home).notifier).refresh(),
                  child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                    SizedBox(height: 120),
                    RasqEmptyView(title: 'まだ関連の束がありません', hint: 'フォロイーの話題が重なると、ここに束ねて表示します。しきい値を下げると束ねやすくなります'),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(timelineProvider(TimelineKind.home).notifier).refresh(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (_, i) => _ClusterCard(cluster: list[i]),
                  ),
                ),
        ),
      ),
    ]);
  }

  void _openSettings(BuildContext context, WidgetRef ref, dynamic manager) {
    manager.showBottomSheet(
      id: 'relational.settings',
      title: 'リレーショナルTL設定',
      builder: (_) => Consumer(builder: (context, ref, _) {
        final s = ref.watch(relationalSettingsProvider);
        final store = ref.read(relationalSettingsProvider.notifier);
        return Column(mainAxisSize: MainAxisSize.min, children: [
          RasqSliderListTile(
            title: '類似度のしきい値',
            subtitle: 'SigLIP cos 類似度の 50〜100 正規化。低いほど広く束ねる(初期値は実測で調整)',
            value: s.threshold.toDouble(),
            min: 50,
            max: 100,
            divisions: 50,
            onChanged: (v) => store.set(s.copyWith(threshold: v.round())),
          ),
          RasqSliderListTile(
            title: '浮上タイムアウト',
            subtitle: '新しい投稿・リノート・自分の関連投稿へのアクションがこの時間なければ沈む',
            value: s.staleMinutes.toDouble(),
            min: 1,
            max: 60,
            divisions: 59,
            valueLabel: '${s.staleMinutes}分',
            onChanged: (v) => store.set(s.copyWith(staleMinutes: v.round())),
          ),
          const SizedBox(height: RasqSpacing.md),
        ]);
      }),
    );
  }
}

/// クラスタカード: GroupAvatar + 「◯◯+N人」 + 代表本文 + タグ → タップで展開。
class _ClusterCard extends ConsumerStatefulWidget {
  const _ClusterCard({required this.cluster});
  final RelationalCluster cluster;

  @override
  ConsumerState<_ClusterCard> createState() => _ClusterCardState();
}

class _ClusterCardState extends ConsumerState<_ClusterCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = widget.cluster;
    final members = c.members;
    final emojis = ref.watch(emojiCacheProvider);
    final session = ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const <ActionDescriptor>[];
    final others = members.length - 1;
    final tags = [for (final t in c.tags) if (t.length >= 2) t].take(4).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.sm, RasqSpacing.sm),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RasqGroupAvatar(users: members, size: RasqSizes.avatarMd, overflowCount: others > 2 ? others - 2 : null),
            const SizedBox(width: RasqSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(others > 0 ? '${c.seed.author.displayName}+$others人' : c.seed.author.displayName, style: RasqTypography.displayName),
                RasqRichText(InlineSpans.parse(c.seed.body, emojis: emojis), style: RasqTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(spacing: 6, children: [for (final t in tags) Text('#$t', style: RasqTypography.caption.copyWith(color: RasqTokens.of(context).link))]),
                  ),
              ]),
            ),
            Column(children: [
              Icon(_expanded ? Icons.keyboard_arrow_down : Icons.chevron_right, color: scheme.onSurfaceVariant),
              Text('${c.posts.length}件', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ]),
        ),
      ),
      if (_expanded)
        for (final p in c.posts) ...[
          const Divider(indent: RasqSpacing.page * 2),
          Padding(
            padding: const EdgeInsets.only(left: RasqSpacing.page),
            child: PostRow(
              post: p,
              actions: actions,
              onAction: (a, {args = const {}}) => ref.read(timelineProvider(TimelineKind.home).notifier).perform(p, a, args: args),
              onTap: () => context.pushPost(p),
              dense: true,
            ),
          ),
        ],
    ]);
  }
}
