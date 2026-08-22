import 'package:meta/meta.dart';

import 'account.dart';
import 'post.dart';
import 'user.dart';

/// Notification kinds — maps onto the 4 notification tile types
/// (原典: UI_Elements「通知アイテム（4種）」):
/// アクション系 / フォロー・リスト追加系 / 投稿タイル系(返信・引用) / タイマー通知.
enum NotificationKind {
  reaction,
  repost,
  quote,
  reply,
  mention,
  follow,
  followRequest,
  followAccepted,
  listAdded,
  pollEnded,
  timer,
  vc,
  other;

  NotificationTileType get tile => switch (this) {
        reaction || repost || pollEnded => NotificationTileType.action,
        follow || followRequest || followAccepted || listAdded => NotificationTileType.follow,
        quote || reply || mention => NotificationTileType.postTile,
        timer || vc => NotificationTileType.timer,
        other => NotificationTileType.action,
      };
}

enum NotificationTileType { action, follow, postTile, timer }

@immutable
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.account,
    required this.kind,
    required this.createdAt,
    this.actors = const [],
    this.post,
    this.reaction,
    this.read = false,
    this.raw,
  });

  final String id;
  final AccountId account;
  final NotificationKind kind;
  final DateTime createdAt;

  /// Users who triggered it (grouped notifications carry several).
  final List<UserSummary> actors;
  final Post? post;

  /// Reaction string / emoji for [NotificationKind.reaction].
  final String? reaction;
  final bool read;

  /// Plugin-specific payload the host does not interpret.
  final Map<String, Object?>? raw;

  String get key => '${account.key}:$id';
}
