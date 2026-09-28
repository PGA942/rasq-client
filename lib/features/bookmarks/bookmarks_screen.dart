import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_store/rasq_store.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../clips/clip_providers.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../vc/astell_actions.dart';
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import '../post/post_bookmark_button.dart';
import '../vc/astell_bookmarks.dart';
import '../vc/astell_tile.dart';

final favoritesProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  // ブックマークを持たない SNS(Bluesky など)は読まない (D-369): RASQ クリップだけを出す。
  if (bookmarkActionOf(s) == null) return const [];
  final items = (await s.favorites(limit: 40)).items;
  // 一覧の投稿はブックマーク済み (D-365): 🔖 / アクションが「外す」になるように状態を入れておく
  // (Misskey の投稿はお気に入り済みかを返さない)。
  final action = bookmarkActionOf(s);
  if (action != null) {
    final store = ref.read(actionStateProvider.notifier);
    store.applyAll({for (final p in items) (postKey: p.key, actionId: action.id): store.of(p.key, action.id).copyWith(done: true)});
  }
  return items;
});

/// 一覧から外した投稿(取り直すまで隠す)(D-365)。
class _RemovedBookmarks extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(favoritesProvider);
    return const {};
  }

  void add(String key) => state = {...state, key};
  void remove(String key) => state = {...state}..remove(key);
}

final _removedBookmarksProvider = NotifierProvider.autoDispose<_RemovedBookmarks, Set<String>>(_RemovedBookmarks.new);

/// ブックマークを外す (D-365)。一覧からはすぐ消し、失敗したら戻す。
Future<void> removeBookmark(WidgetRef ref, Post p) async {
  final session = ref.read(currentSnsSessionProvider);
  final action = bookmarkActionOf(session);
  final messenger = ref.read(rootMessengerKeyProvider).currentState;
  if (action == null) return;
  ref.read(_removedBookmarksProvider.notifier).add(p.key);
  try {
    await ref.read(timelineProvider(TimelineKind.home).notifier).perform(p, action, args: const {'forceUndo': true});
    messenger?.clearSnackBars();
    messenger?.showSnackBar(const SnackBar(content: Text('ブックマークを外しました')));
  } catch (e) {
    ref.read(_removedBookmarksProvider.notifier).remove(p.key);
    messenger?.showSnackBar(SnackBar(content: Text('外せませんでした: $e')));
  }
}

/// ブックマーク(サイドバー): Misskey ではお気に入り(i/favorites)をブックマークとして表示.
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider);
    final actions = ref.watch(currentSnsSessionProvider)?.actions ?? const <ActionDescriptor>[];
    final notifier = ref.read(timelineProvider(TimelineKind.home).notifier);
    final removed = ref.watch(_removedBookmarksProvider);
    final canRemove = bookmarkActionOf(ref.watch(currentSnsSessionProvider)) != null;
    return Scaffold(
      appBar: RasqPageHeader(title: 'ブックマーク', onMore: () {}),
      body: favs.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: () => ref.invalidate(favoritesProvider), retryLabel: '再読み込み'),
        data: (all) {
          final posts = [for (final p in all) if (!removed.contains(p.key)) p];
          // 自分のための保存の置き場 (D-032 改): RASQ 横断クリップと非公開
          // ネイティブクリップはリスト欄ではなくここに並ぶ。
          final clips = ref.watch(bookmarkClipsProvider);
          // AsTell のブックマーク (D-160): タイルの帯(見てみる/戻る、通知)。
          final rooms = ref.watch(astellBookmarksProvider).value ?? const [];
          final scheme = Theme.of(context).colorScheme;
          if (posts.isEmpty && clips.isEmpty && rooms.isEmpty) {
            return canRemove
                ? const RasqEmptyView(title: 'ブックマークはありません', hint: '投稿の 🔖、クリップに追加、AsTell のしおりで集められます')
                : const RasqEmptyView(key: ValueKey('bookmarks.noSns'), title: 'ブックマークはありません', hint: 'このサービスにはブックマークがありません。投稿の 🔖 を長押しすると RASQ クリップに集められます');
          }
          return RefreshIndicator(
            onRefresh: () async {
              await refreshAstellBookmarks(ref);
              ref.invalidate(favoritesProvider);
              await ref.read(favoritesProvider.future);
            },
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              if (rooms.isNotEmpty) ...[
                const RasqSectionHeader(title: 'AsTell', topMargin: 0),
                AstellTileStrip(rooms: rooms, tileBuilder: (r) => AstellRoomTile(room: r)),
              ],
              if (clips.isNotEmpty) ...[
                RasqSectionHeader(title: 'クリップ', topMargin: rooms.isEmpty ? 0 : RasqSpacing.sectionMargin),
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
                if (canRemove)
                  // 左へスワイプか「ブックマークを外す」で外す (D-365)。
                  Dismissible(
                    key: ValueKey('bookmarks.post.${p.key}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: RasqColors.danger,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.bookmark_remove_outlined, color: Colors.white), SizedBox(width: 4), Text('外す', style: TextStyle(color: Colors.white))]),
                    ),
                    onDismissed: (_) => removeBookmark(ref, p),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      PostRow(post: p, actions: actions, onAction: (a, {args = const {}}) => notifier.perform(p, a, args: args), onTap: () => context.pushPost(p)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: ValueKey('bookmarks.remove.${p.id}'),
                          onPressed: () => removeBookmark(ref, p),
                          icon: const Icon(Icons.bookmark_remove_outlined, size: 18),
                          label: const Text('ブックマークを外す'),
                        ),
                      ),
                    ]),
                  )
                else
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
