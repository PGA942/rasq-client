import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../session/session_providers.dart';
import '../../shell/headers.dart';
import '../clips/virtual_index.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import 'relational_engine.dart';
import 'relational_providers.dart';

/// リレーショナルページ / クリップページ共通のヘッダーブロック
/// (リレーショナルページのデザイン.png 準拠):
/// GroupAvatar + 「◯◯+N人」+ **実在語の見出し(太字 1 行)** +
/// 詳しい要約(最大 3 行、生成できたときだけ)+ キーワードチップ。
class EventStyleHeader extends StatelessWidget {
  const EventStyleHeader({super.key, required this.members, required this.title, this.caption, this.headline, this.summary, this.chips = const [], this.description});

  final List<UserSummary> members;
  final String title;

  /// 件数・参加人数など(タイトル右の小さい文字)。
  final String? caption;

  /// 実在語の見出し(仮想目次と同じラベル抽出)。
  final String? headline;

  /// ASTell の詳しい要約(3 行。null = 非表示)。
  final String? summary;

  /// キーワードチップ(実在語)。
  final List<String> chips;

  /// クリップの説明文など(要約とは別枠)。
  final String? description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, RasqSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (members.isNotEmpty) ...[
            RasqGroupAvatar(users: members, size: RasqSizes.avatarMd, overflowCount: members.length > 3 ? members.length - 3 : null),
            const SizedBox(width: RasqSpacing.md),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: RasqTypography.displayName),
              if (caption != null) Text(caption!, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ),
        ]),
        if (headline != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text(headline!, style: RasqTypography.displayName.copyWith(fontSize: 17), maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (description != null && description!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(description!, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))),
        if (summary != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(summary!, style: RasqTypography.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis)),
        if (chips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: RasqSpacing.md, children: [for (final c in chips) Text(c, style: RasqTypography.bodySmall.copyWith(color: RasqTokens.of(context).link))]),
          ),
      ]),
    );
  }
}

/// リレーショナルページ (D-037): 会話イベントの個別ページ。
/// タイルからの遷移で開き、ヘッダー(見出し・3行要約・チップ)+ 投稿列。
class RelationalEventScreen extends ConsumerWidget {
  const RelationalEventScreen({super.key, required this.event});
  final ConversationEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 最新のエンジン結果に同じイベントがあればそちらを表示(浮上を反映)。
    final live = ref.watch(conversationEventsProvider).value?.where((e) => e.id == event.id).firstOrNull ?? event;
    final session = ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const <ActionDescriptor>[];
    final selfKey = ref.watch(currentUserProvider).key;
    final members = live.members;
    final avatars = [for (final u in members) if (u.key != selfKey) u];
    final summary = ref.watch(eventSummaryProvider(live.id)).value;
    final others = members.length - 1;

    return Scaffold(
      appBar: const RasqPageHeader(title: '投稿'),
      body: ListView(children: [
        EventStyleHeader(
          members: avatars.isEmpty ? members : avatars,
          title: others > 0 ? '${live.root.author.displayName}+$others人' : live.root.author.displayName,
          caption: '${live.posts.length}件 ・ ${members.length}人',
          headline: sharedHeadline(live.posts) ?? live.root.body.split('\n').first,
          summary: summary,
          chips: topSharedLabels(live.posts),
        ),
        const Divider(),
        for (final p in live.posts) ...[
          PostRow(
            post: p,
            actions: actions,
            onAction: (a, {args = const {}}) => ref.read(timelineProvider(TimelineKind.home).notifier).perform(p, a, args: args),
            // アカウント選択 (D-110): ↓ で切り替えたコピーで実行。
            actionsFor: (shown) => (a, {args = const {}}) => ref.read(timelineProvider(TimelineKind.home).notifier).perform(shown, a, args: args),
            onTap: () => context.pushPost(p),
          ),
          const Divider(),
        ],
      ]),
    );
  }
}
