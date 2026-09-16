import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';

import 'node_graph.dart';

/// ノードキャンバスの描画部 (D-235): エディタ([NodeEditorScreen])と、RAi チャットのインライン表示
/// (D-234、80% 縮小 / 見るだけ)が同じ部品を使う。
///
/// - グラフ座標 → 画面: `screen = graph * scale + pan`。
/// - [interactive] が false のときはカードのジェスチャ(移動 / メニュー / ポートのドラッグ)を切る。
/// - ポート位置の計算([NodeGeometry])はカードのレイアウト定数と一致させる。

/// ノードカードの寸法(ポート位置の計算とカードのレイアウトを一致させる)。
const kNodeW = 190.0;
const kNodeHeaderH = 34.0;
const kNodeSectionH = 18.0;
const kNodeRowH = 26.0;

/// 条件接続部 (D-094) の行高(上辺/下辺の中央ドット)。
const kNodeCondRowH = 14.0;

/// ポート / カードの幾何(グラフ座標)。
abstract final class NodeGeometry {
  static double condInH(GraphNode n) => n.hasCondIn ? kNodeCondRowH : 0.0;

  static double cardHeight(GraphNode n) {
    final inputsBlock = n.inputs.isEmpty ? 0.0 : kNodeSectionH + n.inputs.length * kNodeRowH;
    final outputsBlock = n.outputs.isEmpty ? 0.0 : kNodeSectionH + n.outputs.length * kNodeRowH;
    return condInH(n) + kNodeHeaderH + inputsBlock + outputsBlock + (n.condOutCount > 0 ? kNodeCondRowH : 6.0);
  }

  static Rect cardRect(GraphNode n) => Rect.fromLTWH(n.x, n.y, kNodeW, cardHeight(n));

  static Offset inputCenter(GraphNode n, int i) => Offset(n.x + 10, n.y + condInH(n) + kNodeHeaderH + kNodeSectionH + i * kNodeRowH + kNodeRowH / 2);

  static Offset outputCenter(GraphNode n, int j) {
    final inputsBlock = n.inputs.isEmpty ? 0.0 : kNodeSectionH + n.inputs.length * kNodeRowH;
    return Offset(n.x + kNodeW - 10, n.y + condInH(n) + kNodeHeaderH + inputsBlock + kNodeSectionH + j * kNodeRowH + kNodeRowH / 2);
  }

  /// 条件接続部 (D-094): 上辺の中央/下辺は分岐ごとに等間隔 (D-099)。
  static Offset condInCenter(GraphNode n) => Offset(n.x + kNodeW / 2, n.y + kNodeCondRowH / 2);
  static Offset condOutCenter(GraphNode n, int branch) {
    final count = n.condOutCount.clamp(1, 99);
    return Offset(n.x + kNodeW * (branch + 1) / (count + 1), n.y + cardHeight(n) - kNodeCondRowH / 2);
  }

  /// ヘッダーアイコンの中心 (D-095: クロックの繋ぎ先)。
  static Offset iconCenter(GraphNode n) => Offset(n.x + 17.5, n.y + condInH(n) + kNodeHeaderH / 2);

  /// 全ノードを囲む矩形(空なら null)。
  static Rect? bounds(NodeGraph g) {
    Rect? r;
    for (final n in g.nodes) {
      final c = cardRect(n);
      r = r == null ? c : r.expandToInclude(c);
    }
    return r;
  }
}

/// 接続ドラッグ中の状態(始点ポートと現在位置、**グラフ座標**)。[cond] のときは縦の条件接続で、
/// isOutput=true は下辺(condOut)始まり。
typedef NodePortDrag = ({String node, int port, bool isOutput, bool cond, Offset pos});

