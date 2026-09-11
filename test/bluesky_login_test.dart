import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await tester.enterText(find.byKey(blueskyLoginHostKey), 'https://bsky.social/');
    await tester.enterText(find.byKey(blueskyLoginIdKey), 'alice.bsky.social');
    await tester.enterText(find.byKey(blueskyLoginPasswordKey), 'wrong');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(blueskyLoginButtonKey));
    await tester.pumpAndSettle();
    // 利用規約シート → 同意。
    if (find.text('同意').evaluate().isNotEmpty) {
      await tester.tap(find.text('同意'));
      await tester.pumpAndSettle();
    }
    expect(plugin.calls.last, ('bsky.social', 'alice.bsky.social', 'wrong'));
    expect(find.text('パスワードが違います'), findsOneWidget);
    await tester.enterText(find.byKey(blueskyLoginPasswordKey), 'app-pass');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(blueskyLoginButtonKey));
    await tester.pumpAndSettle();
    if (find.text('同意').evaluate().isNotEmpty) {
      await tester.tap(find.text('同意'));
      await tester.pumpAndSettle();
    }
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    final sessions = c.read(sessionsProvider).value!.allSessions;
    expect(sessions.map((s) => s.account.key), contains('bluesky:bsky.social:alice.bsky.social'));
    expect(c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString(), startsWith(Routes.home));
    expect(find.byType(BlueskyLoginScreen), findsNothing);
  });
}
