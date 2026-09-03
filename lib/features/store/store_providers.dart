import 'dart:convert';

import 'package:crypto/crypto.dart' show sha512;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_dsl.dart';
import 'store_client.dart';
import 'store_models.dart';

/// ストアクライアント (M4)。v1 はモック — ORGATE-server 実装後に HTTP へ
/// 差し替える(テストは override)。
final storeClientProvider = Provider<StoreClient>((ref) => MockStoreClient());

final storeHomeProvider = FutureProvider((ref) => ref.watch(storeClientProvider).home());
final storeSearchProvider = FutureProvider.family<List<StorePluginCard>, String>((ref, q) => ref.watch(storeClientProvider).search(q));
final storePluginProvider = FutureProvider.family<StorePluginDetail?, String>((ref, id) => ref.watch(storeClientProvider).plugin(id));
final storeManifestProvider = FutureProvider.family<InstallManifest?, String>((ref, id) => ref.watch(storeClientProvider).manifest(id));
final storeReviewsProvider = FutureProvider.family<List<StoreReview>, String>((ref, id) => ref.watch(storeClientProvider).reviews(id));
final storeReleasesProvider = FutureProvider.family<List<ReleaseNote>, String>((ref, id) => ref.watch(storeClientProvider).releases(id));

/// インストール済みプラグイン (M4 v1): KV `store.installed.v1` に永続化。
/// インストール = manifest 取得 → 配布物ダウンロード → **SHA-512 照合**
/// (D-034) → 登録。wasm 実体の常設ロードはノード定義プラグインの配置実行
/// (M4 後段)で拡張し、v1 は状態管理 + 検証パイプラインまで。
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

  /// インストール実行。成功で null、失敗で表示用のエラーメッセージ。
  Future<String?> install(String pluginId) async {
    final client = ref.read(storeClientProvider);
    final m = await client.manifest(pluginId);
    if (m == null) return '構成(マニフェスト)を取得できませんでした';
    final bundle = m.artifacts.where((a) => a.kind == 'bundle').firstOrNull;
    if (bundle == null) return '配布物がありません';
    final bytes = await client.downloadArtifact(pluginId, bundle.id);
    // 整合性検証 (D-034): アーティファクト毎の SHA-512。署名(ed25519)は
    // ストア鍵の配布(サーバー実装)後に検証を足す。
    final digest = sha512.convert(bytes).toString();
    if (digest != bundle.sha512) return '整合性検証に失敗しました(SHA-512 不一致)。時間をおいて再取得してください';
    final name = m.manifest['name'] as String? ?? pluginId;
    await _persist([...state.where((p) => p.id != pluginId), InstalledPlugin(id: pluginId, name: name, version: m.version, sha512: digest, installedAt: DateTime.now())]);
    return null;
  }

  Future<void> uninstall(String pluginId) => _persist([...state.where((p) => p.id != pluginId)]);
}

final installedPluginsProvider = NotifierProvider<InstalledPlugins, List<InstalledPlugin>>(InstalledPlugins.new);
