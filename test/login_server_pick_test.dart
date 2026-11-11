import 'package:flutter/foundation.dart' show LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/login/login_screen.dart' show SnsServiceButton;
import 'package:rasq_client/features/login/server_pick.dart';
import 'package:rasq_client/features/login/sns_login_screen.dart';
import 'package:rasq_client/features/onboarding/sns_discover_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:sns_misskey/sns_misskey.dart';

import 'support/fakes.dart';

// ログインの画面の「サーバーの検索」と、探す画面の入口の見た目 (D-554)。

class _MisskeyPlugin extends FakeSnsPlugin {
  _MisskeyPlugin() : super(id: MisskeyPlugin.pluginId, posts: (_) => const []);
  final inspected = <String>[];
  final began = <String>[];
  @override
  Future<ServerInfo> inspectServer(String host) async {
    inspected.add(host);
    return ServerInfo(host: host, name: 'サーバー $host', description: '説明 <b>太字</b>');
  }

  @override
  Future<AuthFlow> beginAuth(String host, {Uri? callback}) async {
    began.add(host);
    return _Flow(host);
  }
}

class _Flow extends BrowserAuthFlow {
  const _Flow(this.host);
  final String host;
  @override
  Uri get url => Uri.parse('https://$host/miauth/x');
  @override
  String get hint => 'ブラウザで許可したら戻ってきてください';
  @override
  Future<AuthResult> complete() => throw UnimplementedError();
}

Future<ProviderContainer> _pump(WidgetTester tester, SnsPlugin plugin, List<String> launched) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), (call) async {
    if (call.method == 'launch' || call.method == 'launchUrl') launched.add('${(call.arguments as Map)['url']}');
    return true;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), null));
  await tester.pumpWidget(ProviderScope(
    overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage({})), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin))],
    child: const RasqApp(),
  ));
  await tester.pumpAndSettle();
  final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  c.read(routerProvider).go(Routes.login);
  await tester.pumpAndSettle();
  return c;
}

