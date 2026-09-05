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
import 'package:rasq_client/features/onboarding/onboarding_screen.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/session/session_storage.dart';
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
