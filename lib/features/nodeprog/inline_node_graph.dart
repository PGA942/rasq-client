import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../settings/settings_dsl.dart';
import 'node_canvas.dart';
import 'node_editor_screen.dart' show nodeCatalogProvider;
import 'node_graph.dart';
import 'node_tabs.dart';

/// インラインのノード表示 (D-234): RAi のチャットなど別の画面の中に、スコープのグラフを 80% で描く
/// (見るだけ + パン)。右上の「拡大」で全画面のノードエディタへ。高さは画面の半分、幅は親の 80%。
class InlineNodeGraph extends ConsumerStatefulWidget {
  const InlineNodeGraph({super.key, required this.scope, this.accountKey, this.scale = 0.8, this.widthFactor = 0.8, this.heightFactor = 0.5});
  final String scope;
  final String? accountKey;
  final double scale;
  final double widthFactor;
  final double heightFactor;

  @override
  ConsumerState<InlineNodeGraph> createState() => _InlineNodeGraphState();
}

class _InlineNodeGraphState extends ConsumerState<InlineNodeGraph> {
  NodeGraph? _graph;
  Offset _pan = Offset.zero;
  bool _fitted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await readNodeGraphRaw((a) => ref.read(settingsAreaProvider(a).future), widget.accountKey, widget.scope);
    if (!mounted) return;
    NodeGraph g = const NodeGraph();
    if (raw != null) {
      try {
        g = NodeGraph.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
      } catch (_) {}
    }
    final catalog = {for (final e in ref.read(nodeCatalogProvider)) e.type: e};
    setState(() => _graph = upgradeGraphNodes(g, catalog));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final g = _graph;
    final screen = MediaQuery.sizeOf(context);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth * widget.widthFactor : 320.0;
      final h = screen.height * widget.heightFactor;
      // 初回は全体が見える位置へ(左上に少し余白)。
      if (g != null && !_fitted) {
        final b = NodeGeometry.bounds(g);
        if (b != null) _pan = Offset(12 - b.left * widget.scale, 12 - b.top * widget.scale);
        _fitted = true;
      }
      final catalog = {for (final e in ref.watch(nodeCatalogProvider)) e.type: e};
      return SizedBox(
        key: const ValueKey('inline.nodes'),
        width: w,
        height: h,
        child: Material(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            if (g == null)
              const Center(child: RasqLoading())
            else
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) => setState(() => _pan += d.delta),
                  child: NodeGraphCanvas(graph: g, pan: _pan, scale: widget.scale, iconOf: (n) => catalog[n.type]?.icon ?? Icons.extension_outlined),
                ),
              ),
            if (g != null && g.nodes.isEmpty) const Center(child: Text('ノードがありません', style: RasqTypography.caption)),
            Positioned(
              top: 4,
              right: 4,
              child: RasqIconButton(
                key: const ValueKey('inline.nodes.expand'),
                icon: Icons.open_in_full,
                size: 18,
                tooltip: '全画面で編集',
                onPressed: () => ref.read(routerProvider).push(Routes.nodes(widget.scope)),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 4,
              child: Text('${widget.scope} · ${(widget.scale * 100).round()}%', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ]),
        ),
      );
    });
  }
}
