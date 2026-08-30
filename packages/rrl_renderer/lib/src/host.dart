import 'package:flutter/widgets.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rrl_core/rrl_core.dart';

import 'geometry.dart';
import 'registry.dart';

/// Callback for events leaving the renderer: the host wraps these into
/// `event { nodeId, kind, payload }` boundary messages (PROTOCOL §3.2).
/// [fn] is the plugin function name declared in the node's `on` map — it is
/// passed along for logging, the plugin resolves it itself.
typedef RrlEventSink = void Function(String nodeId, String kind, {String? fn, Map<String, Object?> payload});

/// Everything the renderer needs from the host for one plugin instance.
class RrlHost {
  RrlHost({
    required this.instanceScope,
    required this.scope,
    this.onEvent,
    this.rslParser,
    this.slots = const {},
    this.components = const {},
    this.geometry,
  });

  /// `pluginId:accountKey:pluginVersion:instanceId` — prefixed to explicit
  /// keys to form nodeIds for outgoing events.
  final String instanceScope;

  /// Root Bind scope (`$.post`, `$.actions`, `$.actionStates` …): the host
  /// Store's props view. The renderer never talks to the Store directly.
  final RrlScope scope;

  final RrlEventSink? onEvent;

  /// RSL parser for `RichText` sources (URL/@mention/#tag/:emoji:). The app
  /// injects `InlineSpans.parse`; the default renders plain text.
  final List<RasqSpan> Function(String source)? rslParser;

  /// Named host slots for `Slot` nodes.
  final Map<String, Widget> slots;

  /// Extra / overriding L2 builders, merged over [RrlComponentRegistry.standard].
  final Map<String, RrlComponentBuilder> components;

  /// 実物ジオメトリの登録簿 (D-072): 指定すると `role` 付きノードの矩形を
  /// 引けるようになる(FOW の実物アンカー / `geometry.lookup`)。安定した
  /// インスタンス(コントローラ等の持ち物)を渡すこと — RrlHost 自体は
  /// ビルド毎に作り直されてよい。
  final RrlGeometryRegistry? geometry;

  String nodeId(RrlNode node, RrlScope scope) => '$instanceScope:${scope.resolveTemplate(node.k ?? '#${node.t}')}';

  void emit(RrlNode node, RrlScope scope, String kind, [Map<String, Object?> payload = const {}]) {
    final fn = node.on[kind];
    onEvent?.call(nodeId(node, scope), kind, fn: fn, payload: payload);
  }

  List<RasqSpan> parseRsl(String source) => rslParser?.call(source) ?? [RasqTextSpan(source)];
}
