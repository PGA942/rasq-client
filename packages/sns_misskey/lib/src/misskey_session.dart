import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart' show FollowState;

import 'mappers.dart';
import 'misskey_api.dart';

/// Authenticated Misskey session.
class MisskeySession extends SnsSessionBase {
  MisskeySession(this.session, {http.Client? client, List<ActionDescriptor>? actions})
      : api = MisskeyApi(session.account.instance, token: session.token, client: client),
        _actions = actions ?? defaultActions;

  final AccountSession session;
  final MisskeyApi api;
  final List<ActionDescriptor> _actions;
  Map<String, Uri>? _emojis;

  String get host => session.account.instance;

  /// Default reaction used by the single-tap "reaction" button.
  static const defaultReaction = '👍';

  static const defaultActions = [
    ActionDescriptor(id: 'reply', genreTag: 'Reply', label: '返信', icon: 'subdirectory_arrow_left', fow: FowType.interstitial, confirmMode: ConfirmMode.confirm),
    ActionDescriptor(id: 'renote', genreTag: 'Repost', label: 'リノート', icon: 'repeat', doneIcon: 'repeat_on'),
    // 本番: 短押し=予測モデルで最有力の絵文字をリアクション。操作前は投稿ごとに予測絵文字(エッジ抽出)を表示 → iconPerPost.
    ActionDescriptor(id: 'reaction', genreTag: 'Reaction', label: 'リアクション', icon: 'add_reaction_outlined', doneIcon: 'add_reaction', iconPerPost: true),
    ActionDescriptor(id: 'favorite', genreTag: 'Bookmark', label: 'お気に入り', icon: 'star_border', doneIcon: 'star', countSource: CountSource.none),
  ];

  @override
  AccountId get account => session.account;
  @override
  String get pluginId => session.pluginId;
  @override
  List<TimelineKind> get timelines => const [TimelineKind.home, TimelineKind.social, TimelineKind.local, TimelineKind.global];
  @override
  List<ActionDescriptor> get actions => _actions;

  @override
  /// サーバーの広告 (D-438): `meta` の `ads`。1 つのセッションで 1 回だけ読む(読めなければ空)。
  @override
  Future<List<ServerAd>> serverAds() => _ads ??= () async {
        try {
          final meta = await api.callMap('meta', {'detail': false});
          final ads = meta['ads'];
          return [if (ads is List) for (final a in ads) ?ServerAd.fromMisskey(a)];
        } catch (_) {
          return const <ServerAd>[];
        }
      }();
  Future<List<ServerAd>>? _ads;

  @override
  Future<UserSummary> me() async => MisskeyMappers.user(await api.callMap('i'), account: account, host: host);

  static String _timelinePath(TimelineKind k) => switch (k.id) {
        'home' => 'notes/timeline',
        'local' => 'notes/local-timeline',
        'social' => 'notes/hybrid-timeline',
        'global' => 'notes/global-timeline',
        _ => k.id.startsWith('list:') ? 'notes/user-list-timeline' : 'notes/timeline',
      };

  @override
  Future<Page<Post>> timeline(TimelineKind kind, {String? cursor, int limit = 20}) async => (await timelineWithStates(kind, cursor: cursor, limit: limit)).$1;

  /// Raw note list for [kind] (handles dynamic ids: `tag:` / `dm:` / `featured`).
  Future<List<Map<String, Object?>>> _rawTimeline(TimelineKind kind, String? cursor, int limit) async {
    final id = kind.id;
    if (id.startsWith('tag:')) {
      return api.callList('notes/search-by-tag', {'tag': id.substring(4), 'limit': limit, 'untilId': ?cursor});
    }
    if (id == 'featured') {
      return cursor == null ? api.callList('notes/featured', {'limit': limit}) : const [];
    }
    if (id.startsWith('chat:')) {
      if (cursor != null) return const [];
      final peer = id.substring(5);
      try {
        final msgs = await api.callList('chat/messages/user-timeline', {'userId': peer, 'limit': limit});
        return [for (final m in msgs) {...m, '__chat': true}];
      } on SnsApiException catch (e) {
        if (_chatUnavailable(e)) return const [];
        rethrow;
      }
    }
    if (id.startsWith('dm:')) {
      if (cursor != null) return const [];
      final peer = id.substring(3);
      final all = await _directNotes();
      final mine = await _myId();
      return [
        for (final n in all)
          if ((n['userId'] == peer) || (n['userId'] == mine && (n['visibleUserIds'] as List? ?? const []).contains(peer))) n,
      ];
    }
    final body = <String, Object?>{'limit': limit, 'untilId': ?cursor};
    if (id.startsWith('list:')) body['listId'] = id.substring(5);
    // タイムライン設定 (D-044): 標準 TL + リスト TL は withRenotes、
    // withReplies は対応エンドポイント(home/local/social)のみ。
    body['withRenotes'] = _withRenotes;
    if (id == 'home' || id == 'local' || id == 'social') body['withReplies'] = _withReplies;
    return api.callList(_timelinePath(kind), body);
  }

