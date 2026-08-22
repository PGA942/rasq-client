import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

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
  FakeSnsSession(this.session, this._posts);
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
  Future<Page<Post>> timeline(TimelineKind kind, {String? cursor, int limit = 20}) async => Page(items: cursor == null ? _posts : const []);
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
