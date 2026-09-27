import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';

/// Fake SNS plugin/session for widget tests — serves a fixed timeline.
class FakeSnsPlugin extends SnsPlugin {
  FakeSnsPlugin({required this.posts, this.kind = SnsKind.misskey, this.id = 'test.fake', this.feeds = const [], this.settingsPages = const [], this.localEmojis, this.reactionActionId = 'reaction', this.bookmark = false});
  final List<Post> Function(AccountId viewer) posts;

  /// 渡すと、Misskey のように**絵文字でリアクションする**セッションになる(`iconPerPost`。D-278)。中身 = 自サーバーにある絵文字の名前。
  final Set<String>? localEmojis;

  /// リアクションのボタンの id(Mastodon のお気に入りは `favourite` のように、SNS ごとに違う。D-321)。
  final String reactionActionId;

  /// 開いたセッション(テストから、送ったリアクションを見る)。
  final List<FakeSnsSession> opened = [];

  /// SNS 側のブックマーク(Misskey のお気に入りと同じ `favorite` / genreTag `Bookmark`)を持つか (D-342)。
  final bool bookmark;
  @override
  final SnsKind kind;
  final String id;

  /// 設定第二階層ページ (D-225): RAi の settings.set のゲート(操作禁止タグ)のテスト用。
  @override
  final List<String> settingsPages;

  /// カスタムフィード (D-194): Bluesky 役のフェイクが検索で返すもの。
  final List<FeedInfo> feeds;
  @override
  PluginManifest get manifest => PluginManifest(id: id, name: 'Fake', version: '0.0.1', kind: PluginKind.sns, supportedSns: [kind]);
  @override
  Future<ServerInfo> inspectServer(String host) async => ServerInfo(host: host, name: 'Fake');
  @override
  Future<AuthFlow> beginAuth(String host, {Uri? callback}) => throw UnimplementedError();
  @override
  SnsSession open(AccountSession session) {
    final s = FakeSnsSession(session, posts(session.account), feeds: feeds, kind: kind, localEmojis: localEmojis, reactionActionId: reactionActionId, bookmark: bookmark);
    opened.add(s);
    return s;
  }
}

class FakeSnsSession extends SnsSessionBase {
  FakeSnsSession(this.session, List<Post> posts, {this.feeds = const [], this.kind = SnsKind.misskey, this.localEmojis, this.reactionActionId = 'reaction', this.bookmark = false}) : _posts = [...posts];
  final bool bookmark;

  /// addToClip の呼び出し(`clipId:postId`)。
  final List<String> clipAdds = [];
  final Set<String>? localEmojis;
  final String reactionActionId;

  /// TL の先頭に投稿を足す(取り直すと出る)。
  void prepend(Post p) => _posts.insert(0, p);

  /// 送ったリアクション(`args['reaction']`。無ければ null)。
  final List<String?> reactionsSent = [];
  @override
  Future<Uri?> emojiUrl(String shortcode) async => (localEmojis ?? const {}).contains(shortcode) ? Uri.parse('https://example.test/emoji/$shortcode.png') : null;
  final AccountSession session;
  final List<Post> _posts;
  final List<String> performed = [];
  final List<FeedInfo> feeds;
  final SnsKind kind;

  @override
  AccountId get account => session.account;
  @override
  String get pluginId => session.pluginId;
  @override
  List<TimelineKind> get timelines => kind == SnsKind.bluesky ? const [TimelineKind.home, TimelineKind('global', 'Discover')] : const [TimelineKind.home, TimelineKind.social];
  @override
  List<ActionDescriptor> get actions => [
        // 返信は実際のプラグイン同様 confirm + interstitial(RAi からの自動実行は不可、D-223)。
        const ActionDescriptor(id: 'reply', genreTag: 'Reply', label: '返信', icon: 'subdirectory_arrow_left', confirmMode: ConfirmMode.confirm, fow: FowType.interstitial),
        const ActionDescriptor(id: 'renote', genreTag: 'Repost', label: 'リノート', icon: 'repeat', doneIcon: 'repeat_on'),
        ActionDescriptor(id: reactionActionId, genreTag: 'Reaction', label: 'リアクション', icon: 'favorite_border', doneIcon: 'favorite', iconPerPost: localEmojis != null),
        if (bookmark) const ActionDescriptor(id: 'favorite', genreTag: 'Bookmark', label: 'お気に入り', icon: 'star_border', doneIcon: 'star', countSource: CountSource.none),
      ];
  @override
  Future<UserSummary> me() async => UserSummary(id: 'me', account: account, displayName: 'テスター');
  /// TL を取りに来た回数(更新タイルのテスト用)。
  int timelineFetches = 0;

