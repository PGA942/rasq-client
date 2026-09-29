import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/profile/rasq_profile_edit_screen.dart';
import 'package:rasq_client/backend/rasq_consent.dart';
import 'package:rasq_client/features/onboarding/onboarding_screen.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/session/sanctions.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/rasq_terms_gate.dart';
import 'package:rasq_client/shell/rasq_account_fow.dart';
import 'package:rasq_client/shell/rasq_register_fow.dart';
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
          return http.Response('{"accountId":"c1","handle":"rasq_c1","displayName":"RASQ ユーザー","token":"tok"}', 200, headers: {'content-type': 'application/json'});
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
  ({MockClient client, List<String> calls, List<Map<String, Object?>> consents, Set<String> bundle}) fakeCentral({bool restored = false, Set<String>? serverBundle, bool rejectVersion = false, bool pending = false}) {
    final calls = <String>[];
    var accepted = !pending;
    final consents = <Map<String, Object?>>[];
    final bundle = serverBundle ?? <String>{};
    var deleted = false;
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
        return json({'accountId': 'acc-1', 'handle': 'rasq_tester', 'displayName': 'テスター', 'token': 'device-token', 'restored': restored});
      }
      if (req.headers['authorization'] != 'Bearer device-token' || deleted) return json({'error': {'code': '401', 'message': 'valid bearer token required'}}, 401);
      if (req.method == 'POST' && path == '/auth/password') return http.Response('', 204);
      if (req.method == 'GET' && path == '/me') {
        return json({
          'id': 'acc-1',
          'handle': 'rasq_tester',
          'displayName': 'テスター',
          'createdAt': '2026-09-17T00:00:00Z',
          if (pending) 'terms': {'accepted': accepted, 'missing': accepted ? [] : ['terms', 'privacy']},
        });
      }
      if (req.method == 'DELETE' && path == '/me') {
        if (req.url.queryParameters['confirm'] != 'rasq_tester') return json({'error': {'code': '400', 'message': 'confirm'}}, 400);
        deleted = true;
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

  testWidgets('RASQ アカウントの登録 FOW (D-241): 規約と年齢に同意するまで登録できない → 登録 → 同意を記録 → バンドルを置き換える → 削除', (tester) async {
    final central = fakeCentral(serverBundle: {'misskey:old.example:gone'});
    final container = await pumpWithCentral(tester, central.client);
    // 下のボタン (D-272): 「RASQ アカウントを追加」→「新しく作成」。
    await tester.tap(find.byKey(const ValueKey('rasq.account.add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新しく作成'));
    await tester.pumpAndSettle();
    // 登録の前に FOW。まだサーバーへは何も送っていない。
    expect(find.text('RASQ アカウントの登録'), findsOneWidget);
    expect(central.calls.where((c) => c.startsWith('POST /auth/device')), isEmpty);
    FilledButton submit() => tester.widget<FilledButton>(find.byKey(const ValueKey('register.submit')));
    expect(submit().onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('register.agree')));
    await tester.pumpAndSettle();
    expect(submit().onPressed, isNull); // 年齢がまだ
    // 16〜17 歳は保護者の同意も要る。
    await tester.ensureVisible(find.byKey(const ValueKey('register.age.16-17')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('register.age.16-17')));
    await tester.pumpAndSettle();
    expect(submit().onPressed, isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('register.guardian')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('register.guardian')));
    await tester.pumpAndSettle();
    expect(submit().onPressed, isNull); // パスワードがまだ
    // パスワード (D-299): 必須。
    Future<void> typePassword(String pw, [String? confirm]) async {
      await tester.ensureVisible(find.byKey(const ValueKey('register.password')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('register.password')), pw);
      await tester.enterText(find.byKey(const ValueKey('register.passwordConfirm')), confirm ?? pw);
      await tester.pumpAndSettle();
    }

    await typePassword('short');
    expect(submit().onPressed, isNull);
    await typePassword('correct horse', 'correct hors');
    expect(submit().onPressed, isNull); // 確認が違う
    await typePassword('correct horse');
    expect(submit().onPressed, isNotNull);
    // バンドルは「置き換える」が既定(この端末に SNS アカウントが 2 件ある)。
    await tester.ensureVisible(find.byKey(const ValueKey('register.bundle.keep')));
    await tester.pumpAndSettle();
    expect(find.textContaining('ログイン中の 2 件'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('register.submit')));
    await tester.pumpAndSettle();
    // 登録 → 同意の記録(学習は含めない)。
    expect(central.calls.where((c) => c == 'POST /auth/device').length, 1);
    expect(central.calls.where((c) => c == 'POST /auth/password').length, 1, reason: '登録と同時にパスワードを設定する (D-299)');
    expect(central.consents.map((c) => '${c['kind']}:${c['granted']}:${c['detail'] ?? ''}'), ['terms:true:', 'privacy:true:', 'age:true:16-17', 'guardian:true:']);
    expect(central.consents.first['version'], rasqTermsVersion);
    expect(central.consents.any((c) => c['kind'] == 'learning'), isFalse);
    expect(central.consents.every((c) => c['via'] == 'device'), isTrue, reason: '承諾は登録と同じ要求で(後から別に書かない)');
    // プロフィールの編集画面が続く (D-269: SNS のプロフィール編集と同じ作り。FOW は閉じる)→ 戻る。
    expect(find.byType(RasqProfileEditScreen), findsOneWidget);
    expect(find.text('プロフィールの更新'), findsOneWidget);
    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    // FOW は閉じているので、もう一度開く(以降の確認のため)。
    expect(find.text('RASQ アカウントの登録'), findsNothing);
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('RASQ アカウント'));
    await tester.pumpAndSettle();
    // 台帳に載り、SNS アカウントを引き継ぐ。サーバーの前のバンドルは置き換わる。
    final rec = container.read(currentRasqAccountProvider)!;
    expect(rec.isCentral, isTrue);
    expect(rec.sessionKeys, [acc1.key, acc2.key]);
    expect(rec.pruneBundle, isTrue);
    expect(central.bundle, {acc1.key, acc2.key});

    // 削除: … → RASQ アカウントを削除 → 確認 → DELETE /me?confirm=<handle> → 「この端末のみ」へ戻る。
    final centralRow = find.ancestor(of: find.textContaining('rasq_tester'), matching: find.byType(RasqUserRow)).first;
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
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    expect(central.calls, contains('DELETE /me?confirm=rasq_tester'));
    expect(container.read(orgateAccountProvider).value, isNull);
    expect(container.read(currentRasqAccountProvider)!.isCentral, isFalse);
    expect(container.read(currentRasqAccountProvider)!.sessionKeys.toSet(), {acc1.key, acc2.key});
  });

  testWidgets('登録 FOW で「置き換えない」(D-241): SNS アカウントは「この端末のみ」に残り、サーバーのバンドルは消さない。キャンセルなら登録しない', (tester) async {
    final central = fakeCentral(restored: true, serverBundle: {'misskey:old.example:kept'});
    final container = await pumpWithCentral(tester, central.client);
    // キャンセル → 何も送らない。
    // 下のボタン (D-272): 「RASQ アカウントを追加」→「新しく作成」。
    await tester.tap(find.byKey(const ValueKey('rasq.account.add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新しく作成'));
    await tester.pumpAndSettle();
    container.read(overlayManagerProvider).close(rasqRegisterFowId);
    await tester.pumpAndSettle();
    expect(central.calls.where((c) => c.startsWith('POST /auth/device')), isEmpty);
    expect(container.read(currentRasqAccountProvider)?.isCentral ?? false, isFalse);

    // 下のボタン (D-272): 「RASQ アカウントを追加」→「新しく作成」。
    await tester.tap(find.byKey(const ValueKey('rasq.account.add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新しく作成'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('register.agree')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('register.age.18+')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('register.age.18+')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('register.guardian')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('register.bundle.keep')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('register.bundle.keep')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('register.password')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('register.password')), 'correct horse');
    await tester.enterText(find.byKey(const ValueKey('register.passwordConfirm')), 'correct horse');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('register.submit')));
    await tester.pumpAndSettle();
    expect(find.text('この端末の RASQ アカウントへ戻りました'), findsOneWidget); // restored
    container.read(overlayManagerProvider).close('rasq.profile.edit');
    await tester.pumpAndSettle();
    final rec = container.read(currentRasqAccountProvider)!;
    expect(rec.isCentral, isTrue);
    expect(rec.sessionKeys, isEmpty);
    expect(rec.pruneBundle, isFalse);
    expect(central.bundle, {'misskey:old.example:kept'});
    expect(central.consents.map((c) => c['kind']), ['terms', 'privacy', 'age']);
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
    expect(find.text('RASQ アカウントを追加'), findsOneWidget); // Central 未設定なので無効
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('rasq.account.add'))).onPressed, isNull);
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
    await tester.tap(find.byKey(const ValueKey('rasq.account.add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新しく作成'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('register.agree')));
    await tester.ensureVisible(find.byKey(const ValueKey('register.age.18+')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('register.age.18+')));
    await tester.ensureVisible(find.byKey(const ValueKey('register.password')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('register.password')), 'correct horse');
    await tester.enterText(find.byKey(const ValueKey('register.passwordConfirm')), 'correct horse');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('register.submit')));
    await tester.pumpAndSettle();
    expect(central.calls.where((c) => c == 'POST /auth/device').length, 1);
    expect(central.calls.where((c) => c.startsWith('GET /me')), isEmpty, reason: 'トークンを受け取っていない');
    expect(central.consents, isEmpty);
    expect(container.read(orgateAccountProvider).value, isNull);
    expect(find.textContaining('利用規約が新しくなっています'), findsOneWidget);
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
    expect(find.text('RASQ アカウントを作成しますか?'), findsOneWidget);
    await tester.tap(find.text('スキップしてこの端末だけで使う'));
    await tester.pumpAndSettle();
    expect(find.text('SNSにログイン'), findsOneWidget);
    final ledger = container.read(rasqAccountsProvider).value!;
    expect(ledger.onboardingDone, isTrue);
    expect(ledger.current!.kind, RasqAccountKind.local);
  });
}

class _FixedSettingsArea extends SettingsAreaStore {
  _FixedSettingsArea(this.values) : super('backend');
  final Map<String, Object?> values;
  @override
  Future<Map<String, Object?>> build() async => values;
}
