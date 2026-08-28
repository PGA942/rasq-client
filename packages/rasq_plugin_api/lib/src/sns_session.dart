import 'dart:typed_data';

import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_store/rasq_store.dart' show FollowState;

import 'action.dart';
import 'timeline.dart';

/// Authenticated API surface for one account.
///
/// Everything returns host models; action state flows back through
/// [ActionResult] → `ActionStateStore` (状態はDSLの外).
/// Unsupported capabilities throw [UnsupportedError]; the host hides the UI.
abstract class SnsSession {
  AccountId get account;
  String get pluginId;

  /// Timelines this account can show, in display order.
  List<TimelineKind> get timelines;

  /// Action-bar buttons for posts of this account.
  List<ActionDescriptor> get actions;

  Future<UserSummary> me();
  Future<Page<Post>> timeline(TimelineKind kind, {String? cursor, int limit = 20});
  Future<Post> post(String id);
  Future<Thread> thread(String id);
  Future<Post> createPost(NewPost draft);
  Future<void> deletePost(String id);

  /// Performs [actionId] on [postId]. `args` carries e.g. the reaction emoji.
  Future<ActionResult> performAction(String actionId, String postId, {Map<String, Object?> args = const {}});

  /// Current state of every action for a batch of posts (after a fetch).
  /// Default derives from [Post.counts]; plugins override for done flags.
  Future<Map<String, Map<String, ActionResult>>> actionStates(List<Post> posts) async => {
        for (final p in posts) p.id: {for (final a in actions) a.id: ActionResult(done: false, count: p.counts[a.id])},
      };

  Future<Page<NotificationItem>> notifications({String? cursor, int limit = 20});
  Future<void> markNotificationsRead();

  Future<UserProfile> user(String id);
  Future<UserProfile?> userByHandle(String handle, {String? host});
  Future<Page<Post>> userPosts(String id, {String? cursor, int limit = 20, UserPostsFilter filter = UserPostsFilter.posts});

  // --- フォロー申請 / ミュート・ブロック一覧 ---
  Future<List<FollowRequest>> followRequests();
  Future<void> acceptFollowRequest(String userId);
  Future<void> rejectFollowRequest(String userId);
  Future<Page<UserSummary>> mutedUsers({String? cursor, int limit = 30});
  Future<Page<UserSummary>> blockedUsers({String? cursor, int limit = 30});
  Future<void> reportUser(String userId, String comment);

  // --- プロフィール編集 ---
  Future<UserProfile> updateProfile(ProfileUpdate update);

  // --- リスト / ブックマーク(お気に入り) ---
  Future<List<UserListInfo>> lists();
  Future<UserListInfo> listInfo(String listId);
  Future<List<UserSummary>> listMembers(String listId);
  Future<UserListInfo> createList(String name);
  Future<void> addToList(String listId, String userId);
  Future<void> removeFromList(String listId, String userId);
  Future<Page<Post>> favorites({String? cursor, int limit = 20});

  // --- クリップ (D-032: SNS ネイティブ側。ホスト横断クリップはホスト実装) ---
  /// [userId] のクリップ一覧(null = 自分)。他ユーザーは公開クリップのみ。
  /// 非対応 SNS は [UnsupportedError] → ホストがタブ/メニューを隠す。
  Future<List<ClipInfo>> clips({String? userId});
  Future<ClipInfo> clipInfo(String clipId);
  Future<Page<Post>> clipNotes(String clipId, {String? cursor, int limit = 20});
  Future<ClipInfo> createClip(String name, {String? description, bool isPublic = false});
  Future<void> deleteClip(String clipId);
  Future<void> addToClip(String clipId, String postId);
  Future<void> removeFromClip(String clipId, String postId);

  /// [userId] の Play(Misskey Flash 等)一覧 (D-039)。RASQ 内では実行せず
  /// **外部リンク**として表示する。非対応 SNS は [UnsupportedError]。
  Future<List<PlayInfo>> userPlays(String userId);
  Future<Page<UserSummary>> followers(String id, {String? cursor, int limit = 20});
  Future<Page<UserSummary>> following(String id, {String? cursor, int limit = 20});
  Future<FollowState> relationship(String userId);
  Future<FollowState> setFollowing(String userId, bool following);
  Future<FollowState> setMuted(String userId, bool muted);
  Future<FollowState> setBlocked(String userId, bool blocked);

  Future<Page<Post>> searchPosts(String query, {String? cursor, int limit = 20});
  Future<Page<UserSummary>> searchUsers(String query, {String? cursor, int limit = 20});

  /// Resolves custom emoji shortcode → image URL (MFM / Mastodon custom emoji).
  Future<Uri?> emojiUrl(String shortcode);

