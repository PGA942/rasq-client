import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/backend/rasq_consent.dart';
import 'package:rasq_client/features/onboarding/onboarding_feed.dart';
import 'package:rasq_client/features/onboarding/onboarding_previews.dart';
import 'package:rasq_client/features/onboarding/onboarding_steps.dart';
import 'package:rasq_client/features/onboarding/onboarding_screen.dart';
import 'package:rasq_client/features/settings/account_security_screen.dart' show AccountLoginScreen;
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/session/sanctions.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/rasq_terms_gate.dart';
import 'package:rasq_client/shell/rasq_account_fow.dart';
import 'package:rasq_client/shell/sidebar.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-138: RASQ アカウントの実体化 — 台帳(ローカル/Central)と SNS セッションの
/// 所属、サイドバー … → RASQ アカウント FOW、初回オンボーディング。
void main() {
  const acc1 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  const acc2 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'second');
  AccountSession session(AccountId a) => AccountSession(account: a, pluginId: fakeSession().pluginId, token: 't-${a.handle}', createdAt: DateTime(2026, 9, 1), displayName: a.handle);
  Post post(String id, AccountId a, String body) => Post(id: id, account: a, author: UserSummary(id: 'u-${a.handle}', account: a, displayName: a.handle), createdAt: DateTime(2026, 8, 31), body: body);

  MemorySessionStorage seededStorage() => MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [session(acc1).toJson(), session(acc2).toJson()], 'current': acc1.key}),
      });

  Future<ProviderContainer> pump(WidgetTester tester, {SessionStorage? storage}) async {
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [post('p-${v.handle}', v, '${v.handle} の投稿')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage ?? seededStorage()),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  group('台帳', () {
    test('移行: 台帳が無く SNS セッションがある端末は、従来のバンドルを「この端末のみ」にしてオンボーディング済み扱い', () async {
      final container = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(seededStorage())]);
      addTearDown(container.dispose);
      final ledger = await container.read(rasqAccountsProvider.future);
      expect(ledger.onboardingDone, isTrue);
      expect(ledger.accounts.single.kind, RasqAccountKind.local);
      expect(ledger.accounts.single.sessionKeys, [acc1.key, acc2.key]);

      // SessionsState は現在の RASQ アカウントの所属分を見せる。
      final sessions = await container.read(sessionsProvider.future);
      expect(sessions.sessions.length, 2);
      expect(container.read(rasqAccountProvider).account.handle, 'tester'); // ローカルは最初の SNS を借りる
    });

    test('新規端末(セッションなし)は台帳が空でオンボーディング未了', () async {
      final container = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage({}))]);
      addTearDown(container.dispose);
      final ledger = await container.read(rasqAccountsProvider.future);
      expect(ledger.accounts, isEmpty);
      expect(ledger.onboardingDone, isFalse);
    });

    test('Central アカウントの作成 → 台帳に載り現在の SNS を引き継ぐ / ログアウトでローカルへ戻る', () async {
      final http_ = MockClient((req) async {
        if (req.url.path.endsWith('/auth/device')) {
          return http.Response('{"accountId":"c1","handle":"rasq_c1","displayName":"RASQ ユーザー","accessToken":"tok","refreshToken":"tok-refresh"}', 200, headers: {'content-type': 'application/json'});
        }
        if (req.url.path.endsWith('/me')) {
          return http.Response('{"id":"c1","handle":"rasq_c1","displayName":"RASQ ユーザー","avatarUrl":null,"createdAt":"2026-09-05T00:00:00Z"}', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });
      final container = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(seededStorage()),
        settingsAreaProvider(backendSettingsArea).overrideWith(() => _FixedSettingsArea({'baseUrl': 'https://central.test'})),
        orgateClientProvider.overrideWith((ref) {
          final holder = ref.read(orgateTokenHolderProvider);
          return OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: http_, tokenProvider: () => holder.token);
        }),
      ]);
      addTearDown(container.dispose);
      await container.read(rasqAccountsProvider.future);
      await container.read(sessionsProvider.future);
      expect(await container.read(orgateAccountProvider.future), isNull);

      final account = (await container.read(orgateAccountProvider.notifier).createAccount())!;
      final rec = await container.read(rasqAccountsProvider.notifier).attachCentral(centralAccountId: account.id, handle: account.handle, displayName: account.displayName);
      expect(rec.isCentral, isTrue);
      expect(rec.sessionKeys, [acc1.key, acc2.key], reason: '現在のバンドルを引き継ぐ');
      expect(container.read(rasqAccountsProvider).value!.current!.id, rec.id);
      // 顔は Central のプロフィールに。
      await container.read(sessionsProvider.future);
      expect(container.read(rasqAccountProvider).account.handle, 'rasq_c1');
      expect(container.read(rasqAccountProvider).displayName, 'RASQ ユーザー');

      // ログアウト: トークンを捨て、SNS セッションはローカルへ戻る。
      await container.read(orgateAccountProvider.notifier).signOut();
      await container.read(rasqAccountsProvider.notifier).detachCentral(rec.id);
      final ledger = container.read(rasqAccountsProvider).value!;
      expect(ledger.hasCentral, isFalse);
      expect(ledger.current!.kind, RasqAccountKind.local);
      expect(ledger.current!.sessionKeys.toSet(), {acc1.key, acc2.key});
      final stored = jsonDecode((await container.read(sessionStorageProvider).read(OrgateAccountNotifier.storageKey))!) as Map;
      expect(stored['tokens'], isEmpty);
    });

    test('RASQ アカウントを切り替えると見える SNS セッションが変わる(所属外は隠れる)', () async {
      final container = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(seededStorage())]);
      addTearDown(container.dispose);
      await container.read(rasqAccountsProvider.future);
      await container.read(sessionsProvider.future);
      final other = await container.read(rasqAccountsProvider.notifier).attachCentral(centralAccountId: 'c2', handle: 'other', displayName: 'Other', inheritSessions: false);
      var sessions = await container.read(sessionsProvider.future);
      expect(sessions.sessions, isEmpty);
      expect(sessions.allSessions.length, 2, reason: '端末の全セッションは残る');
      expect(sessions.isLoggedIn, isFalse);

      await container.read(rasqAccountsProvider.notifier).select(RasqAccountsNotifier.localId);
      sessions = await container.read(sessionsProvider.future);
      expect(sessions.sessions.length, 2);
      expect(other.sessionKeys, isEmpty);
    });
  });

  /// Central のまね (D-241 / S-015): 端末登録 / me / 同意 / バンドル / 削除。
  /// [multi] = 2 回目からの `POST /auth/device` は別のアカウント(`acc-2` / `device-token-2` …)を作る (D-419)。
  ({MockClient client, List<String> calls, List<Map<String, Object?>> consents, Set<String> bundle}) fakeCentral({bool restored = false, Set<String>? serverBundle, bool rejectVersion = false, bool pending = false, bool multi = false}) {
    final calls = <String>[];
    var accepted = !pending;
    final consents = <Map<String, Object?>>[];
    final bundle = serverBundle ?? <String>{};
    // トークン → アカウント(ユーザー名は PATCH /me で変わる)。消したアカウントは外す。
    final accounts = <String, Map<String, String>>{
      'device-token': {'id': 'acc-1', 'handle': 'rasq_tester'},
    };
    var registered = 0;
    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
    final client = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      calls.add('${req.method} $path${req.url.hasQuery ? '?${req.url.query}' : ''}');
      if (req.method == 'POST' && path == '/auth/device') {
        // 登録と承諾は一緒に (D-371 / S-053): 承諾は登録の本文で届く。
        final c = (jsonDecode(req.body) as Map)['consents'];
        if (c is Map && rejectVersion) return json({'error': {'code': 'terms_version', 'message': 'terms must be accepted at the current version 2099'}}, 409);
        if (c is Map) {
          consents.add({'kind': 'terms', 'version': c['termsVersion'], 'granted': true, 'via': 'device'});
          consents.add({'kind': 'privacy', 'version': c['privacyVersion'], 'granted': true, 'via': 'device'});
          consents.add({'kind': 'age', 'version': c['termsVersion'], 'granted': true, 'detail': c['age'], 'via': 'device'});
          if (c['guardian'] == true) consents.add({'kind': 'guardian', 'version': c['termsVersion'], 'granted': true, 'via': 'device'});
        }
        registered++;
        final n = multi ? registered : 1;
        final token = n == 1 ? 'device-token' : 'device-token-$n';
        accounts[token] = {'id': 'acc-$n', 'handle': n == 1 ? 'rasq_tester' : 'rasq_tester$n'};
        return json({'accountId': 'acc-$n', 'handle': accounts[token]!['handle'], 'displayName': 'テスター', 'accessToken': token, 'refreshToken': 'refresh', 'restored': restored});
      }
      final me = accounts[(req.headers['authorization'] ?? '').replaceFirst('Bearer ', '')];
      if (me == null) return json({'error': {'code': '401', 'message': 'valid bearer token required'}}, 401);
      if (req.method == 'POST' && path == '/auth/password') return http.Response('', 204);
      if (req.method == 'PATCH' && path == '/me') {
        final b = (jsonDecode(req.body) as Map).cast<String, Object?>();
        if (b['handle'] is String) me['handle'] = b['handle'] as String;
        return json({'id': me['id'], 'handle': me['handle'], 'displayName': 'テスター', 'createdAt': '2026-09-17T00:00:00Z'});
      }
      if (req.method == 'GET' && path == '/me') {
        return json({
          'id': me['id'],
          'handle': me['handle'],
          'displayName': 'テスター',
          'createdAt': '2026-09-17T00:00:00Z',
          if (pending) 'terms': {'accepted': accepted, 'missing': accepted ? [] : ['terms', 'privacy']},
        });
      }
      if (req.method == 'DELETE' && path == '/me') {
        if (req.url.queryParameters['confirm'] != me['handle']) return json({'error': {'code': '400', 'message': 'confirm'}}, 400);
        accounts.removeWhere((_, a) => a == me);
        return http.Response('', 204);
      }
      if (req.method == 'PUT' && path.startsWith('/me/consents/')) {
        final b = (jsonDecode(req.body) as Map).cast<String, Object?>();
        consents.add({'kind': path.split('/').last, ...b});
        if (consents.any((x) => x['kind'] == 'terms') && consents.any((x) => x['kind'] == 'privacy')) accepted = true;
        return json({'kind': path.split('/').last, ...b, 'createdAt': '2026-09-17T00:00:00Z'});
      }
      if (req.method == 'GET' && path == '/me/sns-accounts') return json([for (final k in bundle) {'accountKey': k}]);
      if (req.method == 'PUT' && path == '/me/sns-accounts') {
        final b = (jsonDecode(req.body) as Map).cast<String, Object?>();
        bundle.add('${b['kind']}:${b['instance']}:${b['handle']}');
        return json(b);
      }
      if (req.method == 'DELETE' && path.startsWith('/me/sns-accounts/')) {
        bundle.remove(Uri.decodeComponent(path.split('/').last));
        return http.Response('', 204);
      }
      return json([]);
    });
    return (client: client, calls: calls, consents: consents, bundle: bundle);
  }

  Future<ProviderContainer> pumpWithCentral(WidgetTester tester, MockClient client) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [post('p-${v.handle}', v, '${v.handle} の投稿')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(seededStorage()),
        pluginRegistryProvider.overrideWithValue(registry),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: client, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('RASQ アカウント'));
    await tester.pumpAndSettle();
    return container;
  }

  /// ① のページ(ユーザー名・パスワード・年齢)を埋める (D-414)。
  Future<void> fillAccountStep(WidgetTester tester, {String handle = 'neko_taro', String age = '18+'}) async {
    await tester.enterText(find.byKey(const ValueKey('onb.handle')), handle);
    await tester.enterText(find.byKey(const ValueKey('onb.password')), 'correct horse');
    await tester.enterText(find.byKey(const ValueKey('onb.passwordConfirm')), 'correct horse');
    await tester.ensureVisible(find.byKey(ValueKey('onb.age.$age')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('onb.age.$age')));
    await tester.pumpAndSettle();
  }

  /// サイドバーの RASQ アカウントの選択 →「アカウントを新規作成」(D-419 → D-425: 選択肢を挟まず、そのまま ① のページへ)。
  Future<void> openCreateFromPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('rasq.account.create')));
    await tester.pumpAndSettle();
  }

  testWidgets('アカウントの選択のボタン (D-425): 「アカウントを新規作成」「ログイン」の 2 つ。選択肢は出さず、ログインはそのままログインの画面へ', (tester) async {
    final central = fakeCentral();
    await pumpWithCentral(tester, central.client);
    expect(find.text('アカウントを新規作成'), findsOneWidget);
    expect(find.text('ログイン'), findsOneWidget);
    expect(find.text('アカウントを新規作成 / ログイン'), findsNothing);
    expect(find.text('RASQ アカウントを追加'), findsNothing);
    expect(find.byKey(const ValueKey('rasq.account.add')), findsNothing);
    // 電話の幅でも 3 つのボタンが 1 行に収まる(チャイルドセーフはアイコンだけ)。
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('チャイルドセーフ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rasq.account.login')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rasq.account.entry.create')), findsNothing, reason: '選択肢は出さない');
    expect(find.byType(AccountLoginScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('rasq.account.login')), findsNothing, reason: 'FOW は閉じる');
    expect(central.calls.where((c) => c.startsWith('POST /auth/device')), isEmpty);
  });

  testWidgets('「アカウントを新規作成」(D-425): 選択肢を挟まず ① のページへ。FOW は閉じる', (tester) async {
    final central = fakeCentral();
    await pumpWithCentral(tester, central.client);
    await openCreateFromPicker(tester);
    expect(find.byKey(const ValueKey('rasq.account.entry.login')), findsNothing, reason: '選択肢は出さない');
    expect(find.byType(OnboardingAccountScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('rasq.account.create')), findsNothing);
    expect(central.calls.where((c) => c.startsWith('POST /auth/device')), isEmpty);
  });

  testWidgets('オンボーディングの外から作る (D-419): ① ユーザー名・パスワード・年齢 → ② 規約(同意するまで登録できない)→ 登録 → 元の画面へ戻る → 削除', (tester) async {
    final central = fakeCentral(serverBundle: {'misskey:old.example:gone'});
    final container = await pumpWithCentral(tester, central.client);
    await openCreateFromPicker(tester);
    // ① のページ(元へ戻る形: ページは 2 つ)。FOW は閉じた。まだサーバーへは何も送っていない。
    expect(find.byType(OnboardingAccountScreen), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('rasq.account.create')), findsNothing);
    expect(central.calls.where((c) => c.startsWith('POST /auth/device')), isEmpty);
    await fillAccountStep(tester, age: '16-17');
    await tester.tap(find.byKey(const ValueKey('onb.next')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingTermsScreen), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    FilledButton submit() => tester.widget<FilledButton>(find.byKey(const ValueKey('onb.register')));
    expect(submit().onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('onb.agree')));
    await tester.pumpAndSettle();
    expect(submit().onPressed, isNull, reason: '16〜17 歳は保護者の同意も要る');
    await tester.ensureVisible(find.byKey(const ValueKey('onb.guardian')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onb.guardian')));
    await tester.pumpAndSettle();
    expect(submit().onPressed, isNotNull);
    // バンドルは「置き換える」が既定(いまは「この端末のみ」で、SNS アカウントが 2 件ある)。
    await tester.ensureVisible(find.byKey(const ValueKey('onb.bundle.keep')));
    await tester.pumpAndSettle();
    expect(find.textContaining('ログイン中の 2 件'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('onb.register')));
    await tester.tap(find.byKey(const ValueKey('onb.register')));
    await tester.pumpAndSettle();
    // 登録(承諾は一緒に)→ ユーザー名 → パスワード。
    expect(central.calls.where((c) => c == 'POST /auth/device').length, 1);
    expect(central.calls.where((c) => c == 'PATCH /me').length, 1);
    expect(central.calls.where((c) => c == 'POST /auth/password').length, 1, reason: '登録と同時にパスワードを設定する (D-299)');
    expect(central.consents.map((c) => '${c['kind']}:${c['granted']}:${c['detail'] ?? ''}'), ['terms:true:', 'privacy:true:', 'age:true:16-17', 'guardian:true:']);
    expect(central.consents.first['version'], rasqTermsVersion);
    expect(central.consents.any((c) => c['kind'] == 'learning'), isFalse);
    // 元の画面へ戻る(③ の SNS のログインへは進まない)。
    expect(find.byType(OnboardingTermsScreen), findsNothing);
    expect(find.byType(OnboardingAccountScreen), findsNothing);
    expect(find.byType(OnboardingSnsScreen), findsNothing);
    expect(find.text('RASQ アカウント @neko_taro を作成しました'), findsOneWidget);
    final rec = container.read(currentRasqAccountProvider)!;
    expect([rec.isCentral, rec.handle], [true, 'neko_taro']);
    expect(rec.sessionKeys, [acc1.key, acc2.key]);
    expect(rec.pruneBundle, isTrue);
    expect(central.bundle, {acc1.key, acc2.key});
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('RASQ アカウント'));
    await tester.pumpAndSettle();

    // 削除: … → RASQ アカウントを削除 → 確認 → DELETE /me?confirm=<handle> → 「この端末のみ」へ戻る。
    final centralRow = find.ancestor(of: find.textContaining('neko_taro'), matching: find.byType(RasqUserRow)).first;
    await tester.ensureVisible(centralRow);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: centralRow, matching: find.byTooltip('アカウントの操作')));
    await tester.pumpAndSettle();
    // ↓ の操作は、タイルの下に折りたたみで出る (D-291)。一覧の中なので、画面内に送ってから押す。
    await tester.ensureVisible(find.text('RASQ アカウントを削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RASQ アカウントを削除'));
    await tester.pumpAndSettle();
    expect(find.textContaining('「アルゴリズムとコミュニティへの貢献」に同意していた場合は'), findsOneWidget);
    // SNS アカウントをどうするか (D-409): 既定は「SNS もログアウト」。ここでは「この端末のみ に移す」を選ぶ。
    await tester.tap(find.byKey(const ValueKey('rasq.account.delete.sns.moveToLocal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    expect(central.calls, contains('DELETE /me?confirm=neko_taro'));
    expect(container.read(orgateAccountProvider).value, isNull);
    expect(container.read(currentRasqAccountProvider)!.isCentral, isFalse);
    expect(container.read(currentRasqAccountProvider)!.sessionKeys.toSet(), {acc1.key, acc2.key});
  });

  /// D-409: … → ログアウト で、SNS アカウントをどうするかを選ぶ。どちらでも、ほかの Central の RASQ アカウントへは入らない。
  Future<({ProviderContainer container, MemorySessionStorage storage})> pumpSignedIn(WidgetTester tester) async {
    final central = fakeCentral();
    final storage = seededStorage();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [post('p-${v.handle}', v, '${v.handle} の投稿')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: central.client, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    final ledger = container.read(rasqAccountsProvider.notifier);
    // ほかの Central のアカウント(SNS なし)と、いま使うアカウント(この端末の SNS を引き継いで作成)。
    await ledger.attachCentral(centralAccountId: 'other', handle: 'other', displayName: 'ほかの人', inheritSessions: false);
    await ledger.select(RasqAccountsNotifier.localId);
    final account = (await container.read(orgateAccountProvider.notifier).createAccount())!;
    await ledger.attachCentral(centralAccountId: account.id, handle: account.handle, displayName: account.displayName);
    await tester.pumpAndSettle();
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('RASQ アカウント'));
    await tester.pumpAndSettle();
    final centralRow = find.ancestor(of: find.textContaining('rasq_tester'), matching: find.byType(RasqUserRow)).first;
    await tester.ensureVisible(centralRow);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: centralRow, matching: find.byTooltip('アカウントの操作')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ログアウト'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ログアウト'));
    await tester.pumpAndSettle();
    expect(find.text('SNS アカウントもログアウトする'), findsOneWidget);
    expect(find.text('この端末のみ に移す'), findsOneWidget);
    return (container: container, storage: storage);
  }

  Future<Set<String>> storedSessionKeys(SessionStorage storage) async =>
      {for (final s in (jsonDecode((await storage.read(SessionsNotifier.storageKey))!) as Map)['sessions'] as List) AccountSession.fromJson((s as Map).cast()).account.key};

  testWidgets('RASQ アカウントからログアウト (D-409): 既定は SNS アカウントもログアウト。端末から消え、ほかの RASQ アカウントにも入らない', (tester) async {
    final (:container, :storage) = await pumpSignedIn(tester);
    await tester.tap(find.byKey(const ValueKey('rasq.account.logout.confirm')));
    await tester.pumpAndSettle();
    expect(container.read(orgateAccountProvider).value, isNull);
    final ledger = container.read(rasqAccountsProvider).value!;
    expect(ledger.accounts.any((a) => a.centralAccountId == 'acc-1'), isFalse);
    expect(ledger.accounts.firstWhere((a) => a.id == 'central-other').sessionKeys, isEmpty);
    expect(ledger.accounts.expand((a) => a.sessionKeys), isEmpty);
    expect(await storedSessionKeys(storage), isEmpty);
    // 「この端末のみ」に SNS が無く、ほかのアカウントにもトークンが無い → 入口へ。
    expect(ledger.current!.id, RasqAccountsNotifier.localId);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('RASQ アカウントからログアウト (D-409): 「この端末のみ に移す」なら SNS は「この端末のみ」へ。ほかの RASQ アカウントには入らない', (tester) async {
    final (:container, :storage) = await pumpSignedIn(tester);
    await tester.tap(find.byKey(const ValueKey('rasq.account.logout.sns.moveToLocal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rasq.account.logout.confirm')));
    await tester.pumpAndSettle();
    final ledger = container.read(rasqAccountsProvider).value!;
    expect(ledger.current!.id, RasqAccountsNotifier.localId);
    expect(ledger.current!.sessionKeys.toSet(), {acc1.key, acc2.key});
    expect(ledger.accounts.firstWhere((a) => a.id == 'central-other').sessionKeys, isEmpty);
    expect(await storedSessionKeys(storage), {acc1.key, acc2.key});
    expect((await container.read(sessionsProvider.future)).sessions.length, 2);
  });

  testWidgets('② で「置き換えない」(D-241 → D-419): SNS アカウントは「この端末のみ」に残り、サーバーのバンドルは消さない。① で戻れば登録しない', (tester) async {
    final central = fakeCentral(restored: true, serverBundle: {'misskey:old.example:kept'});
    final container = await pumpWithCentral(tester, central.client);
    // キャンセル(① の戻る)→ 何も送らない。
    await openCreateFromPicker(tester);
    await tester.tap(find.byKey(const ValueKey('onb.back')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingAccountScreen), findsNothing);
    expect(central.calls.where((c) => c.startsWith('POST /auth/device')), isEmpty);
    expect(container.read(currentRasqAccountProvider)?.isCentral ?? false, isFalse);

    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('RASQ アカウント'));
    await tester.pumpAndSettle();
    await openCreateFromPicker(tester);
    await fillAccountStep(tester);
    await tester.tap(find.byKey(const ValueKey('onb.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onb.agree')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onb.guardian')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('onb.bundle.keep')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onb.bundle.keep')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('onb.register')));
    await tester.tap(find.byKey(const ValueKey('onb.register')));
    await tester.pumpAndSettle();
    final rec = container.read(currentRasqAccountProvider)!;
    expect(rec.isCentral, isTrue);
    expect(rec.sessionKeys, isEmpty);
    expect(rec.pruneBundle, isFalse);
    expect(central.bundle, {'misskey:old.example:kept'});
    expect(central.consents.map((c) => c['kind']), ['terms', 'privacy', 'age']);
  });

  testWidgets('ほかの RASQ アカウントに入っていても新しく作れる (D-419): 前は「新しく作成」が押せず、作ってもいまのアカウントが返っていた', (tester) async {
    final central = fakeCentral(multi: true);
    final storage = seededStorage();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [post('p-${v.handle}', v, '${v.handle} の投稿')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: central.client, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    // いま入っている Central のアカウント(この端末の SNS を引き継いで作成)。
    final first = (await container.read(orgateAccountProvider.notifier).createAccount())!;
    await container.read(rasqAccountsProvider.notifier).attachCentral(centralAccountId: first.id, handle: first.handle, displayName: first.displayName);
    await tester.pumpAndSettle();
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('RASQ アカウント'));
    await tester.pumpAndSettle();
    await openCreateFromPicker(tester);
    expect(find.byType(OnboardingAccountScreen), findsOneWidget);
    await fillAccountStep(tester, handle: 'second_one');
    await tester.tap(find.byKey(const ValueKey('onb.next')));
    await tester.pumpAndSettle();
    // いまのアカウントが Central のものなら、その SNS を新しいアカウントへ持ち込まない(バンドルは聞かない)。
    expect(find.byKey(const ValueKey('onb.bundle.replace')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('onb.agree')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('onb.register')));
    await tester.tap(find.byKey(const ValueKey('onb.register')));
    await tester.pumpAndSettle();
    expect(central.calls.where((c) => c == 'POST /auth/device').length, 2, reason: '2 つ目のアカウントを作る');
    final ledger = container.read(rasqAccountsProvider).value!;
    final centrals = ledger.accounts.where((a) => a.isCentral).toList();
    expect(centrals.map((a) => a.centralAccountId), ['acc-1', 'acc-2']);
    expect(ledger.current!.centralAccountId, 'acc-2');
    expect(ledger.current!.handle, 'second_one');
    expect(ledger.current!.sessionKeys, isEmpty);
    expect(centrals.first.sessionKeys, [acc1.key, acc2.key], reason: '前のアカウントの SNS はそのまま');
    expect(container.read(centralSignedInAccountIdsProvider), containsAll(['acc-1', 'acc-2']), reason: '前のアカウントのログインも残る');
    expect(find.text('RASQ アカウント @second_one を作成しました'), findsOneWidget);
  });

  testWidgets('アカウント処置の案内と解除申請 (D-151/D-152): 案内が出て、申請シートから POST /me/sanctions/{id}/appeal', (tester) async {
    final posted = <String>[];
    final http_ = MockClient((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/sanctions/sa1/appeal')) {
        posted.add(req.body);
        return http.Response('{"id":"ap1","status":"open"}', 201, headers: {'content-type': 'application/json'});
      }
      return http.Response('[]', 200, headers: {'content-type': 'application/json'});
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [post('p-${v.handle}', v, '${v.handle} の投稿')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(seededStorage()),
        pluginRegistryProvider.overrideWithValue(registry),
        settingsAreaProvider(backendSettingsArea).overrideWith(() => _FixedSettingsArea({'baseUrl': 'https://central.test'})),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: http_, tokenProvider: () => 'tok')),
        rasqSanctionsProvider.overrideWith((ref) async => RasqSanctions.fromJson({
              'level': 'light',
              'restrictedFeatures': ['post'],
              'categories': ['spam'],
              'sanctions': [
                {'id': 'sa1', 'category': 'spam', 'level': 'light', 'note': '宣伝の連投', 'appealStatus': null},
                {'id': 'sa2', 'category': 'harassment', 'level': 'moderate', 'note': '', 'appealStatus': 'open'},
              ],
            })),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('RASQ アカウント'));
    await tester.pumpAndSettle();
    expect(find.byKey(rasqSanctionBannerKey), findsOneWidget);
    expect(find.textContaining('軽度な制限'), findsOneWidget);
    expect(find.textContaining('止まっている機能: 投稿'), findsOneWidget);
    expect(find.textContaining('運営より: 宣伝の連投'), findsOneWidget);
    expect(find.text('申請中(harassment)'), findsOneWidget); // 未処理の申請がある処置
    await tester.tap(find.textContaining('解除を申請(spam'));
    await tester.pumpAndSettle();
    expect(find.text('処置の解除を申請'), findsOneWidget);
    await tester.tap(find.text('申請する')); // 空は送らない
    await tester.pumpAndSettle();
    expect(posted, isEmpty);
    await tester.enterText(find.widgetWithText(TextField, '申請の理由(必須)'), '反省しています');
    await tester.tap(find.text('申請する'));
    await tester.pumpAndSettle();
    expect(posted, ['{"message":"反省しています"}']);
    expect(find.textContaining('解除を申請しました'), findsOneWidget);
  });

  testWidgets('サイドバー … → RASQ アカウント FOW: 投稿タイル風の行(表示名/@handle)+ 左の通知バッジ枠 + … ドロップダウン', (tester) async {
    final container = await pump(tester);
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('RASQ アカウント'));
    await tester.pumpAndSettle();
    // … ではサイドバーを閉じない (D-272 → D-274): FOW は、後ろを暗くしてサイドバーの上に被さって出る。
    final overlay = container.read(overlayManagerProvider);
    expect(overlay.contains(RasqSidebar.overlayId), isTrue);
    expect(overlay.byId(rasqAccountFowId)!.fow!.aboveSidebar, isTrue);
    expect(overlay.contains(rasqAccountFowId), isTrue);

    expect(find.byType(RasqAccountPanel), findsOneWidget);
    final row = find.byType(RasqUserRow);
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('tester')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('@tester')), findsOneWidget);
    expect(find.textContaining('この端末のみ ・ SNS 2件 ・ 使用中'), findsOneWidget);
    expect(find.text('アカウントを新規作成'), findsOneWidget); // Central 未設定なので無効
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('rasq.account.create'))).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('rasq.account.login'))).onPressed, isNull);
    expect(find.byKey(const ValueKey('rasq.account.childSafe')), findsOneWidget);
    // 「SNS アカウントを追加」は、各アカウントの ↓ のメニューへ (D-272)。
    expect(find.text('SNS アカウントを追加'), findsNothing);

    // 行の … → ログアウト / アカウント設定 / プロフィール編集 / 通知設定(ローカルはログアウト不可)。
    await tester.tap(find.descendant(of: row, matching: find.byTooltip('アカウントの操作')));
    await tester.pumpAndSettle();
    for (final label in ['SNS アカウントを追加', '設定', 'プロフィール編集', 'アカウント設定', '通知設定', 'ログアウト']) {
      expect(find.text(label), findsOneWidget);
    }

    // プロフィール編集(ローカル): 表示名だけ変えられる → 顔が変わる。
    // ↓ の操作は、タイルの下に折りたたみで出る (D-291)。一覧の中なので、画面内に送ってから押す。
    await tester.ensureVisible(find.text('プロフィール編集'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('プロフィール編集'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'tester').first, 'わたし');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(container.read(rasqAccountProvider).displayName, 'わたし');
    // 顔(表示名)が変わる。操作の折りたたみで一覧が送られているので、画面の外も含めて探す。
    expect(find.text('わたし', skipOffstage: false), findsWidgets);
  });

  testWidgets('登録と承諾は一緒に (D-371 / CONS-02): サーバーが規約の版を断ったら、アカウントは作られず案内が出る', (tester) async {
    final central = fakeCentral(rejectVersion: true);
    final container = await pumpWithCentral(tester, central.client);
    await openCreateFromPicker(tester);
    await fillAccountStep(tester);
    await tester.tap(find.byKey(const ValueKey('onb.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onb.agree')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('onb.register')));
    await tester.tap(find.byKey(const ValueKey('onb.register')));
    await tester.pumpAndSettle();
    expect(central.calls.where((c) => c == 'POST /auth/device').length, 1);
    expect(central.calls.where((c) => c.startsWith('GET /me')), isEmpty, reason: 'トークンを受け取っていない');
    expect(central.consents, isEmpty);
    expect(container.read(orgateAccountProvider).value, isNull);
    expect(find.textContaining('利用規約が新しくなっています'), findsOneWidget);
    expect(find.byType(OnboardingTermsScreen), findsNothing, reason: '登録はページを閉じてから(D-419)');
  });

  testWidgets('同意待ちのアカウント (D-371): 起動後に承諾のシート、サイドバーに帯。同意すると記録して帯が消える', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final central = fakeCentral(pending: true);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [session(acc1).toJson()], 'current': acc1.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [post('p-${v.handle}', v, 'x')]))),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: central.client, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    expect(container.read(rasqTermsPendingProvider), isTrue);
    // 起動後に 1 度だけ承諾のシート。
    expect(find.text('利用規約への同意'), findsOneWidget);
    expect(find.byKey(const ValueKey('terms.age.18+')), findsNothing, reason: '年齢は申告済み');
    await tester.tap(find.byKey(const ValueKey('terms.agree')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意する'));
    await tester.pumpAndSettle();
    expect(central.consents.map((c) => '${c['kind']}:${c['version']}'), ['terms:$rasqTermsVersion', 'privacy:$rasqPrivacyVersion']);
    expect(container.read(rasqTermsPendingProvider), isFalse);
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('terms.banner')), findsNothing);
  });

  testWidgets('初回オンボーディング: 新規端末は案内 → スキップで「この端末のみ」→ SNS ログインへ', (tester) async {
    final container = await pump(tester, storage: MemorySessionStorage({}));
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('RASQ アカウントを作る'), findsOneWidget, reason: 'D-414: 初回は ① のページ');
    await tester.tap(find.text('スキップしてこの端末だけで使う'));
    await tester.pumpAndSettle();
    expect(find.text('SNSにログイン'), findsOneWidget);
    final ledger = container.read(rasqAccountsProvider).value!;
    expect(ledger.onboardingDone, isTrue);
    expect(ledger.current!.kind, RasqAccountKind.local);
  });

  /// 新規の端末(台帳が空)で、Central につながる構成のオンボーディング。[size] = 画面の論理サイズ。
  Future<ProviderContainer> pumpOnboarding(WidgetTester tester, MockClient client, {Size size = const Size(360, 780)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []))),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: client, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  testWidgets('オンボーディングの ② (D-405 → D-414): 利用規約 / プライバシーポリシーを開いて読め、戻ると入力が残る', (tester) async {
    final central = fakeCentral();
    await pumpOnboarding(tester, central.client);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('onb.handle')), 'neko_taro');
    await tester.enterText(find.byKey(const ValueKey('onb.password')), 'correct horse');
    await tester.enterText(find.byKey(const ValueKey('onb.passwordConfirm')), 'correct horse');
    await tester.ensureVisible(find.byKey(const ValueKey('onb.age.18+')));
    await tester.tap(find.byKey(const ValueKey('onb.age.18+')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onb.next')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingTermsScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onb.agree')));
    await tester.pumpAndSettle();
    // 前は入口の振り分けでオンボーディングへ戻され、文書が開けなかった。
    for (final (key, area) in [('onb.terms.read', 'about.terms'), ('onb.privacy.read', 'about.privacy')]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      expect(tester.widget<SettingsDslScreen>(find.byType(SettingsDslScreen)).area, area);
      expect(find.byType(OnboardingTermsScreen), findsNothing, reason: '文書は ② の上に積む');
      await tester.tap(find.descendant(of: find.byType(SettingsDslScreen), matching: find.byTooltip('戻る')));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingTermsScreen), findsOneWidget);
    }
    final agree = find.descendant(of: find.byKey(const ValueKey('onb.agree')), matching: find.byType(Checkbox));
    expect(tester.widget<Checkbox>(agree).value, isTrue);
    expect(central.calls.where((c) => c.startsWith('POST /auth/device')), isEmpty);
  });

  group('オンボーディングの 2 カラム (D-405 → D-414)', () {
    MockClient feedCentral({bool empty = false}) => MockClient((req) async {
          if (req.url.path.endsWith('/onboarding/feed')) {
            return http.Response.bytes(
                utf8.encode(jsonEncode({
                  'posts': [
                    if (!empty)
                      {
                        'post': {'id': 'f1', 'author': {'id': 'u1', 'kind': 'misskey', 'instance': 'misskey.io', 'handle': 'hana', 'displayName': 'はな'}, 'createdAt': '2026-10-01T00:00:00Z', 'body': 'うちの猫が箱から出てこない、ずっと寝てる', 'visibility': 'public'},
                        'list': {'id': 'l1', 'name': 'ねこ好き', 'ownerHandle': 'neko'},
                        'score': 3,
                      },
                  ],
                  'stale': false,
                })),
                200,
                headers: {'content-type': 'application/json'});
          }
          return http.Response.bytes(utf8.encode(jsonEncode({'error': {'code': '404', 'message': 'not found'}})), 404, headers: {'content-type': 'application/json'});
        });

    testWidgets('狭い画面は 1 カラムのまま(流れは出さず、探す画面への入口)', (tester) async {
      await pumpOnboarding(tester, feedCentral());
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(OnboardingFeedColumn), findsNothing);
      expect(find.byKey(const ValueKey('onboarding.showcase')), findsNothing, reason: 'D-414: サーバーとリストの見本の入口は外した');
      expect(find.byKey(const ValueKey('onboarding.discover')), findsOneWidget);
    });

    testWidgets('広い画面: 左の小カラムに公開 RASQ リストの投稿だけ(サーバーのタイルは出さない)', (tester) async {
      await pumpOnboarding(tester, feedCentral(), size: const Size(1280, 800));
      final column = find.byType(OnboardingFeedColumn);
      expect(column, findsOneWidget);
      expect(tester.getSize(column).width, 320, reason: '小型カラムの既定の幅 (D-320)');
      expect(tester.getTopLeft(column).dx, 0, reason: '左に置く');
      expect(find.byType(OnboardingPreviewColumn), findsNothing);
      expect(find.byKey(const ValueKey('onboarding.previews.servers')), findsNothing);
      expect(find.textContaining('リスト「ねこ好き」'), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding.discover')), findsNothing, reason: '狭い画面の入口は出さない');
      // ① のボタンは右の大型カラム。
      expect(tester.getTopLeft(find.byKey(const ValueKey('onb.next'))).dx, greaterThan(320));
    });

    testWidgets('流れが空なら、そう出す', (tester) async {
      await pumpOnboarding(tester, feedCentral(empty: true), size: const Size(1280, 800));
      expect(find.byKey(const ValueKey('onboarding.feed.empty')), findsOneWidget);
    });
  });
}

class _FixedSettingsArea extends SettingsAreaStore {
  _FixedSettingsArea(this.values) : super('backend');
  final Map<String, Object?> values;
  @override
  Future<Map<String, Object?>> build() async => values;
}
