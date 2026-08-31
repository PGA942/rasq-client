import 'package:rasq_models/rasq_models.dart';

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
}
