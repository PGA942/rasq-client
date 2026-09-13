import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/login/mixi2_login_screen.dart';
import 'package:rasq_client/session/mixi2_auth.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// mixi2 のログイン画面 (D-206): 「ダミーアカウントで試す」→ ホスト dummy の CredentialAuthFlow → セッション追加 → ホーム。
/// 「ブラウザで認証」はブローカー(サーバー)待ちなので、理由が出る。
class _FakeMixi2Plugin extends SnsPlugin {
  final hosts = <String>[];
  @override
  SnsKind get kind => SnsKind.mixi2;
  @override
  PluginManifest get manifest => const PluginManifest(id: mixi2PluginId, name: 'mixi2 (サンプル)', version: '0.1.0', kind: PluginKind.sns, supportedSns: [SnsKind.mixi2]);
  @override
  Future<ServerInfo> inspectServer(String host) async => ServerInfo(host: host, name: host);
  @override
  Future<AuthFlow> beginAuth(String host, {Uri? callback}) async {
    hosts.add(host);
    if (host != mixi2DummyHost) throw SnsApiException(ErrorCode.tryParse('503', message: 'mixi2 のログインには RASQ サーバーが必要です')!);
    return _DummyFlow();
  }

  @override
  SnsSession open(AccountSession session) => FakeSnsSession(session, const []);
}

class _DummyFlow extends CredentialAuthFlow {
  @override
  Future<AuthResult> login({required String identifier, required String secret}) async {
    const account = AccountId(kind: SnsKind.mixi2, instance: mixi2DummyHost, handle: 'me');
    return AuthResult(
      session: AccountSession(account: account, pluginId: mixi2PluginId, token: 'dummy:me', createdAt: DateTime(2026), displayName: 'わたし(ダミー)'),
      me: const UserSummary(id: 'u-me', account: account, displayName: 'わたし(ダミー)'),
    );
  }
}

void main() {
  testWidgets('ログイン画面 → mixi2 → ブラウザ認証はサーバー待ちの理由、ダミーで試す → セッション追加 → ホーム', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final plugin = _FakeMixi2Plugin();
    final registry = PluginRegistry()..register(plugin);
    final storage = MemorySessionStorage({});
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    if (find.text('スキップしてこの端末だけで使う').evaluate().isNotEmpty) {
      await tester.tap(find.text('スキップしてこの端末だけで使う'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('mixi2でログイン'));
    await tester.pumpAndSettle();
    expect(find.byType(Mixi2LoginScreen), findsOneWidget);
    // ブラウザで認証 → 規約 → サーバー待ちの理由。
    await tester.tap(find.byKey(mixi2LoginBrowserKey));
    await tester.pumpAndSettle();
    if (find.text('同意').evaluate().isNotEmpty) {
      await tester.tap(find.text('同意'));
      await tester.pumpAndSettle();
    }
    expect(plugin.hosts.last, 'mixi.social');
    expect(find.byKey(const ValueKey('login.mixi2.error')), findsOneWidget);
    // ダミーで試す。
    await tester.tap(find.byKey(mixi2LoginDummyKey));
    await tester.pumpAndSettle();
    if (find.text('同意').evaluate().isNotEmpty) {
      await tester.tap(find.text('同意'));
      await tester.pumpAndSettle();
    }
    expect(plugin.hosts.last, mixi2DummyHost);
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    expect(c.read(sessionsProvider).value!.allSessions.map((s) => s.account.key), contains('mixi2:dummy:me'));
    expect(c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString(), startsWith(Routes.home));
  });
}
