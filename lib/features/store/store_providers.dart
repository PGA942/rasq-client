import 'dart:convert';

import 'package:crypto/crypto.dart' show sha512;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart' show currentCentralAccountIdProvider;
import '../settings/settings_dsl.dart';
import '../trend/example_match.dart' show pluginExamplePieces;
import 'http_store_client.dart';
import '../plugins/slot_plugins.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../../session/bluesky_auth.dart' show blueskyPluginId;
import '../../session/mixi2_auth.dart' show mixi2PluginId;
import '../../session/session_providers.dart' show mastodonPluginId;
import 'rasqpkg.dart';
import 'sticker_packs.dart';
import '../theme/theme_packs.dart';
import 'store_client.dart';
import 'store_models.dart';

/// ストアクライアント (M4)。接続先が設定されていれば **RASQ Central**
/// (`rasq-central`, D-138。未設定ならエッジ = `orgate-server` へ縮退)の
/// `/api/v1`、どちらも無ければモックへ縮退する(サーバー無しでもアプリは動く)。
/// テストは override して差し替える。
final storeClientProvider = Provider<StoreClient>((ref) {
  final client = ref.watch(centralClientProvider);
  // RASQ アカウントを切り替えたら作り直す(D-316: ブックマークなどは、アカウントごと)。
  ref.watch(currentCentralAccountIdProvider);
  // Central につないでいても、アプリに同梱しているサンプル(Central に掲載の無いもの)のページ / 配布物は同梱のカタログで答える (D-256)。
  return client == null ? MockStoreClient() : BundledFallbackStoreClient(HttpStoreClient(client), MockStoreClient());
});

final storeHomeProvider = FutureProvider((ref) => ref.watch(storeClientProvider).home());
final storeSearchProvider = FutureProvider.family<List<StorePluginCard>, String>((ref, q) => ref.watch(storeClientProvider).search(q));

/// 検索画面 (D-353): 語 + 絞り込み。フィルターは並びを決めて文字列キーにする(family のキーを安定させる)。
final storeFilteredSearchProvider = FutureProvider.autoDispose.family<List<StorePluginCard>, ({String q, String filters})>((ref, k) {
  final filters = {for (final w in k.filters.split(',')) ...StoreFilter.values.where((f) => f.wire == w)};
  return ref.watch(storeClientProvider).search(k.q, filters: filters);
});
final storePluginProvider = FutureProvider.family<StorePluginDetail?, String>((ref, id) => ref.watch(storeClientProvider).plugin(id));
final storeManifestProvider = FutureProvider.family<InstallManifest?, String>((ref, id) => ref.watch(storeClientProvider).manifest(id));
final storeReviewsProvider = FutureProvider.family<List<StoreReview>, String>((ref, id) => ref.watch(storeClientProvider).reviews(id));

/// ストアページの「レビュー」フレームに出す上位 10 件 (D-137): レビュー TL
/// を関連性(参考になった数 → 実利用済み → 新しさ)で並べた先頭。
final storeTopReviewsProvider = FutureProvider.family<List<StoreReview>, String>((ref, id) async {
  final all = await ref.watch(storeReviewsProvider(id).future);
  return StoreReview.sorted(all, ReviewSort.helpful).take(storeTopReviewCount).toList();
});

/// ストアページに載せるレビュー件数(ワイヤーフレーム「レビュー >」の横並び)。
const storeTopReviewCount = 10;
final storeReleasesProvider = FutureProvider.family<List<ReleaseNote>, String>((ref, id) => ref.watch(storeClientProvider).releases(id));

/// 配布物の検証結果。失敗理由はそのままユーザーに見せる。
@immutable
class ArtifactVerification {
  const ArtifactVerification._(this.ok, this.message, {this.signatureChecked = false});
  final bool ok;
  final String message;

  /// ed25519 署名まで検証できたか(モックや未署名のストアでは false)。
  final bool signatureChecked;

  static const _hashOnly = ArtifactVerification._(true, 'SHA-512 照合 OK(署名なし)');
  static const _full = ArtifactVerification._(true, 'SHA-512 + ed25519 署名 検証 OK', signatureChecked: true);
  static ArtifactVerification failure(String why) => ArtifactVerification._(false, why);
}