  @override
  Future<Page<Post>> timeline(TimelineKind kind, {String? cursor, int limit = 20}) async {
    timelineFetches++;
    if (cursor != null) return Page.empty();
    if (kind.id.startsWith('tag:')) return Page(items: _posts.where((p) => p.id == 'p1').toList());
    if (kind.id.startsWith('dm:')) return Page(items: [_posts.last]);
    if (kind == DynamicTimelines.featured) return Page(items: _posts.take(2).toList());
    return Page(items: _posts);
  }
  /// thread() を呼ばれた投稿 id(D-155: どのアカウントのセッションで開いたか)。
  final List<String> threadRequests = [];

  /// 投稿 1 件を取る (D-223: RAi の post.get)。
  @override
  Future<Post> post(String id) async => _posts.firstWhere((p) => p.id == id, orElse: () => throw SnsApiException(ErrorCode.notFound));

  /// 本文に query を含む投稿を返す (D-223: RAi の posts.fetch(kind=search) / user.search と同じ作法)。
  @override
  Future<Page<Post>> searchPosts(String query, {String? cursor, int limit = 20}) async => cursor != null ? Page.empty() : Page(items: [for (final p in _posts) if (p.body.contains(query)) p].take(limit).toList());

  @override
  Future<Thread> thread(String id) async {
    threadRequests.add(id);
    final p = _posts.firstWhere((e) => e.id == id);
    // Misskey の notes/children 同様、リプライ以外(引用等)も混ぜて返す —
    // 返信欄のリプライ絞り込み (D-071) は表示側の仕事。
    return Thread(post: p, descendants: _posts.where((e) => e.id != id).take(2).toList());
  }
  /// 最後に createPost へ渡された draft (投稿オプションのテスト用)。
  NewPost? lastDraft;

  /// 最後に sendDm へ渡された draft (共有 FOW の「DM へ共有」、D-170)。
  NewPost? lastDm;

  @override
  Future<Post> sendDm(DmRoom room, NewPost draft) async {
    lastDm = draft;
    final me = await this.me();
    return Post(id: 'dm${_posts.length}', account: account, author: me, createdAt: DateTime.now(), body: draft.text, visibility: 'specified', directToIds: [room.peer.id]);
  }

  @override
  Future<Post> createPost(NewPost draft) async {
    lastDraft = draft;
    final me = await this.me();
    final p = Post(id: 'new${_posts.length}', account: account, author: me, createdAt: DateTime.now(), body: draft.text, contentWarning: draft.contentWarning);
    _posts.insert(0, p);
    return p;
  }
  /// リアクション済み取得 (D-103/D-154): 手元の投稿をそのまま返す。
  @override
  Future<Page<Post>> reactedPosts({String? cursor, int limit = 20}) async => cursor != null ? Page.empty() : Page(items: _posts.take(limit).toList());
  @override
  Future<Page<ReactionEntry>> reactions(String postId, {String? type, String? cursor, int limit = 30}) async =>
      Page(items: [ReactionEntry(id: 'r1', user: _posts.first.author, reaction: type ?? '👍', createdAt: DateTime(2026))]);
  @override
  Future<Page<UserSummary>> reposters(String postId, {String? cursor, int limit = 30}) async {
    final unique = {for (final p in _posts.where((x) => x.id != postId)) p.author.key: p.author};
    return Page(items: unique.values.toList());
  }

