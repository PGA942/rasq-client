import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugin_runtime/plugin_runtime.dart' show scaleFuelBudget;
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../session/rasq_accounts.dart';
import '../../session/session_providers.dart' show sessionStorageProvider;
import '../../session/session_storage.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../store/rasqpkg.dart';

/// サイドロードの信頼の段 (D-306、ユーザー決定 2026-09-24):
/// サイドロードは**自分の署名がある場合だけフル機能**、それ以外は**制限モード**で動かす。
///
/// - [full]: `.rasqpkg` に開発者鍵の署名(`rasq build` が隣に出す `<pkg>.sig.json`)があり、それが配布物と合い、
///   しかも鍵の指紋が**このアカウントが登録した開発者鍵**([ownDevKeyFingerprintsProvider])のどれかと同じ。
/// - [bundled]: **アプリに同梱しているアセット**(`asset:<name>` で、バイト列が rasq-client 自身の `assets/` のものと同じ)。
///   アプリと同じ信頼 = フル機能 (D-308)。名前が `asset:` でも中身が同梱のものと違えば同梱ではない([isBundledAsset])。
/// - [restricted]: それ以外のサイドロード全部 — 署名なし / 署名が合わない / 他人の鍵 / 素の `.wasm`(入れ物も署名も無い)。
///   利用者があとから dev 画面などで登録した外部ファイルがこれ。
///
/// 段は `SlotPluginsNotifier.register` のたびに決める(次回起動の読み直しでも)。鍵の一覧が後から届いた / 変わったときは
/// `SlotPluginsNotifier` が listen して、登録済みのサイドロードを確かめ直す(段が変わったものだけ起動し直す)。
///
/// 制限モードで閉じるもの (D-308) は [sideloadCapabilityTable] の 1 か所に表で持つ([SideloadTrust.capabilities])。
/// 呼び出し側(`SlotPluginsNotifier.register` / dev の試験画面)は表を引くだけで、段を直接見ない。
///
/// ストア (`store:`) の登録は審査で決まるので、この段は使わない(`isReviewedSlotSource` → [SideloadCapabilities.full])。
enum SideloadTrust {
  full,
  bundled,
  restricted;

  /// フル機能か(自分の署名 [full] / アプリ同梱 [bundled])。
  bool get isFull => this != SideloadTrust.restricted;

  /// この段で開けてよい能力(表 [sideloadCapabilityTable] の行)。
  SideloadCapabilities get capabilities => sideloadCapabilityTable[this]!;

  /// 画面に出す短い名前(dev 試験画面 / スロット登録の一覧)。
  String get label => switch (this) {
        SideloadTrust.full => 'フル',
        SideloadTrust.bundled => 'フル(同梱)',
        SideloadTrust.restricted => '制限',
      };
}

/// 段の説明の 1 行(dev 試験画面 / スロット登録の UI)。
const sideloadTrustHint = '自分の開発者鍵で署名した .rasqpkg はフル機能。rasq build が署名します';

/// FOW の種類(`fow.open` の `spec.type`、権限は `fow.<種類>`)。
const sideloadFowKinds = {'widget', 'interstitial', 'system'};

