import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/home/plugin_actions.dart' show composerTextPluginsProvider;
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/store/plugin_scope.dart';
import 'package:rasq_client/features/store/rasqpkg.dart';
import 'package:rasq_client/features/store/store_models.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/session/session_storage.dart';

import 'support/fake_rasqpkg.dart';
import 'support/fake_store_client.dart';
import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// ストア(`store:`)から入れたスロットプラグインは、wasm が `plugin.manifest` で名乗る権限・接続先・使う場所が、署名を確かめた
/// 配布物のマニフェスト(と、インストール時に記録したその版の内容)を超えたら登録しない(セキュリティ確認 2026-10-21 の #7)。
/// 同意と自動のアップデートの判定は配布物のマニフェストで行うので、id が同じだけの「自己申告」で下書き(composer.text)や
/// 外への通信を足させない。インストール・再起動の読み直し・更新・一時的に動かす、のどれも同じ規則。

const _id = 'net.example.narrow';

/// 配布物のマニフェスト(審査・同意の対象): 投稿のボタンだけ。
Map<String, Object?> _packaged(String v) => {'id': _id, 'name': 'せまい', 'version': v, 'kind': 'action', 'slots': ['post.action'], 'permissions': ['fow.widget']};

/// wasm の自己申告: 同じ id で、下書きと外への通信を足す。
Map<String, Object?> _greedy(String v) => {
      ..._packaged(v),
      'slots': ['post.action', 'composer.text'],
      'permissions': ['fow.widget', 'network'],
      'network': {'hosts': ['evil.example']},
    };

class _Store extends FakeStoreClient {
  _Store(this.packages, {required this.current, this.raw = const {}});

  /// 版 → 配布物。
  final Map<String, Uint8List> packages;

  /// 生の wasm のときの構成のマニフェスト(版 → マニフェスト)。
  final Map<String, Map<String, Object?>> raw;
  String current;

  @override
  Future<StorePluginDetail?> plugin(String pluginId) async =>
      pluginId == _id ? StorePluginDetail(id: _id, name: 'せまい', version: current, pluginType: StorePluginType.post) : super.plugin(pluginId);
  @override
  Future<InstallManifest?> manifest(String pluginId, {String? version}) async {
    if (pluginId != _id) return super.manifest(pluginId, version: version);
    final v = version ?? current;
    final b = packages[v];
    if (b == null) return null;
    return InstallManifest(pluginId: _id, version: v, manifest: raw[v] ?? {'id': _id, 'name': 'せまい'}, artifacts: [StoreArtifact(id: 'bundle', sizeBytes: b.length, sha512: sha512.convert(b).toString())]);
  }

  @override
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId, {String? version}) async =>
      pluginId == _id ? packages[version ?? current]! : super.downloadArtifact(pluginId, artifactId, version: version);
}

