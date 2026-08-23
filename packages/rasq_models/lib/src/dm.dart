import 'package:meta/meta.dart';

import 'post.dart';
import 'user.dart';

/// A DM room. Phase-1 sample: exactly one peer per room, messages are posts
/// (限定公開投稿をDM扱い — 原典: 何をやる.md「一部のSNSでは限定公開がDM代わり」).
enum DmRoomKind {
  /// 限定公開投稿 (Misskey `specified`, Mastodon `direct`).
  direct,

  /// Native chat (Misskey 2025.4+ `chat/*`).
  chat,
}

@immutable
class DmRoom {
  const DmRoom({required this.id, required this.peer, this.lastPost, this.unreadCount = 0, this.title, this.kind = DmRoomKind.direct});
  final String id;
  final DmRoomKind kind;
  final UserSummary peer;
  final Post? lastPost;
  final int unreadCount;

  /// Room title when the backend has one; defaults to the peer's name.
  final String? title;
  String get displayTitle => title ?? peer.displayName;
}
