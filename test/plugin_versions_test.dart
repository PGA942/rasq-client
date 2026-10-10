import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart' show OrgateException;
import 'package:rasq_client/backend/payments_api.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/store/plugin_scope.dart';
import 'package:rasq_client/features/store/plugin_updates.dart';
import 'package:rasq_client/features/store/rasqpkg.dart';
import 'package:rasq_client/features/store/store_client.dart';
import 'package:rasq_client/features/store/store_install.dart' show showPurchaseSheet;
import 'package:rasq_client/features/store/store_models.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart' show RasqListTile;
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_store_client.dart';
import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// アカウントごとのバージョン (D-355)、アップデートの設定 / 更新ログ (D-356)、ポイントで購入 (D-355)。

/// ストア役: `sample.timeline` に 0.1.0 と 0.2.0(現在版)。配布物は版ごとに違う「wasm」(先頭がマジック)。
class _TwoVersionStore extends FakeStoreClient {
  _TwoVersionStore({this.latestAddsPermission = false, this.releasesFail = false, this.current = '0.2.0'});
  final bool latestAddsPermission;

  /// リリース情報が取れない(TERMS-09)。
  final bool releasesFail;

  /// ストアの現在版(REC-10: 入っているより古いこともある)。
  final String current;
  static const id = 'sample.timeline';
  static Uint8List bytesOf(String v) => Uint8List.fromList([0x00, 0x61, 0x73, 0x6d, 1, 0, 0, 0, ...utf8.encode(v)]);

  @override
  Future<StorePluginDetail?> plugin(String pluginId) async =>
      pluginId == id ? StorePluginDetail(id: id, name: 'Unicode 昇順 TL', version: current, pluginType: StorePluginType.timeline) : super.plugin(pluginId);
  @override
  Future<List<ReleaseNote>> releases(String pluginId) async => releasesFail && pluginId == id
      ? throw StateError('offline')
      : pluginId == id
      ? [
          ReleaseNote(version: '0.2.0', notes: '並べ方を変えました', permissionsAdded: latestAddsPermission ? const [PermissionEntry('network', '外へ')] : const [], publishedAt: DateTime(2026, 9, 20)),
          ReleaseNote(version: '0.1.0', notes: '最初の版', publishedAt: DateTime(2026, 9, 1)),
        ]
      : super.releases(pluginId);
  @override
  Future<InstallManifest?> manifest(String pluginId, {String? version}) async {
    if (pluginId != id) return super.manifest(pluginId, version: version);
    final v = version ?? '0.2.0';
    final b = bytesOf(v);
    // 権限が増える版は、構成(マニフェスト)そのものに network と接続先が載る。
    final adds = latestAddsPermission && v == '0.2.0';
    return InstallManifest(pluginId: id, version: v, manifest: {'id': id, 'name': 'Unicode 昇順 TL', 'kind': 'view', if (adds) 'permissions': const ['network'], if (adds) 'network': const {'hosts': ['api.example.com']}}, artifacts: [StoreArtifact(id: 'bundle', sizeBytes: b.length, sha512: sha512.convert(b).toString())]);
  }
  @override
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId, {String? version}) async => pluginId == id ? bytesOf(version ?? '0.2.0') : super.downloadArtifact(pluginId, artifactId, version: version);
}

