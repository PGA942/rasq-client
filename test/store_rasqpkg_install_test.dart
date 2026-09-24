import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/store/rasqpkg.dart';
import 'package:rasq_client/features/store/store_client.dart';
import 'package:rasq_client/features/store/store_models.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/session/session_storage.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// ストアの配布物が `.rasqpkg`(rasq build、D-034 / D-244)のときのインストール:
/// 署名 / ハッシュの検証 → 展開して中身を目次と突き合わせ → root(sns 以外)と子をスロットに登録 →
/// アンインストールで全部外す → 再起動はストアから取り直して、インストール時のハッシュと同じものだけ読む。
class _PkgStore extends MockStoreClient {
  _PkgStore(this.packages);

  /// pluginId → (版, 配布物)。
  final Map<String, (String, Uint8List)> packages;
  int downloads = 0;

  @override
  Future<InstallManifest?> manifest(String id, {String? version}) async {
    final p = packages[id];
    if (p == null) return super.manifest(id, version: version);
    return InstallManifest(
      pluginId: id,
      version: p.$1,
      manifest: {'id': id, 'name': id},
      artifacts: [StoreArtifact(id: 'bundle', sizeBytes: p.$2.length, sha512: sha512.convert(p.$2).toString())],
    );
  }

  @override
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId, {String? version}) async {
    final p = packages[pluginId];
    if (p == null) return super.downloadArtifact(pluginId, artifactId, version: version);
    downloads++;
    return p.$2;
  }
}