/// カードのコールバック(エディタが渡す。インライン表示は null)。
class NodeCanvasCallbacks {
  const NodeCanvasCallbacks({
    required this.onMenu,
    required this.onMove,
    required this.onMoveEnd,
    required this.onEditValue,
    required this.onTapInput,
    required this.onTapCondIn,
    required this.onTapIcon,
    required this.onPortDragStart,
    required this.onCondDragStart,
    required this.onPortDragUpdate,
    required this.onPortDragEnd,
  });
  final void Function(GraphNode n, Offset global) onMenu;
  final void Function(GraphNode n, Offset deltaGraph) onMove;
  final VoidCallback onMoveEnd;
  final void Function(GraphNode n, int index, Rect anchor) onEditValue;
  final void Function(GraphNode n, int index) onTapInput;
  final void Function(GraphNode n) onTapCondIn;
  final void Function(GraphNode n) onTapIcon;
  final void Function(GraphNode n, int index, bool isOutput, Offset global) onPortDragStart;
  final void Function(GraphNode n, bool isOut, int branch, Offset global) onCondDragStart;
  final ValueChanged<Offset> onPortDragUpdate;
  final VoidCallback onPortDragEnd;
}

class NodeGraphCanvas extends StatelessWidget {
  const NodeGraphCanvas({
    super.key,
    required this.graph,
    required this.pan,
    this.scale = 1.0,
    this.selected = const {},
    this.iconOf,
    this.drag,
    this.marquee,
    this.callbacks,
  });

  final NodeGraph graph;

  /// 画面上のずらし(スケール後のピクセル)。
  final Offset pan;
  final double scale;
  final Set<String> selected;
  final IconData Function(GraphNode n)? iconOf;
  final NodePortDrag? drag;

  /// 範囲選択の矩形(グラフ座標、D-235)。
  final Rect? marquee;

  /// null = 見るだけ(インライン表示)。
  final NodeCanvasCallbacks? callbacks;

  bool get interactive => callbacks != null;

  @override
  Widget build(BuildContext context) {
    final cb = callbacks;
    return Stack(clipBehavior: Clip.hardEdge, children: [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: NodeEdgePainter(graph: graph, pan: pan, scale: scale, drag: drag, marquee: marquee)),
        ),
      ),
      for (final n in graph.nodes)
        Positioned(
          left: n.x * scale + pan.dx,
          top: n.y * scale + pan.dy,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: NodeCard(
              node: n,
              icon: iconOf?.call(n) ?? Icons.extension_outlined,
              selected: selected.contains(n.id),
              connectedInputs: {for (final e in graph.edges) if (!e.cond && !e.toIcon && e.to == n.id) e.toPort},
              condInConnected: graph.edges.any((e) => e.cond && e.to == n.id),
              clockConnected: graph.edges.any((e) => e.toIcon && e.to == n.id),
              interactive: interactive,
              onMenu: (g) => cb?.onMenu(n, g),
              onMove: (d) => cb?.onMove(n, d / scale),
              onMoveEnd: () => cb?.onMoveEnd(),
              onEditValue: (i, r) => cb?.onEditValue(n, i, r),
              onTapInput: (i) => cb?.onTapInput(n, i),
              onTapCondIn: () => cb?.onTapCondIn(n),
              onTapIcon: () => cb?.onTapIcon(n),
              onPortDragStart: (i, isOut, g) => cb?.onPortDragStart(n, i, isOut, g),
              onCondDragStart: (isOut, b, g) => cb?.onCondDragStart(n, isOut, b, g),
              onPortDragUpdate: (g) => cb?.onPortDragUpdate(g),
              onPortDragEnd: () => cb?.onPortDragEnd(),
            ),
          ),
        ),
    ]);
  }
}

/// ノードカード (D-092): ヘッダー(移動グリップ + ドロップダウン)、入力 / 出力の行、条件接続部。
/// ポートのドット(データ形式の色)から接続ドラッグ。
class NodeCard extends StatelessWidget {
  const NodeCard({
    super.key,
    required this.node,
    required this.icon,
    required this.selected,
    required this.connectedInputs,
    required this.condInConnected,
    required this.clockConnected,
    this.interactive = true,
    required this.onMenu,
    required this.onMove,
    required this.onMoveEnd,
    required this.onEditValue,
    required this.onTapInput,
    required this.onTapCondIn,
    required this.onTapIcon,
    required this.onPortDragStart,
    required this.onCondDragStart,
    required this.onPortDragUpdate,
    required this.onPortDragEnd,
  });

