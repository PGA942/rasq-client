import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';

import '../clips/clip_picker.dart';
import '../home/timeline_providers.dart';
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;

/// その SNS の「ブックマーク」にあたるアクション(genreTag `Bookmark`: Misskey のお気に入り、Mastodon のブックマーク)。
/// 持たない SNS(Bluesky など)は null。
ActionDescriptor? bookmarkActionOf(SnsSession? session) => session?.actions.where((a) => a.genreTag == 'Bookmark').firstOrNull;

/// ブックマーク済みと分かっている投稿を、状態の取り直しで「未」に戻さない (D-365)。Misskey の投稿は
/// お気に入り済みかを返さない(`notes/state` が別)ので、ブックマーク一覧で分かった「済み」を詳細で消していた
/// (🔖 が外せず、押すと「もう入っています」になる)。外したときは [TimelineNotifier.perform] が直接書き換える。
Map<ActionKey, ActionState> keepKnownBookmarks(ActionStateStore store, SnsSession session, Map<ActionKey, ActionState> batch) {
  final ids = {for (final a in session.actions) if (a.genreTag == 'Bookmark') a.id};
  if (ids.isEmpty) return batch;
  return {
    for (final e in batch.entries)
      e.key: ids.contains(e.key.actionId) && !e.value.done && store.of(e.key.postKey, e.key.actionId).done ? e.value.copyWith(done: true) : e.value,
  };
}

/// 投稿詳細のヘッダーのブックマーク (D-342)。
/// **短押し** = その SNS 自身のブックマーク(クリップに入れない、単独のブックマーク)/ 解除。
/// **長押し** = 追加先を選ぶ: その SNS のクリップ(Misskey のクリップなど、持つ SNS だけ)/ RASQ クリップ(SNS 横断)。
/// ブックマークを持たない SNS では、短押しは「長押しでクリップへ」の案内だけ。
class PostBookmarkButton extends ConsumerWidget {
  const PostBookmarkButton({super.key, required this.post, required this.session});
  final Post post;

  /// 投稿が属するアカウントのセッション(D-155)。
  final SnsSession? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = bookmarkActionOf(session);
    final done = action != null && ref.watch(actionStateOfProvider((postKey: post.key, actionId: action.id))).done;
    return RasqIconButton(
      key: const ValueKey('post.detail.bookmark'),
      icon: done ? Icons.bookmark : Icons.bookmark_border,
      color: done ? RasqColors.accent : null,
      tooltip: action == null ? 'クリップに追加(長押し)' : (done ? 'ブックマークを外す(長押しでクリップへ)' : 'ブックマーク(長押しでクリップへ)'),
      onPressed: () => _toggle(ref, action, done),
      onLongPress: () => showAddToClipSheet(ref, post, session: session),
    );
  }

  Future<void> _toggle(WidgetRef ref, ActionDescriptor? action, bool done) async {
    final messenger = ref.read(rootMessengerKeyProvider).currentState;
    messenger?.clearSnackBars();
    if (action == null) {
      messenger?.showSnackBar(const SnackBar(content: Text('このサービスにはブックマークがありません。長押しでクリップに追加できます')));
      return;
    }
    try {
      await ref.read(timelineProvider(TimelineKind.home).notifier).perform(post, action);
      messenger?.showSnackBar(SnackBar(content: Text(done ? 'ブックマークを外しました' : 'ブックマークしました')));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('ブックマークできませんでした: $e')));
    }
  }
}
