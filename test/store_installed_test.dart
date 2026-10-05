import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/store/installed_plugins_screen.dart';
import 'package:rasq_client/features/store/plugin_page_screen.dart';
import 'package:rasq_client/features/store/store_client.dart';
import 'package:rasq_client/features/store/store_models.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_store_client.dart';
import 'support/fakes.dart';

/// インストール済みのページ (D-256): ストアの掲載とは別。掲載が消えていても開けて、削除できる。
/// Central につないでいても、同梱のサンプルのページは同梱のカタログで開ける。

/// Central 役: 何も掲載していない(どの id も 404 = null、一覧は空)。
class _EmptyCentral extends FakeStoreClient {
  @override
  Future<StoreHomeSections> home() async => (trending: const <StorePluginCard>[], recent: const <StorePluginCard>[], bookmarks: const <StorePluginCard>[]);
  @override
  Future<StorePluginDetail?> plugin(String id) async => null;
  @override
  Future<InstallManifest?> manifest(String id, {String? version}) async => null;
  @override
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId, {String? version}) async => throw StateError('404');
  @override
  Future<List<StoreReview>> reviews(String id, {ReviewSort sort = ReviewSort.helpful}) async => const [];
  @override
  Future<List<ReleaseNote>> releases(String id) async => const [];
}