/// サイドロードの段ごとに開けてよい能力 (D-308、ユーザー決定 2026-09-24)。**値は [sideloadCapabilityTable] の表だけで決める**
/// (調整するときは表を書き換える。ゲートの側はこの型のメソッドで宣言を絞るだけ)。
///
/// どれも「マニフェストの宣言を**さらに絞る**」向きにしか効かない(宣言していないものを開けることはない):
/// - [networkEnabled]: 偽なら `network` 権限を外し、`network.hosts` を空にする → `net.fetch` は `E01`、ネイティブ経路
///   (`nativeFetchEnabled` / `effectiveFetchHosts`)も閉。セッションのトークンが届く場所から署名の無い他人のバイナリを外へ出さない。
/// - [storageUnsafeEnabled]: 偽なら `storage.unsafe` を外す(`storage.safe` は残す)→ `storage.*(ns: unsafe)` は `E01`。
/// - [allowedFowKinds]: `fow.open` の `spec.type` のうち開けてよいもの。外れた種類は権限 `fow.<種類>` ごと外す → `E01`。
/// - [blockedHostFns]: アプリ向けホスト関数(D-167)のうち閉じるもの → `E01`(`appFns` から外す)。
/// - [fuelFactor]: 1 呼び出しの fuel 予算(`fuelBudgetFor`)に掛ける倍率。
/// - [gpuEnabled]: 偽なら `gpu_ml` を外し、`gpu.compute` (D-081) の門を閉じる。
///
/// `replace_tile` / `transform_content` / `post.transform` などの描画だけのものは絞らない(サンドボックスの中で描くだけ)。
/// `auto`(temp)は段に関係なく未審査なら読まない(`SlotPlugin.isReviewed`、契約 v0.14 §2.11)。
@immutable
class SideloadCapabilities {
  const SideloadCapabilities({
    required this.networkEnabled,
    required this.storageUnsafeEnabled,
    required this.allowedFowKinds,
    required this.blockedHostFns,
    required this.fuelFactor,
    required this.gpuEnabled,
  });

  final bool networkEnabled;
  final bool storageUnsafeEnabled;
  final Set<String> allowedFowKinds;
  final Set<String> blockedHostFns;
  final double fuelFactor;
  final bool gpuEnabled;

  /// 審査済み(ストア)/ 自分の署名のサイドロード / アプリ同梱: 宣言どおり。
  static const full = SideloadCapabilities(
    networkEnabled: true,
    storageUnsafeEnabled: true,
    allowedFowKinds: sideloadFowKinds,
    blockedHostFns: {},
    fuelFactor: 1,
    gpuEnabled: true,
  );

  /// 制限モード(署名なし / 他人の鍵 / 素の `.wasm` / 見守り中の端末)。
  static const restricted = SideloadCapabilities(
    networkEnabled: false,
    storageUnsafeEnabled: false,
    allowedFowKinds: {'widget'},
    blockedHostFns: {RasqHostFns.composerOpen, RasqHostFns.astellShare, RasqHostFns.muteAdd, RasqHostFns.urlOpen},
    fuelFactor: 0.5,
    gpuEnabled: false,
  );

  /// 実効の権限から外す名前。
  Set<String> get deniedPermissions => {
        if (!networkEnabled) RasqPermissions.network,
        if (!storageUnsafeEnabled) RasqPermissions.storageUnsafe,
        if (!gpuEnabled) RasqPermissions.gpuMl,
        for (final k in sideloadFowKinds)
          if (!allowedFowKinds.contains(k)) 'fow.$k',
      };

  /// マニフェストの `permissions` → 実効の権限(ランタイムの `permissions` に渡すもの)。
  Set<String> permissions(Iterable<String> declared) {
    final denied = deniedPermissions;
    return {for (final p in declared) if (!denied.contains(p)) p};
  }

  /// `SlotManifest.fowPermissions`(`widget` / `interstitial` / `system`)→ 実効の FOW の種類。
  Set<String> fowKinds(Set<String> declared) => declared.intersection(allowedFowKinds);

  /// `SlotManifest.appFns` → 実効のアプリ向けホスト関数。
  Set<String> appFns(Set<String> declared) => declared.difference(blockedHostFns);

  /// `network.hosts` → 実効の接続先。ネットワークを閉じる段は空(= どこにも繋げない)。
  Set<String> fetchHosts(Set<String> declared) => networkEnabled ? declared : const {};

  /// 1 呼び出しの fuel 予算(null = ランタイム既定)→ 実効の予算。
  int? fuelPerCall(int? budget) => scaleFuelBudget(budget, fuelFactor);
}

/// **制限モードの表 (D-308)**。サイドロードの段 → 能力。調整はここだけ。
const sideloadCapabilityTable = <SideloadTrust, SideloadCapabilities>{
  SideloadTrust.full: SideloadCapabilities.full,
  // アプリ同梱のアセット = アプリと同じ信頼(同梱の SNS サンプルは net.fetch で TL を取る)。
  SideloadTrust.bundled: SideloadCapabilities.full,
  SideloadTrust.restricted: SideloadCapabilities.restricted,
};