  // --- プラグイン設定 (D-044: settings_pages.dart のページに対応) ---
  bool _withRenotes = true;
  bool _withReplies = false;

  @override
  Future<void> applySettings(String area, Map<String, Object?> values) async {
    if (area != 'timeline') return;
    _withRenotes = values['withRenotes'] != false;
    _withReplies = values['withReplies'] == true;
  }

  /// `account` ページ (source: remote) が読み書きするキー。
  static const accountSettingKeys = ['isLocked', 'isExplorable', 'hideOnlineStatus', 'publicReactions', 'isBot', 'isCat'];

  Map<String, Object?> _accountSettings(Map<String, Object?> i) => {for (final k in accountSettingKeys) k: i[k] == true};

  @override
  Future<Map<String, Object?>> settingsRead(String area) async {
    if (area != 'account') throw UnsupportedError('unknown remote settings area: $area');
    return _accountSettings(await api.callMap('i'));
  }

  @override
  Future<Map<String, Object?>> settingsWrite(String area, String key, Object? value) async {
    if (area != 'account' || !accountSettingKeys.contains(key)) {
      throw UnsupportedError('unknown remote setting: $area.$key');
    }
    return _accountSettings(await api.callMap('i/update', {key: value == true}));
  }

  String? _cachedMyId;
  Future<String> _myId() async => _cachedMyId ??= (await api.callMap('i'))['id'] as String;

  /// Received + sent direct notes, newest first (sample: no paging).
  Future<List<Map<String, Object?>>> _directNotes({int limit = 50}) async {
    final mine = await _myId();
    final received = await api.callList('notes/mentions', {'visibility': 'specified', 'limit': limit});
    final sentAll = await api.callList('users/notes', {'userId': mine, 'limit': limit, 'withReplies': true});
    final sent = [for (final n in sentAll) if (n['visibility'] == 'specified') n];
    final seen = <String>{};
    final all = [for (final n in [...received, ...sent]) if (seen.add(n['id'] as String)) n];
    all.sort((a, b) => (b['createdAt'] as String? ?? '').compareTo(a['createdAt'] as String? ?? ''));
    return all;
  }

  UserSummary? _me;
  Future<UserSummary> _meUser() async => _me ??= await me();

  static bool _chatUnavailable(SnsApiException e) => e.code.code == '404' || e.code.code == '403' || e.code.code == '400';

  Page<Post> _page(List<Map<String, Object?>> list) {
    final posts = [
      for (final n in list)
        if (n['__chat'] == true) MisskeyMappers.chatMessage(n, viewer: account, host: host, me: _me ?? UserSummary(id: _cachedMyId ?? '', account: account, displayName: account.handle)) else MisskeyMappers.note(n, viewer: account, host: host),
    ];
    return Page(items: posts, nextCursor: list.isEmpty ? null : list.last['id'] as String?);
  }

  @override
  Future<Post> post(String id) async => MisskeyMappers.note(await api.callMap('notes/show', {'noteId': id}), viewer: account, host: host);

  @override
  Future<Thread> thread(String id) async {
    id = _actionTarget(id); // 純リノートは中身のスレッドへ (D-111)
    final target = await post(id);
    final conv = await api.callList('notes/conversation', {'noteId': id, 'limit': 30});
    final children = await api.callList('notes/children', {'noteId': id, 'limit': 30});
    return Thread(
      post: target,
      ancestors: [for (final n in conv.reversed) MisskeyMappers.note(n, viewer: account, host: host)],
      descendants: [for (final n in children) MisskeyMappers.note(n, viewer: account, host: host)],
    );
  }