void main() {
  Uint8List fixture(String name) => File('test/fixtures/rasqpkg/$name').readAsBytesSync();
  final sns = fixture('dev.test.mysns-0.1.0.rasqpkg');
  final later = fixture('net.example.later-0.1.0.rasqpkg');

  FakeSlotRuntime fake(String id) => FakeSlotRuntime(manifest: {'id': id, 'name': id, 'version': '0.1.0', 'kind': 'action', 'slots': ['post.action'], 'permissions': ['fow.widget'], 'actions': [{'id': 'hello', 'label': 'hello', 'tags': ['Copy']}]}, handler: (_, fn, args) => null);

  ProviderContainer container(_PkgStore store, {SlotRuntimeLoader? loader, Map<String, String> seed = const {}}) {
    TestWidgetsFlutterBinding.ensureInitialized();
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      ...seed,
    });
    final c = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage), storeClientProvider.overrideWithValue(store), if (loader != null) slotRuntimeLoaderProvider.overrideWithValue(loader)]);
    addTearDown(c.dispose);
    return c;
  }

  /// 偽ランタイム: 登録元で選ぶ。渡ってきたバイト列が**展開後の wasm** であることも見る。
  SlotRuntimeLoader loaderFor(Map<String, String> sourceToId, {List<String>? seen}) => (Uint8List bytes, {required String source, required Set<String> fowPermissions, required Set<String> appFns, required Set<String> permissions, required int? fuelPerCall, required Set<String> fetchHosts, required bool gpuCompute}) async {
        expect(isWasmModule(bytes), isTrue, reason: '$source には展開後の wasm が渡る');
        seen?.add(source);
        final id = sourceToId[source];
        if (id == null) throw StateError('unknown source: $source');
        return fake(id);
      };

  test('SNS プラグイン + 子の配布物: 子だけが `store:<id>#<childId>` でスロットに入り、アンインストールで外れる', () async {
    final store = _PkgStore({'dev.test.mysns': ('0.1.0', sns)});
    final c = container(store, loader: loaderFor({'store:dev.test.mysns#dev.test.mysns.hello': 'dev.test.mysns.hello'}));
    final outcome = await c.read(installedPluginsProvider.notifier).install('dev.test.mysns');
    expect(outcome.error, isNull, reason: c.read(slotPluginsNoticeProvider));
    expect(c.read(slotPluginsProvider).map((p) => (p.id, p.source)), [('dev.test.mysns.hello', 'store:dev.test.mysns#dev.test.mysns.hello')]);
    expect(c.read(installedPluginsProvider).single.sha512, sha512.convert(sns).toString());
    await c.read(installedPluginsProvider.notifier).uninstall('dev.test.mysns');
    expect(c.read(slotPluginsProvider), isEmpty);
    expect(c.read(installedPluginsProvider), isEmpty);
  });

  test('他人の土台に足す子: 土台(requires)が無ければ入れない、あれば入る', () async {
    final store = _PkgStore({'dev.test.mysns': ('0.1.0', sns), 'net.example.later': ('0.1.0', later)});
    final c = container(store, loader: loaderFor({'store:dev.test.mysns#dev.test.mysns.hello': 'dev.test.mysns.hello', 'store:net.example.later': 'net.example.later'}));
    final refused = await c.read(installedPluginsProvider.notifier).install('net.example.later');
    expect(refused.error, contains('dev.test.mysns ^0.1.0 が必要'));
    expect(c.read(installedPluginsProvider), isEmpty);
    expect(c.read(slotPluginsProvider), isEmpty);

    expect((await c.read(installedPluginsProvider.notifier).install('dev.test.mysns')).error, isNull);
    final ok = await c.read(installedPluginsProvider.notifier).install('net.example.later');
    expect(ok.error, isNull, reason: c.read(slotPluginsNoticeProvider));
    expect(c.read(slotPluginsProvider).map((p) => p.source), containsAll(['store:dev.test.mysns#dev.test.mysns.hello', 'store:net.example.later']));
  });

  test('掲載と中身が食い違う配布物(別のプラグイン / 別の版)は入れない', () async {
    final c = container(_PkgStore({'net.example.other': ('0.1.0', later), 'net.example.later': ('9.9.9', later)}), loader: loaderFor(const {}));
    expect((await c.read(installedPluginsProvider.notifier).install('net.example.other')).error, contains('掲載'));
    expect((await c.read(installedPluginsProvider.notifier).install('net.example.later')).error, contains('掲載'));
    expect(c.read(installedPluginsProvider), isEmpty);
  });

  test('壊れた配布物はインストール済みにもしない', () async {
    final broken = Uint8List.fromList(later)..[later.length ~/ 2] ^= 0x55;
    final c = container(_PkgStore({'net.example.later': ('0.1.0', broken)}), loader: loaderFor(const {}));
    final outcome = await c.read(installedPluginsProvider.notifier).install('net.example.later');
    expect(outcome.error, contains('中身を検証できませんでした'));
    expect(c.read(installedPluginsProvider), isEmpty);
  });

  test('wasm が目次と違う id を名乗ったら登録しない(入れ物に別のプラグインを紛れ込ませない)', () async {
    final c = container(_PkgStore({'dev.test.mysns': ('0.1.0', sns)}), loader: loaderFor({'store:dev.test.mysns#dev.test.mysns.hello': 'evil.plugin'}));
    final outcome = await c.read(installedPluginsProvider.notifier).install('dev.test.mysns');
    expect(outcome.error, contains('evil.plugin'));
    expect(c.read(slotPluginsProvider), isEmpty);
    expect(c.read(installedPluginsProvider), isEmpty);
  });

  test('再起動: ストアから取り直し(配布物ごとに 1 回)、インストール時の SHA-512 と違えば読み込まない', () async {
    final installed = jsonEncode([InstalledPlugin(id: 'dev.test.mysns', name: 'x', version: '0.1.0', sha512: sha512.convert(sns).toString(), installedAt: DateTime(2026, 9, 18)).toJson()]);
    final sources = jsonEncode(['store:dev.test.mysns#dev.test.mysns.hello']);

    // 同じ配布物: 読み込む
    final good = _PkgStore({'dev.test.mysns': ('0.1.0', sns)});
    final seen = <String>[];
    final c1 = container(good, loader: loaderFor({'store:dev.test.mysns#dev.test.mysns.hello': 'dev.test.mysns.hello'}, seen: seen), seed: {slotPluginsStorageKey: sources});
    await c1.read(settingsAreaProvider('store.installed').notifier).set('list', installed);
    c1.read(slotPluginsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(c1.read(slotPluginsProvider).map((p) => p.id), ['dev.test.mysns.hello']);
    expect(good.downloads, 1);

    // すり替わった配布物(別の正しい .rasqpkg): 読み込まない
    final swapped = _PkgStore({'dev.test.mysns': ('0.1.0', later)});
    final c2 = container(swapped, loader: loaderFor({'store:dev.test.mysns#dev.test.mysns.hello': 'dev.test.mysns.hello'}), seed: {slotPluginsStorageKey: sources});
    await c2.read(settingsAreaProvider('store.installed').notifier).set('list', installed);
    c2.read(slotPluginsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(c2.read(slotPluginsProvider), isEmpty);
    expect(c2.read(slotPluginsNoticeProvider), contains('インストール時と違う'));
  });

  // 本物: zstd(ネイティブ)→ tar → 検証 → 本物の wasm をワーカー isolate で起動 → plugin.manifest が目次と同じ id を名乗る
  test('本物の wasm: .rasqpkg からインストールして post.action が動く', () async {
    final c = container(_PkgStore({'dev.test.mysns': ('0.1.0', sns)}));
    final outcome = await c.read(installedPluginsProvider.notifier).install('dev.test.mysns').timeout(const Duration(seconds: 90));
    expect(outcome.error, isNull, reason: c.read(slotPluginsNoticeProvider));
    final p = c.read(slotPluginsProvider).single;
    expect((p.manifest.id, p.source), ('dev.test.mysns.hello', 'store:dev.test.mysns#dev.test.mysns.hello'));
    expect(p.manifest.actions.map((a) => a.id), ['hello']);
    final r = await p.runtime.invoke('post.action', {'token': 't', 'actionId': 'hello', 'post': {'body': 'abc'}, 'account': <String, Object?>{}});
    expect((r['value'] as Map)['result'], containsPair('done', true));
  });
}
