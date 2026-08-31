import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../home/timeline_providers.dart';
import '../settings/settings_dsl.dart';
import 'node_graph.dart';

/// ノードプログラミング画面 (D-090): TL 選択行の設定ボタン/コンポーザーの
/// 「投稿先のカスタマイズ」から開く。GUI ノードをキャンバスに置き、ポート
/// 同士を繋いで保存する(実行系は RAi/プラグイン統合側で配線予定)。
///
/// - ノードはヘッダー(タイトル行)を掴んで移動
/// - 出力ポート ⇄ 入力ポートをドラッグで接続(入力は 1 本まで、上書き)
/// - 接続済みの入力ポートをタップで切断
/// - 下部のパレット(プラグインノードを検索)からタップ or **長押しドラッグ**
///   でキャンバスに追加(ドラッグ中はパレットが最小表示に折りたたまれる)
class NodeEditorScreen extends ConsumerStatefulWidget {
  const NodeEditorScreen({super.key, required this.scope});

  /// グラフの保存先スコープ: `tl.<timelineId>` / `trend` / `composer`。
  final String scope;

  @override
  ConsumerState<NodeEditorScreen> createState() => _NodeEditorScreenState();
}

/// ノードカードの寸法(ポート位置の計算とカードのレイアウトを一致させる)。
const _nodeW = 190.0;
const _headerH = 34.0;
const _sectionH = 18.0;
const _rowH = 26.0;

class _NodeEditorScreenState extends ConsumerState<NodeEditorScreen> {
  final _canvasKey = GlobalKey();
  final _search = TextEditingController();

  NodeGraph _graph = const NodeGraph();
  bool _loaded = false;
  String? _selected;
  bool _paletteOpen = false;
  String _genre = 'すべて';

  /// 接続ドラッグ中の状態(始点ポートと現在位置、キャンバス座標)。
  ({String node, int port, bool isOutput, Offset pos})? _drag;