/// 配布物 1 件の検証 (D-034)。
///
/// 1. **SHA-512 照合** — 落としたバイト列がマニフェストのハッシュと一致するか。
/// 2. **ed25519 署名** — そのハッシュ(生 64 バイト)にストア鍵の署名が付いて
///    いるか。サーバーは `sign(sha512(bytes))` を返すので、こちらも同じものを
///    検証する。
/// 3. **鍵のピン留め** — `--dart-define=ORGATE_STORE_PUBLIC_KEY` を焼き込んで
///    あれば、マニフェストの `storePublicKey` がそれと一致することも要求する
///    (サーバーがすり替わっても気付ける)。
///
/// 署名が無い(モック / 署名前のストア)ときはハッシュ照合だけで通す。
/// ただし鍵をピン留めしてある構成では、署名の欠落は失敗として扱う。
Future<ArtifactVerification> verifyArtifact({
  required Uint8List bytes,
  required StoreArtifact artifact,
  required String storePublicKey,
}) async {
  final digest = sha512.convert(bytes);
  if (digest.toString() != artifact.sha512) {
    return ArtifactVerification.failure('整合性検証に失敗しました(SHA-512 不一致)。時間をおいて再取得してください');
  }

  if (pinnedStorePublicKey.isNotEmpty && storePublicKey != pinnedStorePublicKey) {
    return ArtifactVerification.failure('ストアの署名鍵がアプリに焼き込んだ鍵と一致しません。接続先を確認してください');
  }
  if (storePublicKey.isEmpty || artifact.signature.isEmpty) {
    if (pinnedStorePublicKey.isNotEmpty) {
      return ArtifactVerification.failure('配布物に署名がありません(このビルドは署名済みストアのみを許可します)');
    }
    return ArtifactVerification._hashOnly;
  }

  try {
    final publicKey = SimplePublicKey(base64Decode(storePublicKey), type: KeyPairType.ed25519);
    final signature = Signature(base64Decode(artifact.signature), publicKey: publicKey);
    // 署名対象はバイト列そのものではなく **SHA-512 ダイジェストの生 64 バイト**。
    final ok = await Ed25519().verify(Uint8List.fromList(digest.bytes), signature: signature);
    return ok ? ArtifactVerification._full : ArtifactVerification.failure('配布物の署名が正しくありません。インストールを中止しました');
  } catch (e) {
    return ArtifactVerification.failure('署名を検証できませんでした: $e');
  }
}

