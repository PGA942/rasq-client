import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';

/// Fake SNS plugin/session for widget tests — serves a fixed timeline.
class FakeSnsPlugin extends SnsPlugin {
  FakeSnsPlugin({required this.posts});
  final List<Post> Function(AccountId viewer) posts;

  @override
  SnsKind get kind => SnsKind.misskey;
  @override
  PluginManifest get manifest => const PluginManifest(id: 'test.fake', name: 'Fake', version: '0.0.1', kind: PluginKind.sns, supportedSns: [SnsKind.misskey]);
  @override
  Future<ServerInfo> inspectServer(String host) async => ServerInfo(host: host, name: 'Fake');
  @override
  Future<AuthFlow> beginAuth(String host, {Uri? callback}) => throw UnimplementedError();
  @override
  SnsSession open(AccountSession session) => FakeSnsSession(session, posts(session.account));
}

class FakeSnsSession extends SnsSessionBase {
  FakeSnsSession(this.session, List<Post> posts) : _posts = [...posts];
  final AccountSession session;
  final List<Post> _posts;
  final List<String> performed = [];

  @override
  AccountId get account => session.account;
  @override
  String get pluginId => session.pluginId;
  @override
  List<TimelineKind> get timelines => const [TimelineKind.home, TimelineKind.social];
  @override
  List<ActionDescriptor> get actions => const [
        ActionDescriptor(id: 'reply', genreTag: 'Reply', label: '返信', icon: 'subdirectory_arrow_left'),
        ActionDescriptor(id: 'renote', genreTag: 'Repost', label: 'リノート', icon: 'repeat', doneIcon: 'repeat_on'),
        ActionDescriptor(id: 'reaction', genreTag: 'Reaction', label: 'リアクション', icon: 'favorite_border', doneIcon: 'favorite'),
      ];
  @override
  Future<UserSummary> me() async => UserSummary(id: 'me', account: account, displayName: 'テスター');
  @override
  Future<Page<Post>> timeline(TimelineKind kind, {String? cursor, int limit = 20}) async {
    if (cursor != null) return Page.empty();
    if (kind.id.startsWith('tag:')) return Page(items: _posts.where((p) => p.id == 'p1').toList());
    if (kind.id.startsWith('dm:')) return Page(items: [_posts.last]);
    if (kind == DynamicTimelines.featured) return Page(items: _posts.take(2).toList());
    return Page(items: _posts);
  }
  @override
  Future<Thread> thread(String id) async {
    final p = _posts.firstWhere((e) => e.id == id);
    return Thread(post: p, descendants: _posts.where((e) => e.id != id).take(1).toList());
  }
  /// 最後に createPost へ渡された draft (投稿オプションのテスト用)。
  NewPost? lastDraft;

  @override
  Future<Post> createPost(NewPost draft) async {
    lastDraft = draft;
    final me = await this.me();
    final p = Post(id: 'new${_posts.length}', account: account, author: me, createdAt: DateTime.now(), body: draft.text, contentWarning: draft.contentWarning);
    _posts.insert(0, p);
    return p;
  }
  @override
  Future<Page<ReactionEntry>> reactions(String postId, {String? type, String? cursor, int limit = 30}) async =>
      Page(items: [ReactionEntry(id: 'r1', user: _posts.first.author, reaction: type ?? '👍', createdAt: DateTime(2026))]);
  @override
  Future<Page<UserSummary>> reposters(String postId, {String? cursor, int limit = 30}) async => Page.empty();
  @override
  Future<Map<String, FollowState>> relationships(List<String> userIds) async => {for (final id in userIds) id: const FollowState()};
  @override
  Future<List<UserProfile>> users(List<String> ids) async => [for (final p in _posts) if (ids.contains(p.author.id)) UserProfile(summary: p.author)];
  @override
  Future<UserProfile> user(String id) async {
    final u = _posts.map((p) => p.author).firstWhere((a) => a.id == id, orElse: () => throw SnsApiException(ErrorCode.notFound));
    return UserProfile(summary: u, description: u.bio, followersCount: 12, followingCount: 34, postsCount: 56, location: '地球', fields: const [ProfileField(name: '千芋', value: 'https://amzn.jp/19f253fc')]);
  }
  @override
  Future<Page<Post>> userPosts(String id, {String? cursor, int limit = 20, UserPostsFilter filter = UserPostsFilter.posts}) async =>
      Page(items: _posts.where((p) => p.author.id == id && (filter != UserPostsFilter.media || p.media.isNotEmpty)).toList());
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
  Future<List<UserSummary>> listMembers(String listId) async => [_posts.last.author];
  @override
  Future<void> removeFromList(String listId, String userId) async {}
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
  @override
  Future<List<TrendTag>> trendingTags() async => const [TrendTag(tag: '打上会', usersCount: 117, chart: [1, 3, 2])];
  @override
  Future<List<DmRoom>> dmRooms() async => [DmRoom(id: _posts.last.author.id, peer: _posts.last.author, lastPost: _posts.last)];
  @override
  Future<ActionResult> performAction(String actionId, String postId, {Map<String, Object?> args = const {}}) async {
    performed.add('$actionId:$postId:${args['undo']}');
    return ActionResult(done: args['undo'] != true, count: 1);
  }
  @override
  Future<Page<NotificationItem>> notifications({String? cursor, int limit = 20}) async => Page.empty();
}

AccountSession fakeSession() => AccountSession(
      account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester'),
      pluginId: 'test.fake',
      token: 't',
      createdAt: DateTime(2026, 8, 22),
      displayName: 'テスター',
    );
