import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../clips/clip_providers.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';

final favoritesProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  return (await s.favorites(limit: 40)).items;
});

/// ブックマーク(サイドバー): Misskey ではお気に入り(i/favorites)をブックマークとして表示.
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider);
    final actions = ref.watch(currentSnsSessionProvider)?.actions ?? const <ActionDescriptor>[];
    final notifier = ref.read(timelineProvider(TimelineKind.home).notifier);
    return Scaffold(
      appBar: RasqPageHeader(title: 'ブックマーク', onMore: () {}),
      body: favs.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: () => ref.invalidate(favoritesProvider), retryLabel: '再読み込み'),
        data: (posts) {
          // 自分のための保存の置き場 (D-032 改): RASQ 横断クリップと非公開
          // ネイティブクリップはリスト欄ではなくここに並ぶ。
          final clips = ref.watch(bookmarkClipsProvider);
          final scheme = Theme.of(context).colorScheme;
          if (posts.isEmpty && clips.isEmpty) {
            return const RasqEmptyView(title: 'ブックマークはありません', hint: '投稿メニューの「お気に入り」「クリップに追加」で集められます');
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(favoritesProvider.future),
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              if (clips.isNotEmpty) ...[
                const RasqSectionHeader(title: 'クリップ', topMargin: 0),
                for (final c in clips) ...[
                  RasqListTile(
                    title: c.name,
                    subtitle: [if (c.notesCount != null) '${c.notesCount}件', if (c.isHost) 'RASQ(SNS 横断)' else '非公開クリップ'].join(' ・ '),
                    leading: Icon(c.isHost ? Icons.workspaces_outlined : Icons.lock_outline, color: scheme.onSurfaceVariant),
                    onTap: () => context.pushClip(c),
                  ),
                  const Divider(height: 1),
                ],
                if (posts.isNotEmpty) const RasqSectionHeader(title: 'お気に入り'),
              ],
              for (final p in posts) ...[
                PostRow(post: p, actions: actions, onAction: (a, {args = const {}}) => notifier.perform(p, a, args: args), onTap: () => context.pushPost(p)),
                const Divider(),
              ],
            ]),
          );
        },
      ),
    );
  }
}