  @override
  Future<Post> createPost(NewPost draft) async {
    final body = <String, Object?>{
      if (draft.repostOfId == null) 'text': draft.text,
      if (draft.contentWarning != null) 'cw': draft.contentWarning,
      if (draft.replyToId != null) 'replyId': draft.replyToId,
      if (draft.quoteOfId != null) 'renoteId': draft.quoteOfId,
      if (draft.repostOfId != null) 'renoteId': draft.repostOfId,
      if (draft.visibility != null) 'visibility': draft.visibility,
      // ダイレクト (D-047): specified には宛先が必須(DM ルームへの返信等)。
      if (draft.visibility == 'specified' && draft.directToIds.isNotEmpty) 'visibleUserIds': draft.directToIds,
      if (draft.localOnly) 'localOnly': true,
      if (draft.reactionAcceptance != null) 'reactionAcceptance': draft.reactionAcceptance,
      if (draft.mediaIds.isNotEmpty) 'fileIds': draft.mediaIds,
      if (draft.poll != null)
        'poll': {
          'choices': draft.poll!.choices,
          'multiple': draft.poll!.multiple,
          if (draft.poll!.expiresAfter != null) 'expiredAfter': draft.poll!.expiresAfter!.inMilliseconds,
        },
    };
    final res = await api.callMap('notes/create', body);
    return MisskeyMappers.note((res['createdNote'] as Map).cast<String, Object?>(), viewer: account, host: host);
  }

  @override
  Future<void> deletePost(String id) => api.call('notes/delete', {'noteId': id});

  @override
  Future<ActionResult> performAction(String actionId, String postId, {Map<String, Object?> args = const {}}) async {
    postId = _actionTarget(postId); // 純リノートは中身のノートへ (D-111)
    switch (actionId) {
      case 'reaction':
        final undo = args['undo'] == true;
        if (undo) {
          await api.call('notes/reactions/delete', {'noteId': postId});
        } else {
          if (args['reaction'] != null) {
            // Explicit emoji: replace whatever reaction exists (Misskey allows one per user).
            try {
              await api.call('notes/reactions/delete', {'noteId': postId});
            } on SnsApiException {
              // no existing reaction
            }
          }
          await api.call('notes/reactions/create', {'noteId': postId, 'reaction': args['reaction'] ?? defaultReaction});
        }
        final n = await api.callMap('notes/show', {'noteId': postId});
        final reactions = (n['reactions'] as Map?)?.cast<String, Object?>() ?? const {};
        final total = reactions.values.fold<int>(0, (a, v) => a + ((v as num?)?.toInt() ?? 0));
        // リアクションした絵文字をボタンアイコンに反映 (D-040, iconPerPost)。
        return ActionResult(done: n['myReaction'] != null, count: total, icon: reactionIcon(n['myReaction'] as String?, host));
      case 'renote':
        if (args['undo'] == true) {
          await api.call('notes/unrenote', {'noteId': postId});
        } else {
          await api.call('notes/create', {'renoteId': postId});
        }
        final n = await api.callMap('notes/show', {'noteId': postId});
        return ActionResult(done: args['undo'] != true, count: (n['renoteCount'] as num?)?.toInt());
      case 'favorite':
        if (args['undo'] == true) {
          await api.call('notes/favorites/delete', {'noteId': postId});
          return const ActionResult(done: false);
        }
        await api.call('notes/favorites/create', {'noteId': postId});
        return const ActionResult(done: true);
      default:
        throw UnsupportedError('action $actionId');
    }
  }

  @override
  Future<Map<String, Map<String, ActionResult>>> actionStates(List<Post> posts) async {
    // Misskey returns myReaction on the note itself; we re-derive from raw
    // fetches in timeline() (see mapper counts). Done flags need the raw note,
    // so callers that need exact "done" should use [noteStates].
    // 投稿の myReaction から「済み」とアイコンを出す (D-281)。カスタム絵文字は、このサーバーの絵文字の URL で。
    final base = await super.actionStates(posts);
    for (final p in posts) {
      if (p.myReaction != null) base[p.id]?['reaction'] = ActionResult(done: true, count: base[p.id]?['reaction']?.count, icon: reactionIcon(p.myReaction, host));
    }
    return base;
  }

