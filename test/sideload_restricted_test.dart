import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';
import 'package:rasq_client/features/child_safe/child_safe_providers.dart' show childGateProvider;
import 'package:rasq_client/features/dev/wasm_plugin_screen.dart';
import 'package:rasq_client/features/plugins/sideload_trust.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/child_safe_fakes.dart';
import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// サイドロードの制限モード (D-308、ユーザー決定 2026-09-24): 自分の署名 / アプリ同梱 = フル、ほか = 制限モード。
/// 表 ([sideloadCapabilityTable]) → register がローダーに渡す値 → ワーカーの環境 (RasqHostEnvironment) の `E01`。
void main() {
  /// `rasq build` と同じ形の `.sig.json`(test/slot_gpu_compute_test.dart と同じ作り方)。
  Future<({Map<String, Object?> sig, String fingerprint})> devSign(Uint8List packageBytes, SimpleKeyPair key) async {
    final digest = sha512.convert(packageBytes);
    final signature = await Ed25519().sign(digest.bytes, keyPair: key);
    final publicKey = (await key.extractPublicKey()).bytes;
    return (
      sig: <String, Object?>{'alg': 'ed25519', 'publicKey': base64Encode(publicKey), 'signature': base64Encode(signature.bytes), 'digest': 'sha512:$digest'},
      fingerprint: sha512.convert(publicKey).bytes.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    );
  }

  final pkgBytes = File('test/fixtures/rasqpkg/net.example.later-0.1.0.rasqpkg').readAsBytesSync();
  final rawWasm = Uint8List.fromList([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0]);

  /// 全部を宣言したマニフェスト(描画だけの権限、通信、storage の両方、FOW の全種類、GPU、副作用のある関数を開くスロット)。
  Map<String, Object?> manifestJson(String id) => {
        'id': id,
        'name': 'Everything',
        'version': '0.1.0',
        'kind': 'action',
        'slots': [SlotIds.tl, SlotIds.postShare, SlotIds.postAction, SlotIds.astellAction, SlotIds.composerText, SlotIds.postTransform],
        'permissions': [
          RasqPermissions.replaceTile, RasqPermissions.transformContent, RasqPermissions.network, RasqPermissions.storageSafe, RasqPermissions.storageUnsafe,
          RasqPermissions.fowWidget, RasqPermissions.fowInterstitial, RasqPermissions.fowSystem, RasqPermissions.gpuMl, 'mute.words',
        ],
        'network': {'hosts': ['api.example']},
      };

  group('表 (sideloadCapabilityTable)', () {
    test('full / bundled = 宣言どおり / restricted = 通信・storage.unsafe・GPU・interstitial / system の FOW・副作用の関数を閉、fuel は半分', () {
      expect(sideloadCapabilityTable.keys, SideloadTrust.values);
      // アプリ同梱のアセット = アプリと同じ信頼(フル)。
      expect(identical(SideloadTrust.bundled.capabilities, SideloadCapabilities.full), isTrue);
      expect(SideloadTrust.bundled.isFull, isTrue);
      expect(SideloadTrust.restricted.isFull, isFalse);
      expect([for (final t in SideloadTrust.values) t.label], ['フル', 'フル(同梱)', '制限', '制限(Swing)']);
      // 未審査の Swing (D-379): 制限モードと同じに閉じ、GPU だけ開ける。
      final sw = SideloadTrust.swing.capabilities;
      final r0 = SideloadTrust.restricted.capabilities;
      expect(SideloadTrust.swing.isFull, isFalse);
      expect(sw.networkEnabled, isFalse);
      expect(sw.storageUnsafeEnabled, isFalse);
      expect(sw.allowedFowKinds, r0.allowedFowKinds);
      expect(sw.blockedHostFns, r0.blockedHostFns);
      expect(sw.gpuEnabled, isTrue);
      final full = SideloadTrust.full.capabilities;
      expect(full.networkEnabled, isTrue);
      expect(full.storageUnsafeEnabled, isTrue);
      expect(full.allowedFowKinds, {'widget', 'interstitial', 'system'});
      expect(full.blockedHostFns, isEmpty);
      expect(full.fuelFactor, 1);
      expect(full.gpuEnabled, isTrue);
      expect(full.deniedPermissions, isEmpty);

      final r = SideloadTrust.restricted.capabilities;
      expect(r.networkEnabled, isFalse);
      expect(r.storageUnsafeEnabled, isFalse);
      expect(r.allowedFowKinds, {'widget'});
      expect(r.blockedHostFns, {RasqHostFns.composerOpen, RasqHostFns.astellShare, RasqHostFns.muteAdd, RasqHostFns.urlOpen});
      expect(r.blockedHostFns, isNot(contains(RasqHostFns.clipboardSet)));
      expect(r.blockedHostFns, isNot(contains(RasqHostFns.toast)));
      expect(r.fuelFactor, 0.5);
      expect(r.gpuEnabled, isFalse);
      expect(r.deniedPermissions, {RasqPermissions.network, RasqPermissions.storageUnsafe, RasqPermissions.gpuMl, RasqPermissions.fowInterstitial, RasqPermissions.fowSystem});
    });

    test('絞るだけ: 宣言していないものは足さない / 描画だけの権限は残す', () {
      final r = SideloadTrust.restricted.capabilities;
      expect(r.permissions(RasqPermissions.all), RasqPermissions.all.difference(r.deniedPermissions));
      expect(r.permissions(const [RasqPermissions.replaceTile, RasqPermissions.transformContent, RasqPermissions.storageSafe]), {RasqPermissions.replaceTile, RasqPermissions.transformContent, RasqPermissions.storageSafe});
      expect(r.permissions(const []), isEmpty);
      expect(r.fowKinds(const {'widget', 'system'}), {'widget'});
      expect(SideloadTrust.full.capabilities.fowKinds(const {'widget'}), {'widget'});
      expect(r.fetchHosts(const {'api.example', '*'}), isEmpty);
      expect(SideloadTrust.full.capabilities.fetchHosts(const {'api.example'}), {'api.example'});
      expect(r.appFns(RasqHostFns.appFns), RasqHostFns.appFns.difference(r.blockedHostFns));
      final standard = fuelBudgetFor(permissions: const {});
      expect(r.fuelPerCall(standard), standard ~/ 2);
      expect(r.fuelPerCall(null), isNotNull); // ランタイム既定(重いほう)の半分
      expect(SideloadTrust.full.capabilities.fuelPerCall(standard), standard);
      expect(SideloadTrust.full.capabilities.fuelPerCall(null), isNull);
    });

    test('ストア (store:) は段に関係なく宣言どおり', () {
      for (final t in SideloadTrust.values) {
        expect(identical(slotCapabilitiesFor('store:x', t), SideloadCapabilities.full), isTrue);
        expect(identical(slotCapabilitiesFor('store:x#child', t), SideloadCapabilities.full), isTrue);
      }
      expect(identical(slotCapabilitiesFor('/home/u/x.wasm', SideloadTrust.restricted), SideloadCapabilities.restricted), isTrue);
      expect(identical(slotCapabilitiesFor('asset:assets/plugins/x.rasqpkg', SideloadTrust.full), SideloadCapabilities.full), isTrue);
    });
  });

  group('register → ローダー → ワーカーの環境', () {
    late List<({String source, Set<String> fowPermissions, Set<String> appFns, Set<String> permissions, int? fuelPerCall, Set<String> fetchHosts, bool gpuCompute})> loads;
    late Map<String, FakeSlotRuntime> runtimes;

    ProviderContainer container({Set<String>? ownFingerprints, List<Override> extra = const [], Map<String, String> ids = const {}}) {
      TestWidgetsFlutterBinding.ensureInitialized();
      loads = [];
      runtimes = {};
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      });
      Future<SlotRuntime> loader(Uint8List bytes, {required String source, required Set<String> fowPermissions, required Set<String> appFns, required Set<String> permissions, required int? fuelPerCall, required Set<String> fetchHosts, required bool gpuCompute}) async {
        loads.add((source: source, fowPermissions: fowPermissions, appFns: appFns, permissions: permissions, fuelPerCall: fuelPerCall, fetchHosts: fetchHosts, gpuCompute: gpuCompute));
        final rt = FakeSlotRuntime(
          manifest: manifestJson(ids[source] ?? 't.everything'),
          // `post.share` を受けたら、すぐ `composer.open` を返す(アプリへの中継 = `_onAppFn` を通る)。
          handler: (rt, fn, args) {
            if (fn == 'post.share') rt.hostFn(RasqHostFns.composerOpen, {'token': args['token'], 'text': 'shared'});
            return const {};
          },
        );
        runtimes[source] = rt;
        return rt;
      }

      final c = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        slotRuntimeLoaderProvider.overrideWithValue(loader),
        if (ownFingerprints != null) ownDevKeyFingerprintsProvider.overrideWithValue(ownFingerprints),
        ...extra,
      ]);
      addTearDown(c.dispose);
      return c;
    }

    /// ワーカー (`wasm_plugin_worker.dart` の ping) と同じ組み立て。
    RasqHostEnvironment envOf(({String source, Set<String> fowPermissions, Set<String> appFns, Set<String> permissions, int? fuelPerCall, Set<String> fetchHosts, bool gpuCompute}) l, {List<String>? relayed}) => RasqHostEnvironment(
          nativeFetch: true,
          fetch: (req) => const SyncFetchResponse(status: 200, bodyText: 'ok'),
          fowPermissions: l.fowPermissions,
          onFow: (fn, args) => null,
          appFns: l.appFns,
          onAppFn: (fn, args) => relayed?.add(fn),
          permissions: l.permissions,
          fetchHosts: l.fetchHosts,
          gpuCompute: l.gpuCompute,
        );

    Map<String, Object?> call(RasqHostEnvironment env, String fn, Map<String, Object?> args) => (jsonDecode(env.dispatch(jsonEncode({'callId': 'c', 'fn': fn, 'args': args}))) as Map).cast<String, Object?>();
    String? code(Map<String, Object?> r) => r['ok'] == true ? null : ((r['error'] as Map)['code'] as String);
    Map<String, Object?> fow(String type) => {'id': 'f', 'spec': {'type': type}, 'root': {'t': 'Column', 'k': 'r'}};

    Future<String> signedPackage(SimpleKeyPair key) async {
      final dir = Directory.systemTemp.createTempSync('rasq_restricted_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final (:sig, fingerprint: _) = await devSign(pkgBytes, key);
      final path = '${dir.path}/net.example.later-0.1.0.rasqpkg';
      File(path).writeAsBytesSync(pkgBytes);
      File('$path.sig.json').writeAsStringSync(jsonEncode(sig));
      return path;
    }

    test('制限モード(素の .wasm): 権限・FOW・関数・接続先・fuel が表どおりに絞られる', () async {
      final dir = Directory.systemTemp.createTempSync('rasq_restricted_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/e.wasm';
      File(path).writeAsBytesSync(rawWasm);
      final c = container(ownFingerprints: {'0123456789abcdef'});
      final p = await c.read(slotPluginsProvider.notifier).register(path, persist: false);
      expect(p, isNotNull, reason: c.read(slotPluginsNoticeProvider));
      expect(p!.sideloadTrust, SideloadTrust.restricted);
      expect(identical(p.capabilities, SideloadCapabilities.restricted), isTrue);
      expect(loads, hasLength(2));
      final declared = SlotManifest.fromJson(manifestJson('t.everything'));
      final first = loads.first;
      expect(first.permissions, isEmpty);
      expect(first.fuelPerCall, scaleFuelBudget(null, 0.5)); // マニフェストを読むだけの 1 段目も半分
      final l = loads.last;
      expect(l.permissions, {RasqPermissions.replaceTile, RasqPermissions.transformContent, RasqPermissions.storageSafe, RasqPermissions.fowWidget, 'mute.words'});
      expect(l.fowPermissions, {'widget'});
      expect(l.fetchHosts, isEmpty);
      expect(l.gpuCompute, isFalse);
      expect(l.appFns, containsAll([RasqHostFns.toast, RasqHostFns.clipboardSet, RasqHostFns.soundPlay, RasqHostFns.composerTextReplace]));
      expect(l.appFns.intersection({RasqHostFns.composerOpen, RasqHostFns.astellShare, RasqHostFns.muteAdd, RasqHostFns.urlOpen}), isEmpty);
      final normal = fuelBudgetFor(permissions: declared.permissions.toSet(), slots: declared.slots.toSet());
      expect(l.fuelPerCall, normal ~/ 2);

      // ワーカーの環境: 閉じたものは E01、許したものは通る。
      final relayed = <String>[];
      final env = envOf(l, relayed: relayed);
      expect(env.nativeFetchEnabled, isFalse);
      expect(env.effectiveFetchHosts, isEmpty);
      expect(env.gpuComputeEnabled, isFalse);
      expect(code(call(env, RasqHostFns.netFetch, {'url': 'https://api.example/x'})), 'E01');
      expect(code(call(env, RasqHostFns.composerOpen, {'token': 't', 'text': 'x'})), 'E01');
      expect(code(call(env, RasqHostFns.astellShare, {'kind': 'text', 'payload': {}})), 'E01');
      expect(code(call(env, RasqHostFns.muteAdd, {'text': 'x'})), 'E01');
      expect(code(call(env, RasqHostFns.urlOpen, {'url': 'https://example.com'})), 'E01');
      expect(code(call(env, RasqHostFns.storageSet, {'ns': 'unsafe', 'key': 'k', 'value': 1})), 'E01');
      expect(code(call(env, RasqHostFns.storageGet, {'ns': 'unsafe', 'key': 'k'})), 'E01');
      expect(code(call(env, RasqHostFns.fowOpen, fow('interstitial'))), 'E01');
      expect(code(call(env, RasqHostFns.fowOpen, fow('system'))), 'E01');
      expect(relayed, isEmpty);
      // 許したもの。
      expect(code(call(env, RasqHostFns.fowOpen, fow('widget'))), isNull);
      expect(code(call(env, RasqHostFns.storageSet, {'ns': 'safe', 'key': 'k', 'value': 1})), isNull);
      expect(call(env, RasqHostFns.storageGet, {'ns': 'safe', 'key': 'k'})['value'], {'value': 1});
      expect(code(call(env, RasqHostFns.toast, {'message': 'hi'})), isNull);
      expect(code(call(env, RasqHostFns.clipboardSet, {'text': 'hi'})), isNull);
      expect(code(call(env, RasqHostFns.composerTextReplace, {'token': 't', 'start': 0, 'end': 0, 'text': 'x'})), isNull);
      expect(relayed, [RasqHostFns.toast, RasqHostFns.clipboardSet, RasqHostFns.composerTextReplace]);

      // アプリへの中継 (`_onAppFn`) でも落とす: 共有から composer.open が来てもコンポーザーは開かない。
      final opened = <String>[];
      await c.read(slotPluginsProvider.notifier).postShare(p, post: const {}, account: const {}, link: 'https://x', onComposerOpen: (text, media, mime, name) => opened.add(text));
      expect(opened, isEmpty);
    });

    test('自分の鍵で署名した .rasqpkg (full): 宣言どおり(通信・storage.unsafe・FOW の全種類・副作用の関数・GPU・通常の fuel)', () async {
      final mine = await Ed25519().newKeyPair();
      final path = await signedPackage(mine);
      final (sig: _, :fingerprint) = await devSign(pkgBytes, mine);
      final c = container(ownFingerprints: {fingerprint}, ids: {path: 'net.example.later'});
      final p = await c.read(slotPluginsProvider.notifier).register(path, persist: false);
      expect(p, isNotNull, reason: c.read(slotPluginsNoticeProvider));
      expect(p!.sideloadTrust, SideloadTrust.full);
      final declared = SlotManifest.fromJson(manifestJson('net.example.later'));
      expect(loads.first.fuelPerCall, isNull);
      final l = loads.last;
      expect(l.permissions, declared.permissions.toSet());
      expect(l.fowPermissions, {'widget', 'interstitial', 'system'});
      expect(l.fetchHosts, {'api.example'});
      expect(l.gpuCompute, isTrue);
      expect(l.appFns, declared.appFns);
      expect(l.appFns, containsAll([RasqHostFns.composerOpen, RasqHostFns.astellShare, RasqHostFns.muteAdd, RasqHostFns.urlOpen]));
      expect(l.fuelPerCall, fuelBudgetFor(permissions: declared.permissions.toSet(), slots: declared.slots.toSet()));

      final relayed = <String>[];
      final env = envOf(l, relayed: relayed);
      expect(env.nativeFetchEnabled, isTrue);
      expect(env.gpuComputeEnabled, isTrue);
      expect(code(call(env, RasqHostFns.netFetch, {'url': 'https://api.example/x'})), isNull);
      expect(code(call(env, RasqHostFns.netFetch, {'url': 'https://other.example/x'})), 'E01'); // 宣言外はフルでも閉
      expect(code(call(env, RasqHostFns.composerOpen, {'token': 't', 'text': 'x'})), isNull);
      expect(code(call(env, RasqHostFns.storageSet, {'ns': 'unsafe', 'key': 'k', 'value': 1})), isNull);
      expect(code(call(env, RasqHostFns.fowOpen, fow('interstitial'))), isNull);
      expect(code(call(env, RasqHostFns.fowOpen, fow('system'))), isNull);

      final opened = <String>[];
      await c.read(slotPluginsProvider.notifier).postShare(p, post: const {}, account: const {}, link: 'https://x', onComposerOpen: (text, media, mime, name) => opened.add(text));
      expect(opened, ['shared']);
    });

    test('アプリ同梱のアセット (asset:、中身が同梱のものと同じ) = bundled(フル)。名前だけ asset: の別物 = 制限モード', () async {
      const name = 'assets/plugins/hello_rasq_plugin.wasm';
      final real = File(name).readAsBytesSync();
      expect(await isBundledAsset('asset:$name', real), isTrue);
      expect(await isBundledAsset('asset:$name', rawWasm), isFalse); // 名前だけ同梱
      expect(await isBundledAsset('asset:assets/plugins/nope.wasm', rawWasm), isFalse); // 同梱に無い
      expect(await isBundledAsset(name, real), isFalse); // ファイルのパスは同梱ではない

      final c = container(ownFingerprints: const {});
      final p = await c.read(slotPluginsProvider.notifier).register('asset:$name', bytes: real, persist: false);
      expect(p, isNotNull, reason: c.read(slotPluginsNoticeProvider));
      expect(p!.sideloadTrust, SideloadTrust.bundled);
      final l = loads.last;
      expect(l.permissions, contains(RasqPermissions.network));
      expect(l.fetchHosts, {'api.example'});
      expect(l.fowPermissions, {'widget', 'interstitial', 'system'});
      expect(l.appFns, contains(RasqHostFns.composerOpen));
      expect(l.gpuCompute, isTrue);
      expect(loads.first.fuelPerCall, isNull);
      // 次回起動の読み直し(bytes なし)も rootBundle から読んで同梱のまま。
      final again = await c.read(slotPluginsProvider.notifier).register('asset:$name', persist: false);
      expect(again!.sideloadTrust, SideloadTrust.bundled);

      final spoof = container(ownFingerprints: const {});
      final q = await spoof.read(slotPluginsProvider.notifier).register('asset:$name#x', bytes: rawWasm, persist: false);
      expect(q!.sideloadTrust, SideloadTrust.restricted);
      expect(loads.last.permissions, isNot(contains(RasqPermissions.network)));
    });

    test('見守られている子の端末 (D-307): 自分の鍵の署名でも制限モード。関所(使ってよいプラグイン / スロット)と AND', () async {
      final mine = await Ed25519().newKeyPair();
      final path = await signedPackage(mine);
      final (sig: _, :fingerprint) = await devSign(pkgBytes, mine);
      final settings = v2();
      ((settings['allow'] as Map)['plugins'] as Map)['ids'] = ['net.example.later'];
      final gate = ChildGate(state: ChildSafeState(managed: true, state: 'active', policy: ChildSafePolicy.fromJson(settings)), now: DateTime(2026, 9, 24, 12));

      // 見守りなし: 同じ鍵の一覧でフル。
      final free = container(ids: {path: 'net.example.later'}, extra: [ownDevKeysProvider.overrideWith(() => _FixedDevKeys({fingerprint}))]);
      expect(free.read(ownDevKeyFingerprintsProvider), {fingerprint});
      expect((await free.read(slotPluginsProvider.notifier).register(path, persist: false))!.sideloadTrust, SideloadTrust.full);

      // 見守り中: 鍵は無いものとして扱う → 制限モード。
      final kid = container(ids: {path: 'net.example.later'}, extra: [ownDevKeysProvider.overrideWith(() => _FixedDevKeys({fingerprint})), childGateProvider.overrideWithValue(gate)]);
      expect(kid.read(ownDevKeyFingerprintsProvider), isEmpty);
      final p = await kid.read(slotPluginsProvider.notifier).register(path, persist: false);
      expect(p, isNotNull, reason: kid.read(slotPluginsNoticeProvider));
      expect(p!.sideloadTrust, SideloadTrust.restricted);
      expect(loads.last.permissions, isNot(contains(RasqPermissions.network)));
      expect(loads.last.fetchHosts, isEmpty);
      expect(loads.last.gpuCompute, isFalse);
      // 関所が許したスロットでは(制限モードのまま)呼ばれる。関所が止めたスロット(post.action: false)には出ない。
      final notifier = kid.read(slotPluginsProvider.notifier);
      expect(notifier.forSlot(SlotIds.tl).map((x) => x.id), ['net.example.later']);
      expect(notifier.forSlot(SlotIds.postAction), isEmpty);
    });
  });

  group('dev 試験画面の門 (devScreenGrantFor)', () {
    test('debug ビルドだけ全権限(段に関係なく)', () {
      for (final t in SideloadTrust.values) {
        final g = devScreenGrantFor(debug: true, trust: t);
        expect(g.isDebugAll, isTrue);
        expect(g.label, 'デバッグビルド: 全権限');
        expect(g.permissions, RasqPermissions.all);
        expect(g.fowPermissions, {'widget', 'interstitial', 'system'});
        expect(g.gpuCompute, isTrue);
        expect(g.fuelPerCall, isNull);
      }
    });

    test('release: 素の .wasm / 署名なし = 制限モード、自分の鍵の .rasqpkg / 同梱のアセット = フル', () {
      final r = devScreenGrantFor(debug: false, trust: SideloadTrust.restricted);
      expect(r.isDebugAll, isFalse);
      expect(r.label, '制限');
      expect(r.permissions, isNot(contains(RasqPermissions.network)));
      expect(r.permissions, isNot(contains(RasqPermissions.storageUnsafe)));
      expect(r.permissions, isNot(contains(RasqPermissions.gpuMl)));
      expect(r.permissions, isNot(contains(RasqPermissions.fowInterstitial)));
      expect(r.permissions, containsAll([RasqPermissions.storageSafe, RasqPermissions.fowWidget, RasqPermissions.replaceTile]));
      expect(r.fowPermissions, {'widget'});
      expect(r.gpuCompute, isFalse);
      expect(r.fuelPerCall, scaleFuelBudget(null, 0.5));
      final env = RasqHostEnvironment(nativeFetch: true, permissions: r.permissions, gpuCompute: r.gpuCompute);
      expect(env.nativeFetchEnabled, isFalse);
      expect(env.gpuComputeEnabled, isFalse);

      final f = devScreenGrantFor(debug: false, trust: SideloadTrust.full);
      expect(f.label, 'フル');
      expect(f.permissions, RasqPermissions.all);
      expect(f.fowPermissions, {'widget', 'interstitial', 'system'});
      expect(f.gpuCompute, isTrue);
      expect(f.fuelPerCall, isNull);

      final b = devScreenGrantFor(debug: false, trust: SideloadTrust.bundled);
      expect(b.label, 'フル(同梱)');
      expect(b.permissions, RasqPermissions.all);
      expect(b.gpuCompute, isTrue);
    });
  });
}

class _FixedDevKeys extends OwnDevKeysNotifier {
  _FixedDevKeys(this.keys);
  final Set<String> keys;
  @override
  Set<String> build() => keys;
}
