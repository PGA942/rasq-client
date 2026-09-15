import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_dsl.dart';
import 'node_tabs.dart';
import 'tl_components.dart';

/// TL カスタマイズの設定を画面を通さずに読み書きする (D-227): フィード TL の「タイムラインに取り込む」ボタンと
/// RAi の関数(`timeline.addFeed` / `timeline.excludeWord`)から。保存の作法は TimelineConfigScreen の `_save` と
/// 同じ(`tlcfg` に簡略 UI の構成、`graph` にコンパイル済みのノードグラフ)。
///
/// [ref] は [ProviderContainer](Widget からは `ProviderScope.containerOf`、プロバイダーからは `ref.container`)。
/// [accountKey] はグラフの持ち主(`AccountId.key`)、[scope] は `tl.home` など。
Future<TlConfig> readTlConfig(ProviderContainer ref, String? accountKey, String scope) async {
  final area = await ref.read(settingsAreaProvider(nodeprogAreaFor(accountKey, scope)).future);
  final raw = area['tlcfg'];
  if (raw is String) {
    try {
      return TlConfig.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {}
  }
  return defaultTlConfig(scope);
}

Future<void> writeTlConfig(ProviderContainer ref, String? accountKey, String scope, TlConfig cfg) async {
  final store = ref.read(settingsAreaProvider(nodeprogAreaFor(accountKey, scope)).notifier);
  await store.set('tlcfg', jsonEncode(cfg.toJson()));
  await store.set('graph', jsonEncode(compileTlConfig(cfg, scope: scope).toJson()));
}

/// 取り込み元を足す(同じ `tl` + `account` が既にあれば何もしない)。戻り値 = 足したか。
Future<bool> addTlSource(ProviderContainer ref, String? accountKey, String scope, TlSourceComponent source) async {
  final cfg = await readTlConfig(ref, accountKey, scope);
  if (cfg.sources.any((s) => s.tl == source.tl && s.account == source.account)) return false;
  await writeTlConfig(ref, accountKey, scope, cfg.copyWith(sources: [...cfg.sources, source]));
  return true;
}

/// アルゴリズムを足す(検索絞り込みは同じワード + 除外が既にあれば何もしない)。戻り値 = 足したか。
Future<bool> addTlAlgorithm(ProviderContainer ref, String? accountKey, String scope, TlAlgorithmComponent algorithm) async {
  final cfg = await readTlConfig(ref, accountKey, scope);
  if (algorithm.isQueryFilter && cfg.algorithms.any((a) => a.isQueryFilter && a.query == algorithm.query && a.exclude == algorithm.exclude)) return false;
  await writeTlConfig(ref, accountKey, scope, cfg.copyWith(algorithms: [...cfg.algorithms, algorithm]));
  return true;
}