  /// `myReaction` 文字列 → ボタンアイコン (D-040)。Unicode はテキスト、
  /// カスタム(`:name@.:`)は `/emoji/<name>.webp` の画像。
  static ActionIcon? reactionIcon(String? reaction, String host) {
    if (reaction == null) return null;
    if (!reaction.startsWith(':')) return ActionIcon.text(reaction);
    final name = reaction.substring(1, reaction.length - 1).split('@').first;
    return ActionIcon.url(snsUri(host, '/emoji/$name.webp'));
  }

  /// Per-note action states from raw note JSON (used by the timeline notifier).
  static Map<String, ActionResult> noteStates(Map<String, Object?> n, {String? host}) {
    final reactions = (n['reactions'] as Map?)?.cast<String, Object?>() ?? const {};
    final total = reactions.values.fold<int>(0, (a, v) => a + ((v as num?)?.toInt() ?? 0));
    return {
      'reply': ActionResult(done: false, count: (n['repliesCount'] as num?)?.toInt() ?? 0),
      'renote': ActionResult(done: false, count: (n['renoteCount'] as num?)?.toInt() ?? 0),
      // TL でもリアクション済み絵文字がボタンに出る (D-040)。
      'reaction': ActionResult(done: n['myReaction'] != null, count: total, icon: host == null ? null : reactionIcon(n['myReaction'] as String?, host)),
      'favorite': ActionResult(done: n['isFavorited'] == true),
    };
  }

  /// Timeline fetch that also returns per-note action states.
  Future<(Page<Post>, Map<String, Map<String, ActionResult>>)> timelineWithStates(TimelineKind kind, {String? cursor, int limit = 20}) async {
    if (kind.id.startsWith('chat:')) await _meUser();
    final list = await _rawTimeline(kind, cursor, limit);
    var page = _page(list);
    if (kind.id == 'featured' || kind.id.startsWith('dm:') || kind.id.startsWith('chat:')) page = Page(items: page.items); // not paged
    final states = <String, Map<String, ActionResult>>{};
    for (var i = 0; i < list.length; i++) {
      final raw = list[i];
      // For pure renotes the displayed post is the inner note, but the row id is the renote id.
      if (raw['__chat'] == true) continue;
      final inner = raw['renote'] is Map && (raw['text'] == null || (raw['text'] as String).isEmpty) ? (raw['renote'] as Map).cast<String, Object?>() : raw;
      // 純リノートのアクション読み替え (D-111): リアクション等は**中身の
      // ノート**に付ける(公式クライアントの appearNote と同じ)。
      if (!identical(inner, raw) && inner['id'] is String) {
        _renoteTarget[page.items[i].id] = inner['id'] as String;
      }
      states[page.items[i].id] = noteStates(inner, host: host);
    }
    return (page, states);
  }

  /// 純リノートの行 id → 中身のノート id (D-111)。TL 取得時に採取。
  final Map<String, String> _renoteTarget = {};

  String _actionTarget(String postId) => _renoteTarget[postId] ?? postId;

  @override
  Future<Page<NotificationItem>> notifications({String? cursor, int limit = 20}) async {
    List<Map<String, Object?>> list;
    try {
      list = await api.callList('i/notifications-grouped', {'limit': limit, 'untilId': ?cursor});
    } on SnsApiException catch (e) {
      if (e.code.code != '404') rethrow;
      list = await api.callList('i/notifications', {'limit': limit, 'untilId': ?cursor});
    }
    return Page(
      items: [for (final n in list) MisskeyMappers.notification(n, viewer: account, host: host)],
      nextCursor: list.isEmpty ? null : list.last['id'] as String?,
    );
  }

  @override
  Future<void> markNotificationsRead() => api.call('notifications/mark-all-as-read');

  @override
  Future<UserProfile> user(String id) async => MisskeyMappers.profile(await api.callMap('users/show', {'userId': id}), account: account, host: host);

  @override
  Future<UserProfile?> userByHandle(String handle, {String? host}) async {
    try {
      final j = await api.callMap('users/show', {'username': handle, if (host != null && host != this.host) 'host': host});
      return MisskeyMappers.profile(j, account: account, host: this.host);
    } on SnsApiException catch (e) {
      if (e.code.code == '404') return null;
      rethrow;
    }
  }

