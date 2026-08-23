import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../home/post_row.dart';
import 'dm_providers.dart';
import '../home/timeline_providers.dart';

/// DMルーム: ページヘッダー(相手名) + ルームタイムライン(通常投稿の使い回し).
/// 送信(下付きコンポーザー)は投稿コンポーザーと一緒に次段階で実装。
class DmRoomScreen extends ConsumerWidget {
  const DmRoomScreen({super.key, required this.peerId, this.room});
  final String peerId;
  final DmRoom? room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(dmRoomsProvider).value;
    final resolved = room ?? rooms?.where((r) => r.peer.id == peerId).firstOrNull;
    final kind = resolved == null ? DynamicTimelines.dm(peerId) : DynamicTimelines.forRoom(resolved);
    final tl = ref.watch(timelineProvider(kind));
    final notifier = ref.read(timelineProvider(kind).notifier);
    final actions = ref.watch(currentSnsSessionProvider)?.actions ?? const [];
    final title = resolved?.displayTitle ?? tl.value?.posts.where((p) => p.author.id == peerId).firstOrNull?.author.displayName ?? 'DM';
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: RasqPageHeader(title: title, onMore: () {}),
      bottomNavigationBar: resolved == null
          ? null
          : Material(
              color: scheme.surface,
              child: SafeArea(
                top: false,
                child: InkWell(
                  onTap: () async {
                    final sent = await showComposer(ref, ComposeDm(resolved));
                    if (sent != null) {
                      await notifier.refresh();
                      ref.invalidate(dmRoomsProvider);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.all(RasqSpacing.sm),
                    padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: RasqSpacing.sm),
                    decoration: BoxDecoration(border: Border.all(color: scheme.onSurface), borderRadius: BorderRadius.circular(RasqSizes.radiusPill)),
                    child: Row(children: [
                      Icon(resolved.kind == DmRoomKind.chat ? Icons.chat_bubble_outline : Icons.lock_outline, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(child: Text(resolved.kind == DmRoomKind.chat ? 'メッセージを入力..' : 'ダイレクト投稿を入力..', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))),
                      Icon(Icons.send, size: 18, color: scheme.primary),
                    ]),
                  ),
                ),
              ),
            ),
      body: tl.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: notifier.refresh, retryLabel: '再読み込み'),
        data: (s) => RefreshIndicator(
          onRefresh: notifier.refresh,
          child: s.posts.isEmpty
              ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 120), RasqEmptyView(title: 'まだメッセージはありません')])
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: s.posts.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, i) => PostRow(post: s.posts[i], actions: actions, onAction: (a) => notifier.perform(s.posts[i], a), onTap: () => context.pushPost(s.posts[i])),
                ),
        ),
      ),
    );
  }
}