  final GraphNode node;
  final IconData icon;
  final bool selected;
  final Set<int> connectedInputs;

  /// 上辺の条件接続部に親が付いているか (D-094)。
  final bool condInConnected;

  /// ヘッダーアイコンにクロックが繋がっているか (D-095)。
  final bool clockConnected;

  /// false = 見るだけ(ジェスチャなし、D-234)。
  final bool interactive;

  /// クリック/長押しのドロップダウン(グローバル座標)。
  final ValueChanged<Offset> onMenu;
  final ValueChanged<Offset> onMove;
  final VoidCallback onMoveEnd;
  final void Function(int index, Rect anchor) onEditValue;
  final ValueChanged<int> onTapInput;
  final VoidCallback onTapCondIn;
  final VoidCallback onTapIcon;
  final void Function(int index, bool isOutput, Offset global) onPortDragStart;
  final void Function(bool isOut, int branch, Offset global) onCondDragStart;
  final ValueChanged<Offset> onPortDragUpdate;
  final VoidCallback onPortDragEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final card = Container(
      width: kNodeW,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? tokens.link : scheme.outlineVariant, width: selected ? 1.6 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        // 条件接続部・上辺 (D-094): 親(並べ替え/消去/条件)からの縦接続を受ける。
        if (node.hasCondIn) SizedBox(height: kNodeCondRowH, child: Center(child: _condDot(scheme, isOut: false, filled: condInConnected, onTap: onTapCondIn))),
        // ヘッダー = 移動グリップ + クリック/長押しでドロップダウン (D-092)。
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: interactive ? (d) => onMenu(d.globalPosition) : null,
          onLongPressStart: interactive ? (d) => onMenu(d.globalPosition) : null,
          onPanUpdate: interactive ? (d) => onMove(d.delta) : null,
          onPanEnd: interactive ? (_) => onMoveEnd() : null,
          child: SizedBox(
            height: kNodeHeaderH,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                // アイコン = クロックの繋ぎ先 (D-095)。接続中はクロック色で塗り、タップで切断。
                clockConnected
                    ? GestureDetector(behavior: HitTestBehavior.opaque, onTap: interactive ? onTapIcon : null, child: Icon(icon, size: 15, color: nodeTypeColor('クロック')))
                    : Icon(icon, size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(child: Text(node.title, style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ),
        ),
        if (node.inputs.isNotEmpty) _sectionLabel(scheme, '入力'),
        for (var i = 0; i < node.inputs.length; i++) _inputRow(scheme, i),
        if (node.outputs.isNotEmpty) _sectionLabel(scheme, '出力'),
        for (var j = 0; j < node.outputs.length; j++) _outputRow(scheme, j),
        // 条件接続部・下辺 (D-094/D-099): 分岐ごとのドット(位置はポート座標計算 `condOutCenter` と同じ等間隔)。
        if (node.condOutCount > 0)
          SizedBox(
            height: kNodeCondRowH,
            child: Stack(clipBehavior: Clip.none, children: [
              for (var b = 0; b < node.condOutCount; b++)
                Positioned(left: kNodeW * (b + 1) / (node.condOutCount + 1) - 17, top: 0, child: _condDot(scheme, isOut: true, branch: b, filled: true)),
            ]),
          )
        else
          const SizedBox(height: 6),
      ]),
    );
    return interactive ? card : IgnorePointer(child: card);
  }

  /// 条件接続部のドット(紫、上下方向)。[branch] は下辺の分岐番号。
  Widget _condDot(ColorScheme scheme, {required bool isOut, int branch = 0, bool filled = false, VoidCallback? onTap}) {
    final color = nodeTypeColor('条件');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onPanStart: (d) => onCondDragStart(isOut, branch, d.globalPosition),
      onPanUpdate: (d) => onPortDragUpdate(d.globalPosition),
      onPanEnd: (_) => onPortDragEnd(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: filled ? color : scheme.surface, border: Border.all(color: color, width: 1.4))),
      ),
    );
  }

  Widget _sectionLabel(ColorScheme scheme, String text) => SizedBox(
        height: kNodeSectionH,
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: Align(alignment: Alignment.centerLeft, child: Text(text, style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant))),
        ),
      );

  Widget _portDot(ColorScheme scheme, {required NodePort port, required int index, required bool isOutput, bool filled = false, VoidCallback? onTap}) {
    final color = nodeTypeColor(port.dataType);
    // 設定ポート (D-235): 繋ぐ相手が無いので接続ドラッグの起点にしない(隣のポートの誤取得を防ぐ)。
    final settings = port.dataType == '設定';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onPanStart: settings ? null : (d) => onPortDragStart(index, isOutput, d.globalPosition),
      onPanUpdate: settings ? null : (d) => onPortDragUpdate(d.globalPosition),
      onPanEnd: settings ? null : (_) => onPortDragEnd(),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            // データ形式の色 (D-092): 出力は塗り、入力は接続時のみ塗り。設定は小さな四角(繋がらない印)。
            shape: settings ? BoxShape.rectangle : BoxShape.circle,
            color: (isOutput || filled) ? color : scheme.surface,
            border: Border.all(color: color, width: 1.4),
            borderRadius: settings ? BorderRadius.circular(2) : null,
          ),
        ),
      ),
    );
  }

  Widget _inputRow(ColorScheme scheme, int i) {
    final p = node.inputs[i];
    return SizedBox(
      height: kNodeRowH,
      child: Row(children: [
        const SizedBox(width: 3),
        _portDot(scheme, port: p, index: i, isOutput: false, filled: connectedInputs.contains(i), onTap: () => onTapInput(i)),
        Expanded(
          child: p.value == null
              ? Text(p.label, style: RasqTypography.caption, overflow: TextOverflow.ellipsis)
              : Builder(builder: (ctx) {
                  return InkWell(
                    onTap: () {
                      final box = ctx.findRenderObject() as RenderBox;
                      onEditValue(i, box.localToGlobal(Offset.zero) & box.size);
                    },
                    child: Container(
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(6)),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            // 設定(JSON)のポート (D-171) は値ではなくラベル(タップで「ノードを設定」FOW)。
                            p.value!.isEmpty || (p.dataType == '設定' && p.label == 'パラメーター') ? p.label : p.value!,
                            style: TextStyle(fontSize: 9, color: p.value!.isEmpty ? scheme.onSurfaceVariant : scheme.onSurface),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 選択肢付き (D-094) はドロップダウンの ∨ を出す。JSON 設定は ⚙。
                        if (p.options != null) Icon(Icons.keyboard_arrow_down, size: 12, color: scheme.onSurfaceVariant),
                        if (p.dataType == '設定' && p.label == 'パラメーター') Icon(Icons.settings_outlined, size: 12, color: scheme.onSurfaceVariant),
                      ]),
                    ),
                  );
                }),
        ),
        const SizedBox(width: 12),
      ]),
    );
  }

  Widget _outputRow(ColorScheme scheme, int j) {
    final p = node.outputs[j];
    return SizedBox(
      height: kNodeRowH,
      child: Row(children: [
        const SizedBox(width: 12),
        Expanded(child: Align(alignment: Alignment.centerRight, child: Text(p.label, style: RasqTypography.caption, overflow: TextOverflow.ellipsis))),
        _portDot(scheme, port: p, index: j, isOutput: true),
        const SizedBox(width: 3),
      ]),
    );
  }
}

