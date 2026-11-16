import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../home/timeline_providers.dart';

/// 全画面表示のスワイプを、投稿をまたいで続ける並び (第1回 全画面 / 台帳 D-565)。
///
/// 添付の最後(最初)まで来たら止めずに、**見ていたタイムラインの並び順**で次(前)のメディア付き投稿へ移る。
/// タイムラインの一覧([ViewerSequenceScope])がこれを渡し、`context.openViewer` が全画面へ持っていく。
/// 渡されなかった(投稿の詳細 / 通知 / アカウントページなど)ときは、これまでどおりその投稿の添付だけ。
///
/// - [posts] = いまの読み込み済みの並び(TL の上から下)。全画面を開いた時点の並びを基準にし、あとで足されたぶんは
///   **末尾だけ**取り込む(上に積まれる新着は取り込まない = 見ている位置の番号がずれない)。
/// - [loadMore] / [canLoadMore] = 下の端(古い側)の続きを読む口。上の端(新しい側)は読み込まずに止まる。
@immutable
class ViewerSequence {
  const ViewerSequence({required this.posts, this.loadMore, this.canLoadMore});

  final List<Post> Function() posts;
  final Future<void> Function()? loadMore;
  final bool Function()? canLoadMore;

  /// 現在のアカウントの [kind] の TL の並び。読み込みは TL の「続きを読む」と同じ([TimelineNotifier.loadMore])。
  static ViewerSequence ofTimeline(BuildContext context, TimelineKind kind) {
    final c = ProviderScope.containerOf(context, listen: false);
    final provider = timelineProvider(kind);
    return ViewerSequence(
      // 見守りで止めた投稿は、TL と同じく並びに入れない(TL の provider も外しているが、念のため同じ関所を通す)。
      posts: () => c.read(childGateProvider).filterPosts(c.read(provider).value?.posts ?? const <Post>[]),
      loadMore: () => c.read(provider.notifier).loadMore(),
      canLoadMore: () => c.read(provider).value?.hasMore ?? false,
    );
  }
}

/// タイムラインの一覧に置く: この下で開いた全画面は、この並びでスワイプを続ける。
class ViewerSequenceScope extends InheritedWidget {
  const ViewerSequenceScope({super.key, required this.sequence, required super.child});
  final ViewerSequence sequence;

  static ViewerSequence? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<ViewerSequenceScope>()?.sequence;

  @override
  bool updateShouldNotify(ViewerSequenceScope oldWidget) => false;
}

/// 全画面表示で開くもの(ルートの extra)。
@immutable
class MediaViewerArgs {
  const MediaViewerArgs({required this.post, this.index = 0, this.sequence});
  final Post post;
  final int index;
  final ViewerSequence? sequence;
}

/// 全画面の 1 枚 = (投稿, その添付の番号)。
typedef ViewerSlide = ({Post post, int media});

/// 続きを読み込み始める位置: 読み込み済みの最後の 1 枚から、これだけ手前に来たら(TL の下端の自動読み込みと同じ考え)。
const viewerLoadMoreAhead = 2;

/// [posts] から全画面の並びを作る。[opened] の投稿は**添付をぜんぶ**(セーフモードで外したものも、外せないクッションで)、
/// ほかの投稿は**タイルに出ている添付だけ**([visibleMedia]: セーフモード / 見守りで取り除いたものは飛ばす)。
/// [opened] が並びに無ければ、その投稿だけ。
List<ViewerSlide> buildViewerSlides(List<Post> posts, Post opened, {required List<int> Function(Post post) visibleMedia}) {
  final at = posts.indexWhere((p) => p.key == opened.key);
  if (at < 0) return [for (var m = 0; m < opened.media.length; m++) (post: opened, media: m)];
  final out = <ViewerSlide>[];
  final seen = <String>{};
  for (var i = 0; i < posts.length; i++) {
    final p = i == at ? opened : posts[i];
    if (!seen.add(p.key)) continue;
    final media = i == at ? [for (var m = 0; m < p.media.length; m++) m] : visibleMedia(p);
    for (final m in media) {
      out.add((post: p, media: m));
    }
  }
  return out;
}

/// 読み込んだ続きを末尾に足す: いまの並びの最後の投稿より後ろにある投稿のぶん(重複は飛ばす)。足すものが無ければ空。
List<ViewerSlide> appendViewerSlides(List<ViewerSlide> current, List<Post> posts, {required List<int> Function(Post post) visibleMedia}) {
  if (current.isEmpty) return const [];
  final have = {for (final s in current) s.post.key};
  final last = current.last.post.key;
  final at = posts.indexWhere((p) => p.key == last);
  if (at < 0) return const [];
  final out = <ViewerSlide>[];
  for (final p in posts.skip(at + 1)) {
    if (!have.add(p.key)) continue;
    for (final m in visibleMedia(p)) {
      out.add((post: p, media: m));
    }
  }
  return out;
}