  String get _area => 'nodeprog.${widget.scope}';
  String get _title => switch (widget.scope) {
        'composer' => '投稿先のカスタマイズ',
        'trend' => 'トレンドをカスタマイズ',
        _ => 'タイムラインをカスタマイズ',
      };

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final m = await ref.read(settingsAreaProvider(_area).future);
        final raw = m['graph'];
        if (!mounted) return;
        setState(() {
          if (raw is String) _graph = NodeGraph.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
          _loaded = true;
        });
      } catch (_) {
        if (mounted) setState(() => _loaded = true);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _save() => ref.read(settingsAreaProvider(_area).notifier).set('graph', jsonEncode(_graph.toJson()));

  /// カタログ: 組み込み + TL プラグイン(tl.timelines 宣言からソートノード)。
  List<NodeCatalogEntry> get _catalog {
    final customs = ref.watch(customTimelinesProvider).value ?? const [];
    return [
      ...builtinNodeCatalog,
      for (final c in customs)
        NodeCatalogEntry(
          type: 'plugin:${c.id}',
          title: '${c.label}でソート',
          icon: Icons.extension_outlined,
          genre: 'ソート/辞書',
          author: 'TLプラグイン',
          description: '投稿リストをプラグインのソート(tl.sort)で並べ替えます。',
          inputs: const [NodePort(label: '投稿リスト')],
          outputs: const [NodePort(label: '投稿リスト')],
        ),
    ];
  }

  Map<String, NodeCatalogEntry> get _catalogByType => {for (final e in _catalog) e.type: e};

  // ---- グラフ操作 -----------------------------------------------------------

  String _newId() {
    var seq = 0;
    for (final n in _graph.nodes) {
      final m = RegExp(r'^n(\d+)$').firstMatch(n.id);
      if (m != null) seq = seq < int.parse(m.group(1)!) ? int.parse(m.group(1)!) : seq;
    }
    return 'n${seq + 1}';
  }

  void _addNode(NodeCatalogEntry entry, Offset at) {
    setState(() {
      _graph = NodeGraph(nodes: [..._graph.nodes, entry.instantiate(_newId(), at)], edges: _graph.edges);
      _paletteOpen = false;
    });
    _save();
  }

  void _removeSelected() {
    final id = _selected;
    if (id == null) return;
    setState(() {
      _graph = NodeGraph(
        nodes: [for (final n in _graph.nodes) if (n.id != id) n],
        edges: [for (final e in _graph.edges) if (e.from != id && e.to != id) e],
      );
      _selected = null;
    });
    _save();
  }

  void _moveNode(String id, Offset delta) {
    setState(() {
      _graph = NodeGraph(
        nodes: [for (final n in _graph.nodes) n.id == id ? n.copyWith(x: (n.x + delta.dx).clamp(0, 4000), y: (n.y + delta.dy).clamp(0, 4000)) : n],
        edges: _graph.edges,
      );
    });
  }

  void _connect(({String node, int port}) from, ({String node, int port}) to) {
    if (from.node == to.node) return;
    setState(() {
      _graph = NodeGraph(
        nodes: _graph.nodes,
        // 入力は 1 本まで — 既存の接続は上書き。
        edges: [
          for (final e in _graph.edges)
            if (!(e.to == to.node && e.toPort == to.port)) e,
          GraphEdge(from: from.node, fromPort: from.port, to: to.node, toPort: to.port),
        ],
      );
    });
    _save();
  }

  void _disconnectInput(String node, int port) {
    final had = _graph.edges.any((e) => e.to == node && e.toPort == port);
    if (!had) return;
    setState(() {
      _graph = NodeGraph(nodes: _graph.nodes, edges: [for (final e in _graph.edges) if (!(e.to == node && e.toPort == port)) e]);
    });
    _save();
  }

  Future<void> _editValue(GraphNode node, int index) async {
    final controller = TextEditingController(text: node.inputs[index].value ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(node.inputs[index].label, style: RasqTypography.title),
        content: TextField(controller: controller, autofocus: true, style: RasqTypography.bodySmall),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('決定')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _graph = NodeGraph(
        nodes: [
          for (final n in _graph.nodes)
            n.id == node.id
                ? n.copyWith(inputs: [for (var i = 0; i < n.inputs.length; i++) i == index ? n.inputs[i].copyWith(value: controller.text) : n.inputs[i]])
                : n,
        ],
        edges: _graph.edges,
      );
    });
    _save();
  }

  // ---- ポート座標(キャンバス座標系)---------------------------------------

  Offset _inputCenter(GraphNode n, int i) => Offset(n.x + 10, n.y + _headerH + _sectionH + i * _rowH + _rowH / 2);

  Offset _outputCenter(GraphNode n, int j) {
    final inputsBlock = n.inputs.isEmpty ? 0.0 : _sectionH + n.inputs.length * _rowH;
    return Offset(n.x + _nodeW - 10, n.y + _headerH + inputsBlock + _sectionH + j * _rowH + _rowH / 2);
  }

  Offset _toCanvas(Offset global) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? global : box.globalToLocal(global);
  }

  /// ドロップ位置に最も近い反対側ポートを拾う(30px 以内)。
  ({String node, int port})? _hitPort(Offset at, {required bool wantOutput}) {
    ({String node, int port})? best;
    var bestD = 30.0;
    for (final n in _graph.nodes) {
      final ports = wantOutput ? n.outputs : n.inputs;
      for (var i = 0; i < ports.length; i++) {
        final c = wantOutput ? _outputCenter(n, i) : _inputCenter(n, i);
        final d = (c - at).distance;
        if (d < bestD) {
          bestD = d;
          best = (node: n.id, port: i);
        }
      }
    }
    return best;
  }

  void _endDrag(Offset at) {
    final drag = _drag;
    if (drag == null) return;
    final target = _hitPort(at, wantOutput: !drag.isOutput);
    if (target != null) {
      if (drag.isOutput) {
        _connect((node: drag.node, port: drag.port), target);
      } else {
        _connect(target, (node: drag.node, port: drag.port));
      }
    }
    setState(() => _drag = null);
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: RasqPageHeader(title: _title, actions: [
        if (_selected != null) RasqIconButton(icon: Icons.delete_outline, tooltip: 'ノードを削除', onPressed: _removeSelected),
      ]),
      body: Column(children: [
        Expanded(
          child: DragTarget<NodeCatalogEntry>(
            onAcceptWithDetails: (d) => _addNode(d.data, _toCanvas(d.offset) - const Offset(0, 10)),
            builder: (context, _, _) => ClipRect(
              child: Stack(key: _canvasKey, clipBehavior: Clip.hardEdge, children: [
                // 余白タップで選択解除。
                Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() => _selected = null))),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _EdgePainter(
                        graph: _graph,
                        inputCenter: _inputCenter,
                        outputCenter: _outputCenter,
                        drag: _drag,
                      ),
                    ),
                  ),
                ),
                if (_loaded && _graph.nodes.isEmpty)
                  const Positioned.fill(child: IgnorePointer(child: RasqEmptyView(title: 'ノードがありません', hint: '下の検索からノードを追加(長押しでドラッグ)'))),
                for (final n in _graph.nodes)
                  Positioned(
                    left: n.x,
                    top: n.y,
                    child: _NodeCard(
                      node: n,
                      icon: _catalogByType[n.type]?.icon ?? Icons.extension_outlined,
                      selected: _selected == n.id,
                      connectedInputs: {for (final e in _graph.edges) if (e.to == n.id) e.toPort},
                      onSelect: () => setState(() => _selected = n.id),
                      onMove: (delta) => _moveNode(n.id, delta),
                      onMoveEnd: _save,
                      onEditValue: (i) => _editValue(n, i),
                      onTapInput: (i) => _disconnectInput(n.id, i),
                      onPortDragStart: (i, isOutput, global) => setState(() => _drag = (node: n.id, port: i, isOutput: isOutput, pos: _toCanvas(global))),
                      onPortDragUpdate: (global) => setState(() => _drag = _drag == null ? null : (node: _drag!.node, port: _drag!.port, isOutput: _drag!.isOutput, pos: _toCanvas(global))),
                      onPortDragEnd: () => _endDrag(_drag?.pos ?? Offset.zero),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        _palette(scheme),
      ]),
    );
  }

  /// プラグインノード検索パレット(ワイヤーフレーム「UI下部に表示」)。
  /// タイル長押しでホバープレビュー(ドラッグ feedback)→ キャンバスへ
  /// ドロップ。ドラッグ中は最小表示に折りたたむ。
  Widget _palette(ColorScheme scheme) {
    final manager = ref.read(overlayManagerProvider);
    final query = _search.text.trim();
    final genres = ['すべて', ...{for (final e in _catalog) e.genre}];
    final entries = [
      for (final e in _catalog)
        if ((_genre == 'すべて' || e.genre == _genre) && (query.isEmpty || e.title.contains(query) || (e.description ?? '').contains(query))) e,
    ];
    return Container(
      decoration: BoxDecoration(color: scheme.surface, border: Border(top: BorderSide(color: scheme.outlineVariant))),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, 6, RasqSpacing.sm, 6),
            child: Row(children: [
              // RAi (未実装): 実装時にはここからノードを内部的に操作する想定。
              Tooltip(
                message: 'RAi(準備中)',
                child: CircleAvatar(radius: 14, backgroundColor: scheme.surfaceContainerHighest, child: Icon(Icons.smart_toy_outlined, size: 16, color: scheme.onSurfaceVariant)),
              ),
              const SizedBox(width: RasqSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _search,
                    style: RasqTypography.bodySmall,
                    decoration: InputDecoration(
                      hintText: 'プラグインノードを検索',
                      prefixIcon: const Icon(Icons.search, size: 16),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    onTap: () => setState(() => _paletteOpen = true),
                    onChanged: (_) => setState(() => _paletteOpen = true),
                  ),
                ),
              ),
              RasqIconButton(
                icon: _paletteOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                tooltip: _paletteOpen ? 'ノード一覧を閉じる' : 'ノード一覧を開く',
                onPressed: () => setState(() => _paletteOpen = !_paletteOpen),
              ),
            ]),
          ),
          if (_paletteOpen)
            SizedBox(
              height: 240,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
                  child: Row(children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('並び替え: ', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                      child: Text('関連順', style: RasqTypography.caption),
                    ),
                    const SizedBox(width: RasqSpacing.md),
                    Text('ジャンル: ', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                    Builder(builder: (ctx) {
                      return InkWell(
                        onTap: () async {
                          final box = ctx.findRenderObject() as RenderBox;
                          final pick = await manager.showDropdown<String>(
                            id: 'nodeprog.genre',
                            anchor: box.localToGlobal(Offset.zero) & box.size,
                            dense: true,
                            items: [for (final g in genres) RasqDropdownItem(g, g, checked: g == _genre)],
                          );
                          if (pick != null) setState(() => _genre = pick);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(10)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(_genre == 'すべて' ? 'ソート/辞書' : _genre, style: RasqTypography.caption),
                            const Icon(Icons.keyboard_arrow_down, size: 14),
                          ]),
                        ),
                      );
                    }),
                        ]),
                      ),
                    ),
                    RasqIconButton(icon: Icons.settings, size: 16, tooltip: '検索設定(準備中)', onPressed: () {}),
                  ]),
                ),
                Expanded(
                  child: entries.isEmpty
                      ? const RasqEmptyView(title: 'ノードが見つかりません', hint: '検索ワードやジャンルを変えてみてください')
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 4, RasqSpacing.page, RasqSpacing.sm),
                          itemCount: entries.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, i) => _paletteCard(scheme, entries[i]),
                        ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _paletteCard(ColorScheme scheme, NodeCatalogEntry e) {
    final card = Container(
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(color: scheme.surface, border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
          child: Icon(e.icon, size: 22),
        ),
        const SizedBox(width: RasqSpacing.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            if (e.author != null) Text(e.author!, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            if (e.description != null) Text(e.description!, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
        const Icon(Icons.chevron_right, size: 18),
      ]),
    );
    // 長押しでホバープレビュー → キャンバスへドラッグ(ドラッグ中は
    // パレットを最小表示に)。タップでも中央付近に追加できる。
    return LongPressDraggable<NodeCatalogEntry>(
      data: e,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.9, child: SizedBox(width: 280, child: card)),
      ),
      onDragStarted: () => setState(() => _paletteOpen = false),
      child: InkWell(
        onTap: () => _addNode(e, Offset(40.0 + (_graph.nodes.length % 4) * 28, 56.0 + (_graph.nodes.length % 5) * 28)),
        child: card,
      ),
    );
  }
}