  @override
  Future<Page<Post>> quotes(String postId, {String? cursor, int limit = 30}) async =>
      Page(items: _posts.where((p) => p.quote?.id == postId && p.body.isNotEmpty).toList());
  @override
  Future<Page<UserSummary>> searchUsers(String query, {String? cursor, int limit = 20}) async {
    final unique = {for (final p in _posts) p.author.key: p.author};
    return Page(items: [for (final u in unique.values) if (u.displayName.contains(query) || u.id.contains(query)) u]);
  }
  @override
  Future<Map<String, FollowState>> relationships(List<String> userIds) async => {for (final id in userIds) id: const FollowState()};
  /// 自分との関係 (D-223: RAi の user.relation)。個別 API 版は既定のまま(フォロー関係なし)。
  @override
  Future<FollowState> relationship(String userId) async => const FollowState();
  @override
  Future<List<UserProfile>> users(List<String> ids) async => [for (final p in _posts) if (ids.contains(p.author.id)) UserProfile(summary: p.author)];
  @override
  Future<UserProfile> user(String id) async {
    final u = _posts.map((p) => p.author).firstWhere((a) => a.id == id, orElse: () => throw SnsApiException(ErrorCode.notFound));
    return UserProfile(summary: u, description: u.bio, followersCount: 12, followingCount: 34, postsCount: 56, location: '地球', fields: const [ProfileField(name: '千芋', value: 'https://amzn.jp/19f253fc')]);
  }

  /// handle からプロフィールを引く (D-223: RAi の user.get(handle=))。
  @override
  Future<UserProfile?> userByHandle(String handle, {String? host}) async {
    final u = _posts.map((p) => p.author).where((a) => a.handle == handle).firstOrNull;
    return u == null ? null : user(u.id);
  }
  @override
  Future<Page<Post>> userPosts(String id, {String? cursor, int limit = 20, UserPostsFilter filter = UserPostsFilter.posts}) async =>
      Page(items: _posts.where((p) {
        if (p.author.id != id) return false;
        final isReply = p.replyTo != null || p.replyToId != null;
        final isQuote = p.quote != null && p.body.isNotEmpty;
        // 返信TL / 引用TL への振り分け (D-069)。
        return switch (filter) {
          UserPostsFilter.media => p.media.isNotEmpty,
          UserPostsFilter.replies => isReply,
          UserPostsFilter.quotes => isQuote,
          UserPostsFilter.posts => !isReply && !isQuote,
          UserPostsFilter.withReplies => true,
        };
      }).toList());
  @override
  Future<Page<UserSummary>> followers(String id, {String? cursor, int limit = 20}) async => Page(items: _posts.map((p) => p.author).toSet().toList());
  @override
  Future<Page<UserSummary>> following(String id, {String? cursor, int limit = 20}) async => Page(items: _posts.map((p) => p.author).take(1).toList());
  @override
  Future<List<FollowRequest>> followRequests() async => [FollowRequest(id: 'fr', user: _posts.last.author)];
  @override
  Future<void> acceptFollowRequest(String userId) async {}
  @override
  Future<void> rejectFollowRequest(String userId) async {}
  @override
  Future<Page<UserSummary>> mutedUsers({String? cursor, int limit = 30}) async => Page.empty();
  @override
  Future<Page<UserSummary>> blockedUsers({String? cursor, int limit = 30}) async => Page(items: [_posts.last.author]);
  @override
  Future<FollowState> setFollowing(String userId, bool following) async => FollowState(following: following);
  @override
  Future<UserProfile> updateProfile(ProfileUpdate update) async => UserProfile(summary: await me(), description: update.description);
  @override
  Future<List<UserListInfo>> lists() async => [UserListInfo(id: 'l1', name: 'Fediverse Banner', memberIds: [_posts.last.author.id])];
  @override
  Future<UserListInfo> listInfo(String listId) async => (await lists()).first;
  @override
  Future<List<FeedInfo>> searchFeeds(String query, {int limit = 20}) async => [for (final f in feeds) if (query.isEmpty || f.uri == query || f.name.toLowerCase().contains(query.toLowerCase())) f]; // at:// は実プラグイン同様 1 件に解く
  @override
  Future<List<FeedInfo>> savedFeeds() async => kind == SnsKind.bluesky ? (saved ??= [...feeds]) : throw UnsupportedError('no feeds');

