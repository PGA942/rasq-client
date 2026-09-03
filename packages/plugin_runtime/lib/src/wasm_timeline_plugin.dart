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

/// 上付きバナー行 (D-085): RT 行(♻︎ 〇〇がリノートしました)と同スタイルの
/// 「アイコン名 + テキスト」。アイコン名はホストのアイコンレジストリで解決。
class TimelineBadge {
  const TimelineBadge({this.icon, required this.text});
  final String? icon;
  final String text;
}

/// `tl.customize` の結果 (D-082/D-085)。
class TimelineDecorations {
  const TimelineDecorations({this.tiles = const {}, this.badges = const {}});

  /// 完全置き換えタイル(V5 検証済み)。
  final Map<String, RrlNode> tiles;

  /// 上付きバナー行(通常タイルに足す)。
  final Map<String, TimelineBadge> badges;
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

  /// 投稿カスタマイザ (D-082/D-085): `tl.customize {id, posts}` →
  /// `{tiles: {postId: RRL Node}, badges: {postId: {icon?, text}}}`。
  /// - `tiles` = 完全置き換えタイル(replace_tile)。**V5 検証ゲート**:
  ///   必須ロール `contentBody` を含まないタイルは破棄して通常タイルに縮退。
  /// - `badges` (D-085) = **上付きバナー行**(RT の「♻︎ 〇〇がリノート
  ///   しました」と同スタイル)。通常タイルのままアイコン名 + テキスト
  ///   だけ足す軽量な口。
  /// 未実装/失敗は空。
  Future<TimelineDecorations> customize(String id, List<Post> posts) async {
    try {
      final value = await _call('tl.customize', {'id': id, 'posts': [for (final p in posts) SnsWire.post(p)]});
      final tiles = (value['tiles'] as Map?)?.cast<String, Object?>() ?? const {};
      final outTiles = <String, RrlNode>{};
      for (final e in tiles.entries) {
        if (e.value is! Map) continue;
        final node = RrlNode.fromJson((e.value as Map).cast<String, Object?>());
        if (!node.containsRole('contentBody')) {
          debugPrint('tl.customize: V5 違反(contentBody 無し)のタイルを破棄: ${e.key}');
          continue;
        }
        outTiles[e.key] = node;
      }
      final badges = (value['badges'] as Map?)?.cast<String, Object?>() ?? const {};
      final outBadges = <String, TimelineBadge>{
        for (final e in badges.entries)
          if (e.value is Map) e.key: TimelineBadge(icon: (e.value as Map)['icon'] as String?, text: '${(e.value as Map)['text'] ?? ''}'),
      };
      return TimelineDecorations(tiles: outTiles, badges: outBadges);
    } catch (_) {
      return const TimelineDecorations();
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

  /// 投稿加工プラグイン (D-083 transform_content): `post.transform {posts}`
  /// → `{posts: {postId: {body?, cw?}}}` — 表示前に本文/注釈を差し替える
  /// (**全 TL 共通**。タイル構造は変えない — 構造は tl.customize の領分)。
  /// 未実装/失敗はそのまま返す。
  Future<List<Post>> transform(List<Post> posts) async {
    try {
      final value = await _call('post.transform', {'posts': [for (final p in posts) SnsWire.post(p)]});
      final patches = (value['posts'] as Map?)?.cast<String, Object?>() ?? const {};
      if (patches.isEmpty) return posts;
      return [
        for (final p in posts)
          if (patches[p.id] is Map)
            p.copyWith(
              body: ((patches[p.id] as Map)['body'] as String?),
              contentWarning: ((patches[p.id] as Map)['cw'] as String?),
            )
          else
            p,
      ];
    } catch (_) {
      return posts;
    }
  }
}