/// インストール済みプラグイン (M4 v1): KV `store.installed.v1` に永続化。
/// インストール = manifest 取得 → 配布物ダウンロード → **SHA-512 照合 +
/// ed25519 署名検証**(D-034)→ 登録。wasm 実体の常設ロードはノード定義
/// プラグインの配置実行(M4 後段)で拡張する。
class InstalledPlugins extends Notifier<List<InstalledPlugin>> {
  @override
  List<InstalledPlugin> build() {
    final area = ref.watch(settingsAreaProvider('store.installed')).value ?? const <String, Object?>{};
    final raw = area['list'];
    if (raw is! String) return const [];
    try {
      return [for (final j in (jsonDecode(raw) as List)) InstalledPlugin.fromJson((j as Map).cast<String, Object?>())];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist(List<InstalledPlugin> list) async {
    state = list;
    await ref.read(settingsAreaProvider('store.installed').notifier).set('list', jsonEncode([for (final p in list) p.toJson()]));
  }

  bool isInstalled(String pluginId) => state.any((p) => p.id == pluginId);

  /// インストール実行。`error` が null なら成功で、`verification` に
  /// どこまで検証できたか(ハッシュのみ / 署名まで)が入る。
  ///
  /// [version] を指定するとその版を入れる(リリースノート FOW の
  /// 「Ver.〇〇をインストール」, D-137)。省略時は stable 最新。既に別の版が
  /// 入っていれば置き換える(アカウントごとの版固定は M4 後段)。
  Future<({String? error, ArtifactVerification? verification})> install(String pluginId, {String? version}) async {
    // チャイルドセーフ (D-307): 保護者のインストールの決め(none / listed / any)。
    final childBlocked = ref.read(childGateProvider).installBlockReason(pluginId);
    if (childBlocked != null) return (error: childBlocked, verification: null);
    final client = ref.read(storeClientProvider);
    final InstallManifest? m;
    try {
      m = await client.manifest(pluginId, version: version);
    } on OrgateException catch (e) {
      // 停止・取り下げ中のプラグインはサーバーが 403 で断る (D-120 ③)。
      return (error: e.message, verification: null);
    }
    if (m == null) return (error: version == null ? '構成(マニフェスト)を取得できませんでした' : 'Ver.$version の構成が見つかりませんでした', verification: null);
    // チャイルドセーフの例 (D-314): 構成の中身(名前 / 説明 / スロット)が分かったので、例との近さでもう 1 度。
    final manifestText = pluginExamplePieces(
      name: '${m.manifest['name'] ?? pluginId}',
      description: '${m.manifest['description'] ?? ''}',
      slots: [for (final s in (m.manifest['slots'] as List? ?? const [])) if (s is String) s],
    );
    final exampleBlocked = ref.read(childGateProvider).installBlockReason(pluginId, text: manifestText);
    if (exampleBlocked != null) return (error: exampleBlocked, verification: null);
    final bundle = m.bundle;
    if (bundle == null) return (error: '配布物がありません', verification: null);

    final Uint8List bytes;
    try {
      bytes = await client.downloadArtifact(pluginId, bundle.id, version: version);
    } on OrgateException catch (e) {
      return (error: e.message, verification: null);
    }

    final verified = await verifyArtifact(bytes: bytes, artifact: bundle, storePublicKey: m.storePublicKey);
    if (!verified.ok) return (error: verified.message, verification: verified);
    debugPrint('store: $pluginId ${m.version} — ${verified.message}');

    // 配布物が .rasqpkg(zstd 圧縮 tar、D-034)なら、署名を確かめた入れ物の**中身**を目次と突き合わせる。
    // 何も登録する前に全部見る: 壊れた / 食い違った配布物は「インストール済み」にもしない。
    RasqPackage? package;
    if (isRasqPackage(bytes)) {
      try {
        package = RasqPackage.open(bytes, decompress: ref.read(rasqpkgZstdProvider));
      } on RasqPackageException catch (e) {
        return (error: '配布物の中身を検証できませんでした: ${e.message}', verification: verified);
      }
      if (package.root.id != pluginId || package.root.version != m.version) {
        return (error: '配布物の中身(${package.root.id} ${package.root.version})がストアの掲載($pluginId ${m.version})と違います', verification: verified);
      }
      // 土台の SNS プラグイン(他人の土台に足す子、D-244c)。第一期は id の有無だけを見る(版の範囲は見ない)。
      final available = {...bundledSnsPluginIds, for (final p in state) p.id};
      final missing = [for (final r in package.requires) if (!available.contains(r.id)) '${r.id} ${r.version}'];
      if (missing.isNotEmpty) return (error: 'このプラグインには ${missing.join(' / ')} が必要です(未対応のため入れられません)', verification: verified);
    }

    final name = m.manifest['name'] as String? ?? pluginId;
    final slots = ref.read(slotPluginsProvider.notifier);
    // 掲載の写し (D-256): 取れなくてもインストールは続ける(写しが無いだけ)。
    InstalledInfo? info;
    try {
      final d = await client.plugin(pluginId);
      if (d != null) info = InstalledInfo.of(d);
    } catch (_) {}
    final record = InstalledPlugin(id: pluginId, name: name, version: m.version, sha512: bundle.sha512, installedAt: DateTime.now(), info: info);

    if (package == null) {
      // 配布物が生の wasm(D-168)や中身の無いモック: 従来どおり、先にインストール済みにしてからスロット登録を試みる。
      // SNS プラグインの wasm は `plugin.manifest` を持たないので登録はできない — 掲載が kind = sns なら試みない、
      // 分からなければ試みて、だめでもインストール自体は残す(エラーは返す)。
      await _persist([...state.where((p) => p.id != pluginId), record]);
      if (isWasmBytes(bytes) && m.manifest['kind'] != 'sns') {
        final slot = await slots.register('store:$pluginId', bytes: bytes);
        if (slot == null) return (error: ref.read(slotPluginsNoticeProvider) ?? 'スロットに登録できませんでした', verification: verified);
      }
      return (error: null, verification: verified);
    }

    // 着せ替え (D-335、契約 v0.16): コードは無い。画像と宣言を端末に保存して、設定 → アプリの外観 → フォントやカラースキームで選ぶ。
    if (package.root.isTheme) {
      try {
        await ref.read(themePacksProvider.notifier).install(package);
      } catch (e) {
        return (error: '着せ替えを保存できませんでした: $e', verification: verified);
      }
      await _persist([...state.where((p) => p.id != pluginId), record]);
      return (error: null, verification: verified);
    }

    // アセットパック (D-252、契約 v0.11): コードは無い。画像を端末に保存して、加工画面のステッカーに出す。
    if (package.root.isAssets) {
      try {
        await ref.read(stickerPacksProvider.notifier).install(package);
      } catch (e) {
        return (error: 'アセットパックを保存できませんでした: $e', verification: verified);
      }
      await _persist([...state.where((p) => p.id != pluginId), record]);
      return (error: null, verification: verified);
    }

    // .rasqpkg: 中のスロットプラグイン(root が sns 以外なら root、それと子)を全部登録できて初めてインストール済みにする。
    // 登録元は `store:<id>`(子は `store:<id>#<childId>`)— 次回起動はストアから取り直して読み込む。
    final registered = <String>[];
    for (final p in package.slotPlugins) {
      final slot = await slots.register(p.id == pluginId ? 'store:$pluginId' : 'store:$pluginId#${p.id}', bytes: bytes);
      if (slot == null) {
        // 途中で失敗したら、この配布物から入れたものを外して、入れなかったことにする。
        for (final id in registered) {
          await slots.unregister(id);
        }
        return (error: ref.read(slotPluginsNoticeProvider) ?? 'スロットに登録できませんでした', verification: verified);
      }
      registered.add(slot.id);
    }
    await _persist([...state.where((p) => p.id != pluginId), record]);
    return (error: null, verification: verified);
  }

  Future<void> uninstall(String pluginId) async {
    await _persist([...state.where((p) => p.id != pluginId)]);
    // アセットパック (D-252) / 着せ替え (D-335) なら保存した画像も消す。
    await ref.read(stickerPacksProvider.notifier).uninstall(pluginId);
    await ref.read(themePacksProvider.notifier).uninstall(pluginId);
    // スロット登録 (D-168) も外す(登録元 `store:<id>` と、.rasqpkg の子 `store:<id>#<childId>`)。
    final slots = ref.read(slotPluginsProvider.notifier);
    for (final p in ref.read(slotPluginsProvider).where((p) => p.source == 'store:$pluginId' || p.source.startsWith('store:$pluginId#'))) {
      await slots.unregister(p.id);
    }
  }
}

final installedPluginsProvider = NotifierProvider<InstalledPlugins, List<InstalledPlugin>>(InstalledPlugins.new);

/// アプリに同梱している SNS プラグイン(`.rasqpkg` の `requires` を満たせる土台)。
const bundledSnsPluginIds = {'rasq.official.misskey', mastodonPluginId, blueskyPluginId, mixi2PluginId};

/// wasm バイナリか(`\0asm`)。ストアの配布物がスロットプラグインかの判定 (D-168)。
bool isWasmBytes(Uint8List b) => b.length > 4 && b[0] == 0 && b[1] == 0x61 && b[2] == 0x73 && b[3] == 0x6d;

/// ブックマークした プラグイン id(サーバー接続時のみ意味がある)。
class StoreBookmarks extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final client = ref.watch(storeClientProvider);
    try {
      return {for (final c in await client.bookmarks()) c.id};
    } on OrgateException catch (e) {
      // 未ログイン(401)でも画面は出す。
      debugPrint('store bookmarks: $e');
      return const {};
    }
  }

