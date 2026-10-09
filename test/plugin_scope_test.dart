import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/store/plugin_scope.dart';
import 'package:rasq_client/features/store/plugin_updates.dart';
import 'package:rasq_client/features/store/store_models.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_store_client.dart';
import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// 自動のアップデートは、選んだ版の構成(実効の権限・接続先・データ・目的)を端末に記録した**最後の承認**と比べる
/// (セキュリティ確認 2026-10-09 の [8])。サーバーのリリース情報の差分(直前の公開版から)は、版を飛ばすと空になるので使わない。

/// ストア役: `sample.scope` の版ごとの構成。リリース情報の「増えた権限」はいつも空(直前の版との差分しか言わない)。
class _ScopeStore extends FakeStoreClient {
  _ScopeStore(this.manifests, {required this.current});
  static const id = 'sample.scope';
  final Map<String, Map<String, Object?>> manifests;
  String current;

  /// 同じ版の配布物を差し替えた(ダイジェストが変わる、[14])。
  final rebuilt = <String>{};
  static Uint8List bytesOf(String v, {bool rebuilt = false}) => Uint8List.fromList([0x00, 0x61, 0x73, 0x6d, 1, 0, 0, 0, ...utf8.encode('scope $v${rebuilt ? ' again' : ''}')]);
  Uint8List _bytes(String v) => bytesOf(v, rebuilt: rebuilt.contains(v));

  @override
  Future<StorePluginDetail?> plugin(String pluginId) async =>
      pluginId == id ? StorePluginDetail(id: id, name: 'スコープ', version: current, pluginType: StorePluginType.timeline) : super.plugin(pluginId);
  @override
  Future<List<ReleaseNote>> releases(String pluginId) async =>
      pluginId == id ? [for (final v in manifests.keys) ReleaseNote(version: v, publishedAt: DateTime(2026, 10, 1))] : super.releases(pluginId);
  @override
  Future<InstallManifest?> manifest(String pluginId, {String? version}) async {
    if (pluginId != id) return super.manifest(pluginId, version: version);
    final v = version ?? current;
    final m = manifests[v];
    if (m == null) return null;
    final b = _bytes(v);
    return InstallManifest(pluginId: id, version: v, manifest: {'id': id, 'name': 'スコープ', 'kind': 'view', ...m}, artifacts: [StoreArtifact(id: 'bundle', sizeBytes: b.length, sha512: sha512.convert(b).toString())]);
  }

  @override
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId, {String? version}) async => pluginId == id ? _bytes(version ?? current) : super.downloadArtifact(pluginId, artifactId, version: version);
}