/// このアカウントが Central に登録した開発者の署名鍵の指紋(失効していないもの。SHA-512 の先頭 8 バイトの hex、
/// `rasq key show` / Central `developer_keys.fingerprint` / [verifyDevSignature] の戻りと同じ形)。
///
/// 中身は [ownDevKeysProvider](Central `GET /me/dev-keys`、rasq-central MR !71)。判定の側([sideloadTrustOf] /
/// `SlotPluginsNotifier.register` / dev 画面)はこれだけを読む。テストは上書きして自分の鍵を与える。
///
/// **見守られている子の端末 (D-307) には開発者鍵が無い**ものとして空を返す = 全てのサイドロードが制限モード (D-308)。
/// チャイルドセーフの関所(`ChildGate.pluginAllowed` = 使ってよいプラグイン / スロット)とは AND で重なる:
/// 関所を通ったプラグインが、さらに制限モードの能力で動く。見守りが始まった / 終わったときは、この一覧が変わるので
/// `SlotPluginsNotifier` が段を確かめ直す(制限モードで閉じたものはトーストを出さず、プラグインに `E01` を返すだけ)。
final ownDevKeyFingerprintsProvider = Provider<Set<String>>((ref) {
  if (ref.watch(childGateProvider.select((g) => g.supervised))) return const {};
  return ref.watch(ownDevKeysProvider);
});

/// KV(セキュアストレージ)の置き場: `{"<Central のアカウント id>": ["<指紋>", …]}`。オフラインのときの最後の一覧。
const ownDevKeysStorageKey = 'plugins.devKeys.v1';

final _fingerprintPattern = RegExp(r'^[0-9a-f]{16}$');

/// アカウント id → 最後に取れた指紋の一覧(メモリ)。[OwnDevKeysNotifier] は依存が変わるたびに作り直される
/// (Riverpod 3)ので、写しは別の箱に持つ。
final _ownDevKeysMemoryProvider = Provider<Map<String, Set<String>>>((ref) => {});