  Future<void> toggle(String pluginId) async {
    final current = state.value ?? const <String>{};
    final next = current.contains(pluginId);
    state = AsyncData(next ? ({...current}..remove(pluginId)) : {...current, pluginId});
    try {
      await ref.read(storeClientProvider).setBookmark(pluginId, !next);
      ref.invalidate(storeHomeProvider);
    } catch (e) {
      state = AsyncData(current); // 巻き戻す
      rethrow;
    }
  }
}

final storeBookmarksProvider = AsyncNotifierProvider<StoreBookmarks, Set<String>>(StoreBookmarks.new);

/// レビューへの 👍/👎 (D-137): 端末側の投票状態。KV `store.reviewVotes.v1` に
/// `"<pluginId>/<reviewId>": "up" | "down"` で永続化し、サーバーには
/// [StoreClient.voteReview] で送る(モックは受け取って捨てる。未実装の
/// サーバーは 404 を返すので、その場合も端末側の状態は残す)。
///
/// 表示側は `helpfulCount + (vote == up ? 1 : 0)` のように**元の集計に自分の
/// 票を足して**見せる。サーバーの集計に自分の票が入る/入らないの二重計上は、
/// レビュー再取得時に自分の票が既に含まれている前提(1 アカウント 1 票)なので
/// 起きない — 再取得後は [ReviewVotes] の記録と一致する。
class ReviewVotes extends Notifier<Map<String, ReviewVote>> {
  @override
  Map<String, ReviewVote> build() {
    final area = ref.watch(settingsAreaProvider('store.reviewVotes')).value ?? const <String, Object?>{};
    return {for (final e in area.entries) if (e.value is String) e.key: ReviewVote.fromWire(e.value as String)};
  }

  static String _key(String pluginId, String reviewId) => '$pluginId/$reviewId';

  ReviewVote of(String pluginId, String reviewId) => state[_key(pluginId, reviewId)] ?? ReviewVote.none;

  /// 同じ票をもう一度押すと取り消し、逆の票なら切り替える。
  Future<void> toggle(String pluginId, String reviewId, ReviewVote vote) async {
    final key = _key(pluginId, reviewId);
    final next = of(pluginId, reviewId) == vote ? ReviewVote.none : vote;
    state = {...state, key: next};
    await ref.read(settingsAreaProvider('store.reviewVotes').notifier).set(key, next.wire);
    try {
      await ref.read(storeClientProvider).voteReview(pluginId, reviewId, next);
    } on OrgateException catch (e) {
      // サーバー側が未対応(404)/未ログイン(401)でも端末側の票は残す。
      debugPrint('store voteReview: $e');
    }
  }
}

final reviewVotesProvider = NotifierProvider<ReviewVotes, Map<String, ReviewVote>>(ReviewVotes.new);
