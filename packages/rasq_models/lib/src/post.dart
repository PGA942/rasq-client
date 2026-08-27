import 'package:meta/meta.dart';

import 'account.dart';
import 'media.dart';
import 'user.dart';

/// A poll attached to a post. Display state machine (未投票 / 投票済み / 期限切れ)
/// is derived by the store, the component only receives props.
@immutable
class Poll {
  const Poll({required this.options, this.multiple = false, this.expiresAt, this.votedIndices = const {}});

  final List<PollOption> options;
  final bool multiple;
  final DateTime? expiresAt;
  final Set<int> votedIndices;

  bool get voted => votedIndices.isNotEmpty;
  bool isExpired(DateTime now) => expiresAt != null && now.isAfter(expiresAt!);
  bool showsResults(DateTime now) => voted || isExpired(now);
  int get totalVotes => options.fold(0, (a, o) => a + o.votes);
}

@immutable
class PollOption {
  const PollOption({required this.text, this.votes = 0, this.imageUrl});
  final String text;
  final int votes;
  final Uri? imageUrl;
}

enum PostSource { note, chatMessage }

/// Minimal post model for phase-1 milestones M0–M2.
/// Body text is kept as raw source plus a plugin-declared [bodyFormat]
/// (plain / mfm / html) — the RSL span tree is built by the renderer.
@immutable
class Post {
  const Post({
    required this.id,
    required this.account,
    required this.author,
    required this.createdAt,
    required this.body,
    this.bodyFormat = 'plain',
    this.contentWarning,
    this.media = const [],
    this.poll,
    this.quote,
    this.repostedBy,
    this.linkUrl,
    this.counts = const {},
    this.visibility,
    this.directToIds = const [],
    this.reactions = const {},
    this.reactionEmojis = const {},
    this.myReaction,
    this.source = PostSource.note,
    this.url,
  });

  final String id;

  /// The viewing account this post was fetched for (keys per-account state).
  final AccountId account;
  final UserSummary author;
  final DateTime createdAt;
  final String body;
  final String bodyFormat;
  final String? contentWarning;
  final List<MediaItem> media;
  final Poll? poll;
  final Post? quote;
  final UserSummary? repostedBy;
  final Uri? linkUrl;

  /// Action counts keyed by action id (e.g. `reply`, `repost`, `like`).
  final Map<String, int> counts;

  /// Plugin visibility string (`public` / `home` / `followers` / `specified` …).
  final String? visibility;

  /// Recipient user ids for direct posts (Misskey `visibleUserIds`).
  final List<String> directToIds;

  bool get isDirect => visibility == 'specified' || visibility == 'direct';

  /// Per-reaction counts (`👍` → 3, `:blobcat:` → 1), display order preserved.
  final Map<String, int> reactions;

  /// Image URLs for custom-emoji reactions keyed by reaction string.
  final Map<String, Uri> reactionEmojis;

  /// Viewer's own reaction, if any.
  final String? myReaction;

  /// Where this post came from (normal note vs. chat message).
  final PostSource source;

  int get reactionTotal => reactions.values.fold(0, (a, b) => a + b);

  /// Canonical web URL of the post (リンクをコピー / 共有).
  final Uri? url;

  /// Store key: `accountKey:postId`.
  String get key => '${account.key}:$id';

  @override
  bool operator ==(Object other) => other is Post && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
