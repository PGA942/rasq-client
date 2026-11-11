import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/login/terms_sheet.dart' show termsAgreeKey;
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/login/bluesky_login_screen.dart';
import 'package:rasq_client/session/bluesky_auth.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// Bluesky のログイン画面 (D-175): PDS / ハンドル / アプリパスワード → CredentialAuthFlow.login → セッション追加 → ホーム。
class _FakeBlueskyPlugin extends SnsPlugin {
  final calls = <(String host, String id, String secret)>[];
  @override
  SnsKind get kind => SnsKind.bluesky;
  @override
  PluginManifest get manifest => const PluginManifest(id: blueskyPluginId, name: 'Bluesky', version: '0.1.0', kind: PluginKind.sns, supportedSns: [SnsKind.bluesky]);
  @override
  Future<ServerInfo> inspectServer(String host) async => ServerInfo(host: host, name: host);
  @override
  Future<AuthFlow> beginAuth(String host, {Uri? callback}) async => _Flow(this, host);
  @override
  SnsSession open(AccountSession session) => FakeSnsSession(session, const []);
}

class _Flow extends CredentialAuthFlow {
  const _Flow(this.plugin, this.host);
  final _FakeBlueskyPlugin plugin;
  final String host;
  @override
  Future<AuthResult> login({required String identifier, required String secret}) async {
    plugin.calls.add((host, identifier, secret));
    if (secret != 'app-pass') throw SnsApiException(ErrorCode.tryParse('401', message: 'パスワードが違います')!);
    const account = AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'alice.bsky.social');
    return AuthResult(
      session: AccountSession(account: account, pluginId: blueskyPluginId, token: jsonEncode({'did': 'did:plc:x', 'accessJwt': 'a', 'refreshJwt': 'r'}), createdAt: DateTime(2026), displayName: 'Alice'),
      me: const UserSummary(id: 'did:plc:x', account: account, displayName: 'Alice'),
    );
  }
}

void main() {
  testWidgets('ログイン画面 → Bluesky → PDS / ハンドル / アプリパスワード → 失敗はエラー表示、成功でセッション追加 → ホーム', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final plugin = _FakeBlueskyPlugin();
    final registry = PluginRegistry()..register(plugin);
    final storage = MemorySessionStorage({});
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    // 初回オンボーディング (D-138) をスキップ → ログイン画面。Bluesky のボタンが有効になっている。
    if (find.text('スキップしてこの端末だけで使う').evaluate().isNotEmpty) {
      await tester.tap(find.text('スキップしてこの端末だけで使う'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Blueskyでログイン'));
    await tester.pumpAndSettle();
    expect(find.byType(BlueskyLoginScreen), findsOneWidget);
    // 1 ページ目 (D-554): PDS の欄は空で始まる。URL を入れて「次へ」→ ハンドルのページ。
    expect(tester.widget<EditableText>(find.descendant(of: find.byKey(blueskyLoginHostKey), matching: find.byType(EditableText))).controller.text, isEmpty);
    expect(find.byKey(blueskyLoginIdKey), findsNothing);
    await tester.enterText(find.byKey(blueskyLoginHostKey), 'https://bsky.social/');
    await tester.tap(find.byKey(blueskyLoginNextKey));
    await tester.pumpAndSettle();
    expect(find.byType(BlueskyHandleScreen), findsOneWidget);
    await tester.enterText(find.byKey(blueskyLoginIdKey), 'alice.bsky.social');
    await tester.enterText(find.byKey(blueskyLoginPasswordKey), 'wrong');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(blueskyLoginButtonKey));
    await tester.pumpAndSettle();
    // 利用規約シート → 同意。
    if (find.byKey(termsAgreeKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(termsAgreeKey));
      await tester.pumpAndSettle();
    }
    expect(plugin.calls.last, ('bsky.social', 'alice.bsky.social', 'wrong'));
    expect(find.text('パスワードが違います'), findsOneWidget);
    await tester.enterText(find.byKey(blueskyLoginPasswordKey), 'app-pass');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(blueskyLoginButtonKey));
    await tester.pumpAndSettle();
    if (find.byKey(termsAgreeKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(termsAgreeKey));
      await tester.pumpAndSettle();
    }
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    final sessions = c.read(sessionsProvider).value!.allSessions;
    expect(sessions.map((s) => s.account.key), contains('bluesky:bsky.social:alice.bsky.social'));
    expect(c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString(), startsWith(Routes.home));
    expect(find.byType(BlueskyLoginScreen), findsNothing);
  });

  test('ハンドルの補完 (D-554): 名前だけなら .<PDS> を補う。ハンドル / メール / DID はそのまま', () {
    expect(blueskyIdentifierFor('alice', 'bsky.social'), 'alice.bsky.social');
    expect(blueskyIdentifierFor(' @alice ', 'pds.example.com'), 'alice.pds.example.com');
    expect(blueskyIdentifierFor('alice.example.com', 'bsky.social'), 'alice.example.com');
    expect(blueskyIdentifierFor('alice@example.com', 'bsky.social'), 'alice@example.com');
    expect(blueskyIdentifierFor('did:plc:abc', 'bsky.social'), 'did:plc:abc');
    expect(blueskyIdentifierFor('', 'bsky.social'), '');
  });

  testWidgets('「サーバーの検索」のタイルを押すと、その PDS でハンドルのページへ。名前だけ入れてログインすると .<PDS> が補われる', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final plugin = _FakeBlueskyPlugin();
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage({})), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin))],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).go(Routes.login);
    await tester.pumpAndSettle();
    c.read(routerProvider).push(Routes.loginBluesky);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('login.server.bsky.social')));
    await tester.pumpAndSettle();
    expect(find.byType(BlueskyHandleScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('login.bluesky.completeNote')), findsOneWidget);
    await tester.enterText(find.byKey(blueskyLoginIdKey), 'alice');
    await tester.enterText(find.byKey(blueskyLoginPasswordKey), 'app-pass');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(blueskyLoginButtonKey));
    await tester.pumpAndSettle();
    if (find.byKey(termsAgreeKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(termsAgreeKey));
      await tester.pumpAndSettle();
    }
    expect(plugin.calls.last, ('bsky.social', 'alice.bsky.social', 'app-pass'));
  });
}
