import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// gpu.compute の門 (D-081、rasq-sdk-sample MR !30): ランタイムの `gpu.compute` は既定で閉で、
/// 埋込側がインスタンスごとに開ける。スロットプラグインは「審査済み(ストア)+ `gpu_ml` の宣言」、
/// サイドロードは `network` と同じく dev 画面での登録を付与とみなして宣言どおり。
void main() {
  SlotManifest manifest(List<String> permissions) => SlotManifest(id: 't.gpu', name: 'GPU', slots: const ['tl'], permissions: permissions);

  group('slotGpuComputeAllowed', () {
    test('ストア (store:): gpu_ml を宣言していれば開ける、無ければ閉', () {
      expect(slotGpuComputeAllowed(manifest(const ['gpu_ml']), source: 'store:t.gpu'), isTrue);
      expect(slotGpuComputeAllowed(manifest(const ['gpu_ml', 'fow.widget']), source: 'store:pkg#t.gpu'), isTrue); // .rasqpkg の子
      expect(slotGpuComputeAllowed(manifest(const ['fow.widget', 'network']), source: 'store:t.gpu'), isFalse);
      expect(slotGpuComputeAllowed(manifest(const []), source: 'store:t.gpu'), isFalse);
    });

    test('サイドロード(ファイル / 同梱アセット): network と同じく宣言どおり(登録が付与)、宣言が無ければ閉', () {
      expect(slotGpuComputeAllowed(manifest(const ['gpu_ml']), source: '/home/u/t.wasm'), isTrue);
      expect(slotGpuComputeAllowed(manifest(const ['gpu_ml']), source: 'asset:assets/plugins/t.wasm'), isTrue);
      expect(slotGpuComputeAllowed(manifest(const ['network']), source: '/home/u/t.wasm'), isFalse);
      expect(slotGpuComputeAllowed(manifest(const []), source: 'asset:assets/plugins/t.wasm'), isFalse);
    });
  });

  group('register がローダーに渡す gpuCompute', () {
    late List<({String source, Set<String> permissions, bool gpuCompute})> loads;

    ProviderContainer container(Map<String, List<String>> permissionsBySource) {
      TestWidgetsFlutterBinding.ensureInitialized();
      loads = [];
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      });
      Future<SlotRuntime> loader(Uint8List bytes, {required String source, required Set<String> fowPermissions, required Set<String> appFns, required Set<String> permissions, required int? fuelPerCall, required Set<String> fetchHosts, required bool gpuCompute}) async {
        loads.add((source: source, permissions: permissions, gpuCompute: gpuCompute));
        return FakeSlotRuntime(
          manifest: {'id': 't.$source'.replaceAll(RegExp(r'[^a-z.]'), ''), 'name': source, 'version': '0.1.0', 'kind': 'action', 'slots': ['tl'], 'permissions': permissionsBySource[source]!},
          handler: (_, fn, args) => null,
        );
      }

      final c = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage), slotRuntimeLoaderProvider.overrideWithValue(loader)]);
      addTearDown(c.dispose);
      return c;
    }

    Future<bool> gpuFor(ProviderContainer c, String source) async {
      final p = await c.read(slotPluginsProvider.notifier).register(source, bytes: Uint8List.fromList(source.codeUnits), persist: false);
      expect(p, isNotNull, reason: c.read(slotPluginsNoticeProvider));
      final mine = loads.where((l) => l.source == source).toList();
      // 1 段目(マニフェストを読むだけ)は権限なし・門は閉。2 段目が宣言どおりに起動する。
      expect(mine, hasLength(2));
      expect(mine.first.permissions, isEmpty);
      expect(mine.first.gpuCompute, isFalse);
      return mine.last.gpuCompute;
    }

    test('ストアの gpu_ml 宣言あり → true、無し → false', () async {
      final c = container({
        'store:a': [RasqPermissions.gpuMl, RasqPermissions.fowWidget],
        'store:b': [RasqPermissions.fowWidget, RasqPermissions.network],
      });
      expect(await gpuFor(c, 'store:a'), isTrue);
      expect(await gpuFor(c, 'store:b'), isFalse);
    });

    test('サイドロード: 宣言があれば dev の付与どおり true、無ければ false', () async {
      final c = container({
        '/tmp/c.wasm': [RasqPermissions.gpuMl],
        'asset:d': [RasqPermissions.storageSafe],
      });
      expect(await gpuFor(c, '/tmp/c.wasm'), isTrue);
      expect(await gpuFor(c, 'asset:d'), isFalse);
    });
  });
}
