import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_store/rasq_store.dart' show FollowState;

/// Misskey JSON → host models.
abstract final class MisskeyMappers {
  static UserSummary user(Map<String, Object?> j, {required AccountId account, required String host}) {
    final username = j['username'] as String? ?? '';
    final userHost = j['host'] as String?; // null = local
    final acct = AccountId(kind: SnsKind.misskey, instance: userHost ?? host, handle: username);
    return UserSummary(
      id: j['id'] as String,
      account: acct,
      displayName: (j['name'] as String?)?.trim().isNotEmpty == true ? j['name'] as String : username,
      avatarUrl: _uri(j['avatarUrl']),
      bio: j['description'] as String?,
    );
  }

  static UserProfile profile(Map<String, Object?> j, {required AccountId account, required String host}) {
    final s = user(j, account: account, host: host);
    final fields = <ProfileField>[
      for (final f in (j['fields'] as List? ?? const []))
        if (f is Map) ProfileField(name: (f['name'] ?? '').toString(), value: (f['value'] ?? '').toString()),
    ];
    return UserProfile(
      summary: s,
      bannerUrl: _uri(j['bannerUrl']),
      description: j['description'] as String?,
      followersCount: (j['followersCount'] as num?)?.toInt(),
      followingCount: (j['followingCount'] as num?)?.toInt(),
      postsCount: (j['notesCount'] as num?)?.toInt(),
      fields: fields,
      createdAt: _date(j['createdAt']),
      birthday: j['birthday'] as String?,
      location: j['location'] as String?,
      url: _uri(j['url']),
      isLocked: j['isLocked'] as bool? ?? false,
      isBot: j['isBot'] as bool? ?? false,
      isSuspended: j['isSuspended'] as bool? ?? false,
    );
  }

  static FollowState relation(Map<String, Object?> j) => FollowState(
        following: j['isFollowing'] as bool? ?? false,
        followedBy: j['isFollowed'] as bool? ?? false,
        requested: j['hasPendingFollowRequestFromYou'] as bool? ?? false,
        muted: j['isMuted'] as bool? ?? false,
        blocked: j['isBlocking'] as bool? ?? false,
        blockedBy: j['isBlocked'] as bool? ?? false,
      );

  static MediaItem file(Map<String, Object?> j) {
    final mime = (j['type'] as String? ?? '').toLowerCase();
    final type = mime.startsWith('image/gif')
        ? MediaType.gif
        : mime.startsWith('image/')
            ? MediaType.image
            : mime.startsWith('video/')
                ? MediaType.video
                : MediaType.file;
    final props = (j['properties'] as Map?)?.cast<String, Object?>() ?? const {};
    return MediaItem(
      id: j['id'] as String,
      type: type,
      url: _uri(j['url']) ?? Uri(),
      thumbnailUrl: _uri(j['thumbnailUrl']),
      alt: j['comment'] as String?,
      sensitive: j['isSensitive'] as bool? ?? false,
      fileName: j['name'] as String?,
      width: (props['width'] as num?)?.toInt(),
      height: (props['height'] as num?)?.toInt(),
    );
  }

  static Poll? poll(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, Object?>();
    final choices = (j['choices'] as List? ?? const []).cast<Map>();
    final voted = <int>{};
    final options = <PollOption>[];
    for (var i = 0; i < choices.length; i++) {
      final c = choices[i].cast<String, Object?>();
      options.add(PollOption(text: (c['text'] ?? '').toString(), votes: (c['votes'] as num?)?.toInt() ?? 0));
      if (c['isVoted'] == true) voted.add(i);
    }
    return Poll(options: options, multiple: j['multiple'] as bool? ?? false, expiresAt: _date(j['expiresAt']), votedIndices: voted);
  }

  /// Maps a note. [viewer] is the logged-in account (keys per-account state).
  static Post note(Map<String, Object?> j, {required AccountId viewer, required String host, int depth = 0}) {
    final author = user((j['user'] as Map).cast<String, Object?>(), account: viewer, host: host);
    final renote = j['renote'] is Map ? (j['renote'] as Map).cast<String, Object?>() : null;
    final text = j['text'] as String?;
    final isPureRenote = renote != null && (text == null || text.isEmpty) && (j['fileIds'] as List? ?? const []).isEmpty && j['poll'] == null;

    if (isPureRenote && depth == 0) {
      // Show the renoted note with "X がリノートしました".
      final inner = note(renote, viewer: viewer, host: host, depth: depth + 1);
      return Post(
        id: j['id'] as String,
        account: viewer,
        author: inner.author,
        createdAt: _date(j['createdAt']) ?? DateTime.now(),
        body: inner.body,
        bodyFormat: inner.bodyFormat,
        contentWarning: inner.contentWarning,
        media: inner.media,
        poll: inner.poll,
        quote: inner.quote,
        repostedBy: author,
        counts: inner.counts,
      );
    }

    final reactions = (j['reactions'] as Map?)?.cast<String, Object?>() ?? const {};
    final reactionTotal = reactions.values.fold<int>(0, (a, v) => a + ((v as num?)?.toInt() ?? 0));
    return Post(
      id: j['id'] as String,
      account: viewer,
      author: author,
      createdAt: _date(j['createdAt']) ?? DateTime.now(),
      body: text ?? '',
      bodyFormat: 'mfm',
      contentWarning: j['cw'] as String?,
      media: [for (final f in (j['files'] as List? ?? const [])) file((f as Map).cast<String, Object?>())],
      poll: poll(j['poll']),
      quote: renote != null && depth < 2 ? note(renote, viewer: viewer, host: host, depth: depth + 1) : null,
      counts: {
        'reply': (j['repliesCount'] as num?)?.toInt() ?? 0,
        'renote': (j['renoteCount'] as num?)?.toInt() ?? 0,
        'reaction': reactionTotal,
      },
    );
  }

  static NotificationItem notification(Map<String, Object?> j, {required AccountId viewer, required String host}) {
    final type = j['type'] as String? ?? 'other';
    final kind = switch (type) {
      'reaction' => NotificationKind.reaction,
      'renote' => NotificationKind.repost,
      'quote' => NotificationKind.quote,
      'reply' => NotificationKind.reply,
      'mention' => NotificationKind.mention,
      'follow' => NotificationKind.follow,
      'receiveFollowRequest' => NotificationKind.followRequest,
      'followRequestAccepted' => NotificationKind.followAccepted,
      'pollEnded' => NotificationKind.pollEnded,
      _ => NotificationKind.other,
    };
    final actors = <UserSummary>[];
    if (j['user'] is Map) actors.add(user((j['user'] as Map).cast<String, Object?>(), account: viewer, host: host));
    for (final u in (j['users'] as List? ?? const [])) {
      if (u is Map) actors.add(user(u.cast<String, Object?>(), account: viewer, host: host));
    }
    return NotificationItem(
      id: j['id'] as String,
      account: viewer,
      kind: kind,
      createdAt: _date(j['createdAt']) ?? DateTime.now(),
      actors: actors,
      post: j['note'] is Map ? note((j['note'] as Map).cast<String, Object?>(), viewer: viewer, host: host) : null,
      reaction: j['reaction'] as String?,
      read: j['isRead'] as bool? ?? false,
      raw: {'type': type},
    );
  }

  static Uri? _uri(Object? v) => v is String && v.isNotEmpty ? Uri.tryParse(v) : null;
  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
}