/// 自分の開発者鍵の指紋を Central から引く (D-306)。
///
/// - 対象 = 現在の RASQ アカウント([currentRasqAccountProvider])が **Central** のときだけ。`local` / 台帳なし /
///   ログアウト(`orgateAccountProvider` が null = トークンなし)は空 = 全てのサイドロードが制限モード。
/// - 取り方: `GET /me/dev-keys`(`centralClientProvider` の口 = 接続先・Bearer トークン・20 秒の timeout・
///   `OrgateException` はそのまま)。応答 `[{fingerprint, label, createdAt}]` の `fingerprint` だけを使う
///   (16 桁の hex でないものは捨てる)。
/// - いつ: アプリの起動(`RasqShell` と `SlotPluginsNotifier` が listen する)と、アカウントが変わったとき
///   (現在の RASQ アカウント / `GET /me` が返すアカウントが変わると作り直す)。明示の取り直しは [refresh]。
/// - 覚え方: メモリ(アカウントごと)+ KV [ownDevKeysStorageKey](アカウント id ごと)。作り直しの直後はまず覚えている一覧を出し、
///   取れたら置き換える(鍵を失効すれば次に取れたときに消える)。**取れない**(オフライン / `GET /me` が失敗 / Central のエラー)
///   なら最後に取れた一覧のまま。
/// - トークンはログに出さない(`OrgateClient` がヘッダに載せるだけ。ここで出すのは失敗の [OrgateException] の 1 行)。
class OwnDevKeysNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final accountId = ref.watch(currentRasqAccountProvider.select(_centralAccountId));
    if (accountId == null) return const {};
    final signedIn = ref.watch(orgateAccountProvider.select(_signedInAs));
    if (signedIn.known && signedIn.accountId == null) return const {}; // トークンなし = ログアウト
    // 取りに行くのは、トークンの持ち主がこのアカウントだと分かっているときだけ(読み込み中 / `GET /me` の失敗 = 覚えている一覧)。
    final fetch = signedIn.accountId == accountId;
    final memory = ref.read(_ownDevKeysMemoryProvider);
    final storage = ref.read(sessionStorageProvider);
    final client = fetch ? ref.read(centralClientProvider) : null;
    Future.microtask(() => _load(accountId, memory: memory, storage: storage, client: client));
    return memory[accountId] ?? const {};
  }

  static String? _centralAccountId(RasqAccountRecord? a) => a != null && a.isCentral && (a.centralAccountId ?? '').isNotEmpty ? a.centralAccountId : null;

  /// `orgateAccountProvider` の見え方: known = 結果が出ている(値あり = トークンの持ち主、null = トークンなし)。
  /// 読み込み中 / 失敗(オフラインなど)は known = false。
  static ({bool known, String? accountId}) _signedInAs(AsyncValue<RasqAccount?> s) =>
      s.isLoading || s.hasError || !s.hasValue ? (known: false, accountId: null) : (known: true, accountId: s.value?.id);

  /// 覚えている一覧(メモリ → KV)を出してから、[client] があれば Central から取り直す。
  Future<void> _load(String accountId, {required Map<String, Set<String>> memory, required SessionStorage storage, required OrgateClient? client}) async {
    if (!memory.containsKey(accountId)) {
      final cached = await _readCache(storage, accountId);
      if (cached != null && !memory.containsKey(accountId)) {
        memory[accountId] = cached;
        if (ref.mounted) state = cached;
      }
    }
    if (client != null) await _fetch(accountId, memory: memory, storage: storage, client: client);
  }

  Future<void> _fetch(String accountId, {required Map<String, Set<String>> memory, required SessionStorage storage, required OrgateClient client}) async {
    final Set<String> keys;
    try {
      keys = parseDevKeyFingerprints(await client.getList('/me/dev-keys'));
    } on OrgateException catch (e) {
      debugPrint('own dev keys: fetch failed, keeping the last known list: $e');
      return;
    } catch (e) {
      debugPrint('own dev keys: unexpected response, keeping the last known list: $e');
      return;
    }
    memory[accountId] = keys;
    // 取っている間にアカウントが変わっていたら、覚えるだけで今の一覧は変えない(作り直しが自分で出す)。
    if (ref.mounted) state = keys;
    await _writeCache(storage, accountId, keys);
  }

  /// いまのアカウントの一覧を Central から取り直す(鍵を登録 / 失効したあとなど)。取れなければ前のまま。
  Future<void> refresh() async {
    final accountId = _centralAccountId(ref.read(currentRasqAccountProvider));
    final client = ref.read(centralClientProvider);
    if (accountId == null || client == null || _signedInAs(ref.read(orgateAccountProvider)).accountId != accountId) return;
    await _fetch(accountId, memory: ref.read(_ownDevKeysMemoryProvider), storage: ref.read(sessionStorageProvider), client: client);
  }

  static Future<Map<String, Object?>> _readAll(SessionStorage storage) async {
    try {
      final raw = await storage.read(ownDevKeysStorageKey);
      if (raw == null) return {};
      final j = jsonDecode(raw);
      return j is Map ? j.cast<String, Object?>() : {};
    } catch (e) {
      debugPrint('own dev keys: unreadable cache, ignoring: $e');
      return {};
    }
  }

  static Future<Set<String>?> _readCache(SessionStorage storage, String accountId) async {
    final list = (await _readAll(storage))[accountId];
    return list is List ? {for (final f in list) if (f is String && _fingerprintPattern.hasMatch(f)) f} : null;
  }

  static Future<void> _writeCache(SessionStorage storage, String accountId, Set<String> keys) async {
    try {
      final all = await _readAll(storage);
      all[accountId] = keys.toList()..sort();
      await storage.write(ownDevKeysStorageKey, jsonEncode(all));
    } catch (e) {
      debugPrint('own dev keys: cache write failed: $e');
    }
  }
}