void main() {
  ProviderContainer container(_ScopeStore store, {Map<String, String> seed = const {}}) {
    TestWidgetsFlutterBinding.ensureInitialized();
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      ...seed,
    });
    final c = ProviderContainer(overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      storeClientProvider.overrideWithValue(store),
      slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader({
        for (final v in store.manifests.keys) 'store:${_ScopeStore.id}@$v': () => FakeSlotRuntime(manifest: {'id': _ScopeStore.id, 'name': 'スコープ', 'version': v, 'kind': 'view', 'slots': ['tl']}, handler: (_, fn, args) => null),
      })),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> auto(ProviderContainer c, [String mode = 'auto']) async {
    await c.read(settingsAreaProvider('store.installed').future);
    await c.read(settingsAreaProvider(pluginUpdateArea).notifier).set('mode.action', mode);
  }

  InstalledPlugin rec(ProviderContainer c) => c.read(installedPluginsProvider).single;

  const v1 = <String, Object?>{'slots': ['tl']};
  const withNet = <String, Object?>{'slots': ['tl'], 'permissions': ['network'], 'network': {'hosts': ['api.example.com']}};

  group('PluginScope', () {
    test('権限・接続先・使う場所・用途 / データの扱いの広がり', () {
      final approved = PluginScope.of([withNet], safety: {'permissions': [{'permission': 'network', 'reason': 'API を呼ぶため'}], 'dataHandling': '端末内だけ'});
      expect(approved.wideningOver(approved), isEmpty);
      expect(PluginScope.of([v1]).wideningOver(approved), isEmpty, reason: '狭まるのは広がりではない');
      final wider = PluginScope.of([
        {'slots': ['tl', 'post.action'], 'permissions': ['network', 'mute.words'], 'network': {'hosts': ['api.example.com', 'b.example.com'], 'instance': true}},
      ], safety: {'permissions': [{'permission': 'network', 'reason': '広告の配信'}], 'dataHandling': '開発元へ送る'});
      expect(wider.wideningOver(approved), [
        '権限 mute.words',
        '接続先 b.example.com',
        '接続先 ログイン先のインスタンス',
        '使う場所 post.action',
        '用途 network — 広告の配信',
        'データの扱い — 開発元へ送る',
      ]);
      // 記録が無い = 何も許していない。
      expect(PluginScope.of([v1]).wideningOver(null), ['使う場所 tl']);
      expect(const PluginScope().wideningOver(null), isEmpty);
    });

    test('接続先のワイルドカード: * はどこでも、*.x はサブドメインだけ', () {
      PluginScope hosts(List<String> h) => PluginScope.of([{'network': {'hosts': h}}]);
      expect(hosts(['a.example.com', '*.b.example.com']).wideningOver(hosts(['*.example.com'])), isEmpty);
      expect(hosts(['example.com']).wideningOver(hosts(['*.example.com'])), ['接続先 example.com']);
      expect(hosts(['*']).wideningOver(hosts(['*.example.com'])), ['接続先 *']);
      expect(hosts(['*.example.com']).wideningOver(hosts(['a.example.com'])), ['接続先 *.example.com']);
      expect(hosts(['anything.test']).wideningOver(hosts(['*'])), isEmpty);
    });

    test('root と子を合わせ、記録の JSON を読み戻せる', () {
      final s = PluginScope.of([v1, {'slots': ['post.action'], 'permissions': ['network'], 'network': {'hosts': ['x.test']}}], safety: {'dataHandling': 'd'});
      expect(s.slots, {'tl', 'post.action'});
      expect(s.permissions, {'network'});
      expect(s.hosts, {'x.test'});
      final back = PluginScope.fromJson((jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, Object?>());
      expect(back.wideningOver(s), isEmpty);
      expect(s.wideningOver(back), isEmpty);
      final p = InstalledPlugin(id: 'a.b', name: 'A', version: '1.0.0', sha512: 'x', installedAt: DateTime(2026, 10, 1), approvedScope: s, versions: [InstalledVersion(version: '1.0.0', sha512: 'x', installedAt: DateTime(2026, 10, 1), scope: s)]);
      final r = InstalledPlugin.fromJson((jsonDecode(jsonEncode(p.toJson())) as Map).cast<String, Object?>());
      expect(r.approvedScope!.hosts, {'x.test'});
      expect(r.versionInfo('1.0.0')!.scope!.slots, {'tl', 'post.action'});
    });
  });

  test('v1 だけ許可 → network を足した v2 を飛ばす → 同じ宣言の v3(サーバーの差分は空)でも自動では有効にしない', () async {
    final store = _ScopeStore({'0.1.0': v1, '0.2.0': withNet, '0.3.0': withNet, '0.4.0': withNet}, current: '0.1.0');
    final c = container(store);
    await auto(c);
    expect((await c.read(installedPluginsProvider.notifier).install(_ScopeStore.id, consent: const PluginConsent())).error, isNull);
    store.current = '0.3.0'; // v2 が出ている間は起動しなかった
    final log = await runPluginUpdates(c);
    expect(log.single.result, 'skipped');
    expect(log.single.note, allOf(contains('権限 network'), contains('接続先 api.example.com')));
    expect(rec(c).version, '0.1.0');
    expect(c.read(slotPluginsProvider).map((p) => p.source), ['store:sample.scope@0.1.0'], reason: '広がる版は登録しない');
    // 確認シートで許せば入り、その内容が最後の承認になる → 同じ宣言の次の版は自動で入る。
    expect((await c.read(installedPluginsProvider.notifier).install(_ScopeStore.id, consent: const PluginConsent())).error, isNull);
    expect(rec(c).approvedScope!.permissions, {'network'});
    store.current = '0.4.0';
    expect((await runPluginUpdates(c)).single.result, 'activated');
    expect(rec(c).version, '0.4.0');
  });

  test('権限名は同じで接続先だけ増える版も、確かめずには有効にしない', () async {
    final store = _ScopeStore({
      '0.1.0': withNet,
      '0.2.0': {...withNet, 'network': {'hosts': ['api.example.com', 'collect.example.net']}},
    }, current: '0.1.0');
    final c = container(store);
    await auto(c);
    await c.read(installedPluginsProvider.notifier).install(_ScopeStore.id, consent: const PluginConsent());
    store.current = '0.2.0';
    final log = await runPluginUpdates(c);
    expect(log.single.result, 'skipped');
    expect(log.single.note, contains('接続先 collect.example.net'));
    expect(rec(c).version, '0.1.0');
  });

  test('インストールだけおまかせ: 広がる版は入れて控えるだけ。おまかせへ変えても切り替えず、確かめれば使える', () async {
    final store = _ScopeStore({'0.1.0': v1, '0.2.0': withNet}, current: '0.1.0');
    final c = container(store);
    await auto(c, 'installOnly');
    final notifier = c.read(installedPluginsProvider.notifier);
    await notifier.install(_ScopeStore.id, consent: const PluginConsent());
    store.current = '0.2.0';
    expect((await runPluginUpdates(c)).single.result, 'installed');
    expect(rec(c).version, '0.1.0');
    expect(rec(c).versionInfo('0.2.0')?.scope?.permissions, {'network'});
    expect(c.read(slotPluginsProvider).map((p) => p.storeVersion), ['0.1.0']);
    // おまかせ: 入っていた 0.2.0 でも、最後の承認より広がるので既定にしない。
    await auto(c);
    final log = await runPluginUpdates(c);
    expect(log.single.result, 'skipped');
    expect(log.single.note, contains('権限 network'));
    expect(rec(c).version, '0.1.0');
    // 確かめずに切り替える / アカウントに指定するのも断る。
    expect(notifier.versionWidening(_ScopeStore.id, '0.2.0'), contains('権限 network'));
    expect(await notifier.setDefaultVersion(_ScopeStore.id, '0.2.0'), contains('広がる'));
    expect(await notifier.setAccountVersion(_ScopeStore.id, fakeSession().account.key, '0.2.0'), contains('広がる'));
    expect(c.read(slotPluginsProvider).map((p) => p.storeVersion), ['0.1.0']);
    // 確かめた(画面の確認)なら切り替わり、最後の承認になる。
    expect(await notifier.setDefaultVersion(_ScopeStore.id, '0.2.0', consent: const PluginConsent()), isNull);
    expect(rec(c).version, '0.2.0');
    expect(rec(c).approvedScope!.permissions, {'network'});
    expect(notifier.versionWidening(_ScopeStore.id, '0.1.0'), isEmpty);
  });

  test('広がらない版はこれまでどおり自動で入る(狭まる版も)', () async {
    final store = _ScopeStore({'0.1.0': withNet, '0.2.0': withNet, '0.3.0': v1}, current: '0.1.0');
    final c = container(store);
    await auto(c);
    await c.read(installedPluginsProvider.notifier).install(_ScopeStore.id, consent: const PluginConsent());
    store.current = '0.2.0';
    expect((await runPluginUpdates(c)).single.result, 'activated');
    store.current = '0.3.0';
    expect((await runPluginUpdates(c)).single.result, 'activated');
    // 自動のアップデートは最後の承認を書き換えない(狭い版を入れても、許していた範囲はそのまま)。
    expect(rec(c).approvedScope!.permissions, {'network'});
  });

  test('移行: 最後の承認の記録が無い(この変更より前に入れた)なら、自動では有効にしない', () async {
    final store = _ScopeStore({'0.1.0': v1, '0.2.0': v1}, current: '0.2.0');
    final old = {'id': _ScopeStore.id, 'name': 'スコープ', 'version': '0.1.0', 'sha512': sha512.convert(_ScopeStore.bytesOf('0.1.0')).toString(), 'installedAt': '2026-09-01T00:00:00.000', 'pluginType': 'timeline'};
    final c = container(store, seed: {'store.installed.v1': jsonEncode({'list': jsonEncode([old])})});
    await auto(c);
    expect(rec(c).approvedScope, isNull);
    final log = await runPluginUpdates(c);
    expect(log.single.result, 'skipped');
    expect(log.single.note, contains('記録がない'));
    expect(rec(c).version, '0.1.0');
  });

  group('確認シートで見た版と配布物だけを入れる(セキュリティ確認 2026-10-09 の [14])', () {
    String digest(String v, {bool rebuilt = false}) => sha512.convert(_ScopeStore.bytesOf(v, rebuilt: rebuilt)).toString();

    test('見たあとに最新版が変わっても、見た版を入れる', () async {
      final store = _ScopeStore({'0.1.0': v1, '0.2.0': withNet}, current: '0.1.0');
      final c = container(store);
      await auto(c);
      store.current = '0.2.0'; // シートを開いている間に、権限の広い版が現在版になった
      final r = await c.read(installedPluginsProvider.notifier).install(_ScopeStore.id, consent: PluginConsent(version: '0.1.0', sha512: digest('0.1.0')));
      expect(r.error, isNull);
      expect(rec(c).version, '0.1.0');
      expect(rec(c).approvedScope!.permissions, isEmpty, reason: '最後の承認は見た版の内容');
      expect(c.read(slotPluginsProvider).map((p) => p.source), ['store:sample.scope@0.1.0']);
    });

    test('同じ版でも配布物が変わっていたら、何も登録・保存せずにやめる', () async {
      final store = _ScopeStore({'0.1.0': v1}, current: '0.1.0');
      final c = container(store);
      await auto(c);
      store.rebuilt.add('0.1.0');
      final r = await c.read(installedPluginsProvider.notifier).install(_ScopeStore.id, consent: PluginConsent(version: '0.1.0', sha512: digest('0.1.0')));
      expect(r.error, contains('もう一度確かめてください'));
      expect(c.read(installedPluginsProvider), isEmpty);
      expect(c.read(slotPluginsProvider), isEmpty);
      // 見たダイジェストが今の配布物なら入る(版の指定と整合性の照合はこれまでどおり)。
      expect((await c.read(installedPluginsProvider.notifier).install(_ScopeStore.id, consent: PluginConsent(version: '0.1.0', sha512: digest('0.1.0', rebuilt: true)))).error, isNull);
    });

    test('版を指定したのに構成が別の版を返したら入れない', () async {
      final store = _LyingStore({'0.1.0': v1, '0.2.0': withNet}, current: '0.2.0');
      final c = container(store);
      await auto(c);
      final r = await c.read(installedPluginsProvider.notifier).install(_ScopeStore.id, consent: PluginConsent(version: '0.1.0', sha512: digest('0.1.0')));
      expect(r.error, contains('もう一度確かめてください'));
      expect(c.read(installedPluginsProvider), isEmpty);
    });

    testWidgets('画面: 確認シートを開いている間に現在版が変わっても、シートの版が入る', (tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final store = _ScopeStore({'0.1.0': v1, '0.2.0': withNet}, current: '0.1.0');
      final storage = MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})});
      await tester.pumpWidget(ProviderScope(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        storeClientProvider.overrideWithValue(store),
        slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader({
          for (final v in store.manifests.keys) 'store:${_ScopeStore.id}@$v': () => FakeSlotRuntime(manifest: {'id': _ScopeStore.id, 'name': 'スコープ', 'version': v, 'kind': 'view', 'slots': ['tl']}, handler: (_, fn, args) => null),
        })),
      ], child: const RasqApp()));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      c.read(routerProvider).push(Routes.storePlugin(_ScopeStore.id));
      await tester.pumpAndSettle();
      await tester.tap(find.text('インストール'));
      await tester.pumpAndSettle();
      expect(find.text('スコープ 0.1.0 をインストール'), findsOneWidget);
      store.current = '0.2.0';
      await tester.tap(find.text('インストールする'));
      await tester.pumpAndSettle();
      final r = c.read(installedPluginsProvider).single;
      expect(r.version, '0.1.0');
      expect(r.versionInfo('0.2.0'), isNull);
      expect(r.approvedScope!.permissions, isEmpty);
    });
  });
}

/// 版を指定しても現在版の構成を返すストア(取り直しで別の版にすり替わる)。
class _LyingStore extends _ScopeStore {
  _LyingStore(super.manifests, {required super.current});
  @override
  Future<InstallManifest?> manifest(String pluginId, {String? version}) => super.manifest(pluginId);
}
