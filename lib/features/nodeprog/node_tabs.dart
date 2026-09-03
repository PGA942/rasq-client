import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../settings/settings_dsl.dart';
import 'node_graph.dart';

/// ユーザーが作ったノード TL タブ (D-101)。ノードエディタの「+」で追加し、
/// ホームのタブ列に `node:<id>` として並ぶ。中身はノードグラフ
/// (`nodeprog.…tl.node:<id>`)の実行結果。
@immutable
class NodeTab {
  const NodeTab({required this.id, required this.label});

  /// タイムライン id(`node:<連番>`)。スコープは `tl.<id>`。
  final String id;
  final String label;

  Map<String, Object?> toJson() => {'id': id, 'label': label};
  factory NodeTab.fromJson(Map<String, Object?> j) => NodeTab(id: j['id'] as String, label: j['label'] as String? ?? 'ノードTL');
}

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

List<NodeTab> _decodeTabs(Map<String, Object?> area) {
  final raw = area['list'];
  if (raw is! String) return const [];
  try {
    return [for (final j in (jsonDecode(raw) as List)) NodeTab.fromJson((j as Map).cast<String, Object?>())];
  } catch (_) {
    return const [];
  }
}

/// 現在アカウントのタブ一覧(旧グローバル保存は読み取りフォールバック)。
final nodeTabsProvider = Provider<List<NodeTab>>((ref) {
  final acc = ref.watch(currentAccountProvider)?.key;
  final own = _decodeTabs(ref.watch(settingsAreaProvider(nodeprogAreaFor(acc, 'tabs'))).value ?? const {});
  if (own.isNotEmpty || acc == null) return own;
  return _decodeTabs(ref.watch(settingsAreaProvider('nodeprog.tabs')).value ?? const {});
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
  return out;
});

/// バンドル(総合表示)でノード TL タブを集合表示するか (D-108)。
/// ノードエディタの … メニューで切り替える。既定はオン。
final bundleNodeTabsVisibleProvider =
    Provider<bool>((ref) => (ref.watch(settingsAreaProvider('nodeprog.prefs')).value ?? const {})['bundleTabs'] != false);

Future<void> saveNodeTabs(WidgetRef ref, List<NodeTab> tabs) {
  final acc = ref.read(currentAccountProvider)?.key;
  return ref.read(settingsAreaProvider(nodeprogAreaFor(acc, 'tabs')).notifier).set('list', jsonEncode([for (final t in tabs) t.toJson()]));
}
