import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/child_safe/child_safe_providers.dart';
import 'package:rasq_client/features/child_safe/child_safe_screens.dart';
import 'package:rasq_client/features/child_safe/guardian_screen.dart';
import 'package:rasq_client/features/dm/dm_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/child_safe_fakes.dart';
import 'support/fakes.dart';

/// チャイルドセーフ v2 (D-307) の画面: 設定待ちの鍵 / TL の関所 / 止めたタブ / 子のログイン / 保護者の設定。
void main() {
  late TestSigner signer;
  setUpAll(() async => signer = await TestSigner.create());

  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
  http.Response err(int code, String message) => json({'error': {'code': '$code', 'message': message}}, code);

  List<Post> posts(AccountId viewer) => [
        Post(id: 'ok', account: viewer, author: MockDataUser.someone, createdAt: DateTime(2026, 9, 24, 11), body: '今日は晴れ'),
        Post(id: 'bad', account: viewer, author: MockDataUser.someone, createdAt: DateTime(2026, 9, 24, 10), body: 'お前バカだな'),
      ];

  /// 子の設定(SNS はどのサーバーの Misskey でも可、見守りの時間は無し = タイマーを置かない)。
  Map<String, Object?> kidSettings() {
    final s = v2();
    s['time'] = {...(s['time'] as Map).cast<String, Object?>(), 'enabled': false};
    ((s['allow'] as Map)['sns'] as Map)['instances'] = <String>[];
    return s;
  }

  Future<Map<String, Object?>> active(Map<String, Object?> settings, {int revision = 1}) async => {
        'managed': true,
        'state': 'active',
        'parent': {'handle': 'mama', 'displayName': 'ママ'},
        'revision': revision,
        'appliedRevision': revision,
        'settings': settings,
        'signature': await signer.sign('kid-1', revision, settings, '2026-09-24T00:00:00Z'),
        'issuedAt': '2026-09-24T00:00:00Z',
        'guardian': {'verified': false},
      };

  Future<ProviderContainer> pump(WidgetTester tester, MockClient mock, {bool loggedIn = true, bool sns = true, PluginRegistry? registry}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      if (sns) SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-kid', if (loggedIn) 'token': 'kid-token', if (loggedIn) 'accountId': 'kid-1'}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry ?? (PluginRegistry()..register(FakeSnsPlugin(posts: posts)))),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        childSafeNowProvider.overrideWithValue(() => DateTime(2026, 9, 24, 12)),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  MockClient central(Future<http.Response?> Function(String route, Map<String, Object?> body) handler, {String id = 'kid-1', List<String> roles = const []}) => MockClient((req) async {
        final path = req.url.path.replaceFirst('/api/v1', '');
        final body = req.body.isEmpty ? const <String, Object?>{} : (jsonDecode(req.body) as Map).cast<String, Object?>();
        final r = await handler('${req.method} $path', body);
        if (r != null) return r;
        switch ('${req.method} $path') {
          case 'GET /me':
            return json({'id': id, 'handle': id == 'kid-1' ? 'kid' : 'mama', 'displayName': 'X', 'roles': roles});
          case 'GET /store-key':
            return json({'algorithm': 'ed25519', 'publicKey': signer.publicKey});
          case 'POST /me/child-safe/ack':
            return http.Response('', 204);
        }
        return err(404, 'not found');
      });

  testWidgets('設定待ちは鍵の画面だけ(更新で外れる)', (tester) async {
    Map<String, Object?> status = {'managed': true, 'state': 'pending_setup', 'parent': {'handle': 'mama', 'displayName': 'ママ'}, 'revision': 0, 'settings': null};
    final settings = kidSettings();
    final c = await pump(tester, central((route, _) async => route == 'GET /me/child-safe' ? json(status) : null));
    expect(find.byType(ChildSafePendingScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('childSafe.pending.logout')), findsOneWidget);
    // ほかの画面へは行けない。
    c.read(routerProvider).go(Routes.settings);
    await tester.pumpAndSettle();
    expect(find.byType(ChildSafePendingScreen), findsOneWidget);
    // 保護者が決めた → 更新で使えるようになる。
    status = await active(settings);
    await tester.tap(find.byKey(const ValueKey('childSafe.pending.refresh')));
    await tester.pumpAndSettle();
    expect(find.byType(ChildSafePendingScreen), findsNothing);
  });

  testWidgets('TL は強い言葉の投稿を見せない / 止めたタブは薄く出して理由 / 投稿の判定で送らない', (tester) async {
    final st = await active(kidSettings());
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: posts));
    final c = await pump(tester, central((route, _) async => route == 'GET /me/child-safe' ? json(st) : null), registry: registry);
    expect(c.read(childGateProvider).supervised, isTrue);
    expect(find.text('今日は晴れ'), findsWidgets);
    expect(find.text('お前バカだな'), findsNothing);

    // コンポーザー: 強い言葉は送らず、当たった語を選んで印を付ける。通る本文は送れて、1 日の数が増える。
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'あいつバカすぎ');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '送信'));
    await tester.pumpAndSettle();
    expect(find.textContaining('「バカ」'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.selection, const TextSelection(baseOffset: 3, extentOffset: 5));
    final session = registry.session(fakeSession()) as FakeSnsSession;
    expect(session.lastDraft, isNull);
    await tester.enterText(find.byType(TextField).last, '宿題がんばる');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '送信'));
    await tester.pumpAndSettle();
    expect(session.lastDraft?.text, '宿題がんばる');
    expect(await c.read(sessionStorageProvider).read('childSafe.posts.2026-09-24'), '1');
    // DM は保護者が止めている: タブを押しても開かず、理由が出る。
    await tester.tap(find.byIcon(Icons.mail_outline).last);
    await tester.pumpAndSettle();
    expect(find.byType(DmScreen), findsNothing);
    expect(find.text('保護者が DM を止めています'), findsOneWidget);
    // ルートからも入れない。
    c.read(routerProvider).go(Routes.dm);
    await tester.pumpAndSettle();
    expect(find.byType(DmScreen), findsNothing);
    // 見守りの画面(入口)に保護者の名前。
    c.read(routerProvider).push(Routes.childSafe);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('childSafe.hub.parent')), findsOneWidget);
    expect(find.textContaining('ママ'), findsWidgets);
  });

  testWidgets('保護者からのコードでログイン: この端末の SNS アカウントは引き継がない', (tester) async {
    Map<String, Object?>? loginBody;
    String? loginAuth;
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      switch ('${req.method} $path') {
        case 'POST /auth/child-login':
          loginBody = (jsonDecode(req.body) as Map).cast<String, Object?>();
          loginAuth = req.headers['authorization'];
          if (loginBody!['code'] != 'KIDCODE1') return err(410, 'gone');
          return json({'token': 'kid-token', 'accountId': 'kid-1', 'restored': false});
        case 'GET /me':
          return req.headers['authorization'] == 'Bearer kid-token' ? json({'id': 'kid-1', 'handle': 'kid', 'displayName': 'キッド'}) : err(401, 'unauthorized');
        case 'GET /me/child-safe':
          return json({'managed': true, 'state': 'pending_setup', 'parent': {'handle': 'mama'}, 'revision': 0, 'settings': null});
      }
      return err(404, 'not found');
    });
    final c = await pump(tester, mock, loggedIn: false);
    c.read(routerProvider).push(Routes.childSafeLogin);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('childSafe.login.code')), 'wrong');
    await tester.tap(find.byKey(const ValueKey('childSafe.login.submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('childSafe.login.error')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('childSafe.login.code')), 'kidcode1');
    await tester.tap(find.byKey(const ValueKey('childSafe.login.submit')));
    await tester.pumpAndSettle();
    expect(loginBody, {'code': 'KIDCODE1', 'deviceId': 'device-kid'});
    expect(loginAuth, isNull); // Bearer は付けない
    final central = c.read(rasqAccountsProvider).value!.central!;
    expect(central.centralAccountId, 'kid-1');
    expect(central.sessionKeys, isEmpty); // 保護者 / 端末の SNS のログインは貸さない
    expect(find.byType(ChildSafePendingScreen), findsOneWidget);
  });

  testWidgets('保護者: 子のアカウントを作る(コードは 1 度だけ)→ 子の設定を順に決めて保存 / 要約', (tester) async {
    final puts = <Map<String, Object?>>[];
    final created = <Map<String, Object?>>[];
    final mock = central((route, body) async {
      switch (route) {
        case 'GET /me/child-safe':
          return json({'managed': false, 'guardian': {'verified': true, 'method': 'jpki', 'country': 'JP'}});
        case 'GET /me/child-safe/guardian':
          return json({
            'verified': true,
            'method': 'jpki',
            'country': 'JP',
            'children': [
              {'handle': 'kid', 'displayName': 'キッド', 'state': 'pending_setup', 'revision': 0, 'appliedRevision': 0, 'ageBand': '13-15', 'createdByGuardian': true},
            ],
          });
        case 'POST /me/child-safe/children':
          created.add(body);
          return json({'handle': body['handle'], 'loginCode': 'ABCD-EFGH-JKLM', 'expiresAt': '2026-09-25T00:00:00Z'}, 201);
        case 'GET /me/child-safe/children/kid':
          return json({
            'handle': 'kid',
            'displayName': 'キッド',
            'state': 'pending_setup',
            'revision': 0,
            'appliedRevision': 0,
            'ageBand': '13-15',
            'createdByGuardian': true,
            'settings': null,
            'summary': {
              'days': [
                {'date': '2026-09-23', 'posts': 2, 'blocked': 1, 'topics': ['宿題']},
              ],
            },
          });
        case 'POST /me/child-safe/children/kid/login-code':
          return json({'handle': 'kid', 'loginCode': 'NEWC-ODEA-BCDE', 'expiresAt': '2026-09-25T00:00:00Z', 'link': 'rasq://child-safe/login?code=NEWCODEABCDE'}, 201);
        case 'PUT /me/child-safe/children/kid/settings':
          puts.add(body);
          return json({'revision': 1, 'signature': 'x', 'issuedAt': '2026-09-24T00:00:00Z'});
      }
      return null;
    }, id: 'mama-1', roles: ['guardian']);
    final c = await pump(tester, mock);
    c.read(routerProvider).push(Routes.childSafeGuardian);
    await tester.pumpAndSettle();
    expect(find.byType(GuardianScreen), findsOneWidget);
    expect(find.text('確認済み'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('guardian.create')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('guardian.create.handle')), '@kid2');
    await tester.enterText(find.byKey(const ValueKey('guardian.create.name')), 'キッド2');
    expect(find.descendant(of: find.byKey(const ValueKey('guardian.create.band')), matching: find.text('18+')), findsNothing); // 子は 13-17 だけ
    await tester.tap(find.text('16-17'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('guardian.create.submit')));
    await tester.tap(find.byKey(const ValueKey('guardian.create.submit')));
    await tester.pumpAndSettle();
    expect(created.single, {'handle': 'kid2', 'displayName': 'キッド2', 'ageBand': '16-17'});
    expect(find.text('ABCD-EFGH-JKLM'), findsOneWidget);

    // 子の設定: 年齢の帯の既定 → 順に進めて保存。
    await tester.ensureVisible(find.byKey(const ValueKey('guardian.child.kid')));
    await tester.tap(find.byKey(const ValueKey('guardian.child.kid')));
    await tester.pumpAndSettle();
    expect(find.byType(GuardianChildScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('guardian.summary.2026-09-23')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('guardian.step.1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('guardian.timeline.blocked')), 'ホラー, 事件');
    await tester.enterText(find.byKey(const ValueKey('guardian.postsPerDay')), '5');
    await tester.tap(find.byKey(const ValueKey('guardian.step.3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guardian.sns.kind.misskey')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guardian.step.4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guardian.save')));
    await tester.pumpAndSettle();
    final saved = puts.single;
    expect(saved['schema'], 'rasq.child-safe/2');
    expect(saved['preset'], 'strict');
    expect(saved['postsPerDay'], 5);
    expect((saved['timeline'] as Map)['blockedTopics'], ['ホラー', '事件']);
    expect(((saved['allow'] as Map)['sns'] as Map)['kinds'], ['misskey']);
    expect(((saved['allow'] as Map)['rai'] as Map)['groups'], ['rai.guide', 'rai.read', 'rai.compose']);
    // 13-15 の既定(カタログが取れないので控え = Central と同じ値): AsTell の共有とストアのレビューも止める。
    expect((saved['allow'] as Map)['features'], containsPair('astell.share', false));
    expect((saved['allow'] as Map)['features'], containsPair('store.review', false));

    // 親が作った子: ログインのコードを出し直す。
    await tester.scrollUntilVisible(find.byKey(const ValueKey('guardian.loginCode')), 200, scrollable: find.descendant(of: find.byType(GuardianChildScreen), matching: find.byType(Scrollable)).first);
    await tester.tap(find.byKey(const ValueKey('guardian.loginCode')));
    await tester.pumpAndSettle();
    expect(find.text('NEWC-ODEA-BCDE'), findsOneWidget);
  });
}

/// テスト用の投稿者。
abstract final class MockDataUser {
  static const someone = UserSummary(id: 'u-someone', account: AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'someone'), displayName: 'だれか');
}