  @override
  Future<Page<Post>> userPosts(String id, {String? cursor, int limit = 20, UserPostsFilter filter = UserPostsFilter.posts}) async {
    final body = <String, Object?>{
      'userId': id,
      'limit': limit,
      'untilId': ?cursor,
      'withReplies': filter == UserPostsFilter.withReplies || filter == UserPostsFilter.replies,
      'withRenotes': filter != UserPostsFilter.media,
      if (filter == UserPostsFilter.media) 'withFiles': true,
    };
    final list = await api.callList('users/notes', body);
    bool isQuote(Map n) => n['renote'] is Map && (n['text'] as String?)?.isNotEmpty == true;
    bool isReply(Map n) => n['reply'] is Map || n['replyId'] != null;
    // 返信TL / 引用TL への振り分け (D-069): 返信は返信のみ、引用は引用のみ、
    // ノートは両方を除いたもの(純リノートは残す)。
    return switch (filter) {
      UserPostsFilter.replies => _page([for (final n in list) if (isReply(n)) n]),
      UserPostsFilter.quotes => _page([for (final n in list) if (isQuote(n)) n]),
      UserPostsFilter.posts => _page([for (final n in list) if (!isQuote(n) && !isReply(n)) n]),
      _ => _page(list),
    };
  }

  @override
  Future<List<FollowRequest>> followRequests() async =>
      [for (final r in await api.callList('following/requests/list', {'limit': 50})) MisskeyMappers.followRequest(r, account: account, host: host)];
  @override
  Future<void> acceptFollowRequest(String userId) => api.call('following/requests/accept', {'userId': userId});
  @override
  Future<void> rejectFollowRequest(String userId) => api.call('following/requests/reject', {'userId': userId});

  @override
  Future<Page<UserSummary>> mutedUsers({String? cursor, int limit = 30}) => _relationList('mute/list', 'mutee', cursor, limit);
  @override
  Future<Page<UserSummary>> blockedUsers({String? cursor, int limit = 30}) => _relationList('blocking/list', 'blockee', cursor, limit);

  Future<Page<UserSummary>> _relationList(String path, String field, String? cursor, int limit) async {
    final list = await api.callList(path, {'limit': limit, 'untilId': ?cursor});
    return Page(
      items: [for (final e in list) if (e[field] is Map) MisskeyMappers.user((e[field] as Map).cast<String, Object?>(), account: account, host: host)],
      nextCursor: list.isEmpty ? null : list.last['id'] as String?,
    );
  }

  @override
  Future<void> reportUser(String userId, String comment) => api.call('users/report-abuse', {'userId': userId, 'comment': comment});

  @override
  Future<UserProfile> updateProfile(ProfileUpdate update) async {
    final u = update;
    final body = <String, Object?>{
      if (u.displayName != null) 'name': u.displayName,
      if (u.description != null) 'description': u.description,
      if (u.location != null) 'location': u.location,
      if (u.birthday != null) 'birthday': u.birthday!.isEmpty ? null : u.birthday,
      if (u.fields != null) 'fields': [for (final f in u.fields!) {'name': f.name, 'value': f.value}],
      if (u.avatarMediaId != null) 'avatarId': u.avatarMediaId,
      if (u.bannerMediaId != null) 'bannerId': u.bannerMediaId,
    };
    final res = await api.callMap('i/update', body);
    _me = null;
    return MisskeyMappers.profile(res, account: account, host: host);
  }

  @override
  Future<List<UserListInfo>> lists() async => [for (final l in await api.callList('users/lists/list')) MisskeyMappers.userList(l)];
  @override
  Future<UserListInfo> listInfo(String listId) async => MisskeyMappers.userList(await api.callMap('users/lists/show', {'listId': listId}));
  @override
  Future<List<UserSummary>> listMembers(String listId) async {
    final info = await listInfo(listId);
    if (info.memberIds.isEmpty) return const [];
    return [for (final p in await users(info.memberIds)) p.summary];
  }
  @override
  Future<UserListInfo> createList(String name) async => MisskeyMappers.userList(await api.callMap('users/lists/create', {'name': name}));
  @override
  Future<void> addToList(String listId, String userId) => api.call('users/lists/push', {'listId': listId, 'userId': userId});
  @override
  Future<void> removeFromList(String listId, String userId) => api.call('users/lists/pull', {'listId': listId, 'userId': userId});

  // --- クリップ (D-032: Misskey ネイティブ) ---
  @override
  Future<List<ClipInfo>> clips({String? userId}) async => [
        for (final c in await api.callList(userId == null ? 'clips/list' : 'users/clips', {'userId': ?userId}))
          MisskeyMappers.clip(c, account: account, host: host),
      ];

