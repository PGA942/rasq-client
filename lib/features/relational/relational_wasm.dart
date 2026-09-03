import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';

import 'relational_engine.dart';

/// 関連TL エンジンの wasm 移植 (M5f / D-084)。
///
/// **特別枠**: ストア配布の TL プラグインではなく RASQ 同梱の公式モジュール
/// (`assets/plugins/relational_wasm.wasm`、rasq-sdk-sample/rust/relational-wasm)。
/// アカウントバンドルに含まれる全アカウントの TL 系を見る前提の口 —
/// v1 は現在アカウントの HTL + ゲスト。入力はタグ規約 (PROTOCOL §2.2) 経由で
/// ホストが抽出した最小ワイヤ(`rasq.relational-post/1`)なので SNS 非依存:
/// `{key, authorKey, repostedByKey?, createdAtMs, body, quoteBody?, linkUrl?, quoteKey?}`
final relationalWasmProvider = FutureProvider<AsyncWasmPluginController?>((ref) async {
  try {
    final bytes = (await rootBundle.load('assets/plugins/relational_wasm.wasm')).buffer.asUint8List();
    final c = AsyncWasmPluginController(wasmBytes: bytes, nativeFetch: false);
    await c.load();
    ref.onDispose(c.dispose);
    return c;
  } catch (e) {
    debugPrint('relational wasm load: $e'); // 不達は Dart エンジンに縮退
    return null;
  }
});

/// Post → 関連TL 入力ワイヤ(最小)。本文/引用の抽出はホストの責務
/// (wasm SNS プラグイン由来の投稿もタグ規約で同じ形になる)。
Map<String, Object?> relationalPostWire(Post p) => {
      'key': p.key,
      'authorKey': p.author.key,
      'repostedByKey': ?p.repostedBy?.key,
      'createdAtMs': p.createdAt.millisecondsSinceEpoch,
      'body': p.body,
      'quoteBody': ?p.quote?.body,
      'linkUrl': ?p.linkUrl?.toString(),
      'quoteKey': ?p.quote?.key,
    };

/// wasm エンジンで会話イベントを組む。結果の postKeys(時系列順)から
/// ホスト側の [ConversationEvent] を復元する(UI はそのまま使える)。
Future<List<ConversationEvent>> buildEventsViaWasm(
  AsyncWasmPluginController controller, {
  required List<Post> followees,
  required List<Post> guests,
  required RelationalSettings settings,
  required DateTime now,
  Duration? lookback,
}) async {
  final result = await controller.invoke('relational.build', {
    'posts': [for (final p in followees) relationalPostWire(p)],
    'guests': [for (final p in guests) relationalPostWire(p)],
    'settings': settings.toJson(),
    'nowMs': now.millisecondsSinceEpoch,
    'lookbackMinutes': ?lookback?.inMinutes,
  });
  if (result['ok'] != true) {
    throw StateError('relational.build failed: ${result['error']}');
  }
  final byKey = {for (final p in [...followees, ...guests]) p.key: p};
  final events = <ConversationEvent>[];
  for (final e in ((result['value'] as Map)['events'] as List? ?? const [])) {
    final keys = [for (final k in ((e as Map)['postKeys'] as List? ?? const [])) '$k'];
    final posts = [for (final k in keys) if (byKey[k] != null) byKey[k]!];
    if (posts.length < 2) continue;
    final event = ConversationEvent.root(posts.first);
    for (final p in posts.skip(1)) {
      event.add(p);
    }
    events.add(event);
  }
  return events;
}
