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
      expect(ledger.central, isNull);
      expect(ledger.current!.kind, RasqAccountKind.local);
      expect(ledger.current!.sessionKeys.toSet(), {acc1.key, acc2.key});
      final stored = jsonDecode((await container.read(sessionStorageProvider).read(OrgateAccountNotifier.storageKey))!) as Map;
      expect(stored['token'], isNull);
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
  ({MockClient client, List<String> calls, List<Map<String, Object?>> consents, Set<String> bundle}) fakeCentral({bool restored = false, Set<String>? serverBundle}) {
    final calls = <String>[];
    final consents = <Map<String, Object?>>[];
    final bundle = serverBundle ?? <String>{};
    var deleted = false;
    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
    final client = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      calls.add('${req.method} $path${req.url.hasQuery ? '?${req.url.query}' : ''}');
      if (req.method == 'POST' && path == '/auth/device') return json({'accountId': 'acc-1', 'handle': 'rasq_tester', 'displayName': 'テスター', 'token': 'device-token', 'restored': restored});
      if (req.headers['authorization'] != 'Bearer device-token' || deleted) return json({'error': {'code': '401', 'message': 'valid bearer token required'}}, 401);
      if (req.method == 'GET' && path == '/me') return json({'id': 'acc-1', 'handle': 'rasq_tester', 'displayName': 'テスター', 'createdAt': '2026-09-17T00:00:00Z'});
      if (req.method == 'DELETE' && path == '/me') {
        if (req.url.queryParameters['confirm'] != 'rasq_tester') return json({'error': {'code': '400', 'message': 'confirm'}}, 400);
        deleted = true;
        return http.Response('', 204);
      }
      if (req.method == 'PUT' && path.startsWith('/me/consents/')) {
        final b = (jsonDecode(req.body) as Map).cast<String, Object?>();
        consents.add({'kind': path.split('/').last, ...b});
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
    await tester.tap(find.text('RASQ アカウントを作成'));
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
    expect(submit().onPressed, isNotNull);
    // バンドルは「置き換える」が既定(この端末に SNS アカウントが 2 件ある)。
    await tester.ensureVisible(find.byKey(const ValueKey('register.bundle.keep')));
    await tester.pumpAndSettle();
    expect(find.textContaining('ログイン中の 2 件'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('register.submit')));
    await tester.pumpAndSettle();
    // 登録 → 同意の記録(学習は含めない)。
    expect(central.calls.where((c) => c == 'POST /auth/device').length, 1);
    expect(central.consents.map((c) => '${c['kind']}:${c['granted']}:${c['detail'] ?? ''}'), ['terms:true:', 'privacy:true:', 'age:true:16-17', 'guardian:true:']);
    expect(central.consents.first['version'], rasqTermsVersion);
    expect(central.consents.any((c) => c['kind'] == 'learning'), isFalse);
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
    await tester.tap(find.text('RASQ アカウントを削除'));
    await tester.pumpAndSettle();
    expect(find.textContaining('学習へのデータ提供に同意していた場合は'), findsOneWidget);
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
    await tester.tap(find.text('RASQ アカウントを作成'));
    await tester.pumpAndSettle();
    container.read(overlayManagerProvider).close(rasqRegisterFowId);
    await tester.pumpAndSettle();
    expect(central.calls.where((c) => c.startsWith('POST /auth/device')), isEmpty);
    expect(container.read(currentRasqAccountProvider)?.isCentral ?? false, isFalse);

    await tester.tap(find.text('RASQ アカウントを作成'));
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

    expect(find.byType(RasqAccountPanel), findsOneWidget);
    final row = find.byType(RasqUserRow);
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('tester')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('@tester')), findsOneWidget);
    expect(find.textContaining('この端末のみ ・ SNS 2件 ・ 使用中'), findsOneWidget);
    expect(find.text('RASQ アカウントを作成'), findsOneWidget); // Central 未設定なので無効
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'RASQ アカウントを作成')).onPressed, isNull);
    expect(find.text('SNS アカウントを追加'), findsOneWidget);

    // 行の … → ログアウト / アカウント設定 / プロフィール編集 / 通知設定(ローカルはログアウト不可)。
    await tester.tap(find.descendant(of: row, matching: find.byTooltip('アカウントの操作')));
    await tester.pumpAndSettle();
    for (final label in ['プロフィール編集', 'アカウント設定', '通知設定', 'ログアウト']) {
      expect(find.text(label), findsOneWidget);
    }

    // プロフィール編集(ローカル): 表示名だけ変えられる → 顔が変わる。
    await tester.tap(find.text('プロフィール編集'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'tester').first, 'わたし');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(container.read(rasqAccountProvider).displayName, 'わたし');
    expect(find.descendant(of: find.byType(RasqUserRow), matching: find.text('わたし')), findsOneWidget);
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