/// 接続線(ベジェ)とドラッグ中の仮線。色は**出力ポートのデータ形式** (D-092)。
/// 条件接続 (D-094) は縦方向のベジェ(紫)。範囲選択の矩形 (D-235) も描く。
class NodeEdgePainter extends CustomPainter {
  NodeEdgePainter({required this.graph, required this.pan, required this.scale, required this.drag, this.marquee});

  final NodeGraph graph;
  final Offset pan;
  final double scale;
  final NodePortDrag? drag;
  final Rect? marquee;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(scale);
    final byId = {for (final n in graph.nodes) n.id: n};
    Paint stroke(Color color) => Paint()
      ..color = color
      ..strokeWidth = 2 / scale
      ..style = PaintingStyle.stroke;
    void dots(Offset a, Offset b, Color color) {
      canvas.drawCircle(a, 3, Paint()..color = color);
      canvas.drawCircle(b, 3, Paint()..color = color);
    }

    void curve(Offset a, Offset b, Color color) {
      final dx = ((b.dx - a.dx).abs() / 2).clamp(24.0, 120.0);
      canvas.drawPath(Path()..moveTo(a.dx, a.dy)..cubicTo(a.dx + dx, a.dy, b.dx - dx, b.dy, b.dx, b.dy), stroke(color));
      dots(a, b, color);
    }

