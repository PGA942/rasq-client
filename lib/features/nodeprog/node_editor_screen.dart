import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../shell/headers.dart';
import '../home/timeline_providers.dart';
import '../settings/settings_dsl.dart';
import 'node_graph.dart';

/// ノードプログラミング画面 (D-090/D-092): TL 選択行の設定ボタン/トレンド/
/// コンポーザーの「投稿先のカスタマイズ」から開く。GUI ノードをキャンバスに
/// 置き、ポート同士を繋いで保存する(実行系は RAi/プラグイン統合側で配線予定)。
///
/// 操作 (D-092 でユーザー指定):
/// - **空領域をドラッグしてキャンバス移動**(キーボードは上下左右キー)
/// - ノードは**タイトル行を掴んで**移動
/// - ノードを**クリック or 長押しでドロップダウン**(ノード情報/ストアへ(無効)/
///   コピー/ペースト/削除)
/// - 接続は**データ形式(色)が一致するポート同士だけ**。プラグインが形式を
///   細かく指定(例: テキスト(.dic))していて食い違う場合も不可
/// - パレット「プラグインノードを検索」は **FOW**(検索ホームの入力欄と同じ
///   デザイン)。タイルのクリックで詳細情報、**長押しドラッグ**でキャンバスへ
///   (ドラッグ中は FOW が最小表示に折りたたまれる)
class NodeEditorScreen extends ConsumerStatefulWidget {
  const NodeEditorScreen({super.key, required this.scope});

  /// グラフの保存先スコープ: `tl.<timelineId>` / `trend` / `composer`。
  final String scope;

  @override
  ConsumerState<NodeEditorScreen> createState() => _NodeEditorScreenState();
}

/// パレット FOW の id / 高さ段階。
const nodePaletteFowId = 'fow.nodepalette';
const _paletteCollapsed = 0.09;
const _paletteExpanded = 0.5;

/// カタログ: 組み込み + TL プラグイン(tl.timelines 宣言からソートノード)。
final nodeCatalogProvider = Provider<List<NodeCatalogEntry>>((ref) {
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
        inputs: const [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
        outputs: const [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
      ),
  ];
});

/// ノードカードの寸法(ポート位置の計算とカードのレイアウトを一致させる)。
const _nodeW = 190.0;
const _headerH = 34.0;
const _sectionH = 18.0;
const _rowH = 26.0;

class _NodeEditorScreenState extends ConsumerState<NodeEditorScreen> {
  final _canvasKey = GlobalKey();
  final _canvasFocus = FocusNode(debugLabel: 'nodeCanvas');

  NodeGraph _graph = const NodeGraph();
  bool _loaded = false;
  String? _selected;

  /// キャンバスのパン(空領域ドラッグ/矢印キー)。ノード座標(グラフ座標)は
  /// 動かさず、表示だけずらす。
  Offset _pan = Offset.zero;

  /// コピーしたノード(ドロップダウンのコピー/ペースト)。
  GraphNode? _clipboard;

  /// 接続ドラッグ中の状態(始点ポートと現在位置、**グラフ座標**)。
  ({String node, int port, bool isOutput, Offset pos})? _drag;

  String get _area => 'nodeprog.${widget.scope}';
  String get _title => switch (widget.scope) {
        'composer' => '投稿先のカスタマイズ',
        'trend' => 'トレンドをカスタマイズ',
        _ => 'タイムラインをカスタマイズ',
      };