void main() {
  test('有力なサーバーの一覧: SNS ごとに 10 個まで、同じものは無い。入力欄の文字からホストを取り出す', () {
    for (final kind in [SnsKind.misskey, SnsKind.mastodon, SnsKind.bluesky]) {
      final list = popularServers[kind]!;
      expect(list, isNotEmpty, reason: '$kind');
      expect(list.length, lessThanOrEqualTo(popularServersMax), reason: '$kind');
      expect(list.toSet().length, list.length, reason: '$kind');
      expect(list.every((h) => h == h.toLowerCase() && h.contains('.') && !h.contains('/')), isTrue, reason: '$kind');
    }
    expect(popularServers[SnsKind.misskey]!.length, 10);
    expect(popularServers[SnsKind.mastodon]!.length, 10);
    expect(serverHostOf(' https://Misskey.IO/@taro '), 'misskey.io');
    expect(serverHostOf('mstdn.jp'), 'mstdn.jp');
    expect(serverHostOf(''), '');
  });

  testWidgets('Misskey でログイン: URL の欄は空。下に有力なサーバーが並び、タイルを押すとそのまま認証(規約 → ブラウザ)へ', (tester) async {
    final plugin = _MisskeyPlugin();
    final launched = <String>[];
    final c = await _pump(tester, plugin, launched);
    c.read(routerProvider).push(Routes.loginMisskey);
    await tester.pumpAndSettle();
    expect(find.byType(SnsLoginScreen), findsOneWidget);
    // URL の欄は空(例は薄い文字で)。
    final urlField = tester.widgetList<EditableText>(find.byType(EditableText)).first;
    expect(urlField.controller.text, isEmpty);
    // 有力なサーバーが 10 個。
    expect(find.byType(ServerPickTile), findsNWidgets(10));
    expect(find.byKey(const ValueKey('login.server.misskey.io')), findsOneWidget);
    // 検索欄で絞り込む。
    await tester.enterText(find.byKey(const ValueKey('login.server.search')), 'design');
    await tester.pumpAndSettle();
    expect(find.byType(ServerPickTile), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('login.server.search')), 'どこにも無い');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login.server.none')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('login.server.search')), '');
    await tester.pumpAndSettle();

    // タイルを押す → サーバーを確かめ、規約 → ブラウザの認証が開く(「ブラウザで認証する」は押さない)。
    await tester.tap(find.byKey(const ValueKey('login.server.misskey.design')));
    await tester.pumpAndSettle();
    if (find.text('同意').evaluate().isNotEmpty) {
      await tester.tap(find.text('同意'));
      await tester.pumpAndSettle();
    }
    expect(plugin.inspected, ['misskey.design']);
    expect(plugin.began, ['misskey.design']);
    expect(launched, ['https://misskey.design/miauth/x']);
    // 確かめたサーバーはタイルの形で出て(説明のタグは外す)、「認証を確認」に進んでいる。一覧は畳む。
    expect(find.byType(ServerPickTile), findsOneWidget);
    expect(find.text('サーバー misskey.design'), findsOneWidget);
    expect(find.text('説明 太字'), findsOneWidget);
    expect(find.text('ブラウザで許可したら戻ってきてください'), findsOneWidget);
    expect(urlField.controller.text, 'misskey.design');
  });

  testWidgets('URL を自分で入れて確かめることも、これまでどおりできる(確かめるだけ。認証は「ブラウザで認証する」を押してから)', (tester) async {
    final plugin = _MisskeyPlugin();
    final launched = <String>[];
    final c = await _pump(tester, plugin, launched);
    c.read(routerProvider).push(Routes.loginMisskey);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'example.misskey.test');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(plugin.inspected, ['example.misskey.test']);
    expect(plugin.began, isEmpty);
    expect(launched, isEmpty);
    expect(find.text('サーバー example.misskey.test'), findsOneWidget);
  });

  testWidgets('探す画面の入口は、ログインと同じボタン 6 つ(左の丸は同じ大きさ)', (tester) async {
    final c = await _pump(tester, _MisskeyPlugin(), []);
    c.read(routerProvider).push(Routes.snsDiscover);
    await tester.pumpAndSettle();
    expect(find.byType(SnsDiscoverScreen), findsOneWidget);
    final buttons = find.descendant(of: find.byType(SnsDiscoverScreen), matching: find.byType(SnsServiceButton));
    expect(buttons, findsNWidgets(6));
    for (final k in ['discover.content', 'discover.people', 'discover.export', 'discover.qr', 'discover.history', 'discover.ask']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      // どのボタンも同じ高さ・同じ幅。
      expect(tester.getSize(find.byKey(ValueKey(k))), tester.getSize(find.byKey(const ValueKey('discover.content'))), reason: k);
    }
  });

  testWidgets('SNS の印 (D-555): Bluesky / Misskey / Mastodon はロゴ、ロゴの無い SNS は色の丸に頭文字。ログインのボタンもロゴ', (tester) async {
    expect(RasqBrandAssets.snsLogo(SnsKind.bluesky), RasqBrandAssets.snsBluesky);
    expect(RasqBrandAssets.snsLogo(SnsKind.misskey), RasqBrandAssets.snsMisskey);
    expect(RasqBrandAssets.snsLogo(SnsKind.mastodon), RasqBrandAssets.snsMastodon);
    expect(RasqBrandAssets.snsLogo(SnsKind.mixi2), isNull);
    await tester.pumpWidget(const MaterialApp(home: Row(children: [RasqSnsMark(kind: SnsKind.bluesky), RasqSnsMark(kind: SnsKind.mixi2, size: 40)])));
    expect(find.byKey(const ValueKey('sns.mark.bluesky')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('m'), findsOneWidget, reason: 'mixi2 は頭文字');

    final c = await _pump(tester, _MisskeyPlugin(), []);
    expect(c.read(routerProvider).routerDelegate.currentConfiguration.uri.path, Routes.login);
    for (final k in ['bluesky', 'misskey', 'mastodon']) {
      expect(find.byKey(ValueKey('sns.mark.$k')), findsOneWidget, reason: k);
    }
    // ロゴの画像は、パッケージの素材として読める。
    await tester.runAsync(() async {
      for (final a in [RasqBrandAssets.snsBluesky, RasqBrandAssets.snsMisskey, RasqBrandAssets.snsMastodon]) {
        final data = await rootBundle.load('packages/rasq_design/$a');
        expect(data.lengthInBytes, greaterThan(1000), reason: a);
      }
    });
  });

  test('ロゴの出典を「ライセンス」の一覧に載せる(2 度呼んでも 1 度だけ)', () async {
    registerRasqBrandLicenses();
    registerRasqBrandLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    String textOf(String name) => [
          for (final e in entries)
            if (e.packages.contains(name)) e.paragraphs.map((p) => p.text).join('\n'),
        ].single;
    expect(textOf('Misskey logo'), allOf(contains('Misskey Project'), contains('CC BY-SA'), contains('https://assets.misskey-hub.net/public/icon.png')));
    expect(textOf('Bluesky logo'), allOf(contains('Bluesky Social, PBC'), contains('Trademark and Brand Guidelines')));
    expect(textOf('Mastodon logo'), allOf(contains('Mastodon Trademark Policy'), contains('https://joinmastodon.org/ja/branding')));
  });
}