void main() {
  /// 登録元 → wasm が名乗るマニフェスト。呼ばれた関数も控える(下書きが渡らないことを見る)。
  final calls = <String>[];
  ProviderContainer container(_Store store, Map<String, Map<String, Object?>> selfReports, {Map<String, String> seed = const {}}) {
    TestWidgetsFlutterBinding.ensureInitialized();
    calls.clear();
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      ...seed,
    });
    final c = ProviderContainer(overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      storeClientProvider.overrideWithValue(store),
      rasqpkgZstdProvider.overrideWithValue(fakeZstdDecompress),
      slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader({
        for (final e in selfReports.entries)
          e.key: () => FakeSlotRuntime(manifest: e.value, handler: (_, fn, args) {
                calls.add(fn);
                return {};
              }),
      })),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('selfReportExcess', () {
    test('配布物のマニフェストを超える権限・接続先・使う場所を挙げる。収まれば空', () {
      expect(selfReportExcess(_greedy('0.1.0'), packaged: _packaged('0.1.0')), ['権限 network', '接続先 evil.example', '使う場所 composer.text']);
      expect(selfReportExcess(_packaged('0.1.0'), packaged: _packaged('0.1.0')), isEmpty);
      expect(selfReportExcess({'id': _id, 'slots': ['post.action']}, packaged: _packaged('0.1.0')), isEmpty, reason: '狭いのはよい');
      // 記録した版の内容とも比べる(重なった項目は 1 回)。
      expect(selfReportExcess(_greedy('0.1.0'), packaged: _greedy('0.1.0'), approved: PluginScope.of([_packaged('0.1.0')])), ['権限 network', '接続先 evil.example', '使う場所 composer.text']);
    });

    test('生の wasm: 構成のマニフェストが使う場所を持たない(同梱のカタログ)なら使う場所は比べず、権限・接続先は比べる', () {
      final catalog = PluginScope.of([{'id': _id, 'permissions': ['fow.widget']}]);
      expect(selfReportExcess({'id': _id, 'slots': ['tl'], 'permissions': ['fow.widget']}, approved: catalog), isEmpty);
      expect(selfReportExcess(_greedy('0.1.0'), approved: catalog), ['権限 network', '接続先 evil.example']);
      expect(selfReportExcess(_greedy('0.1.0'), approved: PluginScope.of([_packaged('0.1.0')])), contains('使う場所 composer.text'));
    });
  });

  test('インストール: 同じ id の wasm が下書き・通信・接続先を足して名乗ったら登録せず、インストール済みにもしない', () async {
    final store = _Store({'0.1.0': fakeRasqPackage(_packaged('0.1.0'))}, current: '0.1.0');
    final c = container(store, {'store:$_id@0.1.0': _greedy('0.1.0')});
    final r = await c.read(installedPluginsProvider.notifier).install(_id, consent: const PluginConsent());
    expect(r.error, allOf(contains('composer.text'), contains('evil.example'), contains('network')));
    expect(c.read(slotPluginsProvider), isEmpty);
    expect(c.read(installedPluginsProvider), isEmpty);
    // composer の許可なしに承認したプラグインには、下書きを渡す相手が無い。
    expect(c.read(slotPluginsForProvider(SlotIds.composerText)), isEmpty);
    expect(c.read(composerTextPluginsProvider), isEmpty);
    expect(calls, isNot(contains('text.changed')));
  });

  test('名乗る内容が配布物のマニフェストに収まれば、これまでどおり登録する(composer を許したものだけが下書きの相手)', () async {
    final store = _Store({'0.1.0': fakeRasqPackage(_greedy('0.1.0'))}, current: '0.1.0');
    final c = container(store, {'store:$_id@0.1.0': _greedy('0.1.0')});
    expect((await c.read(installedPluginsProvider.notifier).install(_id, consent: const PluginConsent())).error, isNull, reason: c.read(slotPluginsNoticeProvider));
    expect(c.read(slotPluginsForProvider(SlotIds.composerText)).map((p) => p.id), [_id]);
  });

  test('生の wasm: 構成のマニフェストに無い権限・接続先を名乗ったら登録しない', () async {
    final wasm = Uint8List.fromList([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0, ...utf8.encode('raw')]);
    final store = _Store({'0.1.0': wasm}, current: '0.1.0', raw: {'0.1.0': {'id': _id, 'name': 'せまい', 'permissions': ['fow.widget']}});
    final c = container(store, {'store:$_id@0.1.0': _greedy('0.1.0')});
    final r = await c.read(installedPluginsProvider.notifier).install(_id, consent: const PluginConsent());
    expect(r.error, allOf(contains('network'), contains('evil.example')));
    expect(c.read(slotPluginsProvider), isEmpty);
  });

  test('再起動の読み直し: 取り直した配布物が同じでも、名乗る内容が超えていれば読み込まない', () async {
    final pkg = fakeRasqPackage(_packaged('0.1.0'));
    final digest = sha512.convert(pkg).toString();
    final scope = PluginScope.of([_packaged('0.1.0')]);
    final installed = jsonEncode([
      InstalledPlugin(id: _id, name: 'せまい', version: '0.1.0', sha512: digest, installedAt: DateTime(2026, 10, 1), approvedScope: scope, versions: [InstalledVersion(version: '0.1.0', sha512: digest, installedAt: DateTime(2026, 10, 1), scope: scope)]).toJson(),
    ]);
    final c = container(_Store({'0.1.0': pkg}, current: '0.1.0'), {'store:$_id@0.1.0': _greedy('0.1.0')}, seed: {slotPluginsStorageKey: jsonEncode(['store:$_id@0.1.0'])});
    await c.read(settingsAreaProvider('store.installed').notifier).set('list', installed);
    c.read(slotPluginsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(c.read(slotPluginsProvider), isEmpty);
    expect(c.read(slotPluginsNoticeProvider), contains('composer.text'));
    expect(c.read(slotPluginsForProvider(SlotIds.composerText)), isEmpty);
  });

  test('更新: 配布物のマニフェストは同じで、wasm だけ広く名乗る版は自動でも確認つきでも入らず、前の版が動き続ける', () async {
    final store = _Store({'0.1.0': fakeRasqPackage(_packaged('0.1.0')), '0.2.0': fakeRasqPackage(_packaged('0.2.0'))}, current: '0.1.0');
    final c = container(store, {'store:$_id@0.1.0': _packaged('0.1.0'), 'store:$_id@0.2.0': _greedy('0.2.0')});
    final notifier = c.read(installedPluginsProvider.notifier);
    expect((await notifier.install(_id, consent: const PluginConsent())).error, isNull, reason: c.read(slotPluginsNoticeProvider));
    store.current = '0.2.0';
    expect((await notifier.install(_id)).error, contains('composer.text'), reason: '自動のアップデート(同意なし)');
    expect((await notifier.install(_id, consent: const PluginConsent())).error, contains('composer.text'), reason: '確認シートから');
    expect(c.read(installedPluginsProvider).single.version, '0.1.0');
    expect(c.read(slotPluginsProvider).map((p) => p.source), ['store:$_id@0.1.0']);
    expect(c.read(slotPluginsForProvider(SlotIds.composerText)), isEmpty);
  });

  test('一時的に動かす(共有セッションの参加者): 同じ規則で、超えていれば動かさない', () async {
    final pkg = fakeRasqPackage(_packaged('0.1.0'));
    final c = container(_Store({'0.1.0': pkg}, current: '0.1.0'), {'store:$_id@0.1.0': _greedy('0.1.0')});
    final p = await c.read(slotPluginsProvider.notifier).register('store:$_id@0.1.0', bytes: pkg, persist: false, temporary: true);
    expect(p, isNull);
    expect(c.read(slotPluginsNoticeProvider), contains('evil.example'));
  });
}
