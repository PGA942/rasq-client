import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

/// センシティブ / 注釈(CW)のメディアを**1 枚ずつ**開いた記録 (D-510)。投稿の key → 開いたメディアの id。
///
/// 投稿のタイル(`RasqMediaGrid`)と全画面表示(`MediaViewerScreen`)で同じものを読む: タイルで開いた 1 枚は
/// 全画面でも開いたまま、全画面でスワイプした先のほかの 1 枚は、押すまでクッションのまま。1 枚を開いても
/// 同じ投稿のほかのメディアは開かない。見た目だけの一時の状態(保存しない、アプリを閉じれば消える)。
/// 投稿ごとの集合は開くたびに作り直すので、`select((s) => s[post.key])` で読めば、ほかの投稿の変化では作り直さない。
class MediaRevealNotifier extends Notifier<Map<String, Set<String>>> {
  /// 覚えておく投稿の数の上限(古いものから忘れる。忘れたものはまたクッションが出るだけ)。
  static const maxPosts = 500;

  @override
  Map<String, Set<String>> build() => const {};

  void reveal(Post post, String mediaId) {
    final current = state[post.key] ?? const <String>{};
    if (current.contains(mediaId)) return;
    // Map リテラルは挿入順を保つ。開いた投稿を末尾へ回し、先頭(一番古い)から忘れる。
    final next = <String, Set<String>>{...state}..remove(post.key);
    next[post.key] = {...current, mediaId};
    while (next.length > maxPosts) {
      next.remove(next.keys.first);
    }
    state = next;
  }
}

final mediaRevealProvider = NotifierProvider<MediaRevealNotifier, Map<String, Set<String>>>(MediaRevealNotifier.new);

/// その投稿で開いたメディアの id(`RasqMediaGrid.revealed` に渡す形)。
Set<String> watchRevealedMedia(WidgetRef ref, Post post) => ref.watch(mediaRevealProvider.select((s) => s[post.key])) ?? const <String>{};
