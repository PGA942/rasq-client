import 'dart:convert';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';
import 'package:rasq_client/features/child_safe/child_safe_providers.dart' show ChildSnsAllowStore, childGateProvider, childSnsAllowProvider;
import 'package:rasq_client/features/profile/rasq_account_page_screen.dart';
import 'package:rasq_client/features/users/user_list.dart';
import 'package:rasq_client/features/users/user_page_screen.dart';
import 'package:rasq_client/features/users/user_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart' show FollowState;

import 'support/fakes.dart';

/// セキュリティ確認 2026-10-21 の #10 (csf_15707277e9bd5a899fbfde22): 見守りで止めた SNS(や、ほかの RASQ アカウントの SNS)の
/// 保存済みのログインを、アカウント指定(Web の `/user/<id>?account=<key>` など)や RASQ のプロフィールの SNS のタイルから使わせない。
/// 許した SNS A(ok.example)と、止めた SNS B(ng.example)を保存している。
const allowed = AccountId(kind: SnsKind.misskey, instance: 'ok.example', handle: 'kid');
const denied = AccountId(kind: SnsKind.misskey, instance: 'ng.example', handle: 'kid');

/// ほかの RASQ アカウントに属する SNS(見守りでは止めていない)。
const otherOwner = AccountId(kind: SnsKind.misskey, instance: 'ok.example', handle: 'sibling');

const onlyOk = ChildSafeSnsAllow(kinds: ['misskey'], instances: ['ok.example']);

UserSummary bobOn(AccountId viewer) => UserSummary(id: 'bob', account: AccountId(kind: SnsKind.misskey, instance: viewer.instance, handle: 'bob'), displayName: 'ボブ');

class _RecSession extends FakeSnsSession {
  _RecSession(super.session, super.posts);
  final calls = <String>[];

  @override
  Future<UserProfile> user(String id) {
    calls.add('user:$id');
    return super.user(id);
  }

  @override
  Future<UserProfile?> userByHandle(String handle, {String? host}) {
    calls.add('userByHandle:$handle');
    return super.userByHandle(handle, host: host);
  }

  @override
  Future<Page<Post>> userPosts(String id, {String? cursor, int limit = 20, UserPostsFilter filter = UserPostsFilter.posts}) {
    calls.add('userPosts:$id');
    return super.userPosts(id, cursor: cursor, limit: limit, filter: filter);
  }

  @override
  Future<Page<UserSummary>> followers(String id, {String? cursor, int limit = 20}) {
    calls.add('followers:$id');
    return super.followers(id, cursor: cursor, limit: limit);
  }

  @override
  Future<Page<UserSummary>> following(String id, {String? cursor, int limit = 20}) {
    calls.add('following:$id');
    return super.following(id, cursor: cursor, limit: limit);
  }

  @override
  Future<Map<String, FollowState>> relationships(List<String> userIds) {
    calls.add('relationships');
    return super.relationships(userIds);
  }

  @override
  Future<FollowState> setFollowing(String userId, bool following) {
    calls.add('setFollowing:$userId:$following');
    return super.setFollowing(userId, following);
  }
}

class _RecPlugin extends FakeSnsPlugin {
  _RecPlugin() : super(posts: (v) => [Post(id: 'p-${v.instance}', account: v, author: bobOn(v), createdAt: DateTime(2026, 10, 21), body: 'ボブの投稿 ${v.instance}')]);
  final sessions = <String, _RecSession>{};
  @override
  SnsSession open(AccountSession session) => sessions[session.account.key] = _RecSession(session, posts(session.account));

  /// [a] のセッション(開いていなければ空)への呼び出し。
  List<String> callsOf(AccountId a) => sessions[a.key]?.calls ?? const [];
}

/// アプリの中のチャイルドセーフ(見守られていない = null を書く)に上書きされない、テストの制限の箱。
class _PinnedSnsAllow extends ChildSnsAllowStore {
  _PinnedSnsAllow(this.initial);
  final ChildSafeSnsAllow? initial;
  @override
  ChildSafeSnsAllow? build() => initial;
  @override
  void set(ChildSafeSnsAllow? v) {}
}

AccountSession sess(AccountId a) => AccountSession(account: a, pluginId: 'test.fake', token: 'tok-${a.key}', createdAt: DateTime(2026));

