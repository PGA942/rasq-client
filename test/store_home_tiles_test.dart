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
    // 色は id から決まる(同じプラグインはいつも同じ)明るい色。
    expect(storeTileColor('a'), storeTileColor('a'));
    expect(HSLColor.fromColor(storeTileColor('net.example.x')).lightness, greaterThan(0.8));
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
    // 戻ると、ホームの列にも出る(印つき)。
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    final tile = find.descendant(of: trending, matching: find.byKey(const ValueKey('store.tile.$storeSamplePluginId')));
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('インストール済み')), findsOneWidget);
    // 更新チップ → ストアのページ。
    c.read(routerProvider).push(Routes.storeManage);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('store.manage.update.$storeSamplePluginId')));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation, Routes.storePlugin(storeSamplePluginId));
  });
}
