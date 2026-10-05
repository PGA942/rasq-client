import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/ads/export_ad.dart';
import 'package:rasq_client/features/ads/timeline_ads.dart';
import 'package:rasq_client/features/home/home_screen.dart';
import 'package:rasq_client/features/rai/rai_widgets.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-433: AdMob の広告の枠を、TL の投稿の間・検索ホームの固定の位置・クラウドの RAi の待ち時間にも(テストの ID)。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(int i, {String? cw, String? body, String author = 'u1'}) => Post(
        id: 'p$i',
        account: acc,
        author: UserSummary(id: author, account: acc, displayName: 'テスター'),
        createdAt: DateTime(2026, 10, 4, 12).subtract(Duration(minutes: i)),
        body: body ?? '投稿 $i',
        contentWarning: cw,
      );

  Future<ProviderContainer> pump(WidgetTester tester, {required List<Post> posts, bool adsAllowed = true, List<ServerAd> serverAds = const []}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts, ads: serverAds))),
        exportAdNetworkProvider.overrideWithValue(ExportAdNetwork.admob),
        exportAdAllowedProvider.overrideWithValue(adsAllowed),
        exportAdSdkProvider.overrideWithValue(_FakeAdSdk()),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  Future<List<String>> adKeysWhileScrolling(WidgetTester tester) async {
    final seen = <String>{};
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 12; i++) {
      for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('tl.ad.')).evaluate()) {
        seen.add((e.widget.key! as ValueKey<String>).value);
      }
      await tester.drag(list, const Offset(0, -500));
      await tester.pump();
    }
    return seen.toList()..sort();
  }

  testWidgets('TL: 10 件ごとに投稿の間に広告(最後には付けない)', (tester) async {
    await pump(tester, posts: [for (var i = 0; i < 25; i++) post(i)]);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(await adKeysWhileScrolling(tester), ['tl.ad.10', 'tl.ad.20']);
  });

  testWidgets('TL: CW のある投稿の隣には置かず、後ろへずらす', (tester) async {
    await pump(tester, posts: [for (var i = 0; i < 25; i++) post(i, cw: i == 10 ? 'ネタバレ' : null)]);
    expect(await adKeysWhileScrolling(tester), ['tl.ad.12', 'tl.ad.22']);
  });

  testWidgets('TL: 子のアカウント(広告を出せない)では出さない', (tester) async {
    await pump(tester, posts: [for (var i = 0; i < 25; i++) post(i)], adsAllowed: false);
    expect(await adKeysWhileScrolling(tester), isEmpty);
  });

  testWidgets('設定で消すと TL にも検索ホームにも出さない', (tester) async {
    final c = await pump(tester, posts: [for (var i = 0; i < 25; i++) post(i)]);
    await c.read(settingsAreaProvider('resources').notifier).set('showAds', false);
    await tester.pumpAndSettle();
    expect(await adKeysWhileScrolling(tester), isEmpty);
    c.read(routerProvider).go('/search');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search.ad')), findsNothing);
  });

  testWidgets('検索ホームの固定の位置は本物の広告の枠(前の灰色の「広告」の箱ではない)', (tester) async {
    final c = await pump(tester, posts: [post(0)]);
    c.read(routerProvider).go('/search');
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('search.ad')), matching: find.byKey(const ValueKey('fake.ad'))), findsOneWidget);
  });

  testWidgets('D-438: サーバーの広告(Misskey の meta.ads)があれば、AdMob と交互に。押すと外へ', (tester) async {
    final ad = ServerAd(id: 'm1', url: Uri.parse('https://shop.example/'), imageUrl: Uri.parse('https://misskey.test/ad.png'));
    await pump(tester, posts: [for (var i = 0; i < 35; i++) post(i)], serverAds: [ad]);
    final seen = <String, bool>{};
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 16; i++) {
      for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('tl.ad.')).evaluate()) {
        seen[(e.widget.key! as ValueKey<String>).value] = find.descendant(of: find.byWidget(e.widget), matching: find.byKey(const ValueKey('serverAd.m1'))).evaluate().isNotEmpty;
      }
      await tester.drag(list, const Offset(0, -500));
      await tester.pump();
    }
    expect(seen, {'tl.ad.10': false, 'tl.ad.20': true, 'tl.ad.30': false}, reason: '1 つ目 AdMob、2 つ目サーバーの広告、3 つ目 AdMob');
  });

  test('D-438: サーバーの広告は割合で選ぶ(同じ番目は同じ広告)', () {
    ServerAd a(String id, int ratio) => ServerAd(id: id, url: Uri.parse('https://a/'), imageUrl: Uri.parse('https://a/$id.png'), ratio: ratio);
    final ads = [a('x', 3), a('y', 1)];
    final picks = [for (var n = 0; n < 400; n++) pickServerAd(ads, n)!.id];
    expect(picks.where((p) => p == 'x').length, closeTo(300, 40));
    expect(pickServerAd(ads, 5)!.id, pickServerAd(ads, 5)!.id);
    expect(pickServerAd(const [], 0), isNull);
  });

  testWidgets('D-438: ホーム以外の TL 系(トレンド / ユーザー / リスト / クリップ / 返信)が使う共通の並び: 10 件ごと、危ない投稿の隣は避け、設定で消える', (tester) async {
    final posts = [for (var i = 0; i < 25; i++) post(i, cw: i == 10 ? 'ネタバレ' : null)];
    late WidgetRef captured;
    Widget app() => ProviderScope(
          overrides: [
            sessionStorageProvider.overrideWithValue(MemorySessionStorage()),
            exportAdNetworkProvider.overrideWithValue(ExportAdNetwork.admob),
            exportAdAllowedProvider.overrideWithValue(true),
            exportAdSdkProvider.overrideWithValue(_FakeAdSdk()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(builder: (context, ref, _) {
                captured = ref;
                return ListView(children: withTimelineAds(ref, posts, scope: 'x', [for (final p in posts) SizedBox(key: ValueKey('row.${p.id}'), height: 10)]));
              }),
            ),
          ),
        );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final keys = [for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('x.ad.')).evaluate()) (e.widget.key! as ValueKey<String>).value];
    expect(keys, ['x.ad.12', 'x.ad.22']);
    await captured.read(settingsAreaProvider('resources').notifier).set('showAds', false);
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is TimelineAdSlot), findsNothing);
  });

  testWidgets('クラウドの RAi の入力: 考えている間だけ広告', (tester) async {
    final input = TextEditingController(text: '猫');
    addTearDown(input.dispose);
    Widget bar(bool busy) => ProviderScope(
          overrides: [
            exportAdNetworkProvider.overrideWithValue(ExportAdNetwork.admob),
            exportAdAllowedProvider.overrideWithValue(true),
            exportAdSdkProvider.overrideWithValue(_FakeAdSdk()),
          ],
          child: MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 400, child: RaiPromptBar(controller: input, onSubmit: () {}, modelLabel: 'クラウド版 RAi', busy: busy))))),
        );
    await tester.pumpWidget(bar(false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.prompt.ad')), findsNothing);
    await tester.pumpWidget(bar(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.descendant(of: find.byKey(const ValueKey('rai.prompt.ad')), matching: find.byKey(const ValueKey('fake.ad'))), findsOneWidget);
  });
}

class _FakeAdSdk implements ExportAdSdk {
  @override
  Widget buildAd({required ExportAdNetwork network, required ExportAdConfig config, required double width, required VoidCallback onLoaded, required VoidCallback onFailed}) {
    Future.microtask(onLoaded);
    return SizedBox(key: const ValueKey('fake.ad'), width: width, height: 60, child: const ColoredBox(color: Colors.grey));
  }
}
