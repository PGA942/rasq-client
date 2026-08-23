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
        data: (posts) => posts.isEmpty
            ? const RasqEmptyView(title: 'ブックマークはありません', hint: '投稿メニューの「お気に入り」で追加できます')
            : RefreshIndicator(
                onRefresh: () => ref.refresh(favoritesProvider.future),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, i) => PostRow(post: posts[i], actions: actions, onAction: (a, {args = const {}}) => notifier.perform(posts[i], a, args: args), onTap: () => context.pushPost(posts[i])),
                ),
              ),
      ),
    );
  }
}