void main() {
  group('アカウント指定のセッション', () {
    late _RecPlugin plugin;

    Future<ProviderContainer> container({ChildSafeSnsAllow? sns, AccountId current = allowed, bool withOtherOwner = false}) async {
      plugin = _RecPlugin();
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({
          'sessions': [sess(allowed).toJson(), sess(denied).toJson(), if (withOtherOwner) sess(otherOwner).toJson()],
          'current': current.key,
        }),
        if (withOtherOwner)
          RasqAccountsNotifier.storageKey: jsonEncode({
            'accounts': [
              RasqAccountRecord(id: 'local-device', kind: RasqAccountKind.local, sessionKeys: [allowed.key, denied.key], createdAt: DateTime(2026)).toJson(),
              RasqAccountRecord(id: 'local-other', kind: RasqAccountKind.local, sessionKeys: [otherOwner.key], createdAt: DateTime(2026)).toJson(),
            ],
            'current': 'local-device',
            'onboardingDone': true,
          }),
      });
      final c = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin)),
        // 投稿の表示制限は見ない(SNS の制限だけを試す)。
        childGateProvider.overrideWithValue(ChildGate.off),
      ]);
      addTearDown(c.dispose);
      c.read(childSnsAllowProvider.notifier).set(sns);
      await c.read(sessionsProvider.future);
      return c;
    }

    test('止めた SNS B の key: セッションは null(現在の A にも縮退しない)。人 / 投稿 / フォローの一覧 / フォローは B でも A でも動かない', () async {
      final c = await container(sns: onlyOk);
      final state = c.read(sessionsProvider).value!;
      expect([for (final s in state.sessions) s.account], [allowed]);
      expect(state.allSessions, hasLength(2), reason: '保存は残る(見せないだけ)');

      expect(c.read(sessionForAccountProvider(denied.key)), isNull);
      expect(c.read(viewerForAccountProvider(denied.key)), isNull);
      expect(c.read(viewerUserIdProvider(denied.key)), isNull);
      expect(c.read(usableSessionsProvider).map((s) => s.account), [allowed]);

      final keep = [
        c.listen(userProfileProvider((id: 'bob', account: denied.key)), (_, _) {}),
        c.listen(userPostsProvider((id: 'bob', filter: UserPostsFilter.posts, account: denied.key)), (_, _) {}),
        c.listen(followsProvider((id: 'bob', followers: true, account: denied.key)), (_, _) {}),
      ];
      await expectLater(c.read(userProfileProvider((id: 'bob', account: denied.key)).future), throwsA(isA<StateError>()));
      expect((await c.read(userPostsProvider((id: 'bob', filter: UserPostsFilter.posts, account: denied.key)).future)).items, isEmpty);
      expect((await c.read(followsProvider((id: 'bob', followers: true, account: denied.key)).future)).items, isEmpty);
      await c.read(userListHelperProvider).toggleFollow(bobOn(denied), account: denied.key);
      await c.read(userListHelperProvider).primeRelationships(['bob'], account: denied.key);
      for (final k in keep) {
        k.close();
      }

      expect(plugin.sessions.containsKey(denied.key), isFalse, reason: 'B のトークンでセッションを開かない');
      expect(plugin.callsOf(allowed), isEmpty, reason: '現在の A にも縮退しない');
    });

    test('許した A の key と、端末に無い key(従来どおり現在へ縮退)はそのまま使える', () async {
      final c = await container(sns: onlyOk);
      expect(c.read(sessionForAccountProvider(allowed.key)), same(plugin.sessions[allowed.key]));
      final profile = await c.read(userProfileProvider((id: 'bob', account: allowed.key)).future);
      expect(profile.summary.id, 'bob');
      await c.read(userListHelperProvider).toggleFollow(bobOn(allowed), account: allowed.key);
      expect(plugin.callsOf(allowed), containsAll(['user:bob', 'setFollowing:bob:true']));

      const remote = 'misskey:elsewhere.example:carol';
      expect(c.read(sessionForAccountProvider(remote)), same(plugin.sessions[allowed.key]));
      expect(c.read(viewerForAccountProvider(remote)), allowed);
      expect(plugin.sessions.containsKey(denied.key), isFalse);
    });

    test('ほかの RASQ アカウントの SNS の key も、現在の RASQ アカウントからは使わない', () async {
      final c = await container(withOtherOwner: true);
      expect(c.read(sessionsProvider).value!.sessions.map((s) => s.account), [allowed, denied]);
      expect(c.read(sessionForAccountProvider(otherOwner.key)), isNull);
      expect(c.read(viewerForAccountProvider(otherOwner.key)), isNull);
      expect(plugin.sessions.containsKey(otherOwner.key), isFalse);
    });

    test('見守りの制限を変えると、開いているアカウント指定のプロバイダも作り直して止める(一覧の読み直しを待たない)。外せば戻る', () async {
      final c = await container();
      final sub = c.listen(sessionForAccountProvider(denied.key), (_, _) {});
      final viewer = c.listen(viewerForAccountProvider(denied.key), (_, _) {});
      final profile = c.listen(userProfileProvider((id: 'bob', account: denied.key)), (_, _) {});
      expect(sub.read(), same(plugin.sessions[denied.key]));
      expect((await c.read(userProfileProvider((id: 'bob', account: denied.key)).future)).summary.id, 'bob');
      expect(plugin.callsOf(denied), contains('user:bob'));
      plugin.sessions[denied.key]!.calls.clear();

      c.read(childSnsAllowProvider.notifier).set(onlyOk);
      // セッションの一覧はまだ読み直し中(前の値が残っている)でも、もう B は返さない。
      expect(c.read(sessionForAccountProvider(denied.key)), isNull);
      expect(viewer.read(), isNull);
      expect(c.read(usableSessionsProvider).map((s) => s.account), [allowed]);
      await expectLater(c.read(userProfileProvider((id: 'bob', account: denied.key)).future), throwsA(isA<StateError>()));
      await c.read(sessionsProvider.future);
      expect(c.read(sessionsProvider).value!.sessions.map((s) => s.account), [allowed]);
      expect(sub.read(), isNull);
      expect(plugin.callsOf(denied), isEmpty);

      c.read(childSnsAllowProvider.notifier).set(null);
      await c.read(sessionsProvider.future);
      expect(sub.read(), isNotNull);
      profile.close();
    });

    test('現在のアカウントが止めた SNS になったら、読み直しを待たずに現在から外す', () async {
      final c = await container(current: denied);
      expect(c.read(currentAccountProvider), denied);
      c.read(childSnsAllowProvider.notifier).set(onlyOk);
      expect(c.read(currentAccountSessionProvider), isNull);
      await c.read(sessionsProvider.future);
      expect(c.read(currentAccountProvider), allowed);
    });
  });

  testWidgets('RASQ のプロフィールの SNS のタイル: 止めた SNS のサーバーのタイルは、保存済みの B で人を引かない(A のタイルは A で開く)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      switch ('${req.method} $path') {
        case 'GET /me':
          return json({'id': 'acc-1', 'handle': 'kid', 'displayName': 'キッド'});
        case 'GET /accounts/hanako':
          return json({
            'id': 'acc-2', 'handle': 'hanako', 'displayName': 'ハナコ',
            'snsAccounts': [
              {'kind': 'misskey', 'instance': 'ng.example', 'handle': 'bob', 'displayName': '止めたサーバーのボブ'},
              {'kind': 'misskey', 'instance': 'ok.example', 'handle': 'bob', 'displayName': '許したサーバーのボブ'},
            ],
          });
        case 'GET /accounts/hanako/posts':
          return json({'source': 'rasq', 'limit': 3, 'posts': <Object>[]});
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    final plugin = _RecPlugin();
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [sess(allowed).toJson(), sess(denied).toJson()], 'current': allowed.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin)),
        childSnsAllowProvider.overrideWith(() => _PinnedSnsAllow(onlyOk)),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    expect(c.read(sessionsProvider).value!.sessions.map((s) => s.account), [allowed]);
    c.read(routerProvider).push(Routes.rasqAccount('hanako'));
    await tester.pumpAndSettle();
    expect(find.byType(RasqAccountPageScreen), findsOneWidget);

    final ng = find.byKey(const ValueKey('rasqPage.tile.misskey:ng.example:bob'));
    await tester.ensureVisible(ng);
    await tester.pumpAndSettle();
    await tester.tap(ng);
    await tester.pumpAndSettle();
    expect(find.byType(UserPageScreen), findsNothing);
    expect(plugin.callsOf(denied), isEmpty, reason: '止めた SNS のセッションで引かない / フォローしない');
    expect(plugin.sessions.containsKey(denied.key), isFalse, reason: 'B のトークンでセッションを開かない');
    expect(plugin.callsOf(allowed), isEmpty, reason: 'A は ng.example の人に操作できない(別のサーバー)');

    final ok = find.byKey(const ValueKey('rasqPage.tile.misskey:ok.example:bob'));
    await tester.ensureVisible(ok);
    await tester.pumpAndSettle();
    await tester.tap(ok);
    await tester.pumpAndSettle();
    expect(find.byType(UserPageScreen), findsOneWidget);
    expect(plugin.callsOf(allowed), contains('userByHandle:bob'));
    expect(plugin.callsOf(denied), isEmpty);
  });
}
