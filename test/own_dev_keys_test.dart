import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/plugins/sideload_trust.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// 自分の開発者鍵の指紋 (D-306): Central `GET /me/dev-keys`(rasq-central MR !71)から引き、アカウントごとに覚える。
/// オフラインは最後の一覧、`local` / ログアウトは空。一覧が届いたら登録済みのサイドロードの段を確かめ直す。
void main() {
  const fp1 = '0123456789abcdef';
  const fp2 = 'fedcba9876543210';

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

  /// 台帳 + 端末資格情報。[central] = 現在のアカウントが Central(`c1`)、[token] = トークンあり(ログイン中)。
  MemorySessionStorage storage({bool central = true, bool token = true, Map<String, List<String>>? cache}) => MemorySessionStorage({
        RasqAccountsNotifier.storageKey: jsonEncode({
          'accounts': [
            central
                ? {'id': 'central-c1', 'kind': 'central', 'handle': 'me', 'centralAccountId': 'c1', 'sessionKeys': <String>[], 'createdAt': '2026-09-01T00:00:00Z'}
                : {'id': RasqAccountsNotifier.localId, 'kind': 'local', 'sessionKeys': <String>[], 'createdAt': '2026-09-01T00:00:00Z'},
          ],
          'current': central ? 'central-c1' : RasqAccountsNotifier.localId,
          'onboardingDone': true,
        }),
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'dev1', 'token': token ? 'tok-c1' : null, 'accountId': 'c1'}),
        if (cache != null) ownDevKeysStorageKey: jsonEncode(cache),
      });

  late List<http.Request> devKeyRequests;

  /// [keys] = `GET /me/dev-keys` の応答(null = そこだけ 503)。[offline] = どこにも届かない。
  ProviderContainer container(SessionStorage storage, {List<Map<String, Object?>>? keys = const [], bool offline = false}) {
    devKeyRequests = [];
    final client = MockClient((req) async {
      if (offline) throw http.ClientException('network unreachable', req.url);
      final json = {'content-type': 'application/json'};
      if (req.url.path == '/api/v1/me') return http.Response('{"id":"c1","handle":"me","displayName":"Me"}', 200, headers: json);
      if (req.url.path == '/api/v1/me/dev-keys') {
        devKeyRequests.add(req);
        if (keys == null) return http.Response('{"error":{"code":"503","message":"down"}}', 503, headers: json);
        return http.Response(jsonEncode(keys), 200, headers: json);
      }
      return http.Response('[]', 200, headers: json);
    });
    final c = ProviderContainer(overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      centralClientProvider.overrideWith((ref) {
        final holder = ref.read(orgateTokenHolderProvider);
        return OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: client, tokenProvider: () => holder.token);
      }),
    ]);
    addTearDown(c.dispose);
    c.listen(ownDevKeyFingerprintsProvider, (_, _) {}); // アプリではシェルが listen している
    return c;
  }

  /// 非同期の取得が落ち着くまで回す。
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Map<String, Object?> key(String fp, String label) => {'fingerprint': fp, 'label': label, 'createdAt': '2026-09-20T00:00:00Z'};

  group('ownDevKeyFingerprintsProvider', () {
    test('Central のアカウント: GET /me/dev-keys の 2 本の鍵がそのまま指紋になる(Bearer はアカウントのトークン)。KV にも覚える', () async {
      final s = storage();
      final c = container(s, keys: [key(fp1, 'laptop'), key(fp2.toUpperCase(), 'ci'), {'fingerprint': 'not-hex', 'label': 'x'}]);
      await settle();
      expect(c.read(ownDevKeyFingerprintsProvider), {fp1, fp2}, reason: '大文字は小文字に揃え、16 桁の hex でないものは捨てる');
      expect(devKeyRequests, isNotEmpty);
      expect(devKeyRequests.first.headers['authorization'] == 'Bearer tok-c1', isTrue); // トークンの中身は出さない
      final cached = jsonDecode((await s.read(ownDevKeysStorageKey))!) as Map;
      expect(cached['c1'], [fp1, fp2]);
    });

    test('オフライン(GET /me も届かない)→ KV に覚えた最後の一覧', () async {
      final c = container(storage(cache: {'c1': [fp1], 'other': [fp2]}), offline: true);
      await settle();
      expect(c.read(ownDevKeyFingerprintsProvider), {fp1}, reason: 'アカウント id ごとに引く');
    });

    test('Central が落ちている(GET /me/dev-keys が 503)→ 最後の一覧のまま。取れたら置き換える(失効した鍵は消える)', () async {
      final s = storage(cache: {'c1': [fp1, fp2]});
      final c = container(s, keys: null);
      await settle();
      expect(devKeyRequests, isNotEmpty);
      expect(c.read(ownDevKeyFingerprintsProvider), {fp1, fp2});

      final c2 = container(s, keys: [key(fp2, 'ci')]);
      await settle();
      expect(c2.read(ownDevKeyFingerprintsProvider), {fp2});
      expect((jsonDecode((await s.read(ownDevKeysStorageKey))!) as Map)['c1'], [fp2]);
    });

    test('local のアカウント → 空(Central へ取りに行かない)', () async {
      final c = container(storage(central: false, cache: {'c1': [fp1]}), keys: [key(fp1, 'laptop')]);
      await settle();
      expect(c.read(ownDevKeyFingerprintsProvider), isEmpty);
      expect(devKeyRequests, isEmpty);
    });

    test('ログアウト(トークンなし)→ 空。覚えた一覧も使わない', () async {
      final c = container(storage(token: false, cache: {'c1': [fp1]}), keys: [key(fp1, 'laptop')]);
      await settle();
      expect(c.read(ownDevKeyFingerprintsProvider), isEmpty);
      expect(devKeyRequests, isEmpty);
    });

    test('アカウントが変わる(Central → local)と空になる', () async {
      final c = container(storage(), keys: [key(fp1, 'laptop')]);
      await settle();
      expect(c.read(ownDevKeyFingerprintsProvider), {fp1});
      await c.read(rasqAccountsProvider.notifier).detachCentral('central-c1');
      await settle();
      expect(c.read(ownDevKeyFingerprintsProvider), isEmpty);
    });

    test('sideloadTrustOf: 一覧にある鍵で署名した .rasqpkg → full、ない鍵 → restricted', () async {
      final mine = await Ed25519().newKeyPair();
      final other = await Ed25519().newKeyPair();
      final (sig: mySig, fingerprint: myFp) = await devSign(pkgBytes, mine);
      final (sig: otherSig, fingerprint: _) = await devSign(pkgBytes, other);
      final c = container(storage(), keys: [key(fp1, 'old'), key(myFp, 'laptop')]);
      await settle();
      final own = c.read(ownDevKeyFingerprintsProvider);
      expect(await sideloadTrustOf(pkgBytes, signature: mySig, ownFingerprints: own), SideloadTrust.full);
      expect(await sideloadTrustOf(pkgBytes, signature: otherSig, ownFingerprints: own), SideloadTrust.restricted);
    });
  });

  group('一覧が届いたら登録済みのサイドロードを確かめ直す', () {
    test('一覧の前に登録した自分の署名の .rasqpkg は restricted → 届くと full(GPU を開けて起動し直す)→ 失効で restricted', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final dir = Directory.systemTemp.createTempSync('rasq_devkeys_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final (:sig, :fingerprint) = await devSign(pkgBytes, await Ed25519().newKeyPair());
      final path = '${dir.path}/net.example.later-0.1.0.rasqpkg';
      File(path).writeAsBytesSync(pkgBytes);
      File('$path.sig.json').writeAsStringSync(jsonEncode(sig));

      final loads = <bool>[];
      Future<SlotRuntime> loader(Uint8List bytes, {required String source, required Set<String> fowPermissions, required Set<String> appFns, required Set<String> permissions, required int? fuelPerCall, required Set<String> fetchHosts, required bool gpuCompute}) async {
        loads.add(gpuCompute);
        return FakeSlotRuntime(
          manifest: {'id': 'net.example.later', 'name': 'later', 'version': '0.1.0', 'kind': 'action', 'slots': ['tl'], 'permissions': [RasqPermissions.gpuMl]},
          handler: (_, fn, args) => null,
        );
      }

      final keys = _Keys();
      final c = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({
          SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
        })),
        slotRuntimeLoaderProvider.overrideWithValue(loader),
        ownDevKeyFingerprintsProvider.overrideWith((ref) => ref.watch(keys.provider)),
      ]);
      addTearDown(c.dispose);
      c.listen(slotPluginsProvider, (_, _) {});

      final first = await c.read(slotPluginsProvider.notifier).register(path, persist: false);
      expect(first!.sideloadTrust, SideloadTrust.restricted);
      expect(loads.last, isFalse);

      c.read(keys.provider.notifier).set({fingerprint});
      await settle();
      final upgraded = c.read(slotPluginsProvider).single;
      expect(upgraded.sideloadTrust, SideloadTrust.full);
      expect(identical(upgraded, first), isFalse, reason: '起動し直した');
      expect(loads.last, isTrue, reason: 'gpu_ml の宣言どおりに開く');

      // 段が変わらない変化(ほかの鍵が増えた)では起動し直さない。
      final loadsBefore = loads.length;
      c.read(keys.provider.notifier).set({fingerprint, fp1});
      await settle();
      expect(loads.length, loadsBefore);
      expect(identical(c.read(slotPluginsProvider).single, upgraded), isTrue);

      // 鍵を失効 → 制限モードへ戻る。
      c.read(keys.provider.notifier).set({fp1});
      await settle();
      expect(c.read(slotPluginsProvider).single.sideloadTrust, SideloadTrust.restricted);
      expect(loads.last, isFalse);
    });
  });
}

/// テスト用の差し替えられる鍵の一覧。
class _Keys {
  final provider = NotifierProvider<_KeysNotifier, Set<String>>(_KeysNotifier.new);
}

class _KeysNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void set(Set<String> v) => state = v;
}
