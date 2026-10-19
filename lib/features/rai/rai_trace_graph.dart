import 'package:flutter/material.dart';

import '../nodeprog/inline_node_graph.dart';
import '../nodeprog/node_graph.dart';
import 'rai_automation.dart';
import '../../l10n/l10n.dart';

/// 工程グラフ (D-236): 自動化の工程([RaiAutoStep] の列)をノードにして描く。手順 = ノード(見出しに番号と
/// 状態の印、値ボックスに 関数 / 結果)、順に「工程」型の辺で繋ぐ。配置は [tidyGraph](左から右)。
NodeGraph raiTraceToGraph(List<RaiAutoStep> trace) {
  final nodes = <GraphNode>[];
  final edges = <GraphEdge>[];
  for (final (i, s) in trace.indexed) {
    final mark = switch (s.status) {
      RaiAutoStatus.done => '✓',
      RaiAutoStatus.skipped => '⤵',
      RaiAutoStatus.guide => '👉',
      RaiAutoStatus.failed => '✗',
      RaiAutoStatus.asking => '?',
      _ => '·',
    };
    final title = s.text.length > 22 ? '${s.text.substring(0, 22)}…' : s.text;
    nodes.add(GraphNode(
      id: 's${s.index}',
      type: 'rai.step',
      title: '$mark ${s.index + 1}. $title',
      x: i * 250.0,
      y: 0,
      inputs: [
        NodePort(label: appL10n.raiTracePortPrev, dataType: '工程'), // l10n-ignore
        NodePort(label: appL10n.raiTracePortState, value: raiAutoStatusLabel(s.status), dataType: '設定'), // l10n-ignore
        if (s.binding != null) NodePort(label: appL10n.raiTracePortFunction, value: s.binding!.call, dataType: '設定'), // l10n-ignore
        if (s.detail.isNotEmpty) NodePort(label: appL10n.raiTracePortResult, value: s.detail.length > 40 ? '${s.detail.substring(0, 40)}…' : s.detail, dataType: '設定'), // l10n-ignore
      ],
      outputs: [NodePort(label: appL10n.raiTracePortNext, dataType: '工程')], // l10n-ignore
    ));
    if (i > 0) edges.add(GraphEdge(from: 's${trace[i - 1].index}', fromPort: 0, to: 's${s.index}', toPort: 0));
  }
  return tidyGraph(NodeGraph(nodes: nodes, edges: edges));
}

String raiAutoStatusLabel(RaiAutoStatus s) => switch (s) {
      RaiAutoStatus.done => appL10n.raiTraceStatusDone,
      RaiAutoStatus.skipped => appL10n.raiTraceStatusSkipped,
      RaiAutoStatus.guide => appL10n.raiTraceStatusGuide,
      RaiAutoStatus.failed => appL10n.raiTraceStatusFailed,
      RaiAutoStatus.asking => appL10n.raiTraceStatusAsking,
      RaiAutoStatus.running => appL10n.raiTraceStatusRunning,
      RaiAutoStatus.pending => appL10n.raiTraceStatusPending,
    };

IconData raiTraceIcon(GraphNode n) {
  final t = n.title;
  if (t.startsWith('✓')) return Icons.check_circle_outline;
  if (t.startsWith('⤵')) return Icons.subdirectory_arrow_right;
  if (t.startsWith('👉')) return Icons.touch_app_outlined;
  if (t.startsWith('✗')) return Icons.error_outline;
  return Icons.radio_button_unchecked;
}

/// 工程グラフの表示(インラインのノード表示と同じ枠、80%)。
class RaiTraceGraph extends StatelessWidget {
  const RaiTraceGraph({super.key, required this.trace});
  final List<RaiAutoStep> trace;
  @override
  Widget build(BuildContext context) => InlineNodeGraph(graph: raiTraceToGraph(trace), iconOf: raiTraceIcon, caption: context.l10n.raiTraceCaption(trace.length));
}
