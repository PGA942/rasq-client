import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/plugins/sideload_trust.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// gpu.compute の門 (D-081、rasq-sdk-sample MR !30): ランタイムの `gpu.compute` は既定で閉で、
/// 埋込側がインスタンスごとに開ける。スロットプラグインは「審査済み(ストア)+ `gpu_ml` の宣言」、
/// サイドロードは **自分の開発者鍵の署名がある場合だけ**フル機能(宣言どおり)、ほかは制限モードで閉 (D-306)。
void main() {
  SlotManifest manifest(List<String> permissions) => SlotManifest(id: 't.gpu', name: 'GPU', slots: const ['tl'], permissions: permissions);

  /// `rasq build` と同じ形の `.sig.json`(rasq-sdk-sample `rust/rasq-cli/src/key.rs` の `sign`):
  /// 署名対象 = 配布物バイト列の SHA-512 の生 64 バイト。指紋 = 公開鍵の SHA-512 の先頭 8 バイトの hex。
  Future<({Map<String, Object?> sig, String fingerprint})> devSign(Uint8List packageBytes, SimpleKeyPair key) async {
    final digest = sha512.convert(packageBytes);
    final signature = await Ed25519().sign(digest.bytes, keyPair: key);
    final publicKey = (await key.extractPublicKey()).bytes;
    return (
      sig: <String, Object?>{'alg': 'ed25519', 'publicKey': base64Encode(publicKey), 'signature': base64Encode(signature.bytes), 'digest': 'sha512:$digest'},
      fingerprint: sha512.convert(publicKey).bytes.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    );
  }

  // 本物の配布物(rasq build が作った .rasqpkg、root = net.example.later)。
  final pkgBytes = File('test/fixtures/rasqpkg/net.example.later-0.1.0.rasqpkg').readAsBytesSync();
  final rawWasm = Uint8List.fromList([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0]);

  group('slotGpuComputeAllowed', () {
    test('ストア (store:): gpu_ml を宣言していれば開ける、無ければ閉(サイドロードの段は見ない)', () {
      for (final t in SideloadTrust.values) {
        expect(slotGpuComputeAllowed(manifest(const ['gpu_ml']), source: 'store:t.gpu', sideloadTrust: t), isTrue);
        expect(slotGpuComputeAllowed(manifest(const ['gpu_ml', 'fow.widget']), source: 'store:pkg#t.gpu', sideloadTrust: t), isTrue); // .rasqpkg の子
        expect(slotGpuComputeAllowed(manifest(const ['fow.widget', 'network']), source: 'store:t.gpu', sideloadTrust: t), isFalse);
        expect(slotGpuComputeAllowed(manifest(const []), source: 'store:t.gpu', sideloadTrust: t), isFalse);
      }
    });

    test('サイドロード: 自分の署名 (full) + gpu_ml だけ開ける。制限モードは宣言があっても閉', () {
      expect(slotGpuComputeAllowed(manifest(const ['gpu_ml']), source: '/home/u/t.rasqpkg', sideloadTrust: SideloadTrust.full), isTrue);
      expect(slotGpuComputeAllowed(manifest(const ['gpu_ml']), source: 'asset:assets/plugins/t.rasqpkg', sideloadTrust: SideloadTrust.full), isTrue);
      expect(slotGpuComputeAllowed(manifest(const ['network']), source: '/home/u/t.rasqpkg', sideloadTrust: SideloadTrust.full), isFalse);
      expect(slotGpuComputeAllowed(manifest(const ['gpu_ml']), source: '/home/u/t.wasm', sideloadTrust: SideloadTrust.restricted), isFalse);
      expect(slotGpuComputeAllowed(manifest(const ['gpu_ml']), source: 'asset:assets/plugins/t.wasm', sideloadTrust: SideloadTrust.restricted), isFalse);
    });
  });

  group('sideloadTrustOf', () {
    test('自分の鍵の署名 → full。他人の鍵 / 署名なし / 改ざん / 素の .wasm / 自分の鍵が未登録 → restricted', () async {
      final mine = await Ed25519().newKeyPair();
      final other = await Ed25519().newKeyPair();
      final (sig: mySig, fingerprint: myFp) = await devSign(pkgBytes, mine);
      final (sig: otherSig, fingerprint: otherFp) = await devSign(pkgBytes, other);
      expect(myFp, matches(RegExp(r'^[0-9a-f]{16}$')));

      expect(await sideloadTrustOf(pkgBytes, signature: mySig, ownFingerprints: {myFp}), SideloadTrust.full);
      expect(await sideloadTrustOf(pkgBytes, signature: mySig, ownFingerprints: {'0000000000000000', myFp}), SideloadTrust.full); // 鍵は複数持てる
      expect(await sideloadTrustOf(pkgBytes, signature: otherSig, ownFingerprints: {myFp}), SideloadTrust.restricted);
      expect(await sideloadTrustOf(pkgBytes, signature: otherSig, ownFingerprints: {otherFp}), SideloadTrust.full); // 指紋で決まる
      expect(await sideloadTrustOf(pkgBytes, signature: null, ownFingerprints: {myFp}), SideloadTrust.restricted);
      expect(await sideloadTrustOf(pkgBytes, signature: mySig, ownFingerprints: const {}), SideloadTrust.restricted); // 今の既定(口が無い)
      // 配布物の差し替え / 署名の改ざん / 鍵のすり替え(他人の鍵で署名して publicKey だけ自分のもの)。
      final tampered = Uint8List.fromList(pkgBytes)..[pkgBytes.length - 1] ^= 1;
      expect(await sideloadTrustOf(tampered, signature: mySig, ownFingerprints: {myFp}), SideloadTrust.restricted);
      expect(await sideloadTrustOf(pkgBytes, signature: {...otherSig, 'publicKey': mySig['publicKey']}, ownFingerprints: {myFp}), SideloadTrust.restricted);
      expect(await sideloadTrustOf(pkgBytes, signature: {...mySig, 'alg': 'rsa'}, ownFingerprints: {myFp}), SideloadTrust.restricted);
      // 素の .wasm は入れ物が無い = 署名が合っても制限モード。
      final (sig: wasmSig, fingerprint: _) = await devSign(rawWasm, mine);
      expect(await sideloadTrustOf(rawWasm, signature: wasmSig, ownFingerprints: {myFp}), SideloadTrust.restricted);
    });
  });

  group('register がローダーに渡す gpuCompute', () {
    late List<({String source, Set<String> permissions, bool gpuCompute})> loads;

    ProviderContainer container(Map<String, List<String>> permissionsBySource, {Set<String> ownFingerprints = const {}, Map<String, String> ids = const {}}) {
      TestWidgetsFlutterBinding.ensureInitialized();
      loads = [];
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      });
      Future<SlotRuntime> loader(Uint8List bytes, {required String source, required Set<String> fowPermissions, required Set<String> appFns, required Set<String> permissions, required int? fuelPerCall, required Set<String> fetchHosts, required bool gpuCompute}) async {
        loads.add((source: source, permissions: permissions, gpuCompute: gpuCompute));
        return FakeSlotRuntime(
          manifest: {'id': ids[source] ?? 't.$source'.replaceAll(RegExp(r'[^a-z.]'), ''), 'name': source, 'version': '0.1.0', 'kind': 'action', 'slots': ['tl'], 'permissions': permissionsBySource[source]!},
          handler: (_, fn, args) => null,
        );
      }

      final c = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        slotRuntimeLoaderProvider.overrideWithValue(loader),
        ownDevKeyFingerprintsProvider.overrideWithValue(ownFingerprints),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    Future<(bool, SideloadTrust)> gpuFor(ProviderContainer c, String source, {Uint8List? bytes}) async {
      final p = await c.read(slotPluginsProvider.notifier).register(source, bytes: bytes, persist: false);
      expect(p, isNotNull, reason: c.read(slotPluginsNoticeProvider));
      final mine = loads.where((l) => l.source == source).toList();
      // 1 段目(マニフェストを読むだけ)は権限なし・門は閉。2 段目が宣言どおりに起動する。
      expect(mine, hasLength(2));
      expect(mine.first.permissions, isEmpty);
      expect(mine.first.gpuCompute, isFalse);
      return (mine.last.gpuCompute, p!.sideloadTrust);
    }

    test('ストアの gpu_ml 宣言あり → true、無し → false(変わらず)', () async {
      final c = container({
        'store:a': [RasqPermissions.gpuMl, RasqPermissions.fowWidget],
        'store:b': [RasqPermissions.fowWidget, RasqPermissions.network],
      });
      expect((await gpuFor(c, 'store:a', bytes: Uint8List.fromList('a'.codeUnits))).$1, isTrue);
      expect((await gpuFor(c, 'store:b', bytes: Uint8List.fromList('b'.codeUnits))).$1, isFalse);
    });

    test('サイドロード: 署名なし(素の .wasm / .rasqpkg / asset:)は gpu_ml を宣言していても false(制限モード)', () async {
      final dir = Directory.systemTemp.createTempSync('rasq_sideload_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/c.wasm').writeAsBytesSync(rawWasm);
      File('${dir.path}/p.rasqpkg').writeAsBytesSync(pkgBytes);
      final c = container({
        '${dir.path}/c.wasm': [RasqPermissions.gpuMl],
        '${dir.path}/p.rasqpkg': [RasqPermissions.gpuMl],
        'asset:d': [RasqPermissions.gpuMl],
      }, ownFingerprints: {'0123456789abcdef'}, ids: {'${dir.path}/p.rasqpkg': 'net.example.later'});
      expect(await gpuFor(c, '${dir.path}/c.wasm'), (false, SideloadTrust.restricted));
      expect(await gpuFor(c, '${dir.path}/p.rasqpkg'), (false, SideloadTrust.restricted));
      expect(await gpuFor(c, 'asset:d', bytes: rawWasm), (false, SideloadTrust.restricted));
    });

    test('サイドロード: 自分の鍵で署名した .rasqpkg(隣に .sig.json)→ true。他人の鍵 / 自分の鍵が未登録 → false', () async {
      final dir = Directory.systemTemp.createTempSync('rasq_sideload_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final mine = await Ed25519().newKeyPair();
      final (:sig, :fingerprint) = await devSign(pkgBytes, mine);
      final path = '${dir.path}/net.example.later-0.1.0.rasqpkg';
      File(path).writeAsBytesSync(pkgBytes);
      File('$path.sig.json').writeAsStringSync(jsonEncode(sig));
      final perms = {path: [RasqPermissions.gpuMl, RasqPermissions.fowWidget]};
      final ids = {path: 'net.example.later'};

      expect(await gpuFor(container(perms, ownFingerprints: {fingerprint}, ids: ids), path), (true, SideloadTrust.full));
      expect(await gpuFor(container(perms, ownFingerprints: {'0123456789abcdef'}, ids: ids), path), (false, SideloadTrust.restricted)); // 他人の鍵
      expect(await gpuFor(container(perms, ids: ids), path), (false, SideloadTrust.restricted)); // 今の既定: 自分の鍵を知る口が無い
      // 自分の鍵でも gpu_ml の宣言が無ければ閉。
      expect(await gpuFor(container({path: [RasqPermissions.fowWidget]}, ownFingerprints: {fingerprint}, ids: ids), path), (false, SideloadTrust.full));
      // 署名のあとで配布物が差し替わった → 制限モード。
      File(path).writeAsBytesSync(Uint8List.fromList(pkgBytes)..[pkgBytes.length - 1] ^= 1);
      final c = container(perms, ownFingerprints: {fingerprint}, ids: ids);
      final p = await c.read(slotPluginsProvider.notifier).register(path, persist: false);
      if (p != null) expect(p.sideloadTrust, SideloadTrust.restricted); // 壊れた zstd なら登録自体が失敗する(どちらでも GPU は開かない)
      expect(loads.where((l) => l.gpuCompute), isEmpty);
    });
  });
}