  /// dispose 時に ref が使えないため、パレット FOW を閉じる用に保持。
  late final OverlayManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = ref.read(overlayManagerProvider);
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPalette());
  }

  @override
  void dispose() {
    _canvasFocus.dispose();
    super.dispose();
  }

  void _save() => ref.read(settingsAreaProvider(_area).notifier).set('graph', jsonEncode(_graph.toJson()));

  Map<String, NodeCatalogEntry> get _catalogByType => {for (final e in ref.watch(nodeCatalogProvider)) e.type: e};

  // ---- パレット FOW (D-092) ------------------------------------------------

  void _openPalette() {
    if (!mounted) return;
    final manager = _manager;
    if (manager.contains(nodePaletteFowId)) return;
    final spec = FowSpec(
      type: FowPanelType.widget,
      initialHeightFactor: _paletteCollapsed,
      minHeightFactor: 0.06,
      maxHeightFactor: 0.85,
      dockAboveFooter: true,
      heightStops: const [_paletteCollapsed, _paletteExpanded],
      freeAboveStops: true,
    );
    // この画面に張り付く FOW — ページ遷移(戻る等)を検知したら自動で
    // 消滅する(常駐 stick コンポーザーと同じ作法, D-048)。
    final router = ref.read(routerProvider);
    void onNavigate() => manager.close(nodePaletteFowId);
    router.routerDelegate.addListener(onNavigate);
    manager
        .showFow<void>(
          id: nodePaletteFowId,
          semanticsLabel: 'プラグインノードを検索',
          spec: spec,
          builder: (ctx, handle) => _NodePalettePanel(spec: spec, onAdd: (e) => _addNode(e, _viewCenter())),
        )
        .whenComplete(() => router.routerDelegate.removeListener(onNavigate));
  }

  /// 現在見えているキャンバス中央(グラフ座標)。タップ追加の置き場所。
  Offset _viewCenter() {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(360, 480);
    return Offset(size.width / 2 - _nodeW / 2, size.height / 3) - _pan;
  }

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
    setState(() => _graph = NodeGraph(nodes: [..._graph.nodes, entry.instantiate(_newId(), at)], edges: _graph.edges));
    _save();
  }

  void _removeNode(String id) {
    setState(() {
      _graph = NodeGraph(
        nodes: [for (final n in _graph.nodes) if (n.id != id) n],
        edges: [for (final e in _graph.edges) if (e.from != id && e.to != id) e],
      );
    });
    _save();
  }

  void _moveNode(String id, Offset delta) {
    setState(() {
      _graph = NodeGraph(
        nodes: [for (final n in _graph.nodes) n.id == id ? n.copyWith(x: (n.x + delta.dx).clamp(-4000, 4000), y: (n.y + delta.dy).clamp(-4000, 4000)) : n],
        edges: _graph.edges,
      );
    });
  }

  void _connect(({String node, int port}) from, ({String node, int port}) to) {
    if (from.node == to.node) return;
    final byId = {for (final n in _graph.nodes) n.id: n};
    final out = byId[from.node]?.outputs.elementAtOrNull(from.port);
    final input = byId[to.node]?.inputs.elementAtOrNull(to.port);
    if (out == null || input == null) return;
    // 形式ゲート (D-092): ジャンル(色)不一致・形式指定の食い違いは接続不可。
    if (!portsCompatible(out, input)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('接続できません: ${out.typeLabel} → ${input.typeLabel}(形式が合いません)'),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
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

  // ---- ノードのドロップダウン (D-092) ---------------------------------------

  Future<void> _nodeMenu(GraphNode n, Offset globalPos) async {
    setState(() => _selected = n.id);
    final manager = ref.read(overlayManagerProvider);
    final pick = await manager.showDropdown<String>(
      id: 'nodeprog.node',
      anchor: globalPos & const Size(1, 1),
      dense: true,
      items: [
        const RasqDropdownItem('ノード情報', 'info'),
        const RasqDropdownItem('プラグインストアに移動', 'store', enabled: false), // ストア統合 (M4) で有効化
        const RasqDropdownItem('コピー', 'copy'),
        RasqDropdownItem('ペースト', 'paste', enabled: _clipboard != null),
        const RasqDropdownItem('削除', 'delete', destructive: true),
      ],
    );
    if (!mounted) return;
    switch (pick) {
      case 'info':
        _showNodeInfo(n);
      case 'copy':
        _clipboard = n;
      case 'paste':
        final c = _clipboard;
        if (c != null) {
          setState(() {
            _graph = NodeGraph(
              nodes: [..._graph.nodes, GraphNode(id: _newId(), type: c.type, title: c.title, x: n.x + 24, y: n.y + 24, inputs: c.inputs, outputs: c.outputs)],
              edges: _graph.edges,
            );
          });
          _save();
        }
      case 'delete':
        _removeNode(n.id);
    }
    if (mounted) setState(() => _selected = null);
  }

  void _showNodeInfo(GraphNode n) {
    final entry = _catalogByType[n.type];
    final manager = ref.read(overlayManagerProvider);
    manager.showBottomSheet<void>(
      id: 'nodeprog.info',
      title: n.title,
      builder: (ctx) => _NodeInfoBody(
        author: entry?.author,
        genre: entry?.genre,
        description: entry?.description,
        inputs: n.inputs,
        outputs: n.outputs,
      ),
    );
  }

  // ---- ポート座標(グラフ座標系)--------------------------------------------

  Offset _inputCenter(GraphNode n, int i) => Offset(n.x + 10, n.y + _headerH + _sectionH + i * _rowH + _rowH / 2);

  Offset _outputCenter(GraphNode n, int j) {
    final inputsBlock = n.inputs.isEmpty ? 0.0 : _sectionH + n.inputs.length * _rowH;
    return Offset(n.x + _nodeW - 10, n.y + _headerH + inputsBlock + _sectionH + j * _rowH + _rowH / 2);
  }

  /// global → グラフ座標(キャンバス local からパンを引く)。
  Offset _toGraph(Offset global) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return (box == null ? global : box.globalToLocal(global)) - _pan;
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

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    const step = 48.0;
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => const Offset(step, 0),
      LogicalKeyboardKey.arrowRight => const Offset(-step, 0),
      LogicalKeyboardKey.arrowUp => const Offset(0, step),
      LogicalKeyboardKey.arrowDown => const Offset(0, -step),
      _ => null,
    };
    if (delta == null) return KeyEventResult.ignored;
    setState(() => _pan += delta);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RasqPageHeader(title: _title),
      body: DragTarget<NodeCatalogEntry>(
        onAcceptWithDetails: (d) => _addNode(d.data, _toGraph(d.offset) - const Offset(0, 10)),
        builder: (context, _, _) => Focus(
          focusNode: _canvasFocus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: ClipRect(
            child: Stack(key: _canvasKey, clipBehavior: Clip.hardEdge, children: [
              // 空領域: ドラッグでキャンバス移動、タップで選択解除 + フォーカス。
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _canvasFocus.requestFocus();
                    setState(() => _selected = null);
                  },
                  onPanUpdate: (d) => setState(() => _pan += d.delta),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _EdgePainter(graph: _graph, pan: _pan, inputCenter: _inputCenter, outputCenter: _outputCenter, drag: _drag),
                  ),
                ),
              ),
              if (_loaded && _graph.nodes.isEmpty)
                const Positioned.fill(child: IgnorePointer(child: RasqEmptyView(title: 'ノードがありません', hint: '下の検索から追加(タップで詳細、長押しでドラッグ)'))),
              for (final n in _graph.nodes)
                Positioned(
                  left: n.x + _pan.dx,
                  top: n.y + _pan.dy,
                  child: _NodeCard(
                    node: n,
                    icon: _catalogByType[n.type]?.icon ?? Icons.extension_outlined,
                    selected: _selected == n.id,
                    connectedInputs: {for (final e in _graph.edges) if (e.to == n.id) e.toPort},
                    onMenu: (global) => _nodeMenu(n, global),
                    onMove: (delta) => _moveNode(n.id, delta),
                    onMoveEnd: _save,
                    onEditValue: (i) => _editValue(n, i),
                    onTapInput: (i) => _disconnectInput(n.id, i),
                    onPortDragStart: (i, isOutput, global) => setState(() => _drag = (node: n.id, port: i, isOutput: isOutput, pos: _toGraph(global))),
                    onPortDragUpdate: (global) => setState(() => _drag = _drag == null ? null : (node: _drag!.node, port: _drag!.port, isOutput: _drag!.isOutput, pos: _toGraph(global))),
                    onPortDragEnd: () => _endDrag(_drag?.pos ?? Offset.zero),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// パレット FOW (D-092): 検索ホームの入力欄と同じデザイン
/// ([RasqExpandableSearchBox])+ ノードタイル(1 行の入出力情報付き)。
/// タイルのタップで詳細情報、長押しドラッグでキャンバスへ(ドラッグ中は
/// FOW を最小表示へ折りたたむ)。
class _NodePalettePanel extends ConsumerStatefulWidget {
  const _NodePalettePanel({required this.spec, required this.onAdd});

  final FowSpec spec;
  final ValueChanged<NodeCatalogEntry> onAdd;

  @override
  ConsumerState<_NodePalettePanel> createState() => _NodePalettePanelState();
}

class _NodePalettePanelState extends ConsumerState<_NodePalettePanel> {
  final _search = TextEditingController();
  final _focus = FocusNode(debugLabel: 'nodePaletteSearch');
  bool _toggled = false;
  String _genre = 'すべて';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    // 入力にフォーカス → FOW を展開段まで持ち上げる。
    if (_focus.hasFocus && widget.spec.heightFactor.value < _paletteExpanded) {
      widget.spec.heightFactor.value = _paletteExpanded;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final manager = ref.read(overlayManagerProvider);
    final catalog = ref.watch(nodeCatalogProvider);
    final query = _search.text.trim();
    final genres = ['すべて', ...{for (final e in catalog) e.genre}];
    final entries = [
      for (final e in catalog)
        if ((_genre == 'すべて' || e.genre == _genre) && (query.isEmpty || e.title.contains(query) || (e.description ?? '').contains(query))) e,
    ];

    final bar = Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, 6, RasqSpacing.sm, 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // RAi (未実装): 実装時にはここからノードを内部的に操作する想定。
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Tooltip(
              message: 'RAi(準備中)',
              child: CircleAvatar(radius: 14, backgroundColor: scheme.surfaceContainerHighest, child: Icon(Icons.smart_toy_outlined, size: 16, color: scheme.onSurfaceVariant)),
            ),
          ),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(
            child: RasqExpandableSearchBox(
              expanded: _toggled || _focus.hasFocus,
              controller: _search,
              focusNode: _focus,
              hintText: 'プラグインノードを検索',
              onDropdownTap: () => setState(() => _toggled = !_toggled),
              filterChips: [
                RasqFilterChipItem(
                  label: '並び替え: 関連順',
                  dropdown: true,
                  onAnchorTap: (rect) => manager.showDropdown<String>(
                    id: 'nodeprog.sort',
                    ownerId: nodePaletteFowId,
                    anchor: rect,
                    dense: true,
                    items: const [RasqDropdownItem('関連順', 'relevance', checked: true)],
                  ),
                ),
                RasqFilterChipItem(
                  label: 'ジャンル: ${_genre == 'すべて' ? 'ソート/辞書' : _genre}',
                  dropdown: true,
                  selected: _genre != 'すべて',
                  onAnchorTap: (rect) async {
                    final pick = await manager.showDropdown<String>(
                      id: 'nodeprog.genre',
                      ownerId: nodePaletteFowId,
                      anchor: rect,
                      dense: true,
                      items: [for (final g in genres) RasqDropdownItem(g, g, checked: g == _genre)],
                    );
                    if (pick != null) setState(() => _genre = pick);
                  },
                ),
              ],
              trailing: RasqIconButton(icon: Icons.settings_outlined, size: 18, tooltip: '検索設定(準備中)', onPressed: () {}),
            ),
          ),
        ]),
    );
    // 最小表示(折りたたみ)時はバーだけをクリップ描画 — 端数ではみ出さない。
    return LayoutBuilder(builder: (context, c) {
      if (c.maxHeight < 130) {
        return SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: bar);
      }
      return Column(children: [
        bar,
        Expanded(
          child: entries.isEmpty
              ? const RasqEmptyView(title: 'ノードが見つかりません', hint: '検索ワードやジャンルを変えてみてください')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 4, RasqSpacing.page, RasqSpacing.sm),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, i) => _tile(scheme, manager, entries[i]),
                ),
        ),
      ]);
    });
  }

  Widget _tile(ColorScheme scheme, OverlayManager manager, NodeCatalogEntry e) {
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
            // 入出力の 1 行表示 (D-092: ワイヤーフレーム書き忘れ分)。
            Text(e.ioSummary, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        const Icon(Icons.chevron_right, size: 18),
      ]),
    );
    return LongPressDraggable<NodeCatalogEntry>(
      data: e,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.9, child: SizedBox(width: 280, child: card)),
      ),
      // ドラッグ中は FOW を最小表示に折りたたむ(WF: 下側に stick)。
      onDragStarted: () {
        _focus.unfocus();
        widget.spec.heightFactor.value = _paletteCollapsed;
      },
      child: InkWell(onTap: () => _showDetail(manager, e), child: card),
    );
  }

  /// タイルのクリック → ノードの詳細情報 (D-092)。
  void _showDetail(OverlayManager manager, NodeCatalogEntry e) {
    manager.showBottomSheet<void>(
      id: 'nodeprog.detail',
      title: e.title,
      ownerId: nodePaletteFowId,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _NodeInfoBody(author: e.author, genre: e.genre, description: e.description, inputs: e.inputs, outputs: e.outputs),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
          child: FilledButton.icon(
            onPressed: () {
              manager.close('nodeprog.detail');
              widget.onAdd(e);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('キャンバスに追加'),
          ),
        ),
      ]),
    );
  }
}

