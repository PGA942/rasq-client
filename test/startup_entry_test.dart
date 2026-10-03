import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/onboarding/onboarding_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-318: 起動したときの入口。RASQ アカウントに入っていなければ、SNS のログインより先に RASQ アカウントの入口
/// (オンボーディング)を出す。
///
/// D-316 からログアウトは「そのアカウントのトークンだけ消す」になり、台帳にほかの Central のアカウントが残る
/// (トークンの無い行も残りうる)。前は「台帳に Central のアカウントがあるか」で決めていたので、ログアウトして起動すると
/// RASQ アカウントの入口を飛ばして SNS のログインが出ていた。
void main() {
  const snsA = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice_sns');
  AccountSession session(AccountId a) => AccountSession(account: a, pluginId: 'test.fake', token: 't-${a.handle}', createdAt: DateTime(2026, 9, 1), displayName: a.handle);
  RasqAccountRecord central(String id, String handle, {List<String> keys = const []}) =>
      RasqAccountRecord(id: 'central-$id', kind: RasqAccountKind.central, handle: handle, displayName: handle, centralAccountId: id, sessionKeys: keys, createdAt: DateTime(2026, 9, 1));
  RasqAccountRecord local({List<String> keys = const []}) => RasqAccountRecord(id: RasqAccountsNotifier.localId, kind: RasqAccountKind.local, sessionKeys: keys, createdAt: DateTime(2026, 9, 1));

  group('入口の振り分け (entryRedirect)', () {
    RasqAccountsState ledger(List<RasqAccountRecord> accounts, String? current) => RasqAccountsState(accounts: accounts, currentId: current, onboardingDone: true);
    String? go(String loc, {bool loggedIn = false, RasqAccountsState? l, Set<String>? signedIn = const {}}) => entryRedirect(loc: loc, loggedIn: loggedIn, ledger: l, signedInCentral: signedIn);

    test('新規の端末(台帳が空)/ RASQ アカウントが 1 つも無い → オンボーディング', () {
      expect(go(Routes.home, l: const RasqAccountsState()), Routes.onboarding);
      expect(go(Routes.home, l: null), Routes.onboarding);
      expect(go(Routes.home, l: ledger([local()], RasqAccountsNotifier.localId)), Routes.onboarding);
    });

    test('ログアウトしたあと、ほかの RASQ アカウントが台帳に残っていても(いまは「この端末のみ」)→ オンボーディング', () {
      final l = ledger([central('acc-b', 'bob'), local(keys: [snsA.key])], RasqAccountsNotifier.localId);
      expect(go(Routes.home, l: l, signedIn: {'acc-b'}), Routes.onboarding);
    });

    test('いまの RASQ アカウントのトークンが端末に無い(ほかの端末でログアウトさせた等)→ オンボーディング', () {
      final l = ledger([central('acc-a', 'alice')], 'central-acc-a');
      expect(go(Routes.home, l: l, signedIn: const {}), Routes.onboarding);
      expect(go(Routes.home, l: l, signedIn: {'acc-b'}), Routes.onboarding);
    });

    test('RASQ アカウントに入っていて、SNS はまだ → SNS のログイン。資格情報を読み終えるまでは動かさない', () {
      final l = ledger([central('acc-a', 'alice')], 'central-acc-a');
      expect(go(Routes.home, l: l, signedIn: {'acc-a'}), Routes.login);
      expect(go(Routes.home, l: l, signedIn: null), isNull);
    });

    test('オンボーディング中に開けるのは、規約とプライバシーポリシーの文書だけ(ほかの設定の文書へは行かない、D-405)', () {
      expect(go('${Routes.settings}/dsl/about.store', l: const RasqAccountsState()), Routes.onboarding);
      expect(go(Routes.settings, l: const RasqAccountsState()), Routes.onboarding);
    });

    test('SNS にログインしていれば(「この端末のみ」でも)そのまま。オンボーディングにいればホームへ', () {
      final l = ledger([local(keys: [snsA.key])], RasqAccountsNotifier.localId);
      expect(go(Routes.home, loggedIn: true, l: l), isNull);
      expect(go(Routes.onboarding, loggedIn: true, l: l), Routes.home);
    });

    test('未ログインでも開ける画面 / SNS のログイン(「SNS アカウントだけで使う」を選んだ)には留まる', () {
      for (final loc in [Routes.onboarding, Routes.rasqRegister, Routes.termsDoc, Routes.privacyDoc, Routes.login, Routes.loginMisskey, '${Routes.settings}/server', '${Routes.settings}/account-login', '${Routes.settings}/account-reset', Routes.catalog]) {
        expect(go(loc, l: const RasqAccountsState()), isNull, reason: loc);
      }
    });
  });

  group('起動 (RasqApp)', () {
    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
    final centralClient = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      final me = switch (req.headers['authorization']) {
        'Bearer tok-a' => {'id': 'acc-a', 'handle': 'alice', 'displayName': 'alice'},
        'Bearer tok-b' => {'id': 'acc-b', 'handle': 'bob', 'displayName': 'bob'},
        _ => null,
      };
      if (me == null) return json({'error': {'code': '401', 'message': 'no token'}}, 401);
      if (path == '/me' && req.method == 'GET') return json(me);
      if (path == '/me/sns-accounts' && req.method == 'GET') return json(const []);
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    List<Override> overrides(SessionStorage storage) => [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []))),
          orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: centralClient, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
          centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
          orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        ];

    Future<ProviderContainer> launch(WidgetTester tester, SessionStorage storage) async {
      await tester.pumpWidget(ProviderScope(overrides: overrides(storage), child: const RasqApp()));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    }

    /// 2 つの RASQ アカウント(A をいま使っている)から、アカウントの FOW と同じ手順で A からログアウトした端末。
    /// SNS のセッションは、Web 版と同じく端末には無い(A の保管庫にあって、トークンが無いと読めない)。
    Future<MemorySessionStorage> loggedOutOfA({bool withB = true}) async {
      final storage = MemorySessionStorage({
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'dev-1', 'tokens': {'acc-a': 'tok-a', if (withB) 'acc-b': 'tok-b'}, 'currentAccountId': 'acc-a'}),
        RasqAccountsNotifier.storageKey: jsonEncode({
          'accounts': [central('acc-a', 'alice', keys: [snsA.key]).toJson(), if (withB) central('acc-b', 'bob').toJson()],
          'current': 'central-acc-a',
          'onboardingDone': true,
        }),
      });
      final c = ProviderContainer(overrides: overrides(storage));
      await c.read(rasqAccountsProvider.future);
      await c.read(orgateAccountProvider.future);
      await c.read(orgateAccountProvider.notifier).signOut(accountId: 'acc-a');
      await c.read(rasqAccountsProvider.notifier).detachCentral('central-acc-a');
      c.dispose();
      return storage;
    }

    testWidgets('ほかの RASQ アカウント(B)が残っていても、ログアウトして起動したら RASQ アカウントの入口。B で続けられる', (tester) async {
      final storage = await loggedOutOfA();
      final c = await launch(tester, storage);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('RASQ アカウントにログインしますか?'), findsOneWidget);
      expect(find.text('SNSにログイン'), findsNothing);
      // A はもう続けられない(トークンが無い)。B はパスワードを入れ直さずに続けられる。
      expect(find.byKey(const ValueKey('onboarding.resume.central-acc-a')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('onboarding.resume.central-acc-b')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3)); // SNS のログインが戻るのを待つ間
      await tester.pumpAndSettle();
      expect(c.read(rasqAccountsProvider).value!.current!.id, 'central-acc-b');
      expect(c.read(orgateAccountProvider).value!.id, 'acc-b');
      // B には SNS がまだ無い → SNS のログインへ(ここでは RASQ の入口に戻さない)。
      expect(find.text('SNSにログイン'), findsOneWidget);
    });

    testWidgets('RASQ アカウントが 1 つも残っていなければ、同じ入口(続けるボタンは無い)', (tester) async {
      final storage = await loggedOutOfA(withB: false);
      await launch(tester, storage);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('RASQ アカウントにログインしますか?'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('onboarding.resume.')), findsNothing);
    });

    testWidgets('いまの RASQ アカウントのトークンが端末に無い(ほかの端末でログアウトさせた等)なら、RASQ アカウントの入口', (tester) async {
      final storage = MemorySessionStorage({
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'dev-1', 'tokens': <String, String>{}, 'currentAccountId': null}),
        RasqAccountsNotifier.storageKey: jsonEncode({'accounts': [central('acc-a', 'alice').toJson()], 'current': 'central-acc-a', 'onboardingDone': true}),
      });
      await launch(tester, storage);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('SNSにログイン'), findsNothing);
    });

    testWidgets('RASQ アカウントに入っていて SNS がまだなら、SNS のログイン(今までどおり)', (tester) async {
      final storage = MemorySessionStorage({
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'dev-1', 'tokens': {'acc-b': 'tok-b'}, 'currentAccountId': 'acc-b'}),
        RasqAccountsNotifier.storageKey: jsonEncode({'accounts': [central('acc-b', 'bob').toJson()], 'current': 'central-acc-b', 'onboardingDone': true}),
      });
      await launch(tester, storage);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text('SNSにログイン'), findsOneWidget);
    });

    testWidgets('ネイティブで SNS のログインが「この端末のみ」に残っていれば、そのままホーム(ログアウトの確認に書いてあるとおり)', (tester) async {
      final storage = await loggedOutOfA();
      await storage.write(SessionsNotifier.storageKey, jsonEncode({'sessions': [session(snsA).toJson()], 'current': snsA.key}));
      final c = await launch(tester, storage);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString(), startsWith(Routes.home));
      expect(c.read(rasqAccountsProvider).value!.current!.id, RasqAccountsNotifier.localId);
    });
  });
}
