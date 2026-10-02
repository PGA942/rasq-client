import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/session/rasq_account_logout.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/session/sns_share.dart' show SnsShareStore;
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-409: RASQ アカウントからログアウト / 削除したとき、その SNS アカウントは「SNS アカウントもログアウトする」(既定)か
/// 「この端末のみ に移す」。どちらでも、ほかの Central の RASQ アカウントへは入らない。
void main() {
  AccountId sns(String h) => AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: h);
  final s0 = sns('local_only'), s1 = sns('a_one'), s2 = sns('a_two'), s3 = sns('b_only');
  AccountSession session(AccountId a) => AccountSession(account: a, pluginId: 'test.fake', token: 't-${a.handle}', createdAt: DateTime(2026, 9, 1), displayName: a.handle);
  Map<String, Object?> row(String id, List<AccountId> keys, {String? central}) => {
        'id': id,
        'kind': central == null ? 'local' : 'central',
        'centralAccountId': central,
        'handle': central,
        'sessionKeys': [for (final k in keys) k.key],
        'createdAt': '2026-09-01T00:00:00Z',
      };

  /// 台帳: 「この端末のみ」(s0) / Central A (s1, s2) / Central B (s3)。いまは A。
  MemorySessionStorage storage({List<AccountId>? local, String current = 'central-a'}) => MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [for (final a in [s0, s1, s2, s3]) session(a).toJson()], 'current': s1.key}),
        RasqAccountsNotifier.storageKey: jsonEncode({
          'accounts': [
            if (local != null) row(RasqAccountsNotifier.localId, local),
            row('central-a', [s1, s2], central: 'a'),
            row('central-b', [s3], central: 'b'),
          ],
          'current': current,
          'onboardingDone': true,
        }),
      });

  Future<ProviderContainer> container(MemorySessionStorage st) async {
    final c = ProviderContainer(overrides: [
      sessionStorageProvider.overrideWithValue(st),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []))),
    ]);
    addTearDown(c.dispose);
    await c.read(rasqAccountsProvider.future);
    await c.read(sessionsProvider.future);
    return c;
  }

  Future<Set<String>> storedSessions(SessionStorage st) async =>
      {for (final s in (jsonDecode((await st.read(SessionsNotifier.storageKey))!) as Map)['sessions'] as List) AccountSession.fromJson((s as Map).cast()).account.key};
  Map<String, Set<String>> rows(ProviderContainer c) => {for (final a in c.read(rasqAccountsProvider).value!.accounts) a.id: a.sessionKeys.toSet()};

  group('releaseRasqAccount', () {
    test('既定(SNS もログアウト): A の SNS は端末から消え、どの行にも残らない。「この端末のみ」に SNS があればそこへ', () async {
      final st = storage(local: [s0]);
      final c = await container(st);
      await releaseRasqAccount(c.read, 'central-a', sns: RasqLogoutSns.logout);
      expect(await storedSessions(st), {s0.key, s3.key});
      expect(rows(c), {RasqAccountsNotifier.localId: {s0.key}, 'central-b': {s3.key}});
      expect(c.read(rasqAccountsProvider).value!.currentId, RasqAccountsNotifier.localId);
      final view = await c.read(sessionsProvider.future);
      expect(view.sessions.map((s) => s.account), [s0]);
    });

    test('「この端末のみ に移す」: A の SNS は「この端末のみ」へ。B には入らない', () async {
      final st = storage(local: [s0]);
      final c = await container(st);
      await releaseRasqAccount(c.read, 'central-a', sns: RasqLogoutSns.moveToLocal);
      expect(await storedSessions(st), {s0.key, s1.key, s2.key, s3.key});
      expect(rows(c), {RasqAccountsNotifier.localId: {s0.key, s1.key, s2.key}, 'central-b': {s3.key}});
      expect(c.read(rasqAccountsProvider).value!.currentId, RasqAccountsNotifier.localId);
      expect((await c.read(sessionsProvider.future)).sessions.map((s) => s.account.key).toSet(), {s0.key, s1.key, s2.key});
    });

    test('「この端末のみ」が無く B にもトークンが無い: 空の「この端末のみ」へ(= 入口のオンボーディング)', () async {
      final st = storage();
      final c = await container(st);
      await releaseRasqAccount(c.read, 'central-a', sns: RasqLogoutSns.logout);
      final ledger = c.read(rasqAccountsProvider).value!;
      expect(ledger.currentId, RasqAccountsNotifier.localId);
      expect(rows(c), {'central-b': {s3.key}, RasqAccountsNotifier.localId: <String>{}});
      final view = await c.read(sessionsProvider.future);
      expect(view.isLoggedIn, isFalse);
      expect(entryRedirect(loc: Routes.home, loggedIn: false, ledger: ledger, signedInCentral: const {'b'}), Routes.onboarding);
    });

    test('ログアウトするのが、いま使っていないアカウント: いまのアカウント (B) はそのまま、B の SNS も変わらない', () async {
      final st = storage(local: [s0], current: 'central-b');
      final c = await container(st);
      await releaseRasqAccount(c.read, 'central-a', sns: RasqLogoutSns.logout);
      expect(c.read(rasqAccountsProvider).value!.currentId, 'central-b');
      expect(rows(c), {RasqAccountsNotifier.localId: {s0.key}, 'central-b': {s3.key}});
      expect((await c.read(sessionsProvider.future)).sessions.map((s) => s.account), [s3]);
      expect(await storedSessions(st), {s0.key, s3.key});
    });

    test('「この端末のみ」にもあった SNS は、SNS もログアウトなら一緒に消える。B にもあった SNS は B のために残す', () async {
      final st = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [for (final a in [s1, s2, s3]) session(a).toJson()]}),
        RasqAccountsNotifier.storageKey: jsonEncode({
          'accounts': [
            row(RasqAccountsNotifier.localId, [s1]), // 作成のときに引き継いだ(D-138)
            row('central-a', [s1, s2, s3], central: 'a'),
            row('central-b', [s3], central: 'b'),
          ],
          'current': 'central-a',
          'onboardingDone': true,
        }),
      });
      final c = await container(st);
      await releaseRasqAccount(c.read, 'central-a', sns: RasqLogoutSns.logout);
      expect(await storedSessions(st), {s3.key});
      expect(rows(c), {RasqAccountsNotifier.localId: <String>{}, 'central-b': {s3.key}});
    });

    test('端末間共有 (D-319) の「揃えた記録」から外す(次にログインしたとき、ほかの端末の SNS をログアウトさせない)', () async {
      final st = storage(local: [s0]);
      final share = SnsShareStore(st);
      await share.update('a', (e) => {...e, 'keyId': 'k', 'known': {s1.key: 'f1', s2.key: 'f2'}});
      await share.update('b', (e) => {...e, 'known': {s3.key: 'f3'}});
      final c = await container(st);
      await releaseRasqAccount(c.read, 'central-a', sns: RasqLogoutSns.logout);
      expect((await share.entry('a'))['known'], isEmpty);
      expect((await share.entry('a'))['keyId'], 'k');
      expect((await share.entry('b'))['known'], {s3.key: 'f3'});
    });
  });

  group('detachCentral の行き先', () {
    test('「この端末のみ」に SNS が無ければ、トークンのある Central のアカウントへ(その行の SNS だけ)', () async {
      final st = storage();
      final c = await container(st);
      await c.read(sessionsProvider.notifier).removeKeys([s1.key, s2.key]);
      await c.read(rasqAccountsProvider.notifier).detachCentral('central-a', keepSessions: false, signedInCentral: const {'b'});
      final ledger = c.read(rasqAccountsProvider).value!;
      expect(ledger.currentId, 'central-b');
      expect(ledger.accounts.map((a) => a.id), ['central-b'], reason: '空の「この端末のみ」は作らない');
      expect(rows(c), {'central-b': {s3.key}});
      expect((await c.read(sessionsProvider.future)).sessions.map((s) => s.account), [s3]);
    });

    test('前と同じ呼び方(引数なし)は、これまでどおり「この端末のみ」へ移す', () async {
      final st = storage();
      final c = await container(st);
      await c.read(rasqAccountsProvider.notifier).detachCentral('central-a');
      expect(rows(c), {'central-b': {s3.key}, RasqAccountsNotifier.localId: {s1.key, s2.key}});
      expect(c.read(rasqAccountsProvider).value!.currentId, RasqAccountsNotifier.localId);
    });
  });

  group('選択の確認', () {
    Future<ProviderContainer> pump(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage(local: [s0], current: RasqAccountsNotifier.localId)),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []))),
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    }

    Future<RasqLogoutSns?> ask(WidgetTester tester, ProviderContainer c, Future<void> Function() act) async {
      final f = askRasqLogoutSns(c.read, id: 'test.logout', title: 'RASQ アカウントからログアウト', message: 'この端末から RASQ アカウントを外します。', confirmText: 'ログアウト');
      await tester.pumpAndSettle();
      expect(find.text('SNS アカウントもログアウトする'), findsOneWidget);
      expect(find.text('この端末のみ に移す'), findsOneWidget);
      await act();
      await tester.pumpAndSettle();
      return f;
    }

    testWidgets('既定は「SNS アカウントもログアウトする」/ 選び直せる / キャンセルは null', (tester) async {
      final c = await pump(tester);
      expect(await ask(tester, c, () => tester.tap(find.byKey(const ValueKey('test.logout.confirm')))), RasqLogoutSns.logout);
      expect(
        await ask(tester, c, () async {
          await tester.tap(find.byKey(const ValueKey('test.logout.sns.moveToLocal')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('test.logout.confirm')));
        }),
        RasqLogoutSns.moveToLocal,
      );
      expect(await ask(tester, c, () => tester.tap(find.byKey(const ValueKey('test.logout.cancel')))), isNull);
    });
  });
}