  @override
  Future<ClipInfo> clipInfo(String clipId) async => MisskeyMappers.clip(await api.callMap('clips/show', {'clipId': clipId}), account: account, host: host);

  @override
  Future<Page<Post>> clipNotes(String clipId, {String? cursor, int limit = 20}) async {
    final list = await api.callList('clips/notes', {'clipId': clipId, 'limit': limit, 'untilId': ?cursor});
    return Page(
      items: [for (final n in list) MisskeyMappers.note(n, viewer: account, host: host)],
      nextCursor: list.length < limit ? null : list.last['id'] as String?,
    );
  }

  @override
  Future<ClipInfo> createClip(String name, {String? description, bool isPublic = false}) async =>
      MisskeyMappers.clip(await api.callMap('clips/create', {'name': name, 'isPublic': isPublic, 'description': ?description}), account: account, host: host);

  @override
  Future<void> deleteClip(String clipId) => api.call('clips/delete', {'clipId': clipId});

  @override
  Future<void> addToClip(String clipId, String postId) => api.call('clips/add-note', {'clipId': clipId, 'noteId': postId});

  @override
  Future<void> removeFromClip(String clipId, String postId) => api.call('clips/remove-note', {'clipId': clipId, 'noteId': postId});

  @override
  Future<List<PlayInfo>> userPlays(String userId) async => [
        for (final f in await api.callList('users/flashs', {'userId': userId}))
          PlayInfo(
            id: f['id'] as String,
            title: (f['title'] ?? '').toString(),
            summary: f['summary'] as String?,
            url: Uri.https(host, '/play/${f['id']}'),
          ),
      ];

  @override
  Future<Page<Post>> favorites({String? cursor, int limit = 20}) async {
    final list = await api.callList('i/favorites', {'limit': limit, 'untilId': ?cursor});
    return Page(
      items: [for (final f in list) if (f['note'] is Map) MisskeyMappers.note((f['note'] as Map).cast<String, Object?>(), viewer: account, host: host)],
      nextCursor: list.isEmpty ? null : list.last['id'] as String?,
    );
  }

  /// 自分がリアクションした投稿 (D-103: ノードの取得口)。
  @override
  Future<Page<Post>> reactedPosts({String? cursor, int limit = 20}) async {
    final list = await api.callList('users/reactions', {'userId': await _myId(), 'limit': limit, 'untilId': ?cursor});
    return Page(
      items: [for (final r in list) if (r['note'] is Map) MisskeyMappers.note((r['note'] as Map).cast<String, Object?>(), viewer: account, host: host)],
      nextCursor: list.isEmpty ? null : list.last['id'] as String?,
    );
  }

  @override
  Future<Page<UserSummary>> followers(String id, {String? cursor, int limit = 20}) => _follows('users/followers', 'follower', id, cursor, limit);
  @override
  Future<Page<UserSummary>> following(String id, {String? cursor, int limit = 20}) => _follows('users/following', 'followee', id, cursor, limit);

  Future<Page<UserSummary>> _follows(String path, String field, String id, String? cursor, int limit) async {
    final list = await api.callList(path, {'userId': id, 'limit': limit, 'untilId': ?cursor});
    return Page(
      items: [for (final e in list) if (e[field] is Map) MisskeyMappers.user((e[field] as Map).cast<String, Object?>(), account: account, host: host)],
      nextCursor: list.isEmpty ? null : list.last['id'] as String?,
    );
  }

  @override
  Future<FollowState> relationship(String userId) async => MisskeyMappers.relation(await api.callMap('users/relation', {'userId': userId}));

  @override
  Future<FollowState> setFollowing(String userId, bool following) async {
    await api.call(following ? 'following/create' : 'following/delete', {'userId': userId});
    return relationship(userId);
  }

  @override
  Future<FollowState> setMuted(String userId, bool muted) async {
    await api.call(muted ? 'mute/create' : 'mute/delete', {'userId': userId});
    return relationship(userId);
  }

  @override
  Future<FollowState> setBlocked(String userId, bool blocked) async {
    await api.call(blocked ? 'blocking/create' : 'blocking/delete', {'userId': userId});
    return relationship(userId);
  }

  @override
  Future<Page<Post>> searchPosts(String query, {String? cursor, int limit = 20}) async =>
      _page(await api.callList('notes/search', {'query': query, 'limit': limit, 'untilId': ?cursor}));