/// `GET /me/dev-keys` の応答 → 指紋の集合(16 桁の hex だけ、小文字に揃える。形の違うものは捨てる)。
Set<String> parseDevKeyFingerprints(List<Object?> body) => {
      for (final k in body)
        if (k is Map && k['fingerprint'] is String && _fingerprintPattern.hasMatch((k['fingerprint'] as String).toLowerCase())) (k['fingerprint'] as String).toLowerCase(),
    };

final ownDevKeysProvider = NotifierProvider<OwnDevKeysNotifier, Set<String>>(OwnDevKeysNotifier.new);

/// サイドロードの配布物の信頼の段を決める(判定の 1 か所)。
///
/// [packageBytes] = 読み込んだ**そのままの**バイト列(`.rasqpkg` なら展開前)。[signature] = 隣の `.sig.json` の中身
/// (無ければ null)。[ownFingerprints] = [ownDevKeyFingerprintsProvider]。署名の確かめは [verifyDevSignature]
/// (digest = 配布物の SHA-512、ed25519、指紋 = 公開鍵の SHA-512 の先頭 8 バイト)。
Future<SideloadTrust> sideloadTrustOf(Uint8List packageBytes, {required Map<String, Object?>? signature, required Set<String> ownFingerprints}) async {
  // 署名の対象は `rasq build` の `.rasqpkg` だけ。素の `.wasm` は入れ物が無い = 制限モード。
  if (signature == null || ownFingerprints.isEmpty || !isRasqPackage(packageBytes)) return SideloadTrust.restricted;
  try {
    final fingerprint = await verifyDevSignature(packageBytes, signature);
    return ownFingerprints.contains(fingerprint) ? SideloadTrust.full : SideloadTrust.restricted;
  } on RasqPackageException catch (e) {
    debugPrint('sideload signature: $e');
    return SideloadTrust.restricted;
  }
}

/// サイドロードの `container`(ファイルのパス / `asset:<name>`)の配布物を読む。`asset:` はアプリ同梱のアセット
/// (`rootBundle`)、それ以外はファイル。読めなければ例外。
Future<Uint8List> readSideloadContainer(String container) async {
  if (container.startsWith('asset:')) {
    final data = await rootBundle.load(container.substring(6));
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
  return File(container).readAsBytesSync();
}

/// [bytes] が**アプリに同梱しているアセットそのもの**か (D-308)。`asset:<name>` の名前だけでは決めない: 同梱の
/// `<name>` を読み直して、バイト列が同じときだけ真(呼び出し側が別のバイト列に `asset:` の名前を付けても同梱にならない)。
Future<bool> isBundledAsset(String container, Uint8List bytes) async {
  if (!container.startsWith('asset:')) return false;
  try {
    return listEquals(await readSideloadContainer(container), bytes);
  } catch (_) {
    return false; // 同梱に無い名前
  }
}

/// サイドロードの段を配布物の置き場ごと決める(`SlotPluginsNotifier.register` / 確かめ直し / dev 画面が使う 1 か所)。
/// 同梱のアセット ([isBundledAsset]) → [SideloadTrust.bundled]、それ以外は [sideloadTrustOf](隣の `.sig.json` と自分の鍵)。
Future<SideloadTrust> sideloadTrustOfContainer(String container, Uint8List packageBytes, {required Set<String> ownFingerprints}) async {
  if (await isBundledAsset(container, packageBytes)) return SideloadTrust.bundled;
  return sideloadTrustOf(packageBytes, signature: await readSideloadSignature(container), ownFingerprints: ownFingerprints);
}

/// サイドロードの `container`(ファイルのパス / `asset:<name>`)の隣の `.sig.json` を読む。無い・読めなければ null。
Future<Map<String, Object?>?> readSideloadSignature(String container) async {
  try {
    final String text;
    if (container.startsWith('asset:')) {
      text = await rootBundle.loadString('${container.substring(6)}.sig.json');
    } else {
      final f = File('$container.sig.json');
      if (!f.existsSync()) return null;
      text = f.readAsStringSync();
    }
    final j = jsonDecode(text);
    return j is Map ? j.cast<String, Object?>() : null;
  } catch (_) {
    return null; // 無い(アセットに無いと例外)/ JSON でない = 署名なし
  }
}
