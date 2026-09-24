import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../session/rasq_accounts.dart';
import '../../session/session_providers.dart' show sessionStorageProvider;
import '../../session/session_storage.dart';
import '../store/rasqpkg.dart';

/// サイドロードの信頼の段 (D-306、ユーザー決定 2026-09-24):
/// サイドロードは**自分の署名がある場合だけフル機能**、それ以外は**制限モード**で動かす。
///
/// - [full]: `.rasqpkg` に開発者鍵の署名(`rasq build` が隣に出す `<pkg>.sig.json`)があり、それが配布物と合い、
///   しかも鍵の指紋が**このアカウントが登録した開発者鍵**([ownDevKeyFingerprintsProvider])のどれかと同じ。
/// - [restricted]: それ以外のサイドロード全部 — 署名なし / 署名が合わない / 他人の鍵 / 素の `.wasm`(入れ物も署名も無い)/
///   同梱アセット(`asset:`、隣に同じ形の `.sig.json` があって自分の鍵なら full)。
///
/// 段は `SlotPluginsNotifier.register` のたびに決める(次回起動の読み直しでも)。鍵の一覧が後から届いた / 変わったときは
/// `SlotPluginsNotifier` が listen して、登録済みのサイドロードを確かめ直す(段が変わったものだけ起動し直す)。
///
/// 制限モードで閉じるもの(判定はどれも [SideloadTrust] の 1 か所から引く):
/// - `gpu.compute` (D-081) — `slotGpuComputeAllowed`。
/// - TODO(制限モード): 残りの制限(`network` の接続先、`storage.unsafe`、fuel の予算、FOW の種類など)は今後決める。
///   足すときは [SideloadTrust.isFull] を見る関数をここに並べ、呼び出し側は変えない。
///
/// ストア (`store:`) の登録は審査で決まるので、この段は使わない(`isReviewedSlotSource`)。
enum SideloadTrust {
  full,
  restricted;

  bool get isFull => this == SideloadTrust.full;
}

/// このアカウントが Central に登録した開発者の署名鍵の指紋(失効していないもの。SHA-512 の先頭 8 バイトの hex、
/// `rasq key show` / Central `developer_keys.fingerprint` / [verifyDevSignature] の戻りと同じ形)。
///
/// 中身は [ownDevKeysProvider](Central `GET /me/dev-keys`、rasq-central MR !71)。判定の側([sideloadTrustOf] /
/// `SlotPluginsNotifier.register` / dev 画面)はこれだけを読む。テストは上書きして自分の鍵を与える。
final ownDevKeyFingerprintsProvider = Provider<Set<String>>((ref) => ref.watch(ownDevKeysProvider));

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