/// ノード情報の中身(詳細シートと「ノード情報」で共用)。
class _NodeInfoBody extends StatelessWidget {
  const _NodeInfoBody({this.author, this.genre, this.description, required this.inputs, required this.outputs});

  final String? author;
  final String? genre;
  final String? description;
  final List<NodePort> inputs;
  final List<NodePort> outputs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget port(NodePort p) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: nodeTypeColor(p.dataType))),
            const SizedBox(width: 6),
            Text(p.label, style: RasqTypography.bodySmall),
            const SizedBox(width: 6),
            Text(p.typeLabel, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (author != null || genre != null)
          Text([?author, if (genre != null) 'ジャンル: $genre'].join(' · '), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        if (description != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(description!, style: RasqTypography.bodySmall)),
        if (inputs.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text('入力', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
          for (final p in inputs) port(p),
        ],
        if (outputs.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text('出力', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
          for (final p in outputs) port(p),
        ],
      ]),
    );
  }
}

/// 1 ノードのカード。ヘッダーを掴んで移動、クリック/長押しでドロップダウン、
/// ポートのドット(データ形式の色)から接続ドラッグ。
class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.node,
    required this.icon,
    required this.selected,
    required this.connectedInputs,
    required this.onMenu,
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

  /// クリック/長押しのドロップダウン(グローバル座標)。
  final ValueChanged<Offset> onMenu;
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
        // ヘッダー = 移動グリップ + クリック/長押しでドロップダウン (D-092)。
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => onMenu(d.globalPosition),
          onLongPressStart: (d) => onMenu(d.globalPosition),
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

  Widget _portDot(ColorScheme scheme, {required NodePort port, required int index, required bool isOutput, bool filled = false, VoidCallback? onTap}) {
    final color = nodeTypeColor(port.dataType);
    return GestureDetector(
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
            // データ形式の色 (D-092): 出力は塗り、入力は接続時のみ塗り。
            color: (isOutput || filled) ? color : scheme.surface,
            border: Border.all(color: color, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _inputRow(ColorScheme scheme, int i) {
    final p = node.inputs[i];
    return SizedBox(
      height: _rowH,
      child: Row(children: [
        const SizedBox(width: 3),
        _portDot(scheme, port: p, index: i, isOutput: false, filled: connectedInputs.contains(i), onTap: () => onTapInput(i)),
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
        _portDot(scheme, port: p, index: j, isOutput: true),
        const SizedBox(width: 3),
      ]),
    );
  }
}

/// 接続線(ベジェ)とドラッグ中の仮線。色は**出力ポートのデータ形式** (D-092)。
class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.graph, required this.pan, required this.inputCenter, required this.outputCenter, required this.drag});

  final NodeGraph graph;
  final Offset pan;
  final Offset Function(GraphNode, int) inputCenter;
  final Offset Function(GraphNode, int) outputCenter;
  final ({String node, int port, bool isOutput, Offset pos})? drag;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(pan.dx, pan.dy);
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

    for (final e in graph.edges) {
      final from = byId[e.from];
      final to = byId[e.to];
      if (from == null || to == null || e.fromPort >= from.outputs.length || e.toPort >= to.inputs.length) continue;
      curve(outputCenter(from, e.fromPort), inputCenter(to, e.toPort), nodeTypeColor(from.outputs[e.fromPort].dataType));
    }
    final d = drag;
    if (d != null) {
      final n = byId[d.node];
      if (n != null) {
        final port = d.isOutput ? n.outputs.elementAtOrNull(d.port) : n.inputs.elementAtOrNull(d.port);
        final start = d.isOutput ? outputCenter(n, d.port) : inputCenter(n, d.port);
        curve(d.isOutput ? start : d.pos, d.isOutput ? d.pos : start, nodeTypeColor(port?.dataType ?? 'any'));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) => true;
}
