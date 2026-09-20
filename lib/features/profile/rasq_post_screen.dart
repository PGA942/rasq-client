import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account_page_api.dart';
import '../../shell/headers.dart';
import 'rasq_post_tile.dart';

/// RASQ の投稿のスレッド (D-271 / S-022): 元の投稿(返信のとき)→ この投稿 → 返信(古い順)。
class RasqPostScreen extends ConsumerWidget {
  const RasqPostScreen({super.key, required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final thread = ref.watch(rasqThreadProvider(postId));
    void refresh() => ref.invalidate(rasqThreadProvider(postId));
    return Scaffold(
      appBar: const RasqPageHeader(title: '投稿'),
      body: thread.when(
        loading: () => const RasqLoading(),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: Text(e is OrgateException && e.code.code == '404' ? 'この投稿は、もうありません' : '読み込めませんでした: ${e is OrgateException ? e.message : e}', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
        ),
        data: (t) => ListView(padding: const EdgeInsets.only(bottom: 48), children: [
          if (t.parent != null) RasqPostTileView(post: t.parent!, onChanged: refresh, onOpen: () => context.push(Routes.rasqPost(t.parent!.id))),
          if (t.parent == null && t.post.isReply)
            Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0), child: Text('元の投稿は削除されています。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
          RasqPostTileView(
            post: t.post,
            focused: true,
            onChanged: () {
              refresh();
            },
          ),
          RasqSectionHeader(title: '返信 ${t.replies.length}'),
          if (t.replies.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text('返信はまだありません。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))),
          for (final r in t.replies) RasqPostTileView(post: r, onChanged: refresh, onOpen: () => context.push(Routes.rasqPost(r.id))),
        ]),
      ),
    );
  }
}
