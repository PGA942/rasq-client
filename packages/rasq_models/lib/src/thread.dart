import 'package:meta/meta.dart';

import 'post.dart';

/// Thread context around one post (スレッド展開画面).
@immutable
class Thread {
  const Thread({required this.post, this.ancestors = const [], this.descendants = const []});
  final Post post;

  /// Oldest → newest.
  final List<Post> ancestors;
  final List<Post> descendants;
}

/// Draft for `createPost`. Visibility / CW semantics are plugin-interpreted.
@immutable
class NewPost {
  const NewPost({
    required this.text,
    this.contentWarning,
    this.replyToId,
    this.quoteOfId,
    this.repostOfId,
    this.visibility,
    this.localOnly = false,
    this.reactionAcceptance,
    this.mediaIds = const [],
    this.poll,
  });
  final String text;
  final String? contentWarning;
  final String? replyToId;
  final String? quoteOfId;

  /// Pure repost (no text) — [text] is ignored.
  final String? repostOfId;
  final String? visibility;

  /// 連合しない(このサーバーのみ)。対応 SNS のみ意味を持つ。
  final bool localOnly;

  /// リアクションの受け入れ (D-045)。null = 全て。値は SNS 側の語彙
  /// (Misskey: likeOnly / likeOnlyForRemote / nonSensitiveOnly /
  /// nonSensitiveOnlyForLocalLikeOnlyForRemote)。
  final String? reactionAcceptance;
  final List<String> mediaIds;
  final NewPoll? poll;
}

@immutable
class NewPoll {
  const NewPoll({required this.choices, this.multiple = false, this.expiresAfter});
  final List<String> choices;
  final bool multiple;
  final Duration? expiresAfter;
}