void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');

  Future<ProviderContainer> pump(WidgetTester tester, StoreClient store, List<InstalledPlugin> installed) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [Post(id: 'p1', account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 19), body: 'こんにちは')]));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry), storeClientProvider.overrideWithValue(store)], child: const RasqApp()));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await c.read(settingsAreaProvider('store.installed').notifier).set('list', jsonEncode([for (final p in installed) p.toJson()]));
    c.invalidate(installedPluginsProvider);
    await tester.pumpAndSettle();
    return c;
  }

  test('写し: 掲載 → InstalledInfo → JSON の往復(権限の理由まで残る)。写しの無い古い記録も読める', () {
    const d = StorePluginDetail(id: 'x.y', name: 'X', summary: '概要', description: '説明', developerName: '開発者', safety: SafetyBlock(permissions: [PermissionEntry('network', '外部 API へ')], externalHosts: ['api.example'], dataHandling: '保存しない', usesGpu: true));
    final p = InstalledPlugin(id: 'x.y', name: 'X', version: '1.0.0', sha512: 'ab', installedAt: DateTime(2026, 9, 19), info: InstalledInfo.of(d));
    final back = InstalledPlugin.fromJson((jsonDecode(jsonEncode(p.toJson())) as Map).cast<String, Object?>());
    expect((back.info!.summary, back.info!.developerName, back.info!.safety.usesGpu), ('概要', '開発者', true));
    expect(back.info!.safety.permissions.single.reason, '外部 API へ');
    expect(back.info!.safety.externalHosts, ['api.example']);
    expect(InstalledPlugin.fromJson({'id': 'old.one', 'name': 'Old', 'version': '0.1.0', 'sha512': 'x', 'installedAt': '2026-01-01T00:00:00.000'}).info, isNull);
  });

  test('Central + 同梱カタログ: 同梱のサンプルは Central に無くてもページ / 配布物が取れる。ほかの id は Central の答えのまま', () async {
    final client = BundledFallbackStoreClient(_EmptyCentral(), FakeStoreClient());
    final sample = storeSlotSamples.first.id;
    expect((await client.plugin(sample))?.id, sample);
    expect((await client.manifest(sample))?.pluginId, sample);
    expect(await client.plugin('net.example.unknown'), isNull);
    // 一覧に足すのは、Central に掲載の無い同梱のサンプルだけ (D-443)。
    expect([for (final c in (await client.home()).recent) c.id].every(BundledFallbackStoreClient.bundledIds.contains), isTrue);
  });

  testWidgets('掲載が消えたプラグイン: ストアのページは「見つかりません」→ インストール済みのページへ → 写しの権限が見えて、削除できる', (tester) async {
    final gone = InstalledPlugin(
      id: 'net.example.gone',
      name: '消えたプラグイン',
      version: '1.2.3',
      sha512: 'a' * 128,
      installedAt: DateTime(2026, 9, 1),
      info: const InstalledInfo(summary: '便利なやつ', developerName: 'だれか', safety: SafetyBlock(permissions: [PermissionEntry('network', '外部 API へ')], externalHosts: ['api.example'])),
    );
    final c = await pump(tester, _EmptyCentral(), [gone, InstalledPlugin(id: 'old.one', name: '', version: '0.1.0', sha512: 'b' * 128, installedAt: DateTime.fromMillisecondsSinceEpoch(0))]);
    // ストアホーム: 一覧が空でも、歯車 →「プラグインを管理」(D-353)にインストール済みが並ぶ(手元の記録だけで描く)。
    c.read(routerProvider).push(Routes.store);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('store.home.manage')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('store.manage.installed.net.example.gone')), findsOneWidget);
    expect(find.byKey(const ValueKey('store.manage.installed.old.one')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('store.manage.installed.net.example.gone')), matching: find.text('だれか')), findsOneWidget);
    expect(find.byKey(const ValueKey('store.manage.version.net.example.gone')), findsOneWidget);
    expect(find.text('1.2.3'), findsOneWidget);
    // ストアのページ(掲載なし)→ 行き止まりにしない。
    c.read(routerProvider).push(Routes.storePlugin('net.example.gone'));
    await tester.pumpAndSettle();
    expect(find.byType(PluginPageScreen), findsOneWidget);
    expect(find.text('このプラグインは見つかりませんでした'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('store.plugin.openInstalled')));
    await tester.pumpAndSettle();
    expect(find.byType(InstalledPluginScreen), findsOneWidget);
    expect(find.text('消えたプラグイン'), findsOneWidget);
    expect(find.text('だれか'), findsOneWidget);
    expect(find.text('便利なやつ'), findsOneWidget);
    expect(find.byKey(const ValueKey('store.installed.unlisted')), findsOneWidget);
    expect(find.text('v1.2.3'), findsOneWidget);
    expect(find.textContaining('インストール: 2026/09/01'), findsOneWidget);
    expect(find.text('network — 外部 API へ'), findsOneWidget);
    expect(find.text('外部通信先: api.example'), findsOneWidget);
    expect(find.byKey(const ValueKey('store.installed.openStore')), findsNothing); // 掲載が無いのでストアへの口は出さない
    // 削除(確認 → 記録が消えて前のページへ)。
    await tester.ensureVisible(find.byKey(const ValueKey('store.installed.remove')));
    await tester.tap(find.byKey(const ValueKey('store.installed.remove')));
    await tester.pumpAndSettle();
    expect(find.text('削除しますか？'), findsOneWidget);
    await tester.tap(find.text('削除').last);
    await tester.pumpAndSettle();
    expect(c.read(installedPluginsProvider).map((p) => p.id), ['old.one']);
    expect(find.byType(InstalledPluginScreen), findsNothing);
    // 写しの無い古い記録でも開ける(id とバージョンだけ)。
    c.read(routerProvider).push(Routes.storeInstalledPlugin('old.one'));
    await tester.pumpAndSettle();
    expect(find.text('old.one'), findsWidgets);
    expect(find.text('v0.1.0'), findsOneWidget);
    expect(find.text('必要な権限: なし'), findsOneWidget);
  });

  testWidgets('掲載が生きているプラグイン: いまの掲載で描き、新しい版の案内とストアのページへの口が出る。一覧からも開ける', (tester) async {
    final sampleId = storeSamplePluginId;
    final c = await pump(tester, FakeStoreClient(), [InstalledPlugin(id: sampleId, name: 'Misskey コネクタ', version: '0.0.1', sha512: 'c' * 128, installedAt: DateTime(2026, 8, 1))]);
    c.read(routerProvider).push(Routes.storeInstalled);
    await tester.pumpAndSettle();
    expect(find.byType(InstalledPluginsScreen), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('store.installed.$sampleId')));
    await tester.pumpAndSettle();
    expect(find.byType(InstalledPluginScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('store.installed.unlisted')), findsNothing);
    expect(find.text('v0.0.1'), findsOneWidget);
    expect(find.byKey(const ValueKey('store.installed.update')), findsOneWidget);
    expect(find.byKey(const ValueKey('store.installed.safety')), findsOneWidget);
    // 権限の節が長いので、操作のボタンは下にある(ListView は見えるところだけ作る)。
    await tester.scrollUntilVisible(find.byKey(const ValueKey('store.installed.openStore')), 200, scrollable: find.descendant(of: find.byType(InstalledPluginScreen), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('store.installed.openStore')));
    await tester.pumpAndSettle();
    expect(find.byType(PluginPageScreen), findsOneWidget);
  });
}