  // --- リアクション / リノート一覧 ---
  Future<Page<ReactionEntry>> reactions(String postId, {String? type, String? cursor, int limit = 30});
  Future<Page<UserSummary>> reposters(String postId, {String? cursor, int limit = 30});

  // --- ユーザー一括 ---
  Future<List<UserProfile>> users(List<String> ids);
  Future<Map<String, FollowState>> relationships(List<String> userIds);

  // --- プラグイン設定 (D-044: rasq.settings-page/1) ---
  /// ローカル保存ページ(source: local)の値をセッションへ反映する。ホストが
  /// 値の変更毎(+ 最初のタイムライン取得前)に呼ぶ。[values] は defaults
  /// マージ済み。既定は no-op — 設定を持たないプラグインはそのままでよい。
  Future<void> applySettings(String area, Map<String, Object?> values) async {}

  /// remote ページ(source: "remote")の現在値(サーバー側設定)。
  Future<Map<String, Object?>> settingsRead(String area) => throw UnsupportedError('$pluginId does not support settingsRead');

  /// remote ページの 1 キー書き込み。戻り値 = 書き込み後の最新値マップ。
  Future<Map<String, Object?>> settingsWrite(String area, String key, Object? value) => throw UnsupportedError('$pluginId does not support settingsWrite');

  // --- コンポーザー ---
  int get maxPostLength;
  Future<MediaItem> uploadMedia(Uint8List bytes, String filename, {String? mimeType, bool sensitive = false, String? alt});
  Future<List<EmojiInfo>> customEmojis();

  // --- トレンド (phase-1 sample: sourced from the SNS itself) ---
  Future<List<TrendTag>> trendingTags();

  // --- DM (限定公開投稿をDM扱い + ネイティブChat) ---
  Future<List<DmRoom>> dmRooms();
  Future<Post> sendDm(DmRoom room, NewPost draft);

  Future<void> close();
}

/// Filter for [SnsSession.userPosts] (ユーザーページのタブ).
enum UserPostsFilter { posts, withReplies, media, quotes }

/// Well-known dynamic timeline ids understood by adapters via [SnsSession.timeline]:
/// `tag:{tag}` (トレンドTL), `dm:{peerUserId}` (DMルーム), `featured` (Today).
abstract final class DynamicTimelines {
  static TimelineKind tag(String tag) => TimelineKind('tag:$tag', '#$tag');
  static TimelineKind dm(String peerUserId) => TimelineKind('dm:$peerUserId', 'DM', extensible: false);
  static TimelineKind chat(String peerUserId) => TimelineKind('chat:$peerUserId', 'Chat', extensible: false);
  static TimelineKind forRoom(DmRoom room) => room.kind == DmRoomKind.chat ? chat(room.peer.id) : dm(room.peer.id);
  static const featured = TimelineKind('featured', 'Today', extensible: false);
}

/// Convenience base: every method throws [UnsupportedError] so adapters only
/// implement what the backend offers.
abstract class SnsSessionBase implements SnsSession {
  Never _unsupported(String what) => throw UnsupportedError('$pluginId does not support $what');