  @override
  Future<Page<UserSummary>> searchUsers(String query, {String? cursor, int limit = 20}) async {
    final list = await api.callList('users/search', {'query': query, 'limit': limit});
    return Page(items: [for (final u in list) MisskeyMappers.user(u, account: account, host: host)]);
  }

  @override
  Future<List<TrendTag>> trendingTags() async => [for (final t in await api.callList('hashtags/trend')) MisskeyMappers.trend(t)];

  @override
  Future<List<DmRoom>> dmRooms() async {
    final mine = await _myId();
    final notes = await _directNotes();
    final byPeer = <String, Map<String, Object?>>{}; // peerId → newest note
    final peerUsers = <String, Map<String, Object?>>{};
    for (final n in notes) {
      final String peer;
      if (n['userId'] == mine) {
        final ids = (n['visibleUserIds'] as List? ?? const []);
        if (ids.isEmpty) continue;
        peer = ids.first.toString();
      } else {
        peer = n['userId'] as String;
        peerUsers[peer] = (n['user'] as Map).cast<String, Object?>();
      }
      byPeer.putIfAbsent(peer, () => n);
    }
    final missing = [for (final id in byPeer.keys) if (!peerUsers.containsKey(id)) id];
    if (missing.isNotEmpty) {
      final users = await api.callList('users/show', {'userIds': missing});
      for (final u in users) {
        peerUsers[u['id'] as String] = u;
      }
    }
    final rooms = <DmRoom>[];
    for (final e in byPeer.entries) {
      final u = peerUsers[e.key];
      if (u == null) continue;
      rooms.add(DmRoom(
        id: e.key,
        peer: MisskeyMappers.user(u, account: account, host: host),
        lastPost: MisskeyMappers.note(e.value, viewer: account, host: host),
      ));
    }
    rooms.addAll(await _chatRooms());
    return rooms;
  }

  /// Native chat rooms (1:1 only). Silently empty when the instance has no chat.
  Future<List<DmRoom>> _chatRooms() async {
    try {
      final me = await _meUser();
      final history = await api.callList('chat/history', {'room': false, 'limit': 50});
      final rooms = <DmRoom>[];
      for (final m in history) {
        final fromId = m['fromUserId'] as String?;
        final toId = m['toUserId'] as String?;
        final peerJson = (fromId == me.id ? m['toUser'] : m['fromUser']);
        final peerId = fromId == me.id ? toId : fromId;
        if (peerId == null) continue;
        UserSummary peer;
        if (peerJson is Map) {
          peer = MisskeyMappers.user(peerJson.cast<String, Object?>(), account: account, host: host);
        } else {
          final us = await api.callList('users/show', {'userIds': [peerId]});
          if (us.isEmpty) continue;
          peer = MisskeyMappers.user(us.first, account: account, host: host);
        }
        rooms.add(DmRoom(
          id: 'chat:$peerId',
          kind: DmRoomKind.chat,
          peer: peer,
          lastPost: MisskeyMappers.chatMessage(m, viewer: account, host: host, me: me, peer: peer),
          unreadCount: m['isRead'] == false && fromId != me.id ? 1 : 0,
        ));
      }
      return rooms;
    } on SnsApiException catch (e) {
      if (_chatUnavailable(e)) return const [];
      rethrow;
    }
  }

  @override
  Future<Post> sendDm(DmRoom room, NewPost draft) async {
    if (room.kind == DmRoomKind.chat) {
      final me = await _meUser();
      final res = await api.callMap('chat/messages/create-to-user', {
        'toUserId': room.peer.id,
        if (draft.text.isNotEmpty) 'text': draft.text,
        if (draft.mediaIds.isNotEmpty) 'fileId': draft.mediaIds.first,
      });
      return MisskeyMappers.chatMessage(res, viewer: account, host: host, me: me, peer: room.peer);
    }
    final res = await api.callMap('notes/create', {
      'text': draft.text,
      'visibility': 'specified',
      'visibleUserIds': [room.peer.id],
      if (draft.contentWarning != null) 'cw': draft.contentWarning,
      if (draft.mediaIds.isNotEmpty) 'fileIds': draft.mediaIds,
    });
    return MisskeyMappers.note((res['createdNote'] as Map).cast<String, Object?>(), viewer: account, host: host);
  }

