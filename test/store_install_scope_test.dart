import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/store/plugin_scope.dart';
import 'package:rasq_client/features/store/rasqpkg.dart';
import 'package:rasq_client/features/store/store_models.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_rasqpkg.dart';
import 'support/fake_store_client.dart';
import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// インストール / 更新の確認シートは、確かめた配布物から読む root と**子**の権限・接続先・使う場所を全部見せ、
/// 見せた内容をそのまま最後の承認として記録する(セキュリティ確認 2026-10-21 の #8)。
/// root(SNS プラグイン)は狭いまま、子が `composer.text`(下書き)と外への接続先を足す配布物で確かめる。

const _id = 'net.example.sns';
const _child = 'net.example.sns.draft';

Map<String, Object?> _root(String v) => {'id': _id, 'name': 'サンプル SNS', 'version': v, 'kind': 'sns', 'permissions': ['storage.safe']};
Map<String, Object?> _childOf(String v, {List<String> hosts = const ['collect.example.net']}) =>
    {'id': _child, 'name': '下書き', 'version': v, 'kind': 'action', 'slots': ['composer.text'], 'permissions': ['network'], 'network': {'hosts': hosts}};

/// ストア役: 構成のマニフェスト(サーバーが返すもの)は root だけ。子は配布物の中にだけある。
class _Store extends FakeStoreClient {
  _Store(this.children, {required this.current}) : packages = {for (final e in children.entries) e.key: fakeRasqPackage(_root(e.key), children: [e.value])};

  /// 版 → 子のマニフェスト。
  final Map<String, Map<String, Object?>> children;
  final Map<String, Uint8List> packages;
  String current;
  int downloads = 0;

  @override
  Future<StorePluginDetail?> plugin(String pluginId) async =>
      pluginId == _id ? StorePluginDetail(id: _id, name: 'サンプル SNS', version: current, pluginType: StorePluginType.other) : super.plugin(pluginId);
  @override
  Future<List<ReleaseNote>> releases(String pluginId) async =>
      pluginId == _id ? [for (final v in packages.keys) ReleaseNote(version: v, publishedAt: DateTime(2026, 10, 1))] : super.releases(pluginId);
  @override
  Future<InstallManifest?> manifest(String pluginId, {String? version}) async {
    if (pluginId != _id) return super.manifest(pluginId, version: version);
    final v = version ?? current;
    final b = packages[v];
    if (b == null) return null;
    return InstallManifest(pluginId: _id, version: v, manifest: _root(v), artifacts: [StoreArtifact(id: 'bundle', sizeBytes: b.length, sha512: sha512.convert(b).toString())]);
  }

  @override
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId, {String? version}) async {
    if (pluginId != _id) return super.downloadArtifact(pluginId, artifactId, version: version);
    downloads++;
    return packages[version ?? current]!;
  }
}

List<Override> _overrides(_Store store) => [
      storeClientProvider.overrideWithValue(store),
      rasqpkgZstdProvider.overrideWithValue(fakeZstdDecompress),
      slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader({
        for (final e in store.children.entries) 'store:$_id@${e.key}#$_child': () => FakeSlotRuntime(manifest: e.value, handler: (_, fn, args) => null),
      })),
    ];

