// rasq-central のホームページ (S-095) の「実機っぽいプレビュー」に貼る、アプリの画面のスクリーンショット。
// 390×844 論理 px(2 倍 = 780×1688)で、ホームのタイムライン / ASTell のホーム / RASQ アカウントページ / オンボーディングを PNG に出す。
// 実行(WebP への変換と置き場までまとめて)は tool/preview/homeshots.sh。手で回すなら:
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf flutter test tool/preview/homeshots_test.dart --update-goldens
// → tool/preview/home_*.png(git には入れない。成果物は rasq-central の src/web/home/*.webp)。
// ほかのプレビュー (vc_preview_test.dart など) と同じく、フォント未指定ならスキップ。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/notify/local_notifier.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../test/support/fakes.dart';

void main() {
  final fontPath = Platform.environment['RASQ_PREVIEW_FONT'];
  if (fontPath == null || !File(fontPath).existsSync()) {
    test('preview harness needs RASQ_PREVIEW_FONT', () {}, skip: 'RASQ_PREVIEW_FONT を日本語フォント(.ttf)へ向けると PNG を出す');
    return;
  }
  setUpAll(() async {
    final bytes = File(fontPath).readAsBytesSync();
    // FlutterTest = flutter_test の既定のフォント(テーマを通らない文字はここへ落ちる)。
    for (final family in ['Roboto', 'NotoSansJP', '.SF UI Text', '.SF UI Display', 'FlutterTest']) {
      final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
    // アイコン: テストの既定ではアイコンのフォントが無く □ になるので、Flutter SDK の控え(bin/cache)から Material Icons を読む。
    // RASQ_PREVIEW_ICONS で別の .otf を指せる。見つからなければ □ のまま(失敗にはしない)。
    const inSdk = 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    var icons = Platform.environment['RASQ_PREVIEW_ICONS'] ?? '${Platform.environment['FLUTTER_ROOT'] ?? ''}/$inSdk';
    // テストは flutter_tester(bin/cache/artifacts/engine/…)で動くので、そこから上へ SDK の根を探す。
    for (var d = File(Platform.resolvedExecutable).parent; !File(icons).existsSync() && d.path != d.parent.path; d = d.parent) {
      icons = '${d.path}/$inSdk';
    }
    if (File(icons).existsSync()) {
      final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(File(icons).readAsBytesSync().buffer)));
      await loader.load();
    } else {
      // ignore: avoid_print
      print('homeshots: Material Icons のフォントが見つかりません ($icons)。アイコンは □ になります');
    }
  });

  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

  /// 画面の大きさ: 390×844 論理 px(iPhone 14 相当)の 2 倍。ホームページの端末の画面に貼るテクスチャの大きさ。
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  final loggedIn = MemorySessionStorage({
    SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
  });

  /// SNS のタイムラインの見本 (MockData) でログイン中。Central には繋がない(ASTell はモックのルーム)。
  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    phone(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(loggedIn),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        localNotifierProvider.overrideWithValue(MemoryLocalNotifier()),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  testWidgets('home timeline', (tester) async {
    await pumpApp(tester);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_timeline.png'));
  });

  testWidgets('astell home', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('ASTell'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_astell.png'));
  });

  testWidgets('rasq account page', (tester) async {
    phone(tester);
    const author = {'id': 'acc-1', 'handle': 'hana', 'displayName': 'はな'};
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      switch ('${req.method} $path') {
        case 'GET /accounts/hana':
          return json({
            'id': 'acc-1', 'handle': 'hana', 'displayName': 'はな', 'bio': '写真と宇宙の話をします。ASTell で夜の雑談もやっています。', 'location': '東京', 'birthday': '', 'createdAt': '2026-09-01T00:00:00Z',
            'links': [{'label': 'サイト', 'url': 'https://example.com/'}],
            'snsAccounts': [
              {'accountKey': 'misskey:misskey.io:hana', 'kind': 'misskey', 'instance': 'misskey.io', 'handle': 'hana', 'displayName': 'はな', 'serverName': 'Misskey.io', 'visibility': 'auto', 'autoVisible': true, 'visible': true},
              {'accountKey': 'mastodon:mastodon.social:hana', 'kind': 'mastodon', 'instance': 'mastodon.social', 'handle': 'hana', 'displayName': 'hana', 'serverName': 'Mastodon', 'visibility': 'auto', 'autoVisible': true, 'visible': true},
            ],
            'plugins': <Object>[],
            'reviews': <Object>[],
          });
        case 'GET /accounts/hana/posts':
          return json({
            'source': 'rasq', 'limit': 3,
            'posts': [
              {'id': 'p1', 'author': author, 'body': '今夜 21 時から ASTell で「夜の雑談」をやります。写真の話をゆるく。', 'images': <Object>[], 'createdAt': '2026-10-09T12:00:00Z', 'replyCount': 3, 'rebroadCount': 2, 'rebroaded': false, 'queues': <Object>[]},
              {'id': 'p2', 'author': author, 'body': 'ロケットの打ち上げ、無事に成功しました。おめでとうございます！ #打上会', 'images': <Object>[], 'createdAt': '2026-10-08T09:30:00Z', 'replyCount': 1, 'rebroadCount': 5, 'rebroaded': false, 'queues': <Object>[]},
              {'id': 'p3', 'author': author, 'body': 'RASQ アカウントを作りました。SNS のアカウントを束ねて使っています。', 'images': <Object>[], 'createdAt': '2026-09-01T00:00:00Z', 'replyCount': 0, 'rebroadCount': 0, 'rebroaded': false, 'queues': <Object>[]},
            ],
          });
        case 'GET /accounts/hana/rasq-collections':
          return json(<Object>[]);
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(loggedIn),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        localNotifierProvider.overrideWithValue(MemoryLocalNotifier()),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).push(Routes.rasqAccount('hana'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_account.png'));
  });

  testWidgets('onboarding (register)', (tester) async {
    phone(tester);
    // サーバーのタイル (D-412) の情報だけ Central の口をまねる(plugin_preview_test の onboarding_wide と同じ)。
    final central = MockClient((req) async => switch (req.url.path) {
          '/api/v1/servers/misskey.io/info' => json({'host': 'misskey.io', 'software': 'misskey', 'version': '2025.4.1', 'name': 'Misskey.io', 'description': 'Misskey.io は、地球で生まれた分散マイクロブログ SNS です。', 'themeColor': '#86b300', 'users': 520000, 'posts': 210000000, 'registrationOpen': true}),
          '/api/v1/servers/mastodon.social/info' => json({'host': 'mastodon.social', 'software': 'mastodon', 'version': '4.8.0', 'name': 'Mastodon', 'description': 'The original server of Mastodon.', 'themeColor': '#6364ff', 'users': 3100000, 'registrationOpen': true}),
          _ => json({'error': {'code': '404', 'message': 'not found'}}, 404),
        });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []))),
        localNotifierProvider.overrideWithValue(MemoryLocalNotifier()),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: central)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_onboarding.png'));
  });
}
