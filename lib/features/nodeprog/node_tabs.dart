import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_dsl.dart';

/// ユーザーが作ったノード TL タブ (D-101)。ノードエディタの「+」で追加し、
/// ホームのタブ列に `node:<id>` として並ぶ。中身はノードグラフ
/// (`nodeprog.tl.node:<id>`)の実行結果。
@immutable
class NodeTab {
  const NodeTab({required this.id, required this.label});

  /// タイムライン id(`node:<連番>`)。スコープは `tl.<id>`。
  final String id;
  final String label;

  Map<String, Object?> toJson() => {'id': id, 'label': label};
  factory NodeTab.fromJson(Map<String, Object?> j) => NodeTab(id: j['id'] as String, label: j['label'] as String? ?? 'ノードTL');
}

/// タブ一覧(KV `nodeprog.tabs.v1` の `list`)。
final nodeTabsProvider = Provider<List<NodeTab>>((ref) {
  final area = ref.watch(settingsAreaProvider('nodeprog.tabs')).value ?? const <String, Object?>{};
  final raw = area['list'];
  if (raw is! String) return const [];
  try {
    return [for (final j in (jsonDecode(raw) as List)) NodeTab.fromJson((j as Map).cast<String, Object?>())];
  } catch (_) {
    return const [];
  }
});

Future<void> saveNodeTabs(WidgetRef ref, List<NodeTab> tabs) =>
    ref.read(settingsAreaProvider('nodeprog.tabs').notifier).set('list', jsonEncode([for (final t in tabs) t.toJson()]));
