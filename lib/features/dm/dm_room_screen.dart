import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';

/// DMルーム: ページヘッダー(相手名) + ルームタイムライン(通常投稿の使い回し).
/// 送信(下付きコンポーザー)は投稿コンポーザーと一緒に次段階で実装。
class DmRoomScreen extends ConsumerWidget {
  const DmRoomScreen({super.key, required this.peerId, this.room});
  final String peerId;
  final DmRoom? room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = DynamicTimelines.dm(peerId);
    final tl = ref.watch(timelineProvider(kind));
    final notifier = ref.read(timelineProvider(kind).notifier);
    final actions = ref.watch(currentSnsSessionProvider)?.actions ?? const [];
    final title = room?.displayTitle ?? tl.value?.posts.where((p) => p.author.id == peerId).firstOrNull?.author.displayName ?? 'DM';
    return Scaffold(
      appBar: RasqPageHeader(title: title, onMore: () {}),
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