  @override
  Future<Page<ReactionEntry>> reactions(String postId, {String? type, String? cursor, int limit = 30}) async {
    postId = _actionTarget(postId); // D-111
    final list = await api.callList('notes/reactions', {'noteId': postId, 'type': ?type, 'limit': limit, 'untilId': ?cursor});
    final urls = <String, Uri>{};
    for (final r in list) {
      final t = (r['type'] ?? '').toString();
      if (t.startsWith(':') && !urls.containsKey(t)) {
        final u = await emojiUrl(t.substring(1, t.length - 1));
        if (u != null) urls[t] = u;
      }
    }
    return Page(items: [for (final r in list) MisskeyMappers.reactionEntry(r, viewer: account, host: host, emojiUrls: urls)], nextCursor: list.isEmpty ? null : list.last['id'] as String?);
  }

  @override
  Future<Page<UserSummary>> reposters(String postId, {String? cursor, int limit = 30}) async {
    postId = _actionTarget(postId); // D-111
    final list = await api.callList('notes/renotes', {'noteId': postId, 'limit': limit, 'untilId': ?cursor});
    return Page(
      items: [for (final n in list) if (n['user'] is Map) MisskeyMappers.user((n['user'] as Map).cast<String, Object?>(), account: account, host: host)],
      nextCursor: list.isEmpty ? null : list.last['id'] as String?,
    );
  }

  @override
  Future<Page<Post>> quotes(String postId, {String? cursor, int limit = 30}) async {
    postId = _actionTarget(postId); // D-111
    final list = await api.callList('notes/renotes', {'noteId': postId, 'limit': limit, 'untilId': ?cursor});
    // 引用ノートのみ(本文/添付/CW のあるリノート)。純リノートは
    // reposters(リノートした人)側で見る (D-070)。
    return _page([
      for (final n in list)
        if ((n['text'] as String?)?.isNotEmpty == true || (n['fileIds'] as List? ?? const []).isNotEmpty || n['cw'] != null) n
    ]);
  }

  @override
  Future<List<UserProfile>> users(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final out = <UserProfile>[];
    for (var i = 0; i < ids.length; i += 100) {
      final chunk = ids.sublist(i, (i + 100).clamp(0, ids.length));
      final list = await api.callList('users/show', {'userIds': chunk});
      out.addAll([for (final u in list) MisskeyMappers.profile(u, account: account, host: host)]);
    }
    return out;
  }

  @override
  Future<Map<String, FollowState>> relationships(List<String> userIds) async {
    if (userIds.isEmpty) return const {};
    final res = await api.call('users/relation', {'userId': userIds});
    final list = res is List ? res : [res];
    return {for (final r in list) if (r is Map) r['id'] as String: MisskeyMappers.relation(r.cast<String, Object?>())};
  }

  @override
  int get maxPostLength => 3000;

  @override
  Future<MediaItem> uploadMedia(Uint8List bytes, String filename, {String? mimeType, bool sensitive = false, String? alt}) async {
    final res = await api.upload('drive/files/create', bytes: bytes, filename: filename, mimeType: mimeType, fields: {
      'name': filename,
      'isSensitive': '$sensitive',
      'force': 'true',
      if (alt != null && alt.isNotEmpty) 'comment': alt,
    });
    return MisskeyMappers.file(res);
  }

  @override
  Future<List<EmojiInfo>> customEmojis() async {
    try {
      final res = await api.callMap('emojis');
      final list = <EmojiInfo>[];
      for (final e in (res['emojis'] as List? ?? const [])) {
        if (e is Map) {
          final info = MisskeyMappers.emoji(e.cast<String, Object?>());
          if (info != null) list.add(info);
        }
      }
      _emojis ??= {for (final e in list) e.name: e.url};
      return list;
    } on SnsApiException {
      return const [];
    }
  }

  @override
  Future<Uri?> emojiUrl(String shortcode) async {
    if (_emojis == null) {
      try {
        final res = await api.callMap('emojis');
        _emojis = {
          for (final e in (res['emojis'] as List? ?? const []))
            if (e is Map && e['name'] is String && e['url'] is String) e['name'] as String: Uri.parse(e['url'] as String),
        };
      } on SnsApiException {
        _emojis = const {};
      }
    }
    return _emojis![shortcode.replaceAll('@.', '')];
  }

  @override
  Future<void> close() async => api.close();
}
