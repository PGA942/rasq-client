import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/account_security_api.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/settings/account_security_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// アカウントのセキュリティ (D-268 / S-019)。サーバーは MockClient で Central の口をまねる。
void main() {
  test('確認コードの欄: メールのリンクを貼り付けたら、長いトークンだけを取り出す (S-028)', () {
    const token = '3mJr7AoUXx3mJr7AoUXx3mJr7AoUXx3mJr7AoUXx';
    expect(emailCodeFromInput('https://central.example/auth/email/open#p=verify&e=a%40example.com&t=$token'), token);
    expect(emailCodeFromInput('rasq://auth/email?p=login&e=a%40example.com&t=$token'), token);
    // 短いコード / 長いトークンは、そのまま。Base58 に無い字(0 / O / I / l など)は落とす。
    expect(emailCodeFromInput('3mJr7-AoUXx'), '3mJr7-AoUXx');
    expect(emailCodeFromInput(token), token);
    expect(emailCodeFromInput('0OIl3m!'), '3m');
  });

  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
  http.Response err(int code, String message) => json({'error': {'code': '$code', 'message': message}}, code);

  Future<ProviderContainer> pump(WidgetTester tester, MockClient mock, {bool loggedIn = true}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', if (loggedIn) 'token': 'device-token', if (loggedIn) 'accountId': 'acc-1'}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  test('エラーの言い換え', () {
    OrgateException e(String code, String m) => OrgateException(ErrorCode.tryParse(code)!, m);
    expect(accountSecurityMessage(e('429', 'too many attempts; retry in 60 seconds')), contains('試行が多すぎます'));
    expect(accountSecurityMessage(e('400', 'invalid or expired code')), contains('コードが違う'));
    expect(accountSecurityMessage(e('400', 'password is too weak: it is a commonly used password')), contains('弱すぎます'));
    expect(accountSecurityMessage(e('409', 'this email is already used by another account')), contains('ほかのアカウント'));
    expect(accountSecurityMessage(e('501', 'mail is not configured on this server')), contains('メールを送れる設定'));
  });

  testWidgets('メールの登録 → コードで確認 → パスワードの設定 → ほかの端末をログアウト', (tester) async {
    final me = <String, Object?>{'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ', 'hasPassword': false, 'emailVerified': false, 'roles': <String>[]};
    final sessions = [
      {'sessionId': 'aaaaaaaaaaaaaaaa', 'label': 'RASQ (Android)', 'current': true, 'createdAt': '2026-09-19T00:00:00Z', 'lastIp': '100.64.0.1'},
      {'sessionId': 'bbbbbbbbbbbbbbbb', 'label': 'laptop', 'current': false, 'createdAt': '2026-09-18T00:00:00Z', 'expiresAt': '2027-03-18T00:00:00Z'},
    ];
    final calls = <String>[];
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      final body = req.body.isEmpty ? const <String, Object?>{} : (jsonDecode(req.body) as Map).cast<String, Object?>();
      calls.add('${req.method} $path');
      switch ('${req.method} $path') {
        case 'GET /me':
          return json(me);
        case 'PUT /me/email':
          if (!'${body['email']}'.contains('@')) return err(400, 'invalid email address');
          me['emailPending'] = body['email'];
          return json({'email': body['email'], 'expiresInSeconds': 900}, 202);
        case 'POST /me/email/verify':
          if (body['code'] != '3mJr7AoUXx') return err(400, 'invalid or expired code');
          me
            ..['email'] = me.remove('emailPending')
            ..['emailVerified'] = true;
          return http.Response('', 204);
        case 'POST /auth/password':
          if (body['password'] == 'Password123') return err(400, 'password is too weak: it is a commonly used password');
          me['hasPassword'] = true;
          return http.Response('', 204);
        case 'GET /me/sessions':
          return json(sessions);
        case 'POST /me/sessions/revoke-others':
          final n = sessions.length - 1;
          sessions.removeWhere((s) => s['current'] != true);
          return json({'revoked': n});
      }
      return err(404, 'not found');
    });
    final c = await pump(tester, mock);
    c.read(routerProvider).push('${Routes.settings}/security');
    await tester.pumpAndSettle();
    expect(find.byType(AccountSecurityScreen), findsOneWidget);
    expect(find.text('未登録'), findsOneWidget);

    // 形のおかしいメール → サーバーの 400 を言い換えて出す。
    await tester.enterText(find.byKey(const ValueKey('security.email.input')), 'nope');
    await tester.tap(find.byKey(const ValueKey('security.email.send')));
    await tester.pumpAndSettle();
    expect(find.text('メールアドレスの形が正しくありません'), findsOneWidget);
    // 登録 → 確認待ち → 違うコード → 正しいコード。
    await tester.enterText(find.byKey(const ValueKey('security.email.input')), 'taro@example.com');
    await tester.tap(find.byKey(const ValueKey('security.email.send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('security.email.pending')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('security.email.code')), '11111-11111');
    await tester.tap(find.byKey(const ValueKey('security.email.verify')));
    await tester.pumpAndSettle();
    expect(find.text('コードが違うか、期限が切れています'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('security.email.code')), '3mJr7AoUXx');
    await tester.tap(find.byKey(const ValueKey('security.email.verify')));
    await tester.pumpAndSettle();
    expect(find.text('taro@example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('security.email.pending')), findsNothing);
    expect(c.read(orgateAccountProvider).value!.emailVerified, isTrue);

    // パスワード: 弱いものは断られる → 設定。
    await tester.ensureVisible(find.byKey(const ValueKey('security.password.save')));
    await tester.enterText(find.byKey(const ValueKey('security.password.new')), 'Password123');
    await tester.tap(find.byKey(const ValueKey('security.password.save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('弱すぎます'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('security.password.new')), 'correct horse battery');
    await tester.tap(find.byKey(const ValueKey('security.password.save')));
    await tester.pumpAndSettle();
    expect(c.read(orgateAccountProvider).value!.hasPassword, isTrue);
    expect(find.byKey(const ValueKey('security.password.current'), skipOffstage: false), findsOneWidget);

    // 端末: この端末の印、ほかを全部ログアウト。
    await tester.scrollUntilVisible(find.byKey(const ValueKey('security.session.bbbbbbbbbbbbbbbb')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('(この端末)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('security.sessions.revokeOthers')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('security.session.bbbbbbbbbbbbbbbb')), findsNothing);
    expect(calls, contains('POST /me/sessions/revoke-others'));
  });

  testWidgets('既存のアカウントにログイン: パスワード → トークンをこの端末のものにする。メールのコードでも入れる', (tester) async {
    String? bearer;
    final bodies = <String, Map<String, Object?>>{};
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      final body = req.body.isEmpty ? const <String, Object?>{} : (jsonDecode(req.body) as Map).cast<String, Object?>();
      bodies['${req.method} $path'] = body;
      switch ('${req.method} $path') {
        case 'GET /me':
          bearer = req.headers['authorization'];
          return bearer == 'Bearer login-token' ? json({'id': 'acc-9', 'handle': 'hanako', 'displayName': 'ハナコ', 'hasPassword': true, 'email': 'hanako@example.com', 'emailVerified': true}) : err(401, 'valid bearer token required');
        case 'POST /auth/login':
          return body['password'] == 'correct horse battery' ? json({'accountId': 'acc-9', 'handle': 'hanako', 'displayName': 'ハナコ', 'token': 'login-token', 'restored': true}) : err(401, 'invalid handle or password');
        case 'POST /auth/login/email/request':
          return http.Response('', 204);
        case 'POST /auth/login/email/confirm':
          return body['code'] == '9zYx8-WvUt7' ? json({'accountId': 'acc-9', 'handle': 'hanako', 'displayName': 'ハナコ', 'token': 'login-token', 'restored': true}) : err(400, 'invalid or expired code');
        case 'GET /me/sns-accounts':
          return json(<Object>[]);
      }
      return err(404, 'not found');
    });
    final c = await pump(tester, mock, loggedIn: false);
    c.read(routerProvider).push('${Routes.settings}/account-login');
    await tester.pumpAndSettle();
    expect(find.byType(AccountLoginScreen), findsOneWidget);
    // 違うパスワード → 言い換えたエラー。
    await tester.enterText(find.byKey(const ValueKey('login.identifier')), 'hanako@example.com');
    await tester.enterText(find.byKey(const ValueKey('login.password')), 'nope nope nope');
    await tester.tap(find.byKey(const ValueKey('login.submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('パスワードが違います'), findsOneWidget);
    // メールのコードで入る。
    await tester.tap(find.text('メールのコード'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login.password')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('login.sendCode')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('login.code')), '9zYx8-WvUt7');
    await tester.tap(find.byKey(const ValueKey('login.submit')));
    await tester.pumpAndSettle();
    expect(bodies['POST /auth/login/email/confirm'], containsPair('deviceId', 'device-abc'));
    expect(bodies['POST /auth/login/email/confirm']!['label'], startsWith('RASQ ('));
    expect(bearer, 'Bearer login-token');
    expect(c.read(orgateAccountProvider).value?.handle, 'hanako');
    expect(find.byType(AccountLoginScreen), findsNothing);
  });
}
