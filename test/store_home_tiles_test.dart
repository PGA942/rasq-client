import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/store/store_client.dart';
import 'package:rasq_client/features/store/store_models.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/features/store/store_tile.dart';
import 'package:rasq_client/features/store/installed_plugins_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// ストアホームのタイル / 除外 / プラグインを管理 (D-353)。
void main() {
  test('カード: developerName / previews を読む。詳細はプレビューが無ければスクリーンショットの先頭 4 枚', () {
    final c = StorePluginCard.fromJson({'id': 'a', 'name': 'A', 'version': '1', 'status': 'published', 'developerName': '作者', 'previews': ['https://x/1.png', 'https://x/2.png']});
    expect((c.developerName, c.tilePreviews.length), ('作者', 2));
    final d = StorePluginDetail.fromJson({'id': 'b', 'name': 'B', 'version': '1', 'status': 'published', 'developer': {'name': '開発元'}, 'screenshots': [for (var i = 0; i < 6; i++) 'https://x/$i.png']});
    expect((d.developerName, d.tilePreviews.length), ('開発元', 4));
    expect(StorePluginCard.fromJson({'id': 'a', 'name': 'A', 'version': '1', 'status': 'published', 'pluginType': 'composer'}).pluginType, StorePluginType.composer);
    expect(StorePluginCard.fromJson({'id': 'a', 'name': 'A', 'version': '1', 'status': 'published', 'pluginType': '???'}).pluginType, StorePluginType.other);
  });

  test('タイルの色 (D-354): 種別ごと。背景にごく薄く重ねる(明るいテーマではほぼ白、暗いテーマでは暗いまま)', () {
    final light = ColorScheme.fromSeed(seedColor: Colors.blue);
    final dark = ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark);
    expect(storeTileColor(StorePluginType.sns, light), isNot(storeTileColor(StorePluginType.theme, light)));
    expect(HSLColor.fromColor(storeTileColor(StorePluginType.sns, light)).lightness, greaterThan(0.93));
    expect(HSLColor.fromColor(storeTileColor(StorePluginType.sns, dark)).lightness, lessThan(0.3));
  });

  test('タイルのボタン (D-354): 入手 / 金額 / 更新 / 開く / 停止中', () {
    const free = StorePluginCard(id: 'a', name: 'A', version: '1.1.0');
    expect(storeTileActionOf(free, null), StoreTileAction.get);
    expect(storeTileActionOf(const StorePluginCard(id: 'a', name: 'A', version: '1.0.0', price: 300), null), StoreTileAction.buy);
    expect(storeTileActionOf(free, '1.0.0'), StoreTileAction.update);
    expect(storeTileActionOf(free, '1.1.0'), StoreTileAction.open);
    expect(storeTileActionOf(const StorePluginCard(id: 'a', name: 'A', version: '1', status: PluginStatus.suspended), null), StoreTileAction.unavailable);
    expect(storeTileActionOf(const StorePluginCard(id: 'a', name: 'A', version: '1', status: PluginStatus.warning), null), StoreTileAction.get); // 警告は明示の上で入れられる
  });

  Future<ProviderContainer> pump(WidgetTester tester, List<InstalledPlugin> installed) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        storeClientProvider.overrideWithValue(MockStoreClient()),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await c.read(settingsAreaProvider('store.installed').notifier).set('list', jsonEncode([for (final p in installed) p.toJson()]));
    c.invalidate(installedPluginsProvider);
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('インストール済みはホームの列に出さない → 管理ページの「インストール済みもホームに出す」で出る。更新があればチップ', (tester) async {
    final misskey = InstalledPlugin(id: storeSamplePluginId, name: 'Misskey コネクタ', version: '0.4.0', sha512: 'a' * 128, installedAt: DateTime(2026, 9, 1));
    final c = await pump(tester, [misskey]);
    c.read(routerProvider).push(Routes.store);
    await tester.pumpAndSettle();
    final trending = find.byKey(const ValueKey('store.home.trending'));
    expect(find.descendant(of: trending, matching: find.byKey(const ValueKey('store.tile.$storeSamplePluginId'))), findsNothing);
    expect(find.descendant(of: trending, matching: find.byKey(const ValueKey('store.tile.net.example.siglip-reco'))), findsOneWidget);

    // 歯車 → プラグインを管理。
    await tester.tap(find.byKey(const ValueKey('store.home.manage')));
    await tester.pumpAndSettle();
    expect(find.text('プラグインを管理'), findsWidgets);
    expect(find.byKey(const ValueKey('store.manage.installed.$storeSamplePluginId')), findsOneWidget);
    expect(find.text('0.4.0'), findsOneWidget); // デプロイしたバージョン(いま入っている版)
    expect(find.text('0.5.0 に更新'), findsOneWidget); // ストアに新しい版
    expect(find.byKey(const ValueKey('store.manage.import')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('store.manage.showInstalled')));
    await tester.pumpAndSettle();
    // 戻ると、ホームの列にも出る(ストアに新しい版があるので「更新」)。
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    final tile = find.descendant(of: trending, matching: find.byKey(const ValueKey('store.tile.$storeSamplePluginId')));
    expect(tile, findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('store.tile.action.$storeSamplePluginId')), matching: find.text('更新')), findsOneWidget);
    // 更新チップ → その場で確認シート(D-355: ストアのページへは飛ばない)。
    c.read(routerProvider).push(Routes.storeManage);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('store.manage.update.$storeSamplePluginId')));
    await tester.pumpAndSettle();
    expect(find.text('このプラグインが使う権限'), findsOneWidget);
    expect(find.textContaining('0.5.0 をインストール'), findsOneWidget);
  });

  testWidgets('タイルの「入手」: 確認シート → 検証 → インストール。入ったら「開く」→ インストール済みのページ', (tester) async {
    final c = await pump(tester, const []);
    c.read(routerProvider).push(Routes.store);
    await tester.pumpAndSettle();
    const id = 'net.example.siglip-reco';
    final action = find.byKey(const ValueKey('store.tile.action.$id'));
    expect(action, findsOneWidget); // 今週のトレンドの 2 番目
    expect(find.descendant(of: action, matching: find.text('入手')), findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('このプラグインが使う権限'), findsOneWidget);
    await tester.tap(find.text('インストールする'));
    await tester.pumpAndSettle();
    expect(c.read(installedPluginsProvider).map((p) => p.id), contains(id));
    // 既定ではインストール済みはホームから消える → 検索画面のタイルは「開く」。
    c.read(routerProvider).push(Routes.storeSearch('SigLIP'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('store.tile.action.$id')), matching: find.text('開く')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('store.tile.action.$id')));
    await tester.pumpAndSettle();
    expect(find.byType(InstalledPluginScreen), findsOneWidget);
  });
}
