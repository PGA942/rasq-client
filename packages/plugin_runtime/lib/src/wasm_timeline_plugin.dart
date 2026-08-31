import 'package:flutter/foundation.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rrl_core/rrl_core.dart';

import 'wasm_sns_session.dart';

/// カスタム TL の宣言 (D-080: `tl.timelines` の 1 エントリ)。
class CustomTimelineSpec {
  const CustomTimelineSpec({required this.id, required this.label, required this.base});

  /// プラグインローカルの TL id(ホストは `custom:` を前置してタブ化)。
  final String id;

  /// タブ表記。
  final String label;

  /// ホストが餌にする基礎 TL(`home` / `local` …)。**データ取得はホスト
  /// (SNS セッション)の仕事** — TL プラグインは並べ替えと除外だけを持つ。
  final String base;
}

/// タイムラインレンダラー契約 v1 のホスト側アダプター (M5e / D-080)。
///
/// 基本思想の「TL プラグイン = Widget コンポーネント + ソートアルゴリズム +
/// 投稿カスタマイザ」のうち、v1 は**宣言とソートアルゴリズム**:
/// - `tl.timelines {}` → `{timelines: [{id, label, base}]}`
/// - `tl.sort {id, posts: [Post ワイヤ]}` → `{order: [postId…]}` —
///   表示順の id 列。**載っていない投稿は除外**。`order` 無し = そのまま。
/// 投稿カスタマイザ(replace_tile の RRL)と visible/hidden は次段。
class WasmTimelinePlugin {
  WasmTimelinePlugin({required WasmSnsInvoke invoke, this.extraArgs = const {}}) : _invoke = invoke; // ignore: prefer_initializing_formals

  final WasmSnsInvoke _invoke;
  final Map<String, Object?> extraArgs;

  Future<Map<String, Object?>> _call(String fn, Map<String, Object?> args) async {
    final result = await _invoke(fn, {...args, ...extraArgs});
    if (result['ok'] == true) return (result['value'] as Map? ?? const {}).cast<String, Object?>();
    throw StateError('$fn failed: ${result['error']}');
  }

  /// 宣言されたカスタム TL。未実装プラグイン(C01 等)は空。
  Future<List<CustomTimelineSpec>> timelines() async {
    try {
      final value = await _call('tl.timelines', const {});
      return [
        for (final t in (value['timelines'] as List? ?? const []))
          CustomTimelineSpec(
            id: '${(t as Map)['id']}',
            label: '${t['label'] ?? t['id']}',
            base: '${t['base'] ?? 'home'}',
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// 基礎 TL の投稿をプラグインのソートアルゴリズムへ通す。
  Future<List<Post>> compose(String id, List<Post> posts) async {
    final value = await _call('tl.sort', {'id': id, 'posts': [for (final p in posts) SnsWire.post(p)]});
    final order = value['order'] as List?;
    if (order == null) return posts;
    final byId = {for (final p in posts) p.id: p};
    return [for (final postId in order) if (byId.containsKey('$postId')) byId['$postId']!];
  }

  /// 投稿カスタマイザ (D-082): `tl.customize {id, posts}` →
  /// `{tiles: {postId: RRL Node}}` — 完全置き換えタイル(replace_tile)。
  /// **V5 検証ゲート**: 置き換えタイルは必須ロール `contentBody` を含む
  /// こと — 欠けたタイルは破棄して通常タイルに縮退する。未実装/失敗は {}。
  Future<Map<String, RrlNode>> customize(String id, List<Post> posts) async {
    try {
      final value = await _call('tl.customize', {'id': id, 'posts': [for (final p in posts) SnsWire.post(p)]});
      final tiles = (value['tiles'] as Map?)?.cast<String, Object?>() ?? const {};
      final out = <String, RrlNode>{};
      for (final e in tiles.entries) {
        if (e.value is! Map) continue;
        final node = RrlNode.fromJson((e.value as Map).cast<String, Object?>());
        if (!node.containsRole('contentBody')) {
          debugPrint('tl.customize: V5 違反(contentBody 無し)のタイルを破棄: ${e.key}');
          continue;
        }
        out[e.key] = node;
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  /// 置き換えタイル内のイベント → プラグイン関数(fire-and-forget)。
  void handleEvent(String nodeId, String kind, {String? fn, Map<String, Object?> payload = const {}}) {
    if (fn == null) return;
    _invoke(fn, {'nodeId': nodeId, 'kind': kind, ...payload, ...extraArgs}).catchError((Object e) {
      debugPrint('tl event $fn: $e');
      return <String, dynamic>{};
    });
  }

  /// 仮想化 TL の可視性 (D-082): 行が生成/破棄されたタイミングで
  /// `lifecycle {kind: visible|hidden, surface: tl:<id>, post}` を届ける。
  void notifyVisibility(String id, String postId, {required bool visible}) {
    _invoke('lifecycle', {'kind': visible ? 'visible' : 'hidden', 'surface': 'tl:$id', 'post': postId, ...extraArgs}).catchError((Object _) => <String, dynamic>{});
  }
}
