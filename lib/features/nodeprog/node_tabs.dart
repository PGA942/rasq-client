import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import '../settings/settings_dsl.dart';
import 'node_graph.dart';

/// ユーザーが作ったノード TL タブ (D-101)。ノードエディタの「+」で追加し、
/// ホームのタブ列に `node:<id>` として並ぶ。中身はノードグラフ
/// (`nodeprog.…tl.node:<id>`)の実行結果。
///
/// D-384: **共有**のタブ([shared])はすべてのアカウントに並び、構成(`tlcfg` / `graph`)はアカウントに依らない領域
/// (`nodeprog.<scope>`、[nodeprogAreaFor] の `null`)に 1 つだけ持つ。一覧は [sharedNodeTabsArea]。
/// SNS プラグインの既定の TL と関連 TL は対象外(ユーザーが作ったタブだけ)。
@immutable
class NodeTab {
  const NodeTab({required this.id, required this.label, this.shared = false});

  /// タイムライン id(`node:<連番>`)。スコープは `tl.<id>`。
  final String id;
  final String label;

  /// すべてのアカウントで共有 (D-384)。
  final bool shared;

  NodeTab copyWith({String? label, bool? shared}) => NodeTab(id: id, label: label ?? this.label, shared: shared ?? this.shared);

  Map<String, Object?> toJson() => {'id': id, 'label': label};
  factory NodeTab.fromJson(Map<String, Object?> j, {bool shared = false}) => NodeTab(id: j['id'] as String, label: j['label'] as String? ?? appL10n.nodeprogEditorNodeTabDefaultLabel
, shared: shared);
}

/// 共有のタブの一覧 (D-384)。
const sharedNodeTabsArea = 'nodeprog.shared.tabs';

/// ノードプロファイルのアカウント分離 (D-108): グラフ/タブ/storage.safe は
/// アカウントごとの KV 領域に置く。アカウント無し(未ログイン)と旧保存は
/// 従来のグローバル領域(読み取りフォールバック)。
String nodeprogAreaFor(String? accountKey, String scope) =>
    (accountKey == null || accountKey.isEmpty) ? 'nodeprog.$scope' : 'nodeprog.$accountKey.$scope';

/// storage.safe (D-104/D-108) のアカウント別領域。
String storageSafeAreaFor(String? accountKey) => (accountKey == null || accountKey.isEmpty) ? 'storage.safe' : 'storage.safe.$accountKey';

/// グラフの raw JSON をアカウント領域 → 旧グローバル領域の順で読む。
Future<String?> readNodeGraphRaw(Future<Map<String, Object?>> Function(String area) readArea, String? accountKey, String scope) async {
  final own = (await readArea(nodeprogAreaFor(accountKey, scope)))['graph'];
  if (own is String) return own;
  if (accountKey != null && accountKey.isNotEmpty) {
    final legacy = (await readArea('nodeprog.$scope'))['graph'];
    if (legacy is String) return legacy;
  }
  return null;
}

/// カスタム関数の中身グラフ (D-118)。関数定義(`nodeprog.functions`)と
/// 同じくグローバル領域(スコープ = 関数 id `fn:<連番>`)。無い/壊れている
/// 場合は null(実行側は素通しになる)。
Future<NodeGraph?> loadFunctionBody(Future<Map<String, Object?>> Function(String area) readArea, String fnId) async {
  final raw = await readNodeGraphRaw(readArea, null, fnId);
  if (raw == null) return null;
  try {
    return NodeGraph.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
  } catch (_) {
    return null;
  }
}

List<NodeTab> _decodeTabs(Map<String, Object?> area, {bool shared = false}) {
  final raw = area['list'];
  if (raw is! String) return const [];
  try {
    return [for (final j in (jsonDecode(raw) as List)) NodeTab.fromJson((j as Map).cast<String, Object?>(), shared: shared)];
  } catch (_) {
    return const [];
  }
}

/// このアカウントだけのタブ(旧グローバル保存は読み取りフォールバック)。
final ownNodeTabsProvider = Provider<List<NodeTab>>((ref) {
  final acc = ref.watch(currentAccountProvider)?.key;
  final own = _decodeTabs(ref.watch(settingsAreaProvider(nodeprogAreaFor(acc, 'tabs'))).value ?? const {});
  if (own.isNotEmpty || acc == null) return own;
  return _decodeTabs(ref.watch(settingsAreaProvider('nodeprog.tabs')).value ?? const {});
});