    void vcurve(Offset a, Offset b, Color color) {
      final dy = ((b.dy - a.dy).abs() / 2).clamp(16.0, 80.0);
      canvas.drawPath(Path()..moveTo(a.dx, a.dy)..cubicTo(a.dx, a.dy + dy, b.dx, b.dy - dy, b.dx, b.dy), stroke(color));
      dots(a, b, color);
    }

    final condColor = nodeTypeColor('条件');
    for (final e in graph.edges) {
      final from = byId[e.from];
      final to = byId[e.to];
      if (from == null || to == null) continue;
      if (e.cond) {
        if (from.condOutCount > 0 && to.hasCondIn) vcurve(NodeGeometry.condOutCenter(from, e.fromPort.clamp(0, from.condOutCount - 1)), NodeGeometry.condInCenter(to), condColor);
        continue;
      }
      if (e.toIcon) {
        // クロック → アイコン (D-095)。
        if (e.fromPort < from.outputs.length) curve(NodeGeometry.outputCenter(from, e.fromPort), NodeGeometry.iconCenter(to), nodeTypeColor(from.outputs[e.fromPort].dataType));
        continue;
      }
      if (e.fromPort >= from.outputs.length || e.toPort >= to.inputs.length) continue;
      curve(NodeGeometry.outputCenter(from, e.fromPort), NodeGeometry.inputCenter(to, e.toPort), nodeTypeColor(from.outputs[e.fromPort].dataType));
    }
    final d = drag;
    if (d != null) {
      final n = byId[d.node];
      if (n != null && d.cond) {
        final start = d.isOutput ? NodeGeometry.condOutCenter(n, d.port.clamp(0, (n.condOutCount - 1).clamp(0, 99))) : NodeGeometry.condInCenter(n);
        vcurve(d.isOutput ? start : d.pos, d.isOutput ? d.pos : start, condColor);
      } else if (n != null) {
        final port = d.isOutput ? n.outputs.elementAtOrNull(d.port) : n.inputs.elementAtOrNull(d.port);
        final start = d.isOutput ? NodeGeometry.outputCenter(n, d.port) : NodeGeometry.inputCenter(n, d.port);
        curve(d.isOutput ? start : d.pos, d.isOutput ? d.pos : start, nodeTypeColor(port?.dataType ?? 'any'));
      }
    }
    final m = marquee;
    if (m != null) {
      canvas.drawRect(m, Paint()..color = RasqColors.link.withValues(alpha: 0.10));
      canvas.drawRect(m, stroke(RasqColors.link));
    }
  }

  @override
  bool shouldRepaint(covariant NodeEdgePainter old) => old.graph != graph || old.pan != pan || old.scale != scale || old.drag != drag || old.marquee != marquee;
}