/// 1 ノードのカード。ヘッダーを掴んで移動、ポートのドットから接続ドラッグ。
class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.node,
    required this.icon,
    required this.selected,
    required this.connectedInputs,
    required this.onSelect,
    required this.onMove,
    required this.onMoveEnd,
    required this.onEditValue,
    required this.onTapInput,
    required this.onPortDragStart,
    required this.onPortDragUpdate,
    required this.onPortDragEnd,
  });

  final GraphNode node;
  final IconData icon;
  final bool selected;
  final Set<int> connectedInputs;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onMove;
  final VoidCallback onMoveEnd;
  final ValueChanged<int> onEditValue;
  final ValueChanged<int> onTapInput;
  final void Function(int index, bool isOutput, Offset global) onPortDragStart;
  final ValueChanged<Offset> onPortDragUpdate;
  final VoidCallback onPortDragEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    return Container(
      width: _nodeW,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? tokens.link : scheme.outlineVariant, width: selected ? 1.6 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        // ヘッダー = 移動グリップ。
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSelect,
          onPanStart: (_) => onSelect(),
          onPanUpdate: (d) => onMove(d.delta),
          onPanEnd: (_) => onMoveEnd(),
          child: SizedBox(
            height: _headerH,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                Icon(icon, size: 15, color: scheme.onSurfaceVariant),
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
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _sectionLabel(ColorScheme scheme, String text) => SizedBox(
        height: _sectionH,
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: Align(alignment: Alignment.centerLeft, child: Text(text, style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant))),
        ),
      );

  Widget _portDot(ColorScheme scheme, {required int index, required bool isOutput, bool filled = false, VoidCallback? onTap}) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onPanStart: (d) => onPortDragStart(index, isOutput, d.globalPosition),
        onPanUpdate: (d) => onPortDragUpdate(d.globalPosition),
        onPanEnd: (_) => onPortDragEnd(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? scheme.primary : scheme.surface,
              border: Border.all(color: filled ? scheme.primary : scheme.outline),
            ),
          ),
        ),
      );

  Widget _inputRow(ColorScheme scheme, int i) {
    final p = node.inputs[i];
    return SizedBox(
      height: _rowH,
      child: Row(children: [
        const SizedBox(width: 3),
        _portDot(scheme, index: i, isOutput: false, filled: connectedInputs.contains(i), onTap: () => onTapInput(i)),
        Expanded(
          child: p.value == null
              ? Text(p.label, style: RasqTypography.caption, overflow: TextOverflow.ellipsis)
              : InkWell(
                  onTap: () => onEditValue(i),
                  child: Container(
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(6)),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        p.value!.isEmpty ? p.label : p.value!,
                        style: TextStyle(fontSize: 9, color: p.value!.isEmpty ? scheme.onSurfaceVariant : scheme.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 12),
      ]),
    );
  }

  Widget _outputRow(ColorScheme scheme, int j) {
    final p = node.outputs[j];
    return SizedBox(
      height: _rowH,
      child: Row(children: [
        const SizedBox(width: 12),
        Expanded(child: Align(alignment: Alignment.centerRight, child: Text(p.label, style: RasqTypography.caption, overflow: TextOverflow.ellipsis))),
        _portDot(scheme, index: j, isOutput: true),
        const SizedBox(width: 3),
      ]),
    );
  }
}

/// 接続線(ベジェ)とドラッグ中の仮線。
class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.graph, required this.inputCenter, required this.outputCenter, required this.drag});

  final NodeGraph graph;
  final Offset Function(GraphNode, int) inputCenter;
  final Offset Function(GraphNode, int) outputCenter;
  final ({String node, int port, bool isOutput, Offset pos})? drag;

  static const _colors = [Color(0xFFE57368), Color(0xFF26A69A), Color(0xFF42A5F5), Color(0xFF80DEEA), Color(0xFFFFB74D), Color(0xFFAB47BC)];

  @override
  void paint(Canvas canvas, Size size) {
    final byId = {for (final n in graph.nodes) n.id: n};
    void curve(Offset a, Offset b, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final dx = ((b.dx - a.dx).abs() / 2).clamp(24.0, 120.0);
      canvas.drawPath(Path()..moveTo(a.dx, a.dy)..cubicTo(a.dx + dx, a.dy, b.dx - dx, b.dy, b.dx, b.dy), paint);
      canvas.drawCircle(a, 3, Paint()..color = color);
      canvas.drawCircle(b, 3, Paint()..color = color);
    }

    for (var i = 0; i < graph.edges.length; i++) {
      final e = graph.edges[i];
      final from = byId[e.from];
      final to = byId[e.to];
      if (from == null || to == null || e.fromPort >= from.outputs.length || e.toPort >= to.inputs.length) continue;
      curve(outputCenter(from, e.fromPort), inputCenter(to, e.toPort), _colors[i % _colors.length]);
    }
    final d = drag;
    if (d != null) {
      final n = byId[d.node];
      if (n != null) {
        final start = d.isOutput ? outputCenter(n, d.port) : inputCenter(n, d.port);
        curve(d.isOutput ? start : d.pos, d.isOutput ? d.pos : start, _colors[graph.edges.length % _colors.length]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) => true;
}