/// 共有のタブ (D-384)。
final sharedNodeTabsProvider = Provider<List<NodeTab>>((ref) => _decodeTabs(ref.watch(settingsAreaProvider(sharedNodeTabsArea)).value ?? const {}, shared: true));

/// 現在アカウントのタブ一覧 = このアカウントだけのもの + 共有のもの。
final nodeTabsProvider = Provider<List<NodeTab>>((ref) {
  final own = ref.watch(ownNodeTabsProvider);
  final ids = {for (final t in own) t.id};
  return [...own, for (final t in ref.watch(sharedNodeTabsProvider)) if (!ids.contains(t.id)) t];
});

/// 全アカウント分のタブ (D-108: バンドルの集合表示用)。(アカウントキー, タブ)。
final allNodeTabsProvider = Provider<List<(String, NodeTab)>>((ref) {
  final sessions = ref.watch(sessionsProvider).value?.sessions ?? const [];
  final current = ref.watch(currentAccountProvider)?.key;
  final out = <(String, NodeTab)>[];
  final seen = <String>{};
  for (final s in sessions) {
    final key = s.account.key;
    var tabs = _decodeTabs(ref.watch(settingsAreaProvider(nodeprogAreaFor(key, 'tabs'))).value ?? const {});
    if (tabs.isEmpty && key == current) {
      tabs = _decodeTabs(ref.watch(settingsAreaProvider('nodeprog.tabs')).value ?? const {}); // 旧保存
    }
    for (final t in tabs) {
      if (seen.add(t.id)) out.add((key, t));
    }
  }
  // 共有のタブ (D-384) は、いまのアカウントのものとして 1 回だけ。
  for (final t in ref.watch(sharedNodeTabsProvider)) {
    if (seen.add(t.id)) out.add((current ?? '', t));
  }
  return out;
});

/// バンドル(総合表示)でノード TL タブを集合表示するか (D-108)。
/// ノードエディタの … メニューで切り替える。既定はオン。
final bundleNodeTabsVisibleProvider =
    Provider<bool>((ref) => (ref.watch(settingsAreaProvider('nodeprog.prefs')).value ?? const {})['bundleTabs'] != false);

/// タブを保存する。共有のものは共有の一覧へ、ほかはこのアカウントの一覧へ振り分ける。
Future<void> saveNodeTabs(WidgetRef ref, List<NodeTab> tabs) async {
  final acc = ref.read(currentAccountProvider)?.key;
  await ref.read(settingsAreaProvider(nodeprogAreaFor(acc, 'tabs')).notifier).set('list', jsonEncode([for (final t in tabs) if (!t.shared) t.toJson()]));
  // [tabs] は一覧の全部(このアカウントのものと共有のもの)。
  await ref.read(settingsAreaProvider(sharedNodeTabsArea).notifier).set('list', jsonEncode([for (final t in tabs) if (t.shared) t.toJson()]));
}

/// そのスコープの構成の置き場(共有のタブはアカウントに依らない、D-384)。
String nodeTabAreaFor(WidgetRef ref, String scope, {String? accountKey}) {
  final shared = ref.read(sharedNodeTabsProvider).any((t) => 'tl.${t.id}' == scope);
  return nodeprogAreaFor(shared ? null : (accountKey ?? ref.read(currentAccountProvider)?.key), scope);
}

/// 共有する / やめる (D-384)。構成も置き場を移す。やめるときは、いまのアカウントのタブになる(ほかのアカウントからは消える)。
Future<void> setNodeTabShared(WidgetRef ref, String id, bool shared) async {
  final tabs = ref.read(nodeTabsProvider);
  final cur = tabs.where((t) => t.id == id).firstOrNull;
  if (cur == null || cur.shared == shared) return;
  final scope = 'tl.$id';
  final acc = ref.read(currentAccountProvider)?.key;
  final from = nodeprogAreaFor(shared ? acc : null, scope);
  final to = nodeprogAreaFor(shared ? null : acc, scope);
  final src = await ref.read(settingsAreaProvider(from).future);
  final dst = ref.read(settingsAreaProvider(to).notifier);
  for (final k in const ['tlcfg', 'graph']) {
    await dst.set(k, src[k]);
  }
  final old = ref.read(settingsAreaProvider(from).notifier);
  for (final k in const ['tlcfg', 'graph']) {
    await old.set(k, null);
  }
  await saveNodeTabs(ref, [for (final t in tabs) t.id == id ? t.copyWith(shared: shared) : t]);
}
