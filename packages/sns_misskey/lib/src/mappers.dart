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
      pinnedPosts: [for (final n in (j['pinnedNotes'] as List? ?? const [])) if (n is Map) note(n.cast<String, Object?>(), viewer: account, host: host)],
      profileUrl: Uri.https(s.account.instance, '/@${s.handle}'),
    );
  }

  static UserListInfo userList(Map<String, Object?> j) => UserListInfo(
        id: j['id'] as String,
        name: (j['name'] ?? '').toString(),
        memberIds: [for (final id in (j['userIds'] as List? ?? const [])) id.toString()],
        isPublic: j['isPublic'] as bool? ?? false,
      );

  /// Misskey clip (`clips/*` / `users/clips`) → [ClipInfo] (D-032).
  static ClipInfo clip(Map<String, Object?> j, {required AccountId account, required String host}) => ClipInfo(
        id: j['id'] as String,
        name: (j['name'] ?? '').toString(),
        description: j['description'] as String?,
        isPublic: j['isPublic'] as bool? ?? false,
        notesCount: (j['notesCount'] as num?)?.toInt(),
        owner: j['user'] is Map ? user((j['user'] as Map).cast<String, Object?>(), account: account, host: host) : null,
      );

  static FollowRequest followRequest(Map<String, Object?> j, {required AccountId account, required String host}) => FollowRequest(
        id: j['id'] as String,
        user: user((j['follower'] as Map).cast<String, Object?>(), account: account, host: host),
        createdAt: _date(j['createdAt']),
      );

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
      // リアクション表示 (D-111): チップ/自分のリアクションは**中身のノート**の
      // ものをそのまま載せる(落とすとフォロー外ユーザーの RT でリアクション系が
      // 一切出ない)。アクション状態も timelineWithStates が内側から取っている。
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
        replyTo: inner.replyTo,
        replyToId: inner.replyToId,
        repostedBy: author,
        counts: inner.counts,
        visibility: inner.visibility,
        localOnly: inner.localOnly,
        reactions: inner.reactions,
        reactionEmojis: inner.reactionEmojis,
        myReaction: inner.myReaction,
        reactionAcceptance: inner.reactionAcceptance,
        url: inner.url,
      );
    }

    final reactions = (j['reactions'] as Map?)?.cast<String, Object?>() ?? const {};
    final reactionTotal = reactions.values.fold<int>(0, (a, v) => a + ((v as num?)?.toInt() ?? 0));
    final reactionEmojis = (j['reactionEmojis'] as Map?)?.cast<String, Object?>() ?? const {};
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
      // リプライ元 (D-069): TL・リプライ欄の省略タイル表示に使う。
      replyTo: j['reply'] is Map && depth < 2 ? note((j['reply'] as Map).cast<String, Object?>(), viewer: viewer, host: host, depth: depth + 1) : null,
      replyToId: j['replyId'] as String?,
      counts: {
        'reply': (j['repliesCount'] as num?)?.toInt() ?? 0,
        'renote': (j['renoteCount'] as num?)?.toInt() ?? 0,
        'reaction': reactionTotal,
      },
      visibility: j['visibility'] as String?,
      localOnly: j['localOnly'] == true,
      directToIds: [for (final id in (j['visibleUserIds'] as List? ?? const [])) id.toString()],
      reactions: {for (final e in reactions.entries) e.key: (e.value as num?)?.toInt() ?? 0},
      reactionEmojis: {
        // ローカルカスタム(`:name@.:`)は Misskey の reactionEmojis に URL が
        // 来ない → /emoji/<name>.webp を補完(ロング絵文字が
        // テキスト fallback になって消える問題の修正、D-041)。
        for (final k in reactions.keys)
          if (k.startsWith(':') && k.endsWith('@.:')) k: Uri.https(host, '/emoji/${k.substring(1, k.length - 3)}.webp'),
        for (final e in reactionEmojis.entries)
          if (e.value is String) ':${e.key}:': Uri.parse(e.value as String),
      },
      myReaction: j['myReaction'] as String?,
      // 「いいねのみ」のノート (D-321): ホストがチップとピッカーを出さない。
      reactionAcceptance: j['reactionAcceptance'] as String?,
      url: _uri(j['url']) ?? _uri(j['uri']) ?? Uri.https(host, '/notes/${j['id']}'),
    );
  }

  /// Chat message (Misskey 2025.4+) → Post so DM rooms can reuse PostRow.
  static Post chatMessage(Map<String, Object?> j, {required AccountId viewer, required String host, required UserSummary me, UserSummary? peer}) {
    final fromId = j['fromUserId'] as String?;
    final fromUser = j['fromUser'] is Map ? user((j['fromUser'] as Map).cast<String, Object?>(), account: viewer, host: host) : (fromId == me.id ? me : (peer ?? me));
    final file = j['file'] is Map ? (j['file'] as Map).cast<String, Object?>() : null;
    final reactions = <String, int>{};
    for (final r in (j['reactions'] as List? ?? const [])) {
      if (r is Map && r['reaction'] is String) reactions.update(r['reaction'] as String, (v) => v + 1, ifAbsent: () => 1);
    }
    return Post(
      id: j['id'] as String,
      account: viewer,
      author: fromUser,
      createdAt: _date(j['createdAt']) ?? DateTime.now(),
      body: j['text'] as String? ?? '',
      bodyFormat: 'mfm',
      media: [if (file != null) MisskeyMappers.file(file)],
      visibility: 'specified',
      directToIds: [if (j['toUserId'] is String) j['toUserId'] as String],
      reactions: reactions,
      source: PostSource.chatMessage,
    );
  }

  static ReactionEntry reactionEntry(Map<String, Object?> j, {required AccountId viewer, required String host, Map<String, Uri> emojiUrls = const {}}) {
    final type = (j['type'] ?? '').toString();
    return ReactionEntry(
      id: j['id'] as String,
      user: user((j['user'] as Map).cast<String, Object?>(), account: viewer, host: host),
      reaction: type,
      createdAt: _date(j['createdAt']) ?? DateTime.now(),
      emojiUrl: emojiUrls[type],
    );
  }

  static EmojiInfo? emoji(Map<String, Object?> j) {
    final name = j['name'];
    final url = j['url'];
    if (name is! String || url is! String) return null;
    return EmojiInfo(name: name, url: Uri.parse(url), category: j['category'] as String?, aliases: [for (final a in (j['aliases'] as List? ?? const [])) a.toString()]);
  }

  static TrendTag trend(Map<String, Object?> j) => TrendTag(
        tag: (j['tag'] ?? '').toString(),
        usersCount: (j['usersCount'] as num?)?.toInt(),
        chart: [for (final c in (j['chart'] as List? ?? const [])) (c as num).toInt()],
      );

  static NotificationItem notification(Map<String, Object?> j, {required AccountId viewer, required String host}) {
    final rawType = j['type'] as String? ?? 'other';
    final type = rawType.replaceFirst(':grouped', '');
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
      'note' => NotificationKind.other,
      // システム通知 (D-045): app(外部アプリ)/ロール付与/実績/ログイン等。
      // 未知タイプもシステム通知として縮退表示する(落とさない・隠さない)。
      _ => NotificationKind.system,
    };
    // システム通知の見出しと本文。
    final (title, body) = switch (type) {
      'app' => (j['header'] as String? ?? 'アプリからの通知', j['body'] as String?),
      'roleAssigned' => ('ロールが付与されました', (j['role'] is Map ? (j['role'] as Map)['name'] : null) as String?),
      'achievementEarned' => ('実績を獲得しました', j['achievement'] as String?),
      'login' => ('新しいログインがありました', null),
      'test' => ('テスト通知', null),
      'exportCompleted' => ('エクスポートが完了しました', j['exportedEntity'] as String?),
      _ => kind == NotificationKind.system ? ('通知 ($type)', null) : (null, null),
    };
    final actors = <UserSummary>[];
    final byActor = <String, String>{};
    if (j['user'] is Map) actors.add(user((j['user'] as Map).cast<String, Object?>(), account: viewer, host: host));
    for (final u in (j['users'] as List? ?? const [])) {
      if (u is Map) actors.add(user(u.cast<String, Object?>(), account: viewer, host: host));
    }
    for (final r in (j['reactions'] as List? ?? const [])) {
      if (r is Map && r['user'] is Map) {
        final u = user((r['user'] as Map).cast<String, Object?>(), account: viewer, host: host);
        actors.add(u);
        if (r['reaction'] is String) byActor[u.id] = r['reaction'] as String;
      }
    }
    return NotificationItem(
      id: j['id'] as String,
      account: viewer,
      kind: kind,
      createdAt: _date(j['createdAt']) ?? DateTime.now(),
      actors: actors,
      post: j['note'] is Map ? note((j['note'] as Map).cast<String, Object?>(), viewer: viewer, host: host) : null,
      reaction: j['reaction'] as String? ?? (byActor.isNotEmpty ? byActor.values.first : null),
      title: title,
      body: body,
      read: j['isRead'] as bool? ?? false,
      raw: {'type': rawType},
      reactionsByActor: byActor,
    );
  }

  static Uri? _uri(Object? v) => v is String && v.isNotEmpty ? Uri.tryParse(v) : null;
  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
}
