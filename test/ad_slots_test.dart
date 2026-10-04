import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/ads/export_ad.dart';
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
  Post post(int i, {String? cw}) => Post(
        id: 'p$i',
        account: acc,
        author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'),
        createdAt: DateTime(2026, 10, 4, 12).subtract(Duration(minutes: i)),
        body: '投稿 $i',
        contentWarning: cw,
      );

  Future<ProviderContainer> pump(WidgetTester tester, {required List<Post> posts, bool adsAllowed = true}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts))),
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