  @override
  List<TimelineKind> get timelines => const [TimelineKind.home];
  @override
  List<ActionDescriptor> get actions => const [];
  @override
  Future<UserSummary> me() => _unsupported('me');
  @override
  Future<Page<Post>> timeline(TimelineKind kind, {String? cursor, int limit = 20}) => _unsupported('timeline');
  @override
  Future<Post> post(String id) => _unsupported('post');
  @override
  Future<Thread> thread(String id) => _unsupported('thread');
  @override
  Future<Post> createPost(NewPost draft) => _unsupported('createPost');
  @override
  Future<void> deletePost(String id) => _unsupported('deletePost');
  @override
  Future<ActionResult> performAction(String actionId, String postId, {Map<String, Object?> args = const {}}) => _unsupported('performAction');
  @override
  Future<Map<String, Map<String, ActionResult>>> actionStates(List<Post> posts) async => {
        for (final p in posts) p.id: {for (final a in actions) a.id: ActionResult(done: false, count: p.counts[a.id])},
      };
  @override
  Future<Page<NotificationItem>> notifications({String? cursor, int limit = 20}) => _unsupported('notifications');
  @override
  Future<void> markNotificationsRead() => _unsupported('markNotificationsRead');
  @override
  Future<UserProfile> user(String id) => _unsupported('user');
  @override
  Future<UserProfile?> userByHandle(String handle, {String? host}) => _unsupported('userByHandle');
  @override
  Future<Page<Post>> userPosts(String id, {String? cursor, int limit = 20, UserPostsFilter filter = UserPostsFilter.posts}) => _unsupported('userPosts');
  @override
  Future<List<FollowRequest>> followRequests() => _unsupported('followRequests');
  @override
  Future<void> acceptFollowRequest(String userId) => _unsupported('acceptFollowRequest');
  @override
  Future<void> rejectFollowRequest(String userId) => _unsupported('rejectFollowRequest');
  @override
  Future<Page<UserSummary>> mutedUsers({String? cursor, int limit = 30}) => _unsupported('mutedUsers');
  @override
  Future<Page<UserSummary>> blockedUsers({String? cursor, int limit = 30}) => _unsupported('blockedUsers');
  @override
  Future<void> reportUser(String userId, String comment) => _unsupported('reportUser');
  @override
  Future<UserProfile> updateProfile(ProfileUpdate update) => _unsupported('updateProfile');
  @override
  Future<List<UserListInfo>> lists() => _unsupported('lists');
  @override
  Future<UserListInfo> listInfo(String listId) => _unsupported('listInfo');
  @override
  Future<List<UserSummary>> listMembers(String listId) => _unsupported('listMembers');
  @override
  Future<UserListInfo> createList(String name) => _unsupported('createList');
  @override
  Future<void> addToList(String listId, String userId) => _unsupported('addToList');
  @override
  Future<void> removeFromList(String listId, String userId) => _unsupported('removeFromList');
  @override
  Future<Page<Post>> favorites({String? cursor, int limit = 20}) => _unsupported('favorites');
  @override
  Future<List<ClipInfo>> clips({String? userId}) => _unsupported('clips');
  @override
  Future<ClipInfo> clipInfo(String clipId) => _unsupported('clipInfo');
  @override
  Future<Page<Post>> clipNotes(String clipId, {String? cursor, int limit = 20}) => _unsupported('clipNotes');
  @override
  Future<ClipInfo> createClip(String name, {String? description, bool isPublic = false}) => _unsupported('createClip');
  @override
  Future<void> deleteClip(String clipId) => _unsupported('deleteClip');
  @override
  Future<void> addToClip(String clipId, String postId) => _unsupported('addToClip');
  @override
  Future<void> removeFromClip(String clipId, String postId) => _unsupported('removeFromClip');
  @override
  Future<List<PlayInfo>> userPlays(String userId) => _unsupported('userPlays');
  @override
  Future<Page<UserSummary>> followers(String id, {String? cursor, int limit = 20}) => _unsupported('followers');
  @override
  Future<Page<UserSummary>> following(String id, {String? cursor, int limit = 20}) => _unsupported('following');
  @override
  Future<FollowState> relationship(String userId) => _unsupported('relationship');
  @override
  Future<FollowState> setFollowing(String userId, bool following) => _unsupported('setFollowing');
  @override
  Future<FollowState> setMuted(String userId, bool muted) => _unsupported('setMuted');
  @override
  Future<FollowState> setBlocked(String userId, bool blocked) => _unsupported('setBlocked');
  @override
  Future<Page<Post>> searchPosts(String query, {String? cursor, int limit = 20}) => _unsupported('searchPosts');
  @override
  Future<Page<UserSummary>> searchUsers(String query, {String? cursor, int limit = 20}) => _unsupported('searchUsers');
  @override
  Future<Uri?> emojiUrl(String shortcode) async => null;
  @override
  Future<Page<ReactionEntry>> reactions(String postId, {String? type, String? cursor, int limit = 30}) => _unsupported('reactions');
  @override
  Future<Page<UserSummary>> reposters(String postId, {String? cursor, int limit = 30}) => _unsupported('reposters');
  @override
  Future<List<UserProfile>> users(List<String> ids) => _unsupported('users');
  @override
  Future<Map<String, FollowState>> relationships(List<String> userIds) => _unsupported('relationships');
  @override
  Future<void> applySettings(String area, Map<String, Object?> values) async {}
  @override
  Future<Map<String, Object?>> settingsRead(String area) => _unsupported('settingsRead');
  @override
  Future<Map<String, Object?>> settingsWrite(String area, String key, Object? value) => _unsupported('settingsWrite');
  @override
  int get maxPostLength => 500;
  @override
  Future<MediaItem> uploadMedia(Uint8List bytes, String filename, {String? mimeType, bool sensitive = false, String? alt}) => _unsupported('uploadMedia');
  @override
  Future<List<EmojiInfo>> customEmojis() async => const [];
  @override
  Future<List<TrendTag>> trendingTags() => _unsupported('trendingTags');
  @override
  Future<List<DmRoom>> dmRooms() => _unsupported('dmRooms');
  @override
  Future<Post> sendDm(DmRoom room, NewPost draft) => _unsupported('sendDm');
  @override
  Future<void> close() async {}
}
