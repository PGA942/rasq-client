import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/backend/learning_api.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account_page_api.dart';
import 'package:rasq_client/features/learning/contribution.dart';
import 'package:rasq_client/features/learning/relational_cloud.dart';
import 'package:rasq_client/features/lists/list_member_picker.dart';
import 'package:rasq_client/features/post/post_bookmark_button.dart';
import 'package:rasq_client/features/rai/rai_llm.dart';
import 'package:rasq_client/features/relational/relational_engine.dart';
import 'package:rasq_client/features/relational/relational_providers.dart';
import 'package:rasq_client/features/vc/astell_models.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';

import 'support/fake_rai_llm.dart';

/// D-365 ブックマークを外せる / D-366 リストに SNS・RASQ のユーザーを足す / D-367 クラウド版のリレーショナル TL。
void main() {
  const viewer = AccountId(kind: SnsKind.misskey, instance: 'misskey.rasq.test', handle: 'me');
  UserSummary user(String id) => UserSummary(id: id, account: AccountId(kind: SnsKind.misskey, instance: 'misskey.rasq.test', handle: id), displayName: id);
  final t0 = DateTime.utc(2026, 9, 28, 12);
  Post post(String id, String author, int minute, String body) => Post(id: id, account: viewer, author: user(author), createdAt: t0.add(Duration(minutes: minute)), body: body);

  group('ブックマーク (D-365)', () {
    test('分かっている「済み」は、状態の取り直しで「未」に戻さない(外したときは perform が書く)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final store = c.read(actionStateProvider.notifier);
      final session = _Session(bookmark: true);
      store.apply('k1', 'favorite', const ActionState(done: true));
      final kept = keepKnownBookmarks(store, session, {
        (postKey: 'k1', actionId: 'favorite'): const ActionState(done: false),
        (postKey: 'k1', actionId: 'renote'): const ActionState(done: false),
        (postKey: 'k2', actionId: 'favorite'): const ActionState(done: false),
      });
      expect(kept[(postKey: 'k1', actionId: 'favorite')]!.done, isTrue);
      expect(kept[(postKey: 'k1', actionId: 'renote')]!.done, isFalse);
      expect(kept[(postKey: 'k2', actionId: 'favorite')]!.done, isFalse);
      expect(bookmarkActionOf(session)?.id, 'favorite');
    });
  });

  group('リストのメンバー (D-366)', () {
    RasqAccountPageApi api(Map<String, Object?> profile) => RasqAccountPageApi(OrgateClient(
          baseUrl: Uri.parse('https://central.test'),
          httpClient: MockClient((req) async => http.Response.bytes(utf8.encode(jsonEncode(profile)), 200, headers: {'content-type': 'application/json'})),
          tokenProvider: () => 't',
        ));
    const who = AstellFollowEntry(id: 'r1', handle: 'hana', displayName: 'はな');

    test('RASQ ユーザーは、公開している同じ SNS のアカウント(同じサーバー・確認済みを優先)で入る', () async {
      final s = _Session();
      final r = await resolveRasqMember(
        api({
          'id': 'r1',
          'handle': 'hana',
          'displayName': 'はな',
          'snsAccounts': [
            {'kind': 'mastodon', 'instance': 'mstdn.rasq.test', 'handle': 'hana_m', 'verified': true},
            {'kind': 'misskey', 'instance': 'other.test', 'handle': 'hana_far', 'verified': true},
            {'kind': 'misskey', 'instance': 'misskey.rasq.test', 'handle': 'hana', 'verified': false},
          ],
        }),
        s,
        who,
      );
      expect(r.user?.id, 'id-hana');
      expect(s.lookups.first, ('hana', null), reason: '同じサーバーのアカウントを先に(host なし)');
    });

    test('同じ SNS のアカウントを公開していなければ選べない', () async {
      final r = await resolveRasqMember(api({'id': 'r1', 'handle': 'hana', 'displayName': 'はな', 'snsAccounts': [{'kind': 'bluesky', 'instance': 'bsky.rasq.test', 'handle': 'hana.bsky'}]}), _Session(), who);
      expect(r.user, isNull);
      expect(r.reason, contains('この SNS のアカウントを公開していません'));
    });

    test('SNS のリストにはまとめて addToList', () async {
      final s = _Session();
      final n = await SnsListMemberTarget(s, 'L1', {}).addAll([user('a'), user('b')]);
      expect(n, 2);
      expect(s.added, ['L1:a', 'L1:b']);
    });
  });

  group('クラウド版のリレーショナル TL (D-367)', () {
    test('エンジン: しきい値の近くの結び付きを控え、クラウドの判定があればそれに従う', () {
      final posts = [post('a1', 'alice', 0, 'ロケットの打ち上げ見てる #rocket'), post('b1', 'bob', 2, 'ロケットの打ち上げすごい #rocket')];
      final e1 = ConversationEngine(borderlineMargin: 1);
      final built = e1.buildAll(followeePosts: posts);
      expect(e1.borderline, hasLength(1));
      final pair = e1.borderline.single;
      expect(pair.post.id, 'b1');
      expect(pair.event.first.id, 'a1');
      expect(built.where((e) => e.posts.length == 2), hasLength(pair.joined ? 1 : 0));
      // クラウドが「別の会話」と言えば分ける。「同じ会話」なら束ねる。判定済みの組は控えない。
      final no = ConversationEngine(borderlineMargin: 1, decisions: {pair.key: false});
      expect(no.buildAll(followeePosts: posts).every((e) => e.posts.length == 1), isTrue);
      expect(no.borderline, isEmpty);
      final yes = ConversationEngine(borderlineMargin: 1, decisions: {pair.key: true});
      expect(yes.buildAll(followeePosts: posts).where((e) => e.posts.length == 2), hasLength(1));
    });

    test('許可の書き手の組だけ送り、判定を覚えて TL を組み直す', () async {
      final calls = <String, Object?>{};
      http.Response json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});
      final client = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api/v1', '');
        switch ('${req.method} $path') {
          case 'POST /me/learning/judge':
            final authors = ((jsonDecode(req.body) as Map)['authors'] as List).cast<Map<String, Object?>>();
            return json({
              'verdicts': [for (final a in authors) {'host': a['host'], 'id': a['id'], 'verdict': a['id'] == 'carol' ? 'deny' : 'allow', 'reason': 'r', 'judgedBy': 'llm'}],
            });
          case 'POST /me/relational/judge':
            final body = jsonDecode(req.body) as Map;
            calls['relational'] = body;
            return json({
              'decisions': [for (final p in body['pairs'] as List) {'key': (p as Map)['key'], 'same': false, 'reason': '別の話', 'judgedBy': 'llm', 'kind': 'hard_negative'}],
              'skipped': [],
            });
        }
        return json(<String, Object?>{});
      });
      final c = ProviderContainer(overrides: [
        centralClientProvider.overrideWithValue(OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: client, tokenProvider: () => 't')),
        learningProvider.overrideWith(_Granted.new),
        conversationEventsProvider.overrideWithValue(const AsyncData([])),
        raiLlmProvider.overrideWithValue(FakeRaiLlm()),
      ]);
      addTearDown(c.dispose);
      RelationalCloudController.debounce = const Duration(days: 1);
      ContributionController.debounce = const Duration(days: 1);
      c.listen(relationalCloudProvider, (_, _) {});
      c.listen(contributionProvider, (_, _) {});
      await c.read(learningProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(relationalCloudProvider).active, isTrue);

      final ok = BorderlinePair(post: post('b1', 'bob', 2, 'すごい @x'), event: [post('a1', 'alice', 0, '打ち上げ'), post('m1', 'me', 1, '見てる')], score: 0.52, threshold: 0.5, joined: true);
      final ng = BorderlinePair(post: post('c1', 'carol', 3, 'ラーメン'), event: [post('a1', 'alice', 0, '打ち上げ')], score: 0.49, threshold: 0.5, joined: false);
      c.read(relationalCloudProvider.notifier).offer([ok, ng]);
      expect(c.read(relationalCloudProvider).pending, 2);
      await c.read(relationalCloudProvider.notifier).flush();

      final body = calls['relational']! as Map;
      final pairs = (body['pairs'] as List).cast<Map<String, Object?>>();
      expect([for (final p in pairs) p['key']], [ok.key], reason: 'carol(拒否)を含む組は送らない');
      expect((pairs.single['post']! as Map)['t'], 'すごい @user');
      expect([for (final e in pairs.single['event']! as List) (e as Map)['a']], [1, -1], reason: '自分の投稿は -1');
      expect(body['authors'], [
        {'host': 'misskey.rasq.test', 'id': 'bob'},
        {'host': 'misskey.rasq.test', 'id': 'alice'},
      ]);
      final s = c.read(relationalCloudProvider);
      expect(s.decisions, {ok.key: false});
      expect(s.hardNegative, 1);
      expect(s.skipped, 1);
      expect(s.pending, 0);
      expect(c.read(relationalCloudDecisionsProvider), {ok.key: false});
      // 同じ組は 2 度送らない。
      c.read(relationalCloudProvider.notifier).offer([ok, ng]);
      expect(c.read(relationalCloudProvider).pending, 0);
    });
  });
}

class _Granted extends LearningNotifier {
  @override
  Future<LearningStatus?> build() async => const LearningStatus(open: true, granted: true, eligible: true);
}

class _Session extends SnsSessionBase {
  _Session({this.bookmark = false});
  final bool bookmark;
  @override
  final AccountId account = const AccountId(kind: SnsKind.misskey, instance: 'misskey.rasq.test', handle: 'me');
  @override
  String get pluginId => 'test.session';
  @override
  List<ActionDescriptor> get actions => [
        const ActionDescriptor(id: 'renote', genreTag: 'Repost', label: 'リノート', icon: 'repeat'),
        if (bookmark) const ActionDescriptor(id: 'favorite', genreTag: 'Bookmark', label: 'お気に入り', icon: 'star_border'),
      ];
  final lookups = <(String, String?)>[];
  final added = <String>[];
  @override
  Future<UserProfile?> userByHandle(String handle, {String? host}) async {
    lookups.add((handle, host));
    return UserProfile(summary: UserSummary(id: 'id-$handle', account: AccountId(kind: SnsKind.misskey, instance: host ?? account.instance, handle: handle), displayName: handle));
  }

  @override
  Future<void> addToList(String listId, String userId) async => added.add('$listId:$userId');
}
