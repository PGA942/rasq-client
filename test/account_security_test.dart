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
          expect(body.keys, ['email'], reason: '初めて付けるときは、パスワードもコードも要らない');
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
    await tester.ensureVisible(find.byKey(const ValueKey('security.password.save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('security.password.save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('弱すぎます'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('security.password.new')), 'correct horse battery');
    await tester.ensureVisible(find.byKey(const ValueKey('security.password.save')));
    await tester.pumpAndSettle();
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

  testWidgets('確認済みのメールの付け替え (ORGATE O-008、D-407): いまのパスワードか、いまのメールに届く email.change のコードを添える。無ければ送らない', (tester) async {
    final me = <String, Object?>{'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ', 'hasPassword': true, 'email': 'old@example.com', 'emailVerified': true, 'roles': <String>[]};
    final emailPuts = <Map<String, Object?>>[];
    final confirms = <String>[];
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      final body = req.body.isEmpty ? const <String, Object?>{} : (jsonDecode(req.body) as Map).cast<String, Object?>();
      switch ('${req.method} $path') {
        case 'GET /me':
          return json(me);
        case 'GET /me/sessions':
          return json(const []);
        case 'POST /me/confirm':
          confirms.add('${body['action']}');
          return json({'email': 'o***@example.com'}, 202);
        case 'PUT /me/email':
          emailPuts.add(body);
          // ORGATE O-008 と同じ: 確認済みのメールの付け替えには currentPassword か code が要る。
          if (body['currentPassword'] == null && body['code'] == null) {
            return err(403, 'confirmation required: request a code with POST /me/confirm {"action":"email.change"} and pass it as code');
          }
          if (body['currentPassword'] != null && body['currentPassword'] != 'right password') return err(403, 'current password is wrong');
          if (body['code'] != null && body['code'] != '3mJr7AoUXx') return err(400, 'invalid or expired code');
          me['emailPending'] = body['email'];
          return json({'email': body['email'], 'expiresInSeconds': 900}, 202);
      }
      return err(404, 'not found');
    });
    final c = await pump(tester, mock);
    c.read(routerProvider).push('${Routes.settings}/security');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('security.email.currentPassword')), findsOneWidget);

    // 何も添えない → 送らずに伝える。
    await tester.enterText(find.byKey(const ValueKey('security.email.input')), 'new@example.com');
    await tester.tap(find.byKey(const ValueKey('security.email.send')));
    await tester.pumpAndSettle();
    expect(emailPuts, isEmpty);
    expect(find.textContaining('いまのパスワードを入れるか'), findsOneWidget);

    // 違うパスワード → サーバーの 403 を言い換える。
    await tester.enterText(find.byKey(const ValueKey('security.email.currentPassword')), 'wrong');
    await tester.tap(find.byKey(const ValueKey('security.email.send')));
    await tester.pumpAndSettle();
    expect(emailPuts.last['currentPassword'], 'wrong');
    expect(find.text('いまのパスワードが違います'), findsOneWidget);

    // 正しいパスワード → 付け替えのコードが新しいアドレスへ。
    await tester.enterText(find.byKey(const ValueKey('security.email.currentPassword')), 'right password');
    await tester.tap(find.byKey(const ValueKey('security.email.send')));
    await tester.pumpAndSettle();
    expect(emailPuts.last, {'email': 'new@example.com', 'currentPassword': 'right password'});
    expect(find.byKey(const ValueKey('security.email.pending')), findsOneWidget);

    // コードで: いまのメールへ email.change のコードを送る → 入れて付け替える。
    me.remove('emailPending');
    await tester.tap(find.byKey(const ValueKey('security.email.byCode')));
    await tester.pumpAndSettle();
    expect(confirms, ['email.change']);
    await tester.enterText(find.byKey(const ValueKey('security.email.input')), 'other@example.com');
    await tester.enterText(find.byKey(const ValueKey('security.email.changeCode')), '3mJr7AoUXx');
    await tester.tap(find.byKey(const ValueKey('security.email.send')));
    await tester.pumpAndSettle();
    expect(emailPuts.last, {'email': 'other@example.com', 'code': '3mJr7AoUXx'});

    // サーバーの 403(確認が要る)も、日本語で伝える。
    OrgateException e(String m) => OrgateException(ErrorCode.tryParse('403')!, m);
    expect(accountSecurityMessage(e('confirmation required: request a code with POST /me/confirm {"action":"email.change"} and pass it as code')), contains('確認コードが要ります'));
    expect(accountSecurityMessage(e('this account has no password: confirm with the mailed code instead')), contains('パスワードがありません'));
  });

  testWidgets('パスワードのあるアカウントの初めてのメール (ORGATE O-009、D-408): いまのパスワードの欄が出て、添えて送る。無ければ送らない', (tester) async {
    final me = <String, Object?>{'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ', 'hasPassword': true, 'emailVerified': false, 'roles': <String>[]};
    final emailPuts = <Map<String, Object?>>[];
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      final body = req.body.isEmpty ? const <String, Object?>{} : (jsonDecode(req.body) as Map).cast<String, Object?>();
      switch ('${req.method} $path') {
        case 'GET /me':
          return json(me);
        case 'GET /me/sessions':
          return json(const []);
        case 'PUT /me/email':
          emailPuts.add(body);
          // ORGATE O-009 と同じ: パスワードがあれば、初めてのメールにもいまのパスワードが要る(403 の文面は日本語)。
          if (body['currentPassword'] == null) return err(403, 'パスワードを設定したアカウントでは、メールアドレスを付けるときにいまのパスワードが要ります');
          if (body['currentPassword'] != 'right password') return err(403, 'いまのパスワードが違います');
          me['emailPending'] = body['email'];
          return json({'email': body['email'], 'expiresInSeconds': 900}, 202);
      }
      return err(404, 'not found');
    });
    final c = await pump(tester, mock);
    c.read(routerProvider).push('${Routes.settings}/security');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('security.email.needsPassword')), findsOneWidget);
    expect(find.byKey(const ValueKey('security.email.currentPassword')), findsOneWidget);
    expect(find.byKey(const ValueKey('security.email.byCode')), findsNothing, reason: '確認済みのメールが無いので、コードの宛先も無い');

    // いまのパスワードが無い → 送らずに伝える。
    await tester.enterText(find.byKey(const ValueKey('security.email.input')), 'taro@example.com');
    await tester.tap(find.byKey(const ValueKey('security.email.send')));
    await tester.pumpAndSettle();
    expect(emailPuts, isEmpty);
    expect(find.text('いまのパスワードを入れてください'), findsOneWidget);

    // 違うパスワード → サーバーの 403(日本語)をそのまま出す。
    await tester.enterText(find.byKey(const ValueKey('security.email.currentPassword')), 'wrong');
    await tester.tap(find.byKey(const ValueKey('security.email.send')));
    await tester.pumpAndSettle();
    expect(emailPuts.last, {'email': 'taro@example.com', 'currentPassword': 'wrong'});
    expect(find.text('いまのパスワードが違います'), findsOneWidget);

    // 正しいパスワード → コードが届く。
    await tester.enterText(find.byKey(const ValueKey('security.email.currentPassword')), 'right password');
    await tester.tap(find.byKey(const ValueKey('security.email.send')));
    await tester.pumpAndSettle();
    expect(emailPuts.last, {'email': 'taro@example.com', 'currentPassword': 'right password'});
    expect(find.byKey(const ValueKey('security.email.pending')), findsOneWidget);
  });

  testWidgets('パスワードの無いアカウントの初めてのメールは、これまで通り何も要らない (ORGATE O-009)', (tester) async {
    final me = <String, Object?>{'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ', 'hasPassword': false, 'emailVerified': false, 'roles': <String>[]};
    final emailPuts = <Map<String, Object?>>[];
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      final body = req.body.isEmpty ? const <String, Object?>{} : (jsonDecode(req.body) as Map).cast<String, Object?>();
      switch ('${req.method} $path') {
        case 'GET /me':
          return json(me);
        case 'GET /me/sessions':
          return json(const []);
        case 'PUT /me/email':
          emailPuts.add(body);
          me['emailPending'] = body['email'];
          return json({'email': body['email'], 'expiresInSeconds': 900}, 202);
      }
      return err(404, 'not found');
    });
    final c = await pump(tester, mock);
    c.read(routerProvider).push('${Routes.settings}/security');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('security.email.currentPassword')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('security.email.input')), 'taro@example.com');
    await tester.tap(find.byKey(const ValueKey('security.email.send')));
    await tester.pumpAndSettle();
    expect(emailPuts, [
      {'email': 'taro@example.com'},
    ]);
  });

  test('ログインの 2 段階目の応答を読む / 廃止したメールのコードだけのログインの言い換え (D-419)', () {
    final e = OrgateException(ErrorCode.http(401), 'メールに確認コードを送りました', serverCode: 'second_factor_required', details: {'challengeId': 'ch-1', 'email': 'h***@example.com', 'expiresInSeconds': 600});
    final ch = RasqLoginChallenge.of(e)!;
    expect([ch.challengeId, ch.email, ch.expiresInSeconds], ['ch-1', 'h***@example.com', 600]);
    expect(RasqLoginChallenge.of(OrgateException(ErrorCode.http(401), 'invalid handle or password', serverCode: '401')), isNull);
    expect(accountSecurityMessage(OrgateException(ErrorCode.http(410), '…', serverCode: 'passwordless_login_removed')), contains('パスワードでログインしてください'));
  });

  /// ORGATE の口をまねる: パスワード(+ 確認済みのメールがあれば 2 段階目)/ 再設定。
  ({MockClient mock, List<String> calls, Map<String, Map<String, Object?>> bodies, Map<String, String?> auth}) fakeLogin({bool secondFactor = true}) {
    final calls = <String>[];
    final bodies = <String, Map<String, Object?>>{};
    final auth = <String, String?>{};
    var challenges = 0;
    final tokens = {'accountId': 'acc-9', 'handle': 'hanako', 'displayName': 'ハナコ', 'accessToken': 'login-token', 'refreshToken': 'refresh', 'restoreSecret': 'restore-9', 'restored': true};
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      final body = req.body.isEmpty ? const <String, Object?>{} : (jsonDecode(req.body) as Map).cast<String, Object?>();
      final key = '${req.method} $path';
      calls.add(key);
      bodies[key] = body;
      auth[key] = req.headers['authorization'];
      switch (key) {
        case 'GET /me':
          final bearer = req.headers['authorization'];
          if (bearer == 'Bearer login-token') return json({'id': 'acc-9', 'handle': 'hanako', 'displayName': 'ハナコ', 'hasPassword': true, 'email': 'hanako@example.com', 'emailVerified': true});
          if (bearer == 'Bearer device-token') return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ', 'hasPassword': true, 'email': 'taro@example.com', 'emailVerified': true});
          return err(401, 'valid bearer token required');
        case 'POST /auth/login':
          if (body['password'] != 'correct horse battery') return err(401, 'invalid handle or password');
          if (!secondFactor) return json(tokens);
          challenges++;
          return json({
            'error': {'code': 'second_factor_required', 'message': 'メールに確認コードを送りました', 'challengeId': 'ch-$challenges', 'email': 'h***@example.com', 'expiresInSeconds': 600},
          }, 401);
        case 'POST /auth/login/confirm':
          return body['challengeId'] == 'ch-$challenges' && body['code'] == '9zYx8-WvUt7' ? json(tokens) : err(400, 'invalid or expired code');
        case 'POST /auth/password/reset/request':
          return http.Response('', 204);
        case 'POST /auth/password/reset/confirm':
          if (body['code'] != '4kPq2-RsTu5') return err(400, 'invalid or expired code');
          final keep = body['keepCurrentSession'] == true && req.headers['authorization'] == 'Bearer device-token';
          return json({'accountId': 'acc-1', 'revokedSessions': 2, 'keptSession': keep, if (keep) 'restoreSecret': 'restore-rotated'});
        case 'GET /me/sns-accounts':
          return json(<Object>[]);
        case 'GET /me/sessions':
          return json(<Object>[]);
      }
      return err(404, 'not found');
    });
    return (mock: mock, calls: calls, bodies: bodies, auth: auth);
  }

  Future<void> typeLogin(WidgetTester tester, String id, String password) async {
    await tester.enterText(find.byKey(const ValueKey('login.identifier')), id);
    await tester.enterText(find.byKey(const ValueKey('login.password')), password);
    await tester.tap(find.byKey(const ValueKey('login.submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('ログインはパスワード (D-419): 違えば「パスワードの無いアカウントは元の端末で設定」まで案内する。メールのコードだけの入口は無い', (tester) async {
    final f = fakeLogin(secondFactor: false);
    final c = await pump(tester, f.mock, loggedIn: false);
    c.read(routerProvider).push('${Routes.settings}/account-login');
    await tester.pumpAndSettle();
    expect(find.byType(AccountLoginScreen), findsOneWidget);
    expect(find.text('メールのコード'), findsNothing, reason: 'メールのコードだけのログインは無くなった');
    expect(find.byKey(const ValueKey('login.sendCode')), findsNothing);
    expect(find.byKey(const ValueKey('login.noPasswordHint')), findsOneWidget);
    await typeLogin(tester, 'hanako', 'nope nope nope');
    expect(find.byKey(const ValueKey('login.problem')), findsOneWidget);
    expect(find.textContaining('パスワードを設定していない RASQ アカウントには、ほかの端末からはログインできません'), findsOneWidget);
    // 2 段階目の無いアカウント: パスワードだけで入る。トークンは添えない(401 の取り直しで送り直さない)。
    await typeLogin(tester, 'hanako', 'correct horse battery');
    expect(f.bodies['POST /auth/login'], containsPair('deviceId', 'device-abc'));
    expect(f.bodies['POST /auth/login']!['label'], startsWith('RASQ ('));
    expect(f.auth['POST /auth/login'], isNull);
    expect(f.calls.where((k) => k.contains('/auth/login/email')), isEmpty);
    expect(c.read(orgateAccountProvider).value?.handle, 'hanako');
    expect(find.byType(AccountLoginScreen), findsNothing);
  });

  testWidgets('2 段階目 (D-419 / ORGATE O-010): 正しいパスワード → メールのコードの画面 → 違うコード → 送り直し → 正しいコードで入る', (tester) async {
    final f = fakeLogin();
    final c = await pump(tester, f.mock, loggedIn: false);
    c.read(routerProvider).push('${Routes.settings}/account-login');
    await tester.pumpAndSettle();
    await typeLogin(tester, 'hanako@example.com', 'correct horse battery');
    // コードの画面: 伏せた宛先と期限。まだトークンは無い。
    expect(find.byKey(const ValueKey('login.challenge')), findsOneWidget);
    expect(find.textContaining('h***@example.com'), findsWidgets);
    expect(find.textContaining('10 分有効'), findsOneWidget);
    expect(find.byKey(const ValueKey('login.password')), findsNothing);
    expect(c.read(orgateAccountProvider).value, isNull);
    // 違うコード → 言い換え。画面はそのまま。
    await tester.enterText(find.byKey(const ValueKey('login.code')), '11111-11111');
    await tester.tap(find.byKey(const ValueKey('login.confirm')));
    await tester.pumpAndSettle();
    expect(find.text('コードが違うか、期限が切れています'), findsOneWidget);
    expect(find.byType(AccountLoginScreen), findsOneWidget);
    // 送り直す = パスワードの段をもう一度(新しいチャレンジ)。
    await tester.tap(find.byKey(const ValueKey('login.resend')));
    await tester.pumpAndSettle();
    expect(f.calls.where((k) => k == 'POST /auth/login').length, 2);
    await tester.enterText(find.byKey(const ValueKey('login.code')), '9zYx8-WvUt7');
    await tester.tap(find.byKey(const ValueKey('login.confirm')));
    await tester.pumpAndSettle();
    expect(f.bodies['POST /auth/login/confirm'], {'challengeId': 'ch-2', 'code': '9zYx8-WvUt7'});
    expect(f.auth['POST /auth/login/confirm'], isNull);
    expect(c.read(orgateAccountProvider).value?.handle, 'hanako');
    expect(find.byType(AccountLoginScreen), findsNothing);
  });

  testWidgets('パスワードの再設定 (D-419): ログインの「パスワードを忘れた」→ メール → コード + 新しいパスワード → ログインの画面へ戻る', (tester) async {
    final f = fakeLogin();
    final c = await pump(tester, f.mock, loggedIn: false);
    c.read(routerProvider).push('${Routes.settings}/account-login');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('login.identifier')), 'hanako@example.com');
    await tester.tap(find.byKey(const ValueKey('login.forgot')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountResetScreen), findsOneWidget);
    // 確認済みのメールが無いアカウントは再設定できない、の案内。メールは入っている。
    expect(find.byKey(const ValueKey('reset.noEmail')), findsOneWidget);
    expect(find.text('hanako@example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('reset.code')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reset.send')));
    await tester.pumpAndSettle();
    // アカウントがあるかどうかは言わない。
    expect(find.textContaining('確認済みのアカウントがあれば'), findsOneWidget);
    expect(f.auth['POST /auth/password/reset/request'], isNull);
    FilledButton submit() => tester.widget<FilledButton>(find.byKey(const ValueKey('reset.submit')));
    await tester.enterText(find.byKey(const ValueKey('reset.code')), '4kPq2-RsTu5');
    await tester.enterText(find.byKey(const ValueKey('reset.password')), 'fresh horse battery');
    await tester.pumpAndSettle();
    expect(submit().onPressed, isNull, reason: '確認の欄がまだ');
    await tester.enterText(find.byKey(const ValueKey('reset.passwordConfirm')), 'fresh horse battery');
    await tester.pumpAndSettle();
    // ログインしていない端末: 「この端末を残す」は出さない。
    expect(find.byKey(const ValueKey('reset.keep')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('reset.submit')));
    await tester.tap(find.byKey(const ValueKey('reset.submit')));
    await tester.pumpAndSettle();
    expect(f.bodies['POST /auth/password/reset/confirm'], {'email': 'hanako@example.com', 'code': '4kPq2-RsTu5', 'password': 'fresh horse battery'});
    expect(f.auth['POST /auth/password/reset/confirm'], isNull);
    expect(find.byType(AccountResetScreen), findsNothing);
    expect(find.byType(AccountLoginScreen), findsOneWidget);
    expect(find.textContaining('新しいパスワードでログインしてください'), findsOneWidget);
    expect(tester.widget<TextField>(find.descendant(of: find.byKey(const ValueKey('login.identifier')), matching: find.byType(TextField))).controller!.text, 'hanako@example.com');
  });

  testWidgets('パスワードの再設定: ログイン中の端末は「この端末のログインは残す」→ 回った復帰の秘密を持ち直す', (tester) async {
    final f = fakeLogin();
    final c = await pump(tester, f.mock);
    c.read(routerProvider).push(Uri(path: '${Routes.settings}/account-reset', queryParameters: {'email': 'taro@example.com'}).toString());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reset.send')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('reset.code')), '4kPq2-RsTu5');
    await tester.enterText(find.byKey(const ValueKey('reset.password')), 'fresh horse battery');
    await tester.enterText(find.byKey(const ValueKey('reset.passwordConfirm')), 'fresh horse battery');
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('reset.keep'))).value, isTrue);
    await tester.ensureVisible(find.byKey(const ValueKey('reset.submit')));
    await tester.tap(find.byKey(const ValueKey('reset.submit')));
    await tester.pumpAndSettle();
    expect(f.bodies['POST /auth/password/reset/confirm'], containsPair('keepCurrentSession', true));
    expect(f.auth['POST /auth/password/reset/confirm'], 'Bearer device-token');
    expect(find.textContaining('ほかの 2 台の端末をログアウトしました'), findsOneWidget);
    final saved = jsonDecode((await c.read(sessionStorageProvider).read(OrgateAccountNotifier.storageKey))!) as Map;
    expect((saved['restore'] as Map)['acc-1'], 'restore-rotated');
  });

  testWidgets('セキュリティ画面の 2 段階目 (D-419): 既定で ON。切るにはいまのパスワード(かメールのコード)、入れるのは何も要らない', (tester) async {
    final me = <String, Object?>{'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ', 'hasPassword': true, 'email': 'taro@example.com', 'emailVerified': true, 'secondFactor': true, 'secondFactorActive': true, 'roles': <String>[]};
    final puts = <Map<String, Object?>>[];
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      final body = req.body.isEmpty ? const <String, Object?>{} : (jsonDecode(req.body) as Map).cast<String, Object?>();
      switch ('${req.method} $path') {
        case 'GET /me':
          return json(me);
        case 'GET /me/sessions':
          return json(<Object>[]);
        case 'PUT /me/second-factor':
          puts.add(body);
          if (body['enabled'] == false && body['currentPassword'] != 'correct horse battery' && body['code'] == null) return err(403, 'いまのパスワードが違います');
          me['secondFactor'] = body['enabled'];
          me['secondFactorActive'] = body['enabled'];
          return json({'enabled': body['enabled'], 'active': body['enabled']});
      }
      return err(404, 'not found');
    });
    final c = await pump(tester, mock);
    c.read(routerProvider).push('${Routes.settings}/security');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('security.2fa.switch')), 200, scrollable: find.byType(Scrollable).first);
    Switch sw() => tester.widget<Switch>(find.byKey(const ValueKey('security.2fa.switch')));
    expect(sw().value, isTrue);
    expect(find.textContaining('パスワードのあとに、メールに届く確認コード'), findsOneWidget);
    // 切る: すぐには送らず、いまのパスワードの欄が出る。
    await tester.tap(find.byKey(const ValueKey('security.2fa.switch')));
    await tester.pumpAndSettle();
    expect(puts, isEmpty);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('security.2fa.off')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('security.2fa.byCode')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('security.2fa.password')), 'correct horse battery');
    await tester.tap(find.byKey(const ValueKey('security.2fa.off')));
    await tester.pumpAndSettle();
    expect(puts.single, {'enabled': false, 'currentPassword': 'correct horse battery'});
    expect(c.read(orgateAccountProvider).value!.secondFactor, isFalse);
    expect(find.textContaining('切っています'), findsOneWidget);
    // 入れ直す: 何も要らない。
    await tester.scrollUntilVisible(find.byKey(const ValueKey('security.2fa.switch')), -200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('security.2fa.switch')));
    await tester.pumpAndSettle();
    expect(puts.last, {'enabled': true});
    expect(sw().value, isTrue);
  });
}
