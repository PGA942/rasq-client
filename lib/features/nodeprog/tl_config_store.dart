import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

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

/// タイムラインの一時変更 (D-338): スコープ(`tl.home` など)→ 一時的な構成。**保存しない**(「元に戻す」/ アプリを閉じる /
/// アカウントを切り替えるまで)。TL は保存した構成の代わりにこれを実行する。タブの ↓ で開く FOW(一時変更 FOW)が書く。
class TlTemporaryConfigs extends Notifier<Map<String, TlConfig>> {
  @override
  Map<String, TlConfig> build() {
    ref.watch(currentAccountProvider.select((a) => a?.key));
    return const {};
  }

  void set(String scope, TlConfig cfg) => state = {...state, scope: cfg};
  void clear(String scope) => state = {...state}..remove(scope);

  /// 一時変更 FOW のキャンセル (D-341): 展開したときの状態へ巻き戻す。
  void restore(Map<String, TlConfig> snapshot) => state = snapshot;
}

final tlTemporaryConfigsProvider = NotifierProvider<TlTemporaryConfigs, Map<String, TlConfig>>(TlTemporaryConfigs.new);

/// タイムラインのタブの並び (D-339): 「タイムラインをカスタマイズ」のタブ行で並べ替えたスコープ(`tl.home` など)の順。
/// ホームのタブもこの順に並ぶ(並びに無いタブは元の位置のまま)。`nodeprog.prefs` の `tabOrder`(アカウント共通)。
final tlTabOrderProvider = Provider<List<String>>((ref) {
  final raw = (ref.watch(settingsAreaProvider('nodeprog.prefs')).value ?? const {})['tabOrder'];
  if (raw is! String) return const [];
  try {
    return [for (final s in jsonDecode(raw) as List) if (s is String) s];
  } catch (_) {
    return const [];
  }
});

Future<void> saveTlTabOrder(WidgetRef ref, List<String> scopes) => ref.read(settingsAreaProvider('nodeprog.prefs').notifier).set('tabOrder', jsonEncode(scopes));

/// [items] を [order] の順に並べ替える: 並びに載っているものは、それらが占めていた位置に並びの順で入り、載っていないものは
/// 元の位置のまま(新しく増えたタブが勝手に端へ飛ばない)。
List<T> applyTlTabOrder<T>(List<T> items, String Function(T) scopeOf, List<String> order) {
  if (order.isEmpty) return items;
  final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
  final slots = [for (var i = 0; i < items.length; i++) if (rank.containsKey(scopeOf(items[i]))) i];
  final ranked = [for (final i in slots) items[i]]..sort((a, b) => rank[scopeOf(a)]!.compareTo(rank[scopeOf(b)]!));
  final out = [...items];
  for (var k = 0; k < slots.length; k++) {
    out[slots[k]] = ranked[k];
  }
  return out;
}

/// 画面に出すための構成 (D-439: 表示モード / セクション)。一時変更 (D-338) があればそれ。保存が無ければ null(= 通常 TL・枠なし)。
/// 置き場は TimelineConfigScreen と同じ(ノード TL は持ち主 / 共有の領域)。
final tlViewConfigProvider = Provider.family<TlConfig?, String>((ref, scope) {
  final temp = ref.watch(tlTemporaryConfigsProvider)[scope];
  if (temp != null) return temp;
  String? account = ref.watch(currentAccountProvider)?.key;
  if (scope == 'tl.bundle') account = null;
  if (scope.startsWith('tl.node:')) {
    if (ref.watch(sharedNodeTabsProvider).any((t) => 'tl.${t.id}' == scope)) {
      account = null;
    } else {
      account = ref.watch(allNodeTabsProvider).where((t) => 'tl.${t.$2.id}' == scope).firstOrNull?.$1 ?? account;
    }
  }
  final raw = ref.watch(settingsAreaProvider(nodeprogAreaFor(account, scope))).value?['tlcfg'];
  if (raw is! String) return null;
  try {
    return TlConfig.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
  } catch (_) {
    return null;
  }
});
