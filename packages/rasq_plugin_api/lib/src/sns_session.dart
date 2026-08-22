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
  Future<Page<Post>> userPosts(String id, {String? cursor, int limit = 20});
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

  Future<void> close();
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
  Future<Page<Post>> userPosts(String id, {String? cursor, int limit = 20}) => _unsupported('userPosts');
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
  Future<void> close() async {}
}
