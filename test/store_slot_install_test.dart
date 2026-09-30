import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/store/store_client.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_store_client.dart';
import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// ストアのダミー掲載からスロットプラグインをインストール (D-168): 配布物 = 同梱 wasm
/// → 検証 → スロット登録、アンインストールで解除、再起動時はストアから取り直す。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 8, 31), body: body);

  Future<ProviderContainer> pump(WidgetTester tester, {SlotRuntimeLoader? loader, Map<String, String> seed = const {}}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      ...seed,
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post('p1', '今日は打ち上げ')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry), if (loader != null) slotRuntimeLoaderProvider.overrideWithValue(loader)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  test('ダミー掲載: サンプル 7 本が新着に載り、配布物は wasm', () async {
    final client = FakeStoreClient();
    final home = await client.home();
    expect(home.recent.map((c) => c.id), containsAll(storeSlotSamples.map((x) => x.id)));
    expect((await client.plugin('sample.astell'))?.safety.permissions.map((p) => p.permission), contains('fow.widget'));
  });

  testWidgets('インストール → スロット登録(偽ランタイム)、アンインストールで解除、再起動でストアから取り直す', (tester) async {
    final fakes = {
      // インストールは版つきの登録元 (D-355)、下の再起動は古い形(版なし)の控えから読み直す。
      for (final src in ['store:sample.timeline@0.2.0', 'store:sample.timeline'])
        src: () => FakeSlotRuntime(manifest: {'id': 'sample.timeline', 'name': 'Unicode 昇順 TL', 'version': '0.1.0', 'kind': 'view', 'slots': ['tl']}, handler: (_, fn, args) => fn == 'tl.timelines' ? {'timelines': []} : null),
    };
    final c = await pump(tester, loader: fakeSlotLoader(fakes));
    final outcome = await c.read(installedPluginsProvider.notifier).install('sample.timeline');
    expect(outcome.error, isNull);
    expect(c.read(installedPluginsProvider).map((p) => p.id), contains('sample.timeline'));
    expect(c.read(slotPluginsForProvider(SlotIds.tl)).single.source, 'store:sample.timeline@0.2.0');
    await c.read(installedPluginsProvider.notifier).uninstall('sample.timeline');
    expect(c.read(slotPluginsProvider), isEmpty);
    // 再起動: 登録元 `store:` はストアの配布物を取り直して読み込む。
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final c2 = await pump(tester, loader: fakeSlotLoader(fakes), seed: {slotPluginsStorageKey: jsonEncode(['store:sample.timeline'])});
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(c2.read(slotPluginsForProvider(SlotIds.tl)).map((p) => p.id), ['sample.timeline']);
  });

  // ワーカー isolate(本物の wasm)は testWidgets の FakeAsync では進まないので、素の test で。
  test('本物の wasm(同梱アセット)をストアからインストール → ワーカー isolate で常駐 → post.transform が動く', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final c = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
    addTearDown(c.dispose);
    final outcome = await c.read(installedPluginsProvider.notifier).install('sample.post-process').timeout(const Duration(seconds: 60));
    expect(outcome.error, isNull, reason: c.read(slotPluginsNoticeProvider));
    final p = c.read(slotPluginsForProvider(SlotIds.postTransform)).single;
    expect(p.source, 'store:sample.post-process@0.1.0');
    expect(p.manifest.id, 'sample.post-process');
    final v = await p.value('post.transform', {'posts': [{'id': 'x', 'body': '今日', 'createdAt': '2026-09-10T00:00:00Z'}]});
    expect(((v!['posts'] as Map)['x'] as Map)['body'], '9/10(今日)');
    final out = await c.read(slotPluginsProvider.notifier).transform([post('p1', '今日は打ち上げ')]);
    expect(out.single.body, '8/31(今日)は打ち上げ');
    await c.read(installedPluginsProvider.notifier).uninstall('sample.post-process');
    expect(c.read(slotPluginsProvider), isEmpty);
  });
}