void main() {
  ProviderContainer container(_Store store) {
    TestWidgetsFlutterBinding.ensureInitialized();
    final storage = MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})});
    final c = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage), ..._overrides(store)]);
    addTearDown(c.dispose);
    return c;
  }

  /// 確認シートが見せるもの(= [InstalledPlugins.previewInstall])を取り、そのまま consent にする。
  Future<(PluginScope, PluginConsent)> shown(ProviderContainer c, _Store store, String v) async {
    final m = (await store.manifest(_id, version: v))!;
    final preview = await c.read(installedPluginsProvider.notifier).previewInstall(_id, m);
    expect(preview.error, isNull);
    return (preview.scope!, PluginConsent(version: v, sha512: m.bundle!.sha512, scope: preview.scope));
  }

  test('確認の前に配布物を確かめて読む: 子が足す使う場所・接続先・権限も出る。読むだけで何も登録・保存しない', () async {
    final store = _Store({'0.1.0': _childOf('0.1.0')}, current: '0.1.0');
    final c = container(store);
    final (scope, _) = await shown(c, store, '0.1.0');
    expect(scope.slots, {'composer.text'});
    expect(scope.hosts, {'collect.example.net'});
    expect(scope.permissions, {'storage.safe', 'network'});
    expect(c.read(installedPluginsProvider), isEmpty);
    expect(c.read(slotPluginsProvider), isEmpty);
  });

  test('インストール: 記録する最後の承認は、見せた内容(root と子)と同じ。確認で取った配布物を使う', () async {
    final store = _Store({'0.1.0': _childOf('0.1.0')}, current: '0.1.0');
    final c = container(store);
    final (scope, consent) = await shown(c, store, '0.1.0');
    final r = await c.read(installedPluginsProvider.notifier).install(_id, consent: consent);
    expect(r.error, isNull, reason: c.read(slotPluginsNoticeProvider));
    final rec = c.read(installedPluginsProvider).single;
    expect(rec.approvedScope!.sameAs(scope), isTrue);
    expect(rec.approvedScope!.slots, {'composer.text'});
    expect(c.read(slotPluginsProvider).map((p) => p.source), ['store:$_id@0.1.0#$_child']);
    expect(store.downloads, 1, reason: '確認のときに取って確かめた配布物を、もう一度確かめて使う');
  });

  test('見せた内容が root だけ(子を見せていない)なら、何も登録・保存せずにやめる', () async {
    final store = _Store({'0.1.0': _childOf('0.1.0')}, current: '0.1.0');
    final c = container(store);
    final m = (await store.manifest(_id))!;
    final r = await c.read(installedPluginsProvider.notifier).install(_id, consent: PluginConsent(version: '0.1.0', sha512: m.bundle!.sha512, scope: PluginScope.of([m.manifest])));
    expect(r.error, contains('もう一度確かめてください'));
    expect(c.read(installedPluginsProvider), isEmpty);
    expect(c.read(slotPluginsProvider), isEmpty);
  });

  test('更新: root は同じで子だけ接続先を足す版も、広がりとして見せ、見せた内容がそのまま最後の承認になる', () async {
    final store = _Store({'0.1.0': _childOf('0.1.0'), '0.2.0': _childOf('0.2.0', hosts: ['collect.example.net', 'more.example.net'])}, current: '0.1.0');
    final c = container(store);
    final notifier = c.read(installedPluginsProvider.notifier);
    expect((await notifier.install(_id, consent: (await shown(c, store, '0.1.0')).$2)).error, isNull);
    store.current = '0.2.0';
    final (scope, consent) = await shown(c, store, '0.2.0');
    expect(scope.wideningOver(c.read(installedPluginsProvider).single.approvedScope), ['接続先 more.example.net']);
    expect((await notifier.install(_id, version: '0.2.0', consent: consent)).error, isNull, reason: c.read(slotPluginsNoticeProvider));
    final rec = c.read(installedPluginsProvider).single;
    expect(rec.version, '0.2.0');
    expect(rec.approvedScope!.sameAs(scope), isTrue);
    expect(rec.approvedScope!.hosts, {'collect.example.net', 'more.example.net'});
  });

  testWidgets('画面: 確認シートに子の使う場所・接続先が出る。閉じたら何も入れず、入れたら見せた内容が承認になる', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final store = _Store({'0.1.0': _childOf('0.1.0')}, current: '0.1.0');
    final storage = MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})});
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
      ..._overrides(store),
    ], child: const RasqApp()));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).push(Routes.storePlugin(_id));
    await tester.pumpAndSettle();

    await tester.tap(find.text('インストール'));
    await tester.pumpAndSettle();
    expect(find.text('サンプル SNS 0.1.0 をインストール'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('store.install.slots'))).data, 'composer.text');
    expect(tester.widget<Text>(find.byKey(const ValueKey('store.install.hosts'))).data, 'collect.example.net');
    expect(find.textContaining('network'), findsWidgets);
    // 閉じる(余白 / スワイプと同じ): 何も登録・保存しない。
    c.read(overlayManagerProvider).close('store.install');
    await tester.pumpAndSettle();
    expect(c.read(installedPluginsProvider), isEmpty);
    expect(c.read(slotPluginsProvider), isEmpty);

    await tester.tap(find.text('インストール'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('インストールする'));
    await tester.pumpAndSettle();
    final rec = c.read(installedPluginsProvider).single;
    expect(rec.approvedScope!.slots, {'composer.text'});
    expect(rec.approvedScope!.hosts, {'collect.example.net'});
    expect(rec.approvedScope!.permissions, {'storage.safe', 'network'});
    expect(c.read(slotPluginsProvider).map((p) => p.source), ['store:$_id@0.1.0#$_child']);
  });
}