void main() {
  final second = AccountSession(account: const AccountId(kind: SnsKind.misskey, instance: 'other.test', handle: 'hanako'), pluginId: 'test.fake', token: 't2', createdAt: DateTime(2026, 9, 1), displayName: 'ハナコ');

  test('登録元 / 版の選び方 / 記録の JSON', () {
    expect(storeSlotSource('a.b', '1.0.0'), 'store:a.b@1.0.0');
    expect(storeSlotSource('a.b', '1.0.0', child: 'a.b.c'), 'store:a.b@1.0.0#a.b.c');
    expect(parseStoreSlotSource('store:a.b@1.0.0#a.b.c'), (pluginId: 'a.b', version: '1.0.0', child: 'a.b.c'));
    expect(parseStoreSlotSource('store:a.b'), (pluginId: 'a.b', version: null, child: null)); // 古い形
    expect(parseStoreSlotSource('/tmp/x.wasm'), isNull);

    final p = InstalledPlugin(
      id: 'a.b',
      name: 'A',
      version: '2.0.0',
      sha512: 'x',
      installedAt: DateTime(2026, 9, 1),
      versions: [InstalledVersion(version: '2.0.0', sha512: 'x', installedAt: DateTime(2026, 9, 2)), InstalledVersion(version: '1.0.0', sha512: 'y', installedAt: DateTime(2026, 9, 1), channel: 'beta')],
      accountVersions: const {'misskey:other.test:hanako': '1.0.0'},
      pluginType: StorePluginType.composer,
    );
    final back = InstalledPlugin.fromJson((jsonDecode(jsonEncode(p.toJson())) as Map).cast<String, Object?>());
    expect((back.versionFor('misskey:other.test:hanako'), back.versionFor('misskey:example.test:tester'), back.pluginType), ('1.0.0', '2.0.0', StorePluginType.composer));
    expect(back.usedVersions, {'2.0.0', '1.0.0'});
    expect(back.versionInfo('1.0.0')!.isPreview, isTrue);
    // 古い記録(版の一覧なし)は既定の版 1 つ。
    final old = InstalledPlugin.fromJson({'id': 'o', 'name': 'O', 'version': '0.1.0', 'sha512': 'z', 'installedAt': '2026-01-01T00:00:00.000'});
    expect(old.allVersions.single.version, '0.1.0');
  });

  ProviderContainer container(StoreClient store, SlotRuntimeLoader loader) {
    TestWidgetsFlutterBinding.ensureInitialized();
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson(), second.toJson()], 'current': fakeSession().account.key}),
    });
    final c = ProviderContainer(overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
      storeClientProvider.overrideWithValue(store),
      slotRuntimeLoaderProvider.overrideWithValue(loader),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  /// 版ごとの偽ランタイム: tl.sort は並べ方で版が分かる(0.1.0 = そのまま、0.2.0 = 逆順)。
  SlotRuntimeLoader loader() => fakeSlotLoader({
        for (final v in ['0.1.0', '0.2.0'])
          'store:sample.timeline@$v': () => FakeSlotRuntime(
                manifest: {'id': 'sample.timeline', 'name': 'Unicode 昇順 TL', 'version': v, 'kind': 'view', 'slots': ['tl']},
                handler: (_, fn, args) {
                  if (fn == 'tl.timelines') return {'timelines': [{'id': 'u', 'label': 'U'}]};
                  if (fn == 'tl.sort') {
                    final ids = [for (final p in args['posts']! as List) (p as Map)['id'] as String];
                    return {'order': v == '0.2.0' ? ids.reversed.toList() : ids};
                  }
                  return null;
                },
              ),
      });

  test('アカウントごとの版: 並べて入れる → アカウントに版を指定 → そのアカウントの並べ替えはその版 → 既定を切り替えると使わない版は外れる', () async {
    final c = container(_TwoVersionStore(), loader());
    final store = c.read(installedPluginsProvider.notifier);
    await c.read(settingsAreaProvider('store.installed').future);
    expect((await store.install('sample.timeline', version: '0.1.0')).error, isNull);
    expect(c.read(slotPluginsProvider).map((p) => p.source), ['store:sample.timeline@0.1.0']);
    // 新しい版を「入れるだけ」: 既定は 0.1.0 のまま、登録もしない。
    expect((await store.install('sample.timeline', activate: false)).error, isNull);
    var rec = c.read(installedPluginsProvider).single;
    expect(rec.version, '0.1.0');
    expect([for (final v in rec.allVersions) v.version], ['0.2.0', '0.1.0']);
    expect(c.read(slotPluginsProvider).length, 1);
    // ハナコだけ 0.2.0 → 両方の版が動く。並べ替えはアカウントの版で。
    expect(await store.setAccountVersion('sample.timeline', second.account.key, '0.2.0'), isNull);
    expect(c.read(slotPluginsProvider).map((p) => p.storeVersion).toSet(), {'0.1.0', '0.2.0'});
    final slots = c.read(slotPluginsProvider.notifier);
    expect(slots.active(accountKey: fakeSession().account.key).single.storeVersion, '0.1.0');
    expect(slots.active(accountKey: second.account.key).single.storeVersion, '0.2.0');
    final posts = [for (final id in ['p1', 'p2', 'p3']) Post(id: id, account: fakeSession().account, author: UserSummary(id: 'u', account: fakeSession().account, displayName: 'u'), createdAt: DateTime(2026, 9, 27), body: id)];
    expect([for (final p in await slots.sortById('slot:sample.timeline:u', posts, accountKey: fakeSession().account.key)) p.id], ['p1', 'p2', 'p3']);
    expect([for (final p in await slots.sortById('slot:sample.timeline:u', posts, accountKey: second.account.key)) p.id], ['p3', 'p2', 'p1']);
    // 使っている版は消せない。
    expect(await store.removeVersion('sample.timeline', '0.2.0'), contains('使われています'));
    // 既定を 0.2.0 に: 0.1.0 はどのアカウントも使わない → 登録を外す → 消せる。
    expect(await store.setDefaultVersion('sample.timeline', '0.2.0'), isNull);
    expect(c.read(slotPluginsProvider).map((p) => p.storeVersion), ['0.2.0']);
    expect(await store.removeVersion('sample.timeline', '0.1.0'), isNull);
    rec = c.read(installedPluginsProvider).single;
    expect([for (final v in rec.allVersions) v.version], ['0.2.0']);
    // 再起動: 版つきの登録元は、その版を取り直して読み込む。
    final persisted = await c.read(sessionStorageProvider).read(slotPluginsStorageKey);
    expect(jsonDecode(persisted!), ['store:sample.timeline@0.2.0']);
  });

  test('アップデートの設定: インストールだけ = 入れて控える / おまかせ = 既定に / 権限が増える版は入れない。更新ログに残る', () async {
    final c = container(_TwoVersionStore(), loader());
    final store = c.read(installedPluginsProvider.notifier);
    await c.read(settingsAreaProvider('store.installed').future);
    await store.install('sample.timeline', version: '0.1.0');
    // 既定 = インストールだけおまかせ。
    var log = await runPluginUpdates(c);
    expect(log.single.result, 'installed');
    var rec = c.read(installedPluginsProvider).single;
    expect((rec.version, rec.versionInfo('0.2.0') != null), ('0.1.0', true));
    // おまかせにすると、入っていた 0.2.0 を既定に切り替える。
    await c.read(settingsAreaProvider(pluginUpdateArea).notifier).set('mode.action', 'auto');
    log = await runPluginUpdates(c);
    expect(log.single.result, 'switched');
    rec = c.read(installedPluginsProvider).single;
    expect(rec.version, '0.2.0');
    expect(c.read(pluginUpdateLogProvider).map((e) => e.result), ['switched', 'installed']);

    // 権限が増える版: どのモードでも入れない(理由つき)。
    final c2 = container(_TwoVersionStore(latestAddsPermission: true), loader());
    await c2.read(settingsAreaProvider('store.installed').future);
    await c2.read(installedPluginsProvider.notifier).install('sample.timeline', version: '0.1.0', consent: const PluginConsent());
    await c2.read(settingsAreaProvider(pluginUpdateArea).notifier).set('mode.action', 'auto');
    final skipped = await runPluginUpdates(c2);
    expect(skipped.single.result, 'skipped');
    expect(skipped.single.note, allOf(contains('権限 network'), contains('接続先 api.example.com')));
    expect(c2.read(installedPluginsProvider).single.version, '0.1.0');
    expect(c2.read(installedPluginsProvider).single.versionInfo('0.2.0'), isNull, reason: '広がる版は保存もしない');
    // 全て手動: 何もしない。
    await c2.read(settingsAreaProvider(pluginUpdateArea).notifier).set('mode.action', 'manual');
    expect(await runPluginUpdates(c2), isEmpty);
  });

  test('TERMS-09 / REC-10: 判断は配布物の中身(リリース情報が取れなくても広がる版は入れない)/ ストアの版が古ければ更新しない(下げない)', () async {
    // リリース情報(サーバーの差分)が取れなくても、選んだ版の構成と最後の承認を比べる(セキュリティ確認 2026-10-09 の [8])。
    final c = container(_TwoVersionStore(releasesFail: true, latestAddsPermission: true), loader());
    await c.read(settingsAreaProvider('store.installed').future);
    await c.read(installedPluginsProvider.notifier).install('sample.timeline', version: '0.1.0', consent: const PluginConsent());
    await c.read(settingsAreaProvider(pluginUpdateArea).notifier).set('mode.action', 'auto');
    final log = await runPluginUpdates(c);
    expect(log.single.result, 'skipped');
    expect(log.single.note, contains('権限 network'));
    expect(c.read(installedPluginsProvider).single.version, '0.1.0');
    // 広がらない版なら、リリース情報が取れなくても入れる。
    final c1 = container(_TwoVersionStore(releasesFail: true), loader());
    await c1.read(settingsAreaProvider('store.installed').future);
    await c1.read(installedPluginsProvider.notifier).install('sample.timeline', version: '0.1.0', consent: const PluginConsent());
    await c1.read(settingsAreaProvider(pluginUpdateArea).notifier).set('mode.action', 'auto');
    expect((await runPluginUpdates(c1)).single.result, 'activated');

    // 入っている 0.2.0 より、ストアの現在版 0.1.0 のほうが古い: 何もしない。
    final c2 = container(_TwoVersionStore(current: '0.1.0'), loader());
    await c2.read(settingsAreaProvider('store.installed').future);
    await c2.read(installedPluginsProvider.notifier).install('sample.timeline', version: '0.2.0');
    await c2.read(settingsAreaProvider(pluginUpdateArea).notifier).set('mode.action', 'auto');
    expect(await runPluginUpdates(c2), isEmpty);
    expect(c2.read(installedPluginsProvider).single.version, '0.2.0');
  });

  testWidgets('有料のプラグイン: タイルの金額 → 購入シート(残高 / 失効)→ 購入 → 確認シート → インストール。残高が減る', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final store = FakeStoreClient();
    final storage = MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})});
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
      storeClientProvider.overrideWithValue(store),
      // 有料の機能が使える構成(ORGATE_PAID_FEATURES=on、D-401)。
      paymentsConfigProvider.overrideWith((ref) async => const PaymentsConfig(paidFeatures: true, stripeMode: 'dummy', pointsAvailable: true)),
    ], child: const RasqApp()));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).push(Routes.storeSearch('プロ向け'));
    await tester.pumpAndSettle();
    const id = 'net.example.pro-cards';
    final action = find.byKey(const ValueKey('store.tile.action.$id'));
    expect(find.descendant(of: action, matching: find.text('¥300')), findsOneWidget);
    // 買う前は、構成も配布物も出ない。
    await expectLater(store.manifest(id), throwsA(isA<Object>()));
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('store.purchase.price')), findsOneWidget);
    expect(find.textContaining('残り 1000 ポイント'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('store.purchase.buy')));
    await tester.pumpAndSettle();
    expect(find.text('このプラグインが使う権限'), findsOneWidget);
    await tester.tap(find.text('インストールする'));
    await tester.pumpAndSettle();
    expect(c.read(installedPluginsProvider).map((p) => p.id), contains(id));
    expect((await store.points()).balance, 700);
    // もう一度買っても減らない。
    expect((await store.purchase(id)).pointsSpent, 0);
  });

  testWidgets('公開テスト(有料の機能が止まっている、D-401): タイルの金額は押せない、購入シートは「使えません」、プラグインを管理のポイントは灰色', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final store = FakeStoreClient();
    final storage = MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})});
    // ORGATE につながない構成 = 有料の機能は止まっている扱い(paymentsConfigProvider は上書きしない)。
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
      storeClientProvider.overrideWithValue(store),
    ], child: const RasqApp()));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    expect(c.read(paidFeaturesProvider), isFalse);
    c.read(routerProvider).push(Routes.storeSearch('プロ向け'));
    await tester.pumpAndSettle();
    const id = 'net.example.pro-cards';
    final action = find.byKey(const ValueKey('store.tile.action.$id'));
    expect(find.descendant(of: action, matching: find.text('¥300')), findsOneWidget, reason: '金額は出す');
    expect(tester.widget<FilledButton>(find.descendant(of: action, matching: find.byType(FilledButton))).onPressed, isNull, reason: '押せない');

    // プラグインのページ: 購入ボタンは押せず、「公開テストでは購入できません」。
    c.read(routerProvider).push(Routes.storePlugin(id));
    await tester.pumpAndSettle();
    expect(find.textContaining('公開テストでは購入できません'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '¥300 で購入')).onPressed, isNull);
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();

    // 購入シート(古い設定のまま入ってきたときの保険): 「使えません」だけで、買えない / コンソールへも誘わない。
    final detail = (await store.plugin(id))!;
    final sheet = showPurchaseSheet(c.read(overlayManagerProvider), store, detail, consoleUrl: Uri.parse('https://central.test/console/points'), paidFeatures: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('store.purchase.disabled')), findsOneWidget);
    expect(find.text('公開テストでは有料プラグインは使えません'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('store.purchase.buy'))).onPressed, isNull);
    expect(find.byKey(const ValueKey('store.purchase.console')), findsNothing);
    c.read(overlayManagerProvider).close('store.purchase');
    await tester.pumpAndSettle();
    expect(await sheet, isNull);
    expect((await store.points()).balance, 1000, reason: '減っていない');

    // プラグインを管理: ポイントの行は灰色(押せない)。
    c.read(routerProvider).push(Routes.storeManage);
    await tester.pumpAndSettle();
    final row = tester.widget<RasqListTile>(find.byKey(const ValueKey('store.manage.points')));
    expect(row.enabled, isFalse);
    expect(row.subtitle, '公開テストでは使えません');
    expect(c.read(storePointsProvider).value, isNull);
  });

  testWidgets('サーバーが paid_features_disabled で断った: 購入シートは同じ「使えません」', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final store = _PaidOffStore();
    final storage = MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})});
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
      storeClientProvider.overrideWithValue(store),
    ], child: const RasqApp()));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    final detail = (await store.plugin('net.example.pro-cards'))!;
    final sheet = showPurchaseSheet(c.read(overlayManagerProvider), store, detail);
    await tester.pumpAndSettle();
    expect(find.text('公開テストでは有料プラグインは使えません'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('store.purchase.buy'))).onPressed, isNull);
    c.read(overlayManagerProvider).close('store.purchase');
    await tester.pumpAndSettle();
    expect(await sheet, isNull);
  });

  testWidgets('画面: プラグインを管理 → アップデートの設定(区分ごとのモード / ポップアップ / 更新ログ)、アカウントごとにバージョンを設定', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final record = InstalledPlugin(
      id: _TwoVersionStore.id,
      name: 'Unicode 昇順 TL',
      version: '0.1.0',
      sha512: 'x',
      installedAt: DateTime(2026, 9, 1),
      versions: [InstalledVersion(version: '0.1.0', sha512: 'x', installedAt: DateTime(2026, 9, 1))],
      pluginType: StorePluginType.timeline,
    );
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson(), second.toJson()], 'current': fakeSession().account.key}),
      'store.installed.v1': jsonEncode({'list': jsonEncode([record.toJson()])}),
    });
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
      storeClientProvider.overrideWithValue(_TwoVersionStore()),
      slotRuntimeLoaderProvider.overrideWithValue(loader()),
    ], child: const RasqApp()));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).push(Routes.storeManage);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('store.manage.installed.sample.timeline')), findsOneWidget);
    expect(find.text('0.2.0 に更新'), findsOneWidget);

    // アップデートの設定: アクションのタブで「おまかせ」→ 保存される。
    await tester.tap(find.byKey(const ValueKey('store.manage.updateSettings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('アクションプラグイン'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('store.updates.action.auto')));
    await tester.pumpAndSettle();
    expect(c.read(pluginUpdateModeProvider(PluginUpdateGroup.action)), PluginUpdateMode.auto);
    expect(c.read(pluginUpdateModeProvider(PluginUpdateGroup.sns)), PluginUpdateMode.installOnly);
    await tester.tap(find.byKey(const ValueKey('store.updates.popup')));
    await tester.pumpAndSettle();
    expect(c.read(pluginUpdatePopupProvider), isFalse);
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();

    // アカウントごとにバージョンを設定: ほかの版(0.2.0)を入れる → ハナコに 0.2.0。
    await tester.tap(find.byKey(const ValueKey('store.manage.versions.sample.timeline')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('store.versions.installed.0.1.0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('store.versions.install.0.2.0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('インストールする'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('store.versions.installed.0.2.0')), findsOneWidget);
    expect(c.read(installedPluginsProvider).single.version, '0.1.0'); // 既定はそのまま
    await tester.tap(find.byKey(ValueKey('store.versions.account.pick.${second.account.key}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0.2.0').last);
    await tester.pumpAndSettle();
    expect(c.read(installedPluginsProvider).single.versionFor(second.account.key), '0.2.0');
    expect(c.read(installedPluginsProvider).single.versionFor(fakeSession().account.key), '0.1.0');
  });

  testWidgets('画面: 最後に許可した内容より広がる版を既定にする前に、広がるものを見せて確かめる(セキュリティ確認 2026-10-09 の [8])', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const net = PluginScope(permissions: {'network'}, hosts: {'api.example.com'});
    final record = InstalledPlugin(
      id: _TwoVersionStore.id,
      name: 'Unicode 昇順 TL',
      version: '0.1.0',
      sha512: 'x',
      installedAt: DateTime(2026, 9, 1),
      approvedScope: const PluginScope(),
      versions: [
        InstalledVersion(version: '0.2.0', sha512: sha512.convert(_TwoVersionStore.bytesOf('0.2.0')).toString(), installedAt: DateTime(2026, 9, 2), scope: net),
        InstalledVersion(version: '0.1.0', sha512: 'x', installedAt: DateTime(2026, 9, 1), scope: const PluginScope()),
      ],
      pluginType: StorePluginType.timeline,
    );
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      'store.installed.v1': jsonEncode({'list': jsonEncode([record.toJson()])}),
    });
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
      storeClientProvider.overrideWithValue(_TwoVersionStore()),
      slotRuntimeLoaderProvider.overrideWithValue(loader()),
    ], child: const RasqApp()));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).push(Routes.storePluginVersions(_TwoVersionStore.id));
    await tester.pumpAndSettle();
    Future<void> pickDefault() async {
      await tester.tap(find.byKey(const ValueKey('store.versions.menu.0.2.0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('既定の版にする'));
      await tester.pumpAndSettle();
    }

    await pickDefault();
    expect(find.text('Ver.0.2.0 は許可する内容が広がります'), findsOneWidget);
    expect(find.textContaining('権限 network'), findsOneWidget);
    expect(find.textContaining('接続先 api.example.com'), findsOneWidget);
    await tester.tap(find.text('やめる'));
    await tester.pumpAndSettle();
    expect(c.read(installedPluginsProvider).single.version, '0.1.0');
    await pickDefault();
    await tester.tap(find.text('許可して使う'));
    await tester.pumpAndSettle();
    final rec = c.read(installedPluginsProvider).single;
    expect(rec.version, '0.2.0');
    expect(rec.approvedScope!.hosts, {'api.example.com'});
  });
}

/// ORGATE が有料の機能を止めているストア (`403 paid_features_disabled`)。
class _PaidOffStore extends FakeStoreClient {
  static OrgateException get _off => OrgateException(ErrorCode.http(403), paidFeaturesDisabledMessage, serverCode: paidFeaturesDisabledCode);
  @override
  Future<StorePoints> points() async => throw _off;
  @override
  Future<StorePurchaseResult> purchase(String pluginId) async => throw _off;
}
