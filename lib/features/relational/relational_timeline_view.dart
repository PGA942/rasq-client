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

/// 「関連」タブ = リレーショナルTL v1 (D-027、会話イベント方式)。
/// フォロイーの投稿を「どの直前投稿への暗黙応答か」で会話イベントに束ね、
/// **イベントカード**を活動が新しい順に並べる。カードをタップすると中の投稿
/// (PostRow)を展開する。束ねやすさと TTL 上限は右上 ⚙ のスライダーで調整。
class RelationalTimelineView extends ConsumerWidget {
  const RelationalTimelineView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(conversationEventsProvider);
    final settings = ref.watch(relationalSettingsProvider);
    final manager = ref.watch(overlayManagerProvider);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
        child: Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: RasqSpacing.sm),
              child: Text('束ねやすさ ${settings.linkBias} / 会話のテンポに応じて最長${settings.maxTtlMinutes}分で沈む', style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ),
          RasqIconButton(icon: Icons.tune, size: 20, tooltip: 'リレーショナルTL設定', onPressed: () => _openSettings(context, ref, manager)),
        ]),
      ),
      Expanded(
        child: events.when(
          loading: () => const RasqLoading(),
          error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.relationalTimelineBroken, onRetry: () => ref.invalidate(timelineProvider(TimelineKind.home)), retryLabel: '再読み込み'),
          data: (list) => list.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => ref.read(timelineProvider(TimelineKind.home).notifier).refresh(),
                  child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                    SizedBox(height: 120),
                    RasqEmptyView(title: 'いま進行中の会話はありません', hint: 'フォロイーの空リプや会話が始まると、ここに束ねて表示します。束ねやすさを下げると拾いやすくなります'),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(timelineProvider(TimelineKind.home).notifier).refresh(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (_, i) => _EventCard(event: list[i]),
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
            title: '束ねやすさ',
            subtitle: '会話リンク判定のしきい値バイアス(50〜100)。低いほど広く束ねる。しきい値自体はコミュニティ別に自動調整',
            value: s.linkBias.toDouble(),
            min: 50,
            max: 100,
            divisions: 50,
            onChanged: (v) => store.set(s.copyWith(linkBias: v.round())),
          ),
          RasqSliderListTile(
            title: '沈むまでの最長時間',
            subtitle: '会話の TTL は投稿間隔から自動調整(テンポの速い空リプは早く沈む)。その上限',
            value: s.maxTtlMinutes.toDouble(),
            min: 5,
            max: 60,
            divisions: 55,
            valueLabel: '${s.maxTtlMinutes}分',
            onChanged: (v) => store.set(s.copyWith(maxTtlMinutes: v.round())),
          ),
          const SizedBox(height: RasqSpacing.md),
        ]);
      }),
    );
  }
}

/// イベントカード: GroupAvatar + 「◯◯+N人」 + ROOT本文 + 共通エンティティ
/// → タップで会話(投稿列)を展開。
class _EventCard extends ConsumerStatefulWidget {
  const _EventCard({required this.event});
  final ConversationEvent event;

  @override
  ConsumerState<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends ConsumerState<_EventCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = widget.event;
    final members = e.members;
    final emojis = ref.watch(emojiCacheProvider);
    final session = ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const <ActionDescriptor>[];
    final others = members.length - 1;
    final tags = [for (final t in e.entities) if (t.length >= 2) t].take(4).toList();

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
                Text(others > 0 ? '${e.root.author.displayName}+$others人' : e.root.author.displayName, style: RasqTypography.displayName),
                RasqRichText(InlineSpans.parse(e.root.body, emojis: emojis), style: RasqTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(spacing: 6, children: [for (final t in tags) Text('#$t', style: RasqTypography.caption.copyWith(color: RasqTokens.of(context).link))]),
                  ),
              ]),
            ),
            Column(children: [
              Icon(_expanded ? Icons.keyboard_arrow_down : Icons.chevron_right, color: scheme.onSurfaceVariant),
              Text('${e.posts.length}件', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ]),
        ),
      ),
      if (_expanded)
        for (final p in e.posts) ...[
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
