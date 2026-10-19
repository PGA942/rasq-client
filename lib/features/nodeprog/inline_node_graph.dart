import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../settings/settings_dsl.dart';
import 'node_canvas.dart';
import 'node_editor_screen.dart' show nodeCatalogProvider;
import 'node_graph.dart';
import 'node_tabs.dart';

/// インラインのノード表示 (D-234): RAi のチャットなど別の画面の中に、スコープのグラフを 80% で描く
/// (見るだけ + パン)。右上の「拡大」で全画面のノードエディタへ。高さは画面の半分、幅は親の 80%。
class InlineNodeGraph extends ConsumerStatefulWidget {
  const InlineNodeGraph({super.key, this.scope, this.accountKey, this.graph, this.iconOf, this.caption, this.scale = 0.8, this.widthFactor = 0.8, this.heightFactor = 0.5});

  /// 読むスコープ(`tl.home` など)。[graph] を直接渡すときは null でよい(拡大ボタンは出ない)。
  final String? scope;
  final String? accountKey;

  /// 直接描くグラフ(工程グラフ、D-236)。
  final NodeGraph? graph;
  final IconData Function(GraphNode n)? iconOf;
  final String? caption;
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
    if (widget.graph != null) {
      _graph = widget.graph;
    } else {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant InlineNodeGraph old) {
    super.didUpdateWidget(old);
    if (widget.graph != null && widget.graph != old.graph) {
      _graph = widget.graph;
      _fitted = false;
    }
  }

  Future<void> _load() async {
    final scope = widget.scope;
    if (scope == null) return;
    final raw = await readNodeGraphRaw((a) => ref.read(settingsAreaProvider(a).future), widget.accountKey, scope);
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
        key: ValueKey(widget.scope == null ? 'inline.nodes.graph' : 'inline.nodes'),
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
                  child: NodeGraphCanvas(graph: g, pan: _pan, scale: widget.scale, iconOf: (n) => widget.iconOf?.call(n) ?? catalog[n.type]?.icon ?? Icons.extension_outlined),
                ),
              ),
            if (g != null && g.nodes.isEmpty) Center(child: Text(context.l10n.nodeprogEditorInlineEmpty, style: RasqTypography.caption)),
            if (widget.scope != null)
              Positioned(
                top: 4,
                right: 4,
                child: RasqIconButton(
                  key: const ValueKey('inline.nodes.expand'),
                  icon: Icons.open_in_full,
                  size: 18,
                  tooltip: context.l10n.nodeprogEditorInlineExpandTooltip,

                  onPressed: () => ref.read(routerProvider).push(Routes.nodes(widget.scope!)),
                ),
              ),
            Positioned(
              left: 8,
              bottom: 4,
              child: Text('${widget.caption ?? widget.scope ?? ''} · ${(widget.scale * 100).round()}%', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ]),
        ),
      );
    });
  }
}
