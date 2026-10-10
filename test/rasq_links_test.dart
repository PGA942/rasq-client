import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/rasq_links.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/custom/custom_plugins_screen.dart';
import 'package:rasq_client/features/profile/rasq_account_page_screen.dart';
import 'package:rasq_client/features/vc/astell_open_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-456: Central の Web のページ(rasq-central S-092)の「Web クライアントで開く」(`/app/…` = path の URL)と
/// 「アプリで開く」(`rasq://astell|account|custom-invite/…`)の着地点。
void main() {
  group('rasq:// のリンク → アプリの中の場所', () {
    test('AsTell ルーム / アカウント / カスタムプラグインの招待', () {
      expect(rasqDeepLinkLocation(Uri.parse('rasq://astell/3yQ7mFJx1bZk9T2aWnVq8E')), '/astell/3yQ7mFJx1bZk9T2aWnVq8E');
      expect(rasqDeepLinkLocation(Uri.parse('rasq://astell/0b0e4c1e-7f6a-4f0e-9a43-3f1f2b9e1c11')), '/astell/0b0e4c1e-7f6a-4f0e-9a43-3f1f2b9e1c11');
      expect(rasqDeepLinkLocation(Uri.parse('rasq://account/taro.dev')), '/rasq/taro.dev');
      expect(rasqDeepLinkLocation(Uri.parse('rasq://account/@hana')), '/rasq/hana');
      expect(rasqDeepLinkLocation(Uri.parse('rasq://custom-invite/AbC123xyz')), '/custom/invite/AbC123xyz');
    });

    test('形の合わない値は画面に渡さず、その種類の入口へ', () {
      expect(rasqDeepLinkLocation(Uri.parse('rasq://astell/')), Routes.vc);
      expect(rasqDeepLinkLocation(Uri.parse('rasq://astell/a%2Fb')), Routes.vc);
      expect(rasqDeepLinkLocation(Uri.parse('rasq://astell/${'a' * 65}')), Routes.vc);
      expect(rasqDeepLinkLocation(Uri.parse('rasq://account/%3Cscript%3E')), Routes.home);
      expect(rasqDeepLinkLocation(Uri.parse('rasq://custom-invite/ab')), Routes.customPlugins);
      expect(rasqDeepLinkLocation(Uri.parse('rasq://custom-invite/ab-cd')), Routes.customPlugins);
    });

    test('ほかの host / scheme は扱わない(チャイルドセーフ / 仮インポートはそれぞれの関数)', () {
      expect(rasqDeepLinkLocation(Uri.parse('rasq://child-safe/pair?code=X')), isNull);
      expect(rasqDeepLinkLocation(Uri.parse('rasq://dev-import?url=https://a.test/x')), isNull);
      expect(rasqDeepLinkLocation(Uri.parse('rasq://other/x')), isNull);
      expect(rasqDeepLinkLocation(Uri.parse('https://astell.rasq.jp/@hana/3yQ7mF')), isNull);
      expect(rasqDeepLinkLocation(Uri.parse('/astell/3yQ7mF')), isNull);
    });

    test('招待リンクは Central のオリジンの直下(API の起点のパス / クエリは捨てる)', () {
      expect(centralCustomInviteUrl(Uri.parse('https://central.example/api/v1?x=1'), 'AbC123'), 'https://central.example/custom/invite/AbC123');
      expect(centralCustomInviteUrl(Uri.parse('http://100.64.0.1:8080'), 'AbC123'), 'http://100.64.0.1:8080/custom/invite/AbC123');
    });
  });

  group('ルーター', () {
    Future<ProviderContainer> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      });
      final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(registry),
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    }

    String location(ProviderContainer c) => c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

    testWidgets('rasq://astell/<id> → /astell/<id>: ルームを引いてプレビューを開き、閉じたあとも開き直せる', (tester) async {
      final c = await pump(tester);
      c.read(routerProvider).go('rasq://astell/r-launch');
      await tester.pumpAndSettle();
      expect(location(c), '/astell/r-launch');
      expect(find.byType(AstellOpenScreen), findsOneWidget);
      // プレビューの FOW(タイトル = ルーム名、「閉じる」)が画面の上に出ている。
      expect(find.text('打ち上げの打ち上げ'), findsWidgets);
      await tester.tap(find.text('閉じる').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('astell.open.room')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('astell.open.again')));
      await tester.pumpAndSettle();
      expect(find.text('閉じる'), findsWidgets);
    });

    testWidgets('Web クライアントの場所(/astell/<code>)で無いルームは、見つからないと出す', (tester) async {
      final c = await pump(tester);
      c.read(routerProvider).go(Routes.astellRoom('nope'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('astell.open.error')), findsOneWidget);
    });

    testWidgets('rasq://account/<handle> → アカウントページ、rasq://custom-invite/<code> → 招待', (tester) async {
      final c = await pump(tester);
      c.read(routerProvider).go('rasq://account/hana');
      await tester.pumpAndSettle();
      expect(location(c), '/rasq/hana');
      expect(find.byType(RasqAccountPageScreen), findsOneWidget);
      c.read(routerProvider).go('rasq://custom-invite/AbC123xyz');
      await tester.pumpAndSettle();
      expect(location(c), '/custom/invite/AbC123xyz');
      // 招待の画面(モックにはこのコードのセッションが無いので「参加できませんでした」)。
      expect(find.byType(CustomInviteScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('custom.invite.error')), findsOneWidget);
    });

    testWidgets('チャイルドセーフのリンクは今までどおり、知らない rasq:// はホーム', (tester) async {
      final c = await pump(tester);
      c.read(routerProvider).go('rasq://child-safe/pair?code=abcd-efgh');
      await tester.pumpAndSettle();
      expect(location(c), '/child-safe/pair?code=ABCD-EFGH');
      c.read(routerProvider).go('rasq://other/x');
      await tester.pumpAndSettle();
      expect(location(c), startsWith(Routes.home));
    });
  });
}
