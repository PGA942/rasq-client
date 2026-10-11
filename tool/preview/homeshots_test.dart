// rasq-central のホームページ (S-095 / S-096 / S-098) の「実機っぽいプレビュー」に貼る、アプリの画面のスクリーンショット。
// ホームページには スマホ / タブレット の 2 つのプレビューがあり (S-098)、節ごとに両方の画面を持つ:
//
//   | 節 | スマホ(縦、390×844 論理 px の 2 倍 = 780×1688) | タブレット |
//   |---|---|---|
//   | はじめ | home_onboarding.png | 横向き(1280×800 の 1.5 倍 = 1920×1200): home_onboarding_wide.png(2 カラム、D-405) |
//   | RASQ Web クライアント | home_timeline.png(ホームのタイムライン) | 横向き: home_client.png(レール + 2 カラムのホーム) |
//   | RASQ アカウント・QuickView | home_account.png | 縦向き(800×1280 の 1.5 倍 = 1200×1920、1 カラム): home_account_tall.png |
//   | ASTell | home_astell_listen.png(ルームで聞いているところ) | 縦向き: home_astell_listen_tall.png |
//
// タブレットの縦向きは幅 800 論理 px(< RasqSizes.tabletBreakpoint = 840)なので、アプリはスマホと同じ 1 カラムで描く。
// ホームページは画像の比率で端末(長辺 / 短辺 が 2 以上ならスマホ、それ未満ならタブレット)と向きを決める (S-096)。
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
import 'package:rasq_client/features/vc/astell_providers.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/notify/local_notifier.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../test/support/fakes.dart';

/// 端末の画面の大きさ(物理 px と倍率)。ホームページの端末の画面に貼るテクスチャの大きさになる。
enum HomeView {
  /// スマホの縦: 390×844 論理 px(iPhone 14 相当)の 2 倍。
  phone(780, 1688, 2),

  /// タブレットの横向き: 1280×800 論理 px(16:10)の 1.5 倍。レール + 2 カラム。
  tabletWide(1920, 1200, 1.5),

  /// タブレットの縦向き: 800×1280 論理 px(10:16)の 1.5 倍。幅が 840 未満なので 1 カラム。
  tabletTall(1200, 1920, 1.5);

  const HomeView(this.width, this.height, this.dpr);
  final double width;
  final double height;
  final double dpr;

  void apply(WidgetTester tester) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
  }
}

void main() {
  final fontPath = Platform.environment['RASQ_PREVIEW_FONT'];
  if (fontPath == null || !File(fontPath).existsSync()) {
    test('preview harness needs RASQ_PREVIEW_FONT', () {}, skip: 'RASQ_PREVIEW_FONT を日本語フォント(.ttf)へ向けると PNG を出す');
    return;
  }
  setUpAll(() async {
    final bytes = File(fontPath).readAsBytesSync();
    // FlutterTest = flutter_test の既定のフォント(テーマを通らない文字はここへ落ちる)。
    // fontFamily の無い文字は、ここで登録した名前では探されずエンジンのテストのフォントに落ちて □ になる(D-458 で
    // FilledButton / OutlinedButton の文言がそうだった → rasq_design のテーマ側で labelLarge と同じ名前を付けた)。
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

  final loggedIn = MemorySessionStorage({
    SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
  });

  /// SNS のタイムラインの見本 (MockData) でログイン中。Central には繋がない(ASTell はモックのルーム)。
  Future<ProviderContainer> pumpApp(WidgetTester tester, HomeView view) async {
    view.apply(tester);
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

  /// ASTell のルーム「打ち上げの打ち上げ」(モック、ダグラスが話していて TiVard が画面を共有中)に入って**聞いている**ところ:
  /// ルーム FOW(共有欄 / 参加メンバー / 字幕の文字起こし / 下段のマイク(オフ)・画面・字幕・共有)。ホームページの ASTell の節。
  Future<void> pumpListening(WidgetTester tester, HomeView view) async {
    final c = await pumpApp(tester, view);
    final room = (await c.read(astellClientProvider).room('r-launch'))!;
    await c.read(astellSessionProvider.notifier).join(room);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ASTell'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('参加中: '));
    await tester.pumpAndSettle();
  }

  /// RASQ アカウントページ(はな @hana、Central の口をまねる)。ホームページの RASQ アカウント・QuickView の節。
  Future<void> pumpAccount(WidgetTester tester, HomeView view) async {
    view.apply(tester);
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
  }

  /// 最初のオンボーディング(登録)。サーバーのタイル (D-412) の情報だけ Central の口をまねる
  /// (plugin_preview_test の onboarding_wide と同じ)。ホームページの はじめ の節。
  Future<void> pumpOnboarding(WidgetTester tester, HomeView view) async {
    view.apply(tester);
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
  }

  // ── はじめ ──
  testWidgets('onboarding (phone)', (tester) async {
    await pumpOnboarding(tester, HomeView.phone);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_onboarding.png'));
  });

  testWidgets('onboarding (tablet, landscape)', (tester) async {
    await pumpOnboarding(tester, HomeView.tabletWide);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_onboarding_wide.png'));
  });

  // ── RASQ Web クライアント ──
  testWidgets('home timeline (phone)', (tester) async {
    await pumpApp(tester, HomeView.phone);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_timeline.png'));
  });

  testWidgets('web client (tablet, landscape)', (tester) async {
    await pumpApp(tester, HomeView.tabletWide);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_client.png'));
  });

  // ── RASQ アカウント・QuickView ──
  testWidgets('rasq account page (phone)', (tester) async {
    await pumpAccount(tester, HomeView.phone);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_account.png'));
  });

  testWidgets('rasq account page (tablet, portrait)', (tester) async {
    await pumpAccount(tester, HomeView.tabletTall);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_account_tall.png'));
  });

  // ── ASTell ──
  testWidgets('astell listening in a room (phone)', (tester) async {
    await pumpListening(tester, HomeView.phone);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_astell_listen.png'));
  });

  testWidgets('astell listening in a room (tablet, portrait)', (tester) async {
    await pumpListening(tester, HomeView.tabletTall);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_astell_listen_tall.png'));
  });
}
