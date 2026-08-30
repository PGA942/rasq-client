import 'package:flutter/widgets.dart';

/// `role` 付きノードの実物ジオメトリの登録簿 (D-072)。
///
/// FOW の**実物アクションバーへのアンカー**(`fow.open` の `anchor`)と、
/// ホスト関数 `geometry.lookup`(RAi の位置検索・アクセシビリティ)の土台。
/// ホスト(プラグインコントローラ等)が 1 インスタンスを持ち [RrlHost] に
/// 渡す — レンダラーは `role` を持つノードを登録し、矩形は**呼ばれた
/// 時点の RenderBox** から解決する(スクロール追従のため保存しない)。
class RrlGeometryRegistry {
  final Map<String, (String role, BuildContext context)> _nodes = {};

  void register(String nodeId, String role, BuildContext context) => _nodes[nodeId] = (role, context);

  void unregister(String nodeId, BuildContext context) {
    final cur = _nodes[nodeId];
    if (cur != null && identical(cur.$2, context)) _nodes.remove(nodeId);
  }

  /// [nodeId] 完全一致(または [role] 一致の最初のノード)の現在の矩形
  /// (グローバル座標)。画面から外れている/未レイアウトなら null。
  Rect? lookup({String? nodeId, String? role}) {
    for (final e in _nodes.entries) {
      if (nodeId != null && e.key != nodeId) continue;
      if (role != null && e.value.$1 != role) continue;
      final ctx = e.value.$2;
      if (!ctx.mounted) continue;
      final obj = ctx.findRenderObject();
      if (obj is RenderBox && obj.attached && obj.hasSize) {
        return obj.localToGlobal(Offset.zero) & obj.size;
      }
    }
    return null;
  }
}

/// レンダラーが `role` 付きノードに被せる登録ウィジェット。
class RrlGeometryTag extends StatefulWidget {
  const RrlGeometryTag({super.key, required this.registry, required this.nodeId, required this.role, required this.child});
  final RrlGeometryRegistry registry;
  final String nodeId;
  final String role;
  final Widget child;

  @override
  State<RrlGeometryTag> createState() => _RrlGeometryTagState();
}

class _RrlGeometryTagState extends State<RrlGeometryTag> {
  @override
  void initState() {
    super.initState();
    widget.registry.register(widget.nodeId, widget.role, context);
  }

  @override
  void didUpdateWidget(RrlGeometryTag old) {
    super.didUpdateWidget(old);
    if (old.nodeId != widget.nodeId || !identical(old.registry, widget.registry)) {
      old.registry.unregister(old.nodeId, context);
      widget.registry.register(widget.nodeId, widget.role, context);
    }
  }

  @override
  void dispose() {
    widget.registry.unregister(widget.nodeId, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