  /// 保存済みフィード (D-227): 最初は [feeds] 全部。saveFeed で足す / 外す。
  List<FeedInfo>? saved;
  @override
  Future<List<FeedInfo>> saveFeed(String uri, {bool on = true}) async {
    if (kind != SnsKind.bluesky) throw UnsupportedError('no feeds');
    final cur = saved ??= [...feeds];
    cur.removeWhere((f) => f.uri == uri);
    if (on) cur.add(feeds.where((f) => f.uri == uri).firstOrNull ?? FeedInfo(uri: uri, name: uri.split('/').last));
    return [...cur];
  }
  @override
  Future<List<UserSummary>> listMembers(String listId) async => [_posts.last.author];
  @override
  Future<void> removeFromList(String listId, String userId) async {}
  /// リストへの追加 / 新規作成 (D-223: RAi の list.edit / list.create)。
  @override
  Future<void> addToList(String listId, String userId) async {}
  @override
  Future<UserListInfo> createList(String name) async => UserListInfo(id: 'l-new', name: name);
  @override
  Future<Page<Post>> favorites({String? cursor, int limit = 20}) async => Page(items: _posts.take(1).toList());
  @override
  Future<List<ClipInfo>> clips({String? userId}) async => const [
        ClipInfo(id: 'c-pub', name: '公開クリップ', isPublic: true, notesCount: 2),
        ClipInfo(id: 'c-priv', name: '内緒のクリップ', notesCount: 1),
      ];
  @override
  Future<ClipInfo> clipInfo(String clipId) async => (await clips()).firstWhere((c) => c.id == clipId);
  @override
  Future<Page<Post>> clipNotes(String clipId, {String? cursor, int limit = 20}) async => Page(items: _posts.take(2).toList());
  /// クリップの新規作成 / 投稿の追加 (D-223: RAi の clip.create / clip.edit)。
  @override
  Future<ClipInfo> createClip(String name, {String? description, bool isPublic = false}) async => ClipInfo(id: 'c-new', name: name, description: description, isPublic: isPublic);
  @override
  Future<void> addToClip(String clipId, String postId) async => clipAdds.add('$clipId:$postId');
  @override
  Future<List<TrendTag>> trendingTags() async => const [TrendTag(tag: '打上会', usersCount: 117, chart: [1, 3, 2])];
  @override
  Future<List<DmRoom>> dmRooms() async => [DmRoom(id: _posts.last.author.id, peer: _posts.last.author, lastPost: _posts.last)];
  @override
  Future<ActionResult> performAction(String actionId, String postId, {Map<String, Object?> args = const {}}) async {
    performed.add('$actionId:$postId:${args['undo']}');
    if (actionId == reactionActionId && args['undo'] != true) reactionsSent.add(args['reaction'] as String?);
    if (actionId == reactionActionId && localEmojis != null) {
      final i = _posts.indexWhere((p) => p.id == postId);
      if (i >= 0) {
        final p = _posts[i];
        _posts[i] = Post(id: p.id, account: p.account, author: p.author, createdAt: p.createdAt, body: p.body, reactions: p.reactions, reactionEmojis: p.reactionEmojis, myReaction: args['undo'] == true ? null : args['reaction'] as String?, reactionAcceptance: p.reactionAcceptance);
      }
    }
    return ActionResult(done: args['undo'] != true, count: 1);
  }
  /// 通知 2 件(未読 1 / 既読 1)を固定で返す (D-223: RAi の notifications.list)。
  @override
  Future<Page<NotificationItem>> notifications({String? cursor, int limit = 20}) async {
    if (cursor != null) return Page.empty();
    final author = _posts.last.author;
    return Page(items: [
      NotificationItem(id: 'n1', account: account, kind: NotificationKind.reaction, createdAt: DateTime(2026, 9, 14), actors: [author], post: _posts.first, reaction: '👍', read: false),
      NotificationItem(id: 'n2', account: account, kind: NotificationKind.follow, createdAt: DateTime(2026, 9, 13), actors: [author], read: true),
    ]);
  }

  /// 通知の既読処理 (D-223: RAi の notifications.read)。
  final List<String> markReadCalls = [];
  @override
  Future<void> markNotificationsRead() async => markReadCalls.add('read');
}

AccountSession fakeSession() => AccountSession(
      account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester'),
      pluginId: 'test.fake',
      token: 't',
      createdAt: DateTime(2026, 8, 22),
      displayName: 'テスター',
    );
