import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/rasq_collections_api.dart' show RasqCollection;
import '../../l10n/l10n.dart';
import '../../shell/app_overlay_root.dart';
import '../../shell/headers.dart';
import '../collections/rasq_list_picker.dart' show rasqListCandidatesProvider;
import '../home/timeline_providers.dart';
import '../plugins/slot_plugins.dart' show slotPluginsProvider;
import '../settings/settings_dsl.dart';
import '../store/store_client.dart' show storeSamplePluginId;
import 'node_canvas.dart';
import 'node_executor.dart' show pluginParamsOf;
import 'node_graph.dart';
import 'node_tabs.dart';
import 'plugin_params_panel.dart';
import 'plugin_node_badge.dart';

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

/// リスト/DM ノードの選択肢 (D-097): ログイン中セッションから引く。
/// 失敗・未対応は空(値ボックスは自由入力のまま)。
/// リスト名 (D-194): 全ログインアカウントのリストを合わせる(取れない SNS は飛ばす)。
final _nodeListNamesProvider = FutureProvider<List<String>>((ref) async {
  final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
  final names = <String>{};
  for (final s in sessions) {
    final session = ref.watch(sessionForAccountProvider(s.account.key));
    if (session == null) continue;
    try {
      names.addAll([for (final l in await session.lists()) l.name]);
    } catch (_) {}
  }
  return names.toList();
});

/// TL 種別 (D-194): 各アカウントの SNS が宣言するタイムライン id を合わせる(「現在のアカウント」は無し)。
final _nodeTimelineIdsProvider = Provider<List<String>>((ref) {
  final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
  final ids = <String>{};
  for (final s in sessions) {
    final session = ref.watch(sessionForAccountProvider(s.account.key));
    if (session != null) ids.addAll([for (final t in session.timelines) t.id]);
  }
  return ids.isEmpty ? const ['home', 'social', 'local', 'global'] : ids.toList();
});

final _nodeDmPeersProvider = FutureProvider<List<String>>((ref) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  try {
    return [for (final r in await s.dmRooms()) r.peer.handle];
  } catch (_) {
    return const [];
  }
});

/// カスタム関数の定義一覧 (D-099)。KV `nodeprog.functions.v1` の `list` に
/// 全スコープ共通で保存し、パレット(ジャンル「関数」)に載る。
final customFunctionsProvider = Provider<List<CustomFunctionDef>>((ref) {
  final area = ref.watch(settingsAreaProvider('nodeprog.functions')).value ?? const <String, Object?>{};
  final raw = area['list'];
  if (raw is! String) return const [];
  try {
    return [for (final j in (jsonDecode(raw) as List)) CustomFunctionDef.fromJson((j as Map).cast<String, Object?>())];
  } catch (_) {
    return const [];
  }
});

/// カタログ: 組み込み + TL プラグイン(tl.timelines 宣言からソートノード)
/// + カスタム関数 (D-099)。リストTL取得/DM取得には実データの選択肢を
/// 注入する (D-097)。
final nodeCatalogProvider = Provider<List<NodeCatalogEntry>>((ref) {
  final customs = ref.watch(customTimelinesProvider).value ?? const [];
  final functions = ref.watch(customFunctionsProvider);
  final listNames = ref.watch(_nodeListNamesProvider).value ?? const <String>[];
  final dmPeers = ref.watch(_nodeDmPeersProvider).value ?? const <String>[];
  // RASQ リスト (D-346): 自分のリスト + フォロー中で、リスト内の人の情報を取れるもの(名前で選ぶ。実行側が名前 → id を引く)。
  final rasqLists = [for (final c in ref.watch(rasqListCandidatesProvider('')).value ?? const <RasqCollection>[]) if (c.isOwner || c.canFetch == true) c.name];
  // アカウント選択 (D-106/D-109): ログイン済みアカウントを選択肢に。
  final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
  final accounts = [for (final s in sessions) '${s.account}'];
  // 「現在のアカウント」表記は無し (D-194): アカウントを明示する(空 = 従来設定の互換)。
  final acctOptions = accounts;
  final blueskyAccounts = [for (final s in sessions) if (s.account.kind == SnsKind.bluesky) '${s.account}'];
  final timelineIds = ref.watch(_nodeTimelineIdsProvider);
  final l = appL10n;
  NodeCatalogEntry withOptions(NodeCatalogEntry e, String label, List<String> options) {
    if (options.isEmpty) return e;
    return NodeCatalogEntry(
      type: e.type,
      title: e.title,
      icon: e.icon,
      genre: e.genre,
      author: e.author,
      description: e.description,
      detail: e.detail,
      inputs: [
        for (final p in e.inputs)
          p.label == label ? NodePort(label: p.label, value: p.value, dataType: p.dataType, format: p.format, options: options) : p,
      ],
      outputs: e.outputs,
      hasCondIn: e.hasCondIn,
      hasCondOut: e.hasCondOut,
      condBranches: e.condBranches,
    );
  }

  return [
    for (final e in builtinNodeCatalogOf(l))
      switch (e.type) {
        'tl.list' => withOptions(withOptions(e, 'リスト', listNames), 'アカウント', acctOptions),
        'tl.feed' => withOptions(e, 'アカウント', blueskyAccounts),
        'tl.rasqlist' => withOptions(e, 'リスト', rasqLists),
        'tl.dm' => withOptions(withOptions(e, '相手', dmPeers), 'アカウント', acctOptions),
        'tl.source' => withOptions(withOptions(e, 'TL', timelineIds), 'アカウント', acctOptions),
        'tl.search' || 'tl.myreactions' || 'trend.posts' => withOptions(e, 'アカウント', acctOptions),
        'composer.target' => withOptions(e, 'アカウント', accounts),
        _ => e,
      },
    for (final c in customs)
      NodeCatalogEntry(
        type: 'plugin:${c.id}',
        title: l.nodeprogEditorPluginSortTitle(c.label),
        icon: Icons.extension_outlined,
        genre: l.nodeprogCatalogGenreSortDictionary,
        author: l.nodeprogEditorPluginSortAuthor,
        description: l.nodeprogEditorPluginSortDescription,
        detail: l.nodeprogEditorPluginSortDetail,
        inputs: [
          const NodePort(label: '投稿リスト', dataType: '投稿リスト'),
          // スロットの TL プラグイン (D-171): パラメーター(JSON)は「ノードを設定」FOW の RRL で編集。
          if (c.id.startsWith('slot:')) const NodePort(label: 'パラメーター', value: '{}', dataType: '設定'),
        ],
        outputs: const [NodePort(label: '投稿リスト', dataType: '投稿リスト')],
      ),
    for (final f in functions) f.toCatalogEntry(),
  ];
});

class _NodeEditorScreenState extends ConsumerState<NodeEditorScreen> {
  final _canvasKey = GlobalKey();
  final _canvasFocus = FocusNode(debugLabel: 'nodeCanvas');

  NodeGraph _graph = const NodeGraph();
  bool _loaded = false;
  String? _selected;

  /// キャンバスのパン(空領域ドラッグ/矢印キー)。ノード座標(グラフ座標)は
  /// 動かさず、表示だけずらす。画面 = グラフ × [_scale] + パン。
  Offset _pan = Offset.zero;

  /// 拡大 / 縮小 (D-235): ピンチ / ホイール / ツールバーの ± で 0.4〜2.0。
  double _scale = 1.0;
  static const _minScale = 0.4;
  static const _maxScale = 2.0;

  /// グループ選択 (D-235): 範囲選択モードの矩形(グラフ座標)と選ばれたノード。
  bool _selectMode = false;
  Offset? _marqueeStart;
  Rect? _marquee;
  final Set<String> _selectedIds = {};

  /// ツールバーの位置 (D-236): 右上からのずれ(dx ≤ 0、dy ≥ 0)。設定 `nodeprog.ui` の `toolbar` に保存。
  Offset _toolbarShift = Offset.zero;

  /// ピンチの起点(前回のスケール)。
  double _scaleStart = 1.0;
  Offset _focalStart = Offset.zero;
  Offset _panStart = Offset.zero;

  /// コピーしたノード(ドロップダウンのコピー/ペースト)。
  GraphNode? _clipboard;

  /// 接続ドラッグ中の状態(始点ポートと現在位置、**グラフ座標**)。
  /// [cond] のときは縦の条件接続で、isOutput=true は下辺(condOut)始まり。
  ({String node, int port, bool isOutput, bool cond, Offset pos})? _drag;

  /// 現在のスコープ (D-101: 上側のタブ行で切り替わる)。
  late String _scope = widget.scope;

  /// グラフの持ち主アカウント (D-108: アカウント分離)。ノード TL タブは
  /// 作ったアカウント、それ以外は現在アカウント。
  String? get _accountKey {
    if (_scope == 'tl.bundle') return null; // 総合はバンドル共有 (D-114)
    if (_scope.startsWith('fn:')) return null; // 関数の中身はグローバル (D-118: 定義と同じ)
    if (_scope.startsWith('tl.node:')) {
      final id = _scope.substring(3);
      final owner = ref.read(allNodeTabsProvider).where((t) => t.$2.id == id).firstOrNull;
      if (owner != null) return owner.$1;
    }
    return ref.read(currentAccountProvider)?.key;
  }

  String get _area => nodeprogAreaFor(_accountKey, _scope);

  /// グラフの持ち主のアカウント(ヘッダーのアイコン、D-355)。総合 / 関数の中身は null。
  AccountSession? get _ownerSession {
    final key = _accountKey;
    if (key == null) return null;
    return ref.read(sessionsProvider).value?.sessions.where((s) => s.account.key == key).firstOrNull;
  }

  /// プラグインの並べ替えノード(`plugin:slot:<id>:<tl>`)の印: 持ち主のアカウントのアイコン + そのアカウントで動く版 (D-355)。
  Widget? _pluginBadge(GraphNode n) {
    if (!n.type.startsWith('plugin:slot:')) return null;
    final pluginId = n.type.substring('plugin:slot:'.length).split(':').first;
    final plugin = ref.read(slotPluginsProvider.notifier).active(accountKey: _accountKey).where((p) => p.id == pluginId).firstOrNull;
    return PluginNodeBadge(key: ValueKey('nodes.pluginBadge.${n.id}'), owner: _ownerSession, version: plugin?.storeVersion ?? (plugin == null ? null : 'dev'));
  }
  String get _title {
    // 関数の中身の編集 (D-118): タイトルに関数名を出す。
    if (_scope.startsWith('fn:')) {
      final def = ref.read(customFunctionsProvider).where((d) => d.id == _scope).firstOrNull;
      return def == null ? context.l10n.nodeprogEditorTitleFunctionBody : context.l10n.nodeprogEditorTitleFunctionBodyNamed(def.name);
    }
    return switch (_scope) {
      'composer' => context.l10n.nodeprogEditorTitleComposer,
      'trend' => context.l10n.nodeprogEditorTitleTrend,
      _ => context.l10n.nodeprogEditorTitleTimeline,
    };
  }

  /// dispose 時に ref が使えないため、パレット FOW を閉じる用に保持。
  late final OverlayManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = ref.read(overlayManagerProvider);
    _loadGraph();
    ref.read(settingsAreaProvider('nodeprog.ui').future).then((v) {
      final t = v['toolbar'];
      if (t is Map && mounted) setState(() => _toolbarShift = Offset((t['dx'] as num?)?.toDouble() ?? 0, (t['dy'] as num?)?.toDouble() ?? 0));
    }).catchError((_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPalette());
  }

  /// スコープのグラフを読み込む。空なら**タイムラインノードをデフォルト
  /// 配置** (D-101 — 関連スコープは関連タイムラインノード)。保存はユーザー
  /// が何か編集したときに全体ごと入る。
  Future<void> _loadGraph() async {
    setState(() {
      _loaded = false;
      _graph = const NodeGraph();
      _selected = null;
      _drag = null;
      _pan = Offset.zero;
    });
    try {
      // アカウント分離 (D-108): アカウント領域 → 旧グローバル領域の順で読む。
      final raw = await readNodeGraphRaw((a) => ref.read(settingsAreaProvider(a).future), _accountKey, _scope);
      if (!mounted) return;
      var g = raw is String ? NodeGraph.fromJson((jsonDecode(raw) as Map).cast<String, Object?>()) : const NodeGraph();
      if (g.nodes.isEmpty) g = _defaultGraph();
      // カタログ追従 (D-113): 追加された入力(アカウント等)と最新の選択肢を
      // 既存ノードにも反映(値はラベルで引き継ぎ。保存は次の編集時)。
      g = upgradeGraphNodes(g, _catalogByType);
      setState(() {
        _graph = g;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _switchScope(String next) {
    if (next == _scope) return;
    setState(() => _scope = next);
    _loadGraph();
  }

  /// 空グラフのデフォルト配置 (D-101/D-107): TL 系タブは
  /// **クロックメーカー → タイムライン取得 → タイムライン** のフルチェーン、
  /// 関連は関連タイムライン、コンポーザーはポスト先。
  NodeGraph _defaultGraph() {
    GraphNode inst(String type, String id, Offset at, {String? value}) {
      final e = builtinNodeCatalog.firstWhere((x) => x.type == type);
      final n = e.instantiate(id, at);
      return value == null ? n : n.copyWith(inputs: [n.inputs.first.copyWith(value: value), ...n.inputs.skip(1)]);
    }

    if (_scope == 'tl.relational') return NodeGraph(nodes: [inst('timeline.relational', 'n1', const Offset(100, 120))]);
    if (_scope == 'composer') return NodeGraph(nodes: [inst('composer.target', 'n1', const Offset(100, 120))]);
    // 関数の中身 (D-118): 関数入力 → 関数出力 の素通し鎖から始める。
    if (_scope.startsWith('fn:')) {
      return NodeGraph(
        nodes: [inst('fn.input', 'n1', const Offset(40, 120)), inst('fn.output', 'n2', const Offset(340, 140))],
        edges: const [GraphEdge(from: 'n1', fromPort: 0, to: 'n2', toPort: 0)],
      );
    }
    // 総合 (D-114): アカウント列から自動構成(取得×N → マージ → タイムライン)。
    if (_scope == 'tl.bundle') {
      final accounts = [for (final s in ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[]) '${s.account}'];
      return buildBundleGraph(accounts);
    }
    // トレンドのノートタブ (D-113): トレンド枠(トレンド取得 → トレンド枠)も
    // デフォルトで添える。
    if (_scope == 'trend') {
      return NodeGraph(
        nodes: [
          inst('clock', 'n1', const Offset(24, 32)),
          inst('tl.search', 'n2', const Offset(64, 214), value: ''),
          inst('timeline', 'n3', const Offset(300, 120)),
          inst('trend.tags', 'n4', const Offset(24, 400)),
          inst('trend.frame', 'n5', const Offset(300, 420)),
        ],
        edges: const [
          GraphEdge(from: 'n1', fromPort: 0, to: 'n2', toPort: 0, toIcon: true),
          GraphEdge(from: 'n2', fromPort: 0, to: 'n3', toPort: 0),
          GraphEdge(from: 'n4', fromPort: 0, to: 'n5', toPort: 0),
        ],
      );
    }
    final (srcType, srcValue) = switch (_scope) {
      'tl.social' => ('tl.source', 'social'),
      'tl.home' => ('tl.source', 'home'),
      'tl.local' => ('tl.source', 'local'),
      'tl.global' => ('tl.source', 'global'),
      'trend.following' => ('tl.source', 'home'),
      'trend.users' => ('tl.search', ''),
      _ => ('tl.source', 'home'), // node:<id> など
    };
    return NodeGraph(
      nodes: [
        inst('clock', 'n1', const Offset(24, 32)),
        inst(srcType, 'n2', const Offset(64, 214), value: srcValue),
        inst('timeline', 'n3', const Offset(300, 120)),
      ],
      edges: const [
        GraphEdge(from: 'n1', fromPort: 0, to: 'n2', toPort: 0, toIcon: true),
        GraphEdge(from: 'n2', fromPort: 0, to: 'n3', toPort: 0),
      ],
    );
  }

  // ---- タブ行 (D-101) -------------------------------------------------------

  /// (スコープ, ラベル, ユーザー作成か)。基本タブ + ノードTLタブ。
  /// トレンドのエディタは ノート/フォロー中/ユーザー のタブ (D-107)。
  List<(String, String, bool)> _tabs() {
    final l = context.l10n;
    if (_scope.startsWith('trend')) {
      return [('trend', l.nodeprogEditorTabTrendNotes, false), ('trend.following', l.nodeprogEditorTabFollowing, false), ('trend.users', l.nodeprogEditorTabTrendUsers, false)];
    }
    final nodeTabs = ref.watch(nodeTabsProvider);

    final tabs = <(String, String, bool)>[
      ('tl.bundle', l.nodeprogEditorTabBundle, false),
      ('tl.social', l.nodeprogEditorTabSocial, false),
      ('tl.home', l.nodeprogEditorTabFollowing, false),
      ('tl.relational', l.nodeprogEditorTabRelational, false),
      ('tl.local', l.nodeprogEditorTabLocal, false),
      ('tl.global', l.nodeprogEditorTabGlobal, false),
      for (final t in nodeTabs) ('tl.${t.id}', t.label, true),
    ];
    if (_scope.startsWith('tl.') && !tabs.any((t) => t.$1 == _scope)) {
      tabs.insert(0, (_scope, _scope.substring(3), false)); // 列にない基本 TL
    }
    return tabs;
  }

  /// 上側のタブ行: 今開いているタブをクリックで名前編集(ユーザータブのみ)、
  /// 「+」でタブ追加。
  PreferredSizeWidget _tabBar() {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final tabs = _tabs();
    return PreferredSize(
      preferredSize: const Size.fromHeight(40),
      child: Container(
        height: 40,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
        child: Row(children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
              child: Row(children: [
                for (final t in tabs)
                  InkWell(
                    onTap: () {
                      if (t.$1 != _scope) {
                        _switchScope(t.$1);
                      } else if (t.$3) {
                        _renameTab(t.$1); // 開いているタブをクリック → 名前編集
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: _scope == t.$1 ? BoxDecoration(border: Border(bottom: BorderSide(color: tokens.link, width: 2))) : null,
                      child: Text(
                        t.$2,
                        style: RasqTypography.bodySmall.copyWith(fontWeight: _scope == t.$1 ? FontWeight.w700 : null, color: _scope == t.$1 ? tokens.link : scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          if (_scope.startsWith('tl.')) RasqIconButton(icon: Icons.add, size: 20, tooltip: context.l10n.nodeprogEditorAddTabTooltip, onPressed: _addTab),
        ]),
      ),
    );
  }

  Future<String?> _promptText(String title, {String? initial, String hint = ''}) async {
    final controller = TextEditingController(text: initial ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: RasqTypography.title),
        content: TextField(controller: controller, autofocus: true, style: RasqTypography.bodySmall, decoration: InputDecoration(hintText: hint, isDense: true)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ctx.l10n.nodeprogEditorCancelButton)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(ctx.l10n.nodeprogEditorConfirmButton)),
        ],
      ),
    );
    return ok == true ? controller.text.trim() : null;
  }

  Future<void> _addTab() async {
    final name = await _promptText(context.l10n.nodeprogEditorNewTabTitle, hint: context.l10n.nodeprogEditorTabNameHint);
    if (name == null || name.isEmpty || !mounted) return;
    final tab = NodeTab(id: 'node:${DateTime.now().millisecondsSinceEpoch}', label: name);
    await saveNodeTabs(ref, [...ref.read(nodeTabsProvider), tab]);
    _switchScope('tl.${tab.id}');
  }

  Future<void> _renameTab(String scope) async {
    final id = scope.substring(3);
    final tabs = ref.read(nodeTabsProvider);
    final cur = tabs.where((t) => t.id == id).firstOrNull;
    if (cur == null) return;
    final name = await _promptText(context.l10n.nodeprogEditorRenameTab, initial: cur.label);
    if (name == null || name.isEmpty || !mounted) return;
    await saveNodeTabs(ref, [for (final t in tabs) t.id == id ? NodeTab(id: id, label: name) : t]);
    setState(() {});
  }

  Future<void> _deleteTab(String scope) async {
    final id = scope.substring(3);
    final tabs = ref.read(nodeTabsProvider);
    if (!tabs.any((t) => t.id == id)) return; // 他アカウントのタブは消せない (D-108)
    await saveNodeTabs(ref, [for (final t in tabs) if (t.id != id) t]);
    await ref.read(settingsAreaProvider(_area).notifier).set('graph', null);
    if (mounted) _switchScope('tl.home');
  }

  /// … メニュー (D-101/D-108): タブ名を変更/タブを削除(自分のユーザー
  /// タブのみ)/グラフをクリア/バンドルの集合表示切替。
  Future<void> _moreMenu(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final ownTab = _scope.startsWith('tl.node:') && ref.read(nodeTabsProvider).any((t) => 'tl.${t.id}' == _scope);
    final bundleTabs = ref.read(bundleNodeTabsVisibleProvider);
    final l = context.l10n;
    final pick = await _manager.showDropdown<String>(id: 'nodeprog.more', anchor: anchor, dense: true, items: [
      RasqDropdownItem(l.nodeprogEditorRenameTab, 'rename', enabled: ownTab),
      RasqDropdownItem(l.nodeprogEditorDeleteTab, 'deleteTab', enabled: ownTab, destructive: true),
      RasqDropdownItem(l.nodeprogEditorClearGraph, 'clear'),
      RasqDropdownItem(l.nodeprogEditorBundleTabsToggle, 'bundleTabs', checked: bundleTabs),
    ]);
    if (!mounted) return;
    switch (pick) {
      case 'rename':
        await _renameTab(_scope);
      case 'deleteTab':
        await _deleteTab(_scope);
      case 'clear':
        await ref.read(settingsAreaProvider(_area).notifier).set('graph', null);
        if (mounted) await _loadGraph();
      case 'bundleTabs':
        await ref.read(settingsAreaProvider('nodeprog.prefs').notifier).set('bundleTabs', !bundleTabs);
    }
  }

  @override
  void dispose() {
    _canvasFocus.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(settingsAreaProvider(_area).notifier).set('graph', jsonEncode(_graph.toJson()));
    // 総合 (D-114): ユーザーが編集したら自動構成の管理から外す(以降の
    // アカウント追加はマージの空き口への差し込みだけ試す)。
    if (_scope == 'tl.bundle') ref.read(settingsAreaProvider(_area).notifier).set('auto', null);
    // グラフで編集 (D-124): グラフが正になったのでコンポーネント構成
    // (tlcfg)は破棄 — 簡易側は「ノードで編集済み」の置き換え警告になる。
    // プラグインの自動構成もグラフ編集済み TL には触れない。
    if (_scope.startsWith('tl.') || _scope.startsWith('trend')) {
      ref.read(settingsAreaProvider(_area).notifier).set('tlcfg', null);
    }
    if (_scope == 'composer') {
      ref.read(settingsAreaProvider(_area).notifier).set('composercfg', null); // D-125
    }
  }

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
          semanticsLabel: context.l10n.nodeprogEditorPaletteSearchHint,
          spec: spec,
          builder: (ctx, handle) => _NodePalettePanel(spec: spec, scopeOf: () => _scope, onAdd: (e) => _addNode(e, _viewCenter()), onCreateFunction: () => _createFunction(_viewCenter())),
        )
        .whenComplete(() => router.routerDelegate.removeListener(onNavigate));
  }

  /// 現在見えているキャンバス中央(グラフ座標)。タップ追加の置き場所。
  Offset _viewCenter() {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(360, 480);
    return (Offset(size.width / 2, size.height / 3) - _pan) / _scale - Offset(kNodeW / 2, 0);
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

  /// ノードを動かす(グラフ座標の差分)。選ばれているノードの 1 つなら選択全体を一緒に動かす (D-235)。
  void _moveNode(String id, Offset delta) {
    final ids = _selectedIds.contains(id) ? _selectedIds : {id};
    setState(() {
      _graph = NodeGraph(
        nodes: [for (final n in _graph.nodes) ids.contains(n.id) ? n.copyWith(x: (n.x + delta.dx).clamp(-4000, 4000), y: (n.y + delta.dy).clamp(-4000, 4000)) : n],
        edges: _graph.edges,
      );
    });
  }

  /// 選択の削除 (D-235): ツールバーの削除 / Delete キー。
  void _removeSelected() {
    if (_selectedIds.isEmpty) return;
    final ids = {..._selectedIds};
    setState(() {
      _graph = NodeGraph(
        nodes: [for (final n in _graph.nodes) if (!ids.contains(n.id)) n],
        edges: [for (final e in _graph.edges) if (!ids.contains(e.from) && !ids.contains(e.to)) e],
      );
      _selectedIds.clear();
    });
    _save();
  }

  /// 整理整頓 (D-235): 取得 → 加工 → タイムラインの層に並べ直す([tidyGraph])。
  void _tidy() {
    setState(() {
      _graph = tidyGraph(_graph);
      _pan = Offset.zero;
    });
    _save();
  }

  /// 拡大 / 縮小 (D-235): [focal](画面座標)を中心に。
  void _zoomTo(double next, {Offset? focal}) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(360, 480);
    final f = focal ?? Offset(size.width / 2, size.height / 2);
    final s = next.clamp(_minScale, _maxScale);
    setState(() {
      // 焦点のグラフ座標を固定: (f - pan) / scale = (f - pan') / s。
      _pan = f - (f - _pan) * (s / _scale);
      _scale = s;
    });
  }

  /// 全体表示 (D-235): 全ノードが収まる倍率と位置。
  void _fitAll() {
    final b = NodeGeometry.bounds(_graph);
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (b == null || box == null) return;
    final size = box.size;
    final sx = ((size.width - 48) / b.width).clamp(_minScale, 1.0);
    final sy = ((size.height - 48) / b.height).clamp(_minScale, 1.0);
    final s = sx < sy ? sx : sy;
    setState(() {
      _scale = s;
      _pan = Offset((size.width - b.width * s) / 2 - b.left * s, 24 - b.top * s);
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
        content: Text(context.l10n.nodeprogEditorConnectTypeMismatch(out.typeLabel, input.typeLabel)),

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
            if (!(!e.cond && !e.toIcon && e.to == to.node && e.toPort == to.port)) e,
          GraphEdge(from: from.node, fromPort: from.port, to: to.node, toPort: to.port),
        ],
      );
    });
    _save();
  }

  void _disconnectInput(String node, int port) {
    final had = _graph.edges.any((e) => !e.cond && !e.toIcon && e.to == node && e.toPort == port);
    if (!had) return;
    setState(() {
      _graph = NodeGraph(nodes: _graph.nodes, edges: [for (final e in _graph.edges) if (!(!e.cond && !e.toIcon && e.to == node && e.toPort == port)) e]);
    });
    _save();
  }

  /// クロック接続 (D-095): クロック出力 → ノードのヘッダーアイコン。
  /// アイコンへの接続は 1 本まで(上書き)。
  void _connectClock(({String node, int port}) from, String toId) {
    if (from.node == toId) return;
    setState(() {
      _graph = NodeGraph(nodes: _graph.nodes, edges: [
        for (final e in _graph.edges)
          if (!(e.toIcon && e.to == toId)) e,
        GraphEdge(from: from.node, fromPort: from.port, to: toId, toPort: 0, toIcon: true),
      ]);
    });
    _save();
  }

  void _disconnectIcon(String toId) {
    final had = _graph.edges.any((e) => e.toIcon && e.to == toId);
    if (!had) return;
    setState(() {
      _graph = NodeGraph(nodes: _graph.nodes, edges: [for (final e in _graph.edges) if (!(e.toIcon && e.to == toId)) e]);
    });
    _save();
  }

  Future<void> _editValue(GraphNode node, int index, Rect anchor) async {
    final port = node.inputs[index];
    String? next;
    // スロットの TL プラグインの「パラメーター」ポート (D-171) は RRL の FOW で編集。
    if (port.label == 'パラメーター' && slotSortNodeOf(node.type) != null) {
      _openNodeParams(node);
      return;
    }
    if (port.options != null) {
      // 選択肢付きの値 (D-094) はドロップダウンで選ぶ。
      next = await _manager.showDropdown<String>(
        id: 'nodeprog.value',
        anchor: anchor,
        dense: true,
        items: [for (final o in port.options!) RasqDropdownItem(o, o, checked: o == port.value)],
      );
      if (next == null) return;
    } else {
      final controller = TextEditingController(text: port.value ?? '');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(port.label, style: RasqTypography.title),
          content: TextField(controller: controller, autofocus: true, style: RasqTypography.bodySmall),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ctx.l10n.nodeprogEditorCancelButton)),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(ctx.l10n.nodeprogEditorConfirmButton)),
          ],
        ),
      );
      if (ok != true) return;
      next = controller.text;
    }
    setState(() {
      _graph = NodeGraph(
        nodes: [
          for (final n in _graph.nodes)
            n.id == node.id
                ? n.copyWith(inputs: [for (var i = 0; i < n.inputs.length; i++) i == index ? n.inputs[i].copyWith(value: next) : n.inputs[i]])
                : n,
        ],
        edges: _graph.edges,
      );
    });
    _save();
  }

  // ---- カスタム関数 (D-099) -------------------------------------------------

  Future<void> _saveFunctions(List<CustomFunctionDef> defs) =>
      ref.read(settingsAreaProvider('nodeprog.functions').notifier).set('list', jsonEncode([for (final d in defs) d.toJson()]));

  /// キャンバスの空白を(長)押して作成画面 (D-099)。入力元が条件以外なら
  /// 入出力をリストから選択、条件なら条件タグを選択(複数 = 下側分岐が
  /// 複数個)。作成すると定義が保存され、その場にノードが置かれる。
  Future<void> _createFunction(Offset graphPos) async {
    final name = TextEditingController();
    var kind = 'cond';
    final tags = <String>{};
    final ins = <String>{};
    final outs = <String>{};
    const dataTypes = ['クロック', '数値', 'テキスト', 'テキスト配列', '投稿リスト'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        Widget chips(List<String> all, Set<String> picked) => Wrap(spacing: 6, runSpacing: 4, children: [
              for (final t in all)
                FilterChip(
                  label: Text(t, style: RasqTypography.caption),
                  selected: picked.contains(t),
                  visualDensity: VisualDensity.compact,
                  onSelected: (on) => setLocal(() => on ? picked.add(t) : picked.remove(t)),
                ),
            ]);
        final valid = name.text.trim().isNotEmpty && (kind == 'cond' ? tags.isNotEmpty : (ins.isNotEmpty || outs.isNotEmpty));
        final l = ctx.l10n;
        return AlertDialog(
          title: Text(l.nodeprogEditorCreateFunction, style: RasqTypography.title),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: name, autofocus: true, style: RasqTypography.bodySmall, decoration: InputDecoration(hintText: l.nodeprogEditorFunctionNameHint, isDense: true), onChanged: (_) => setLocal(() {})),
              const SizedBox(height: RasqSpacing.sm),
              Text(l.nodeprogEditorFunctionSourceLabel, style: RasqTypography.caption),
              Row(children: [
                ChoiceChip(label: Text(l.nodeprogEditorFunctionSourceCond), selected: kind == 'cond', visualDensity: VisualDensity.compact, onSelected: (_) => setLocal(() => kind = 'cond')),
                const SizedBox(width: 6),
                ChoiceChip(label: Text(l.nodeprogEditorFunctionSourceData), selected: kind == 'data', visualDensity: VisualDensity.compact, onSelected: (_) => setLocal(() => kind = 'data')),
              ]),
              const SizedBox(height: RasqSpacing.sm),
              if (kind == 'cond') ...[
                Text(l.nodeprogEditorFunctionCondTagsLabel, style: RasqTypography.caption),
                chips(condTagOptions, tags),
              ] else ...[
                Text(l.nodeprogEditorFunctionInputsLabel, style: RasqTypography.caption),
                chips(dataTypes, ins),
                const SizedBox(height: RasqSpacing.sm),
                Text(l.nodeprogEditorFunctionOutputsLabel, style: RasqTypography.caption),
                chips(dataTypes, outs),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ctx.l10n.nodeprogEditorCancelButton)),
            TextButton(onPressed: valid ? () => Navigator.of(ctx).pop(true) : null, child: Text(l.nodeprogEditorCreateButton)),
          ],
        );
      }),
    );
    if (ok != true || !mounted) return;
    final def = CustomFunctionDef(
      id: 'fn:${DateTime.now().millisecondsSinceEpoch}',
      name: name.text.trim(),
      kind: kind,
      tags: tags.toList(),
      inputs: ins.toList(),
      outputs: outs.toList(),
    );
    await _saveFunctions([...ref.read(customFunctionsProvider), def]);
    _addNode(def.toCatalogEntry(), graphPos);
    // データ関数 (D-118) はそのまま中身(関数入力 → … → 関数出力)の編集へ。
    if (kind == 'data' && mounted) ref.read(routerProvider).push(Routes.nodes(def.id));
  }

  // ---- ノードのドロップダウン (D-092) ---------------------------------------

  Future<void> _nodeMenu(GraphNode n, Offset globalPos) async {
    setState(() => _selected = n.id);
    final manager = ref.read(overlayManagerProvider);
    final l = context.l10n;
    final pick = await manager.showDropdown<String>(
      id: 'nodeprog.node',
      anchor: globalPos & const Size(1, 1),
      dense: true,
      items: [
        RasqDropdownItem(l.nodeprogEditorMenuInfo, 'info'),
        // スロットの TL プラグイン (D-171): パラメーターを RRL で編集。
        if (slotSortNodeOf(n.type) != null) RasqDropdownItem(l.nodeprogEditorParamsTitle, 'params'),
        // 関数の中身の編集 (D-118): fn.input → … → fn.output のサブグラフへ。
        if (n.type.startsWith('fn:')) RasqDropdownItem(l.nodeprogEditorMenuEditFunctionBody, 'fnbody'),
        // ストア統合 (M4/D-120): プラグインノードは提供元のページへ、
        // それ以外はストアホームへ。
        RasqDropdownItem(l.nodeprogEditorMenuStore, 'store'),
        RasqDropdownItem(l.nodeprogEditorMenuCopy, 'copy'),
        RasqDropdownItem(l.nodeprogEditorMenuPaste, 'paste', enabled: _clipboard != null),
        RasqDropdownItem(l.nodeprogEditorMenuDelete, 'delete', destructive: true),
      ],
    );
    if (!mounted) return;
    switch (pick) {
      case 'info':
        _showNodeInfo(n);
      case 'params':
        _openNodeParams(n);
      case 'fnbody':
        ref.read(routerProvider).push(Routes.nodes(n.type));
      case 'store':
        // v1: TL プラグインノードは同梱 wasm サンプルの掲載ページへ
        // (独立プラグインのノード → 掲載 id の対応はノード定義配布で拡張)。
        ref.read(routerProvider).push(n.type.startsWith('plugin:') ? Routes.storePlugin(storeSamplePluginId) : Routes.store);
      case 'copy':
        _clipboard = n;
      case 'paste':
        final c = _clipboard;
        if (c != null) {
          setState(() {
            _graph = NodeGraph(
              // 条件接続部も引き継ぐ (D-235: 以前は落ちていた)。
              nodes: [..._graph.nodes, GraphNode(id: _newId(), type: c.type, title: c.title, x: n.x + 24, y: n.y + 24, inputs: c.inputs, outputs: c.outputs, hasCondIn: c.hasCondIn, hasCondOut: c.hasCondOut, condBranches: c.condBranches)],
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

  /// 「ノードを設定」FOW (D-171): プラグインの `tl.params` の RRL。決定で
  /// 「パラメーター」ポートの値(JSON)に入る(実行時は `pluginParamsOf`)。
  void _openNodeParams(GraphNode n) {
    final manager = ref.read(overlayManagerProvider);
    if (manager.contains(nodeParamsFowId)) manager.close(nodeParamsFowId);
    final spec = FowSpec(type: FowPanelType.interstitial, initialHeightFactor: 0.85, minHeightFactor: 0.2, maxHeightFactor: 0.85, dockAboveFooter: true, heightStops: const [0.85], freeAboveStops: true);
    final router = ref.read(routerProvider);
    void onNavigate() => manager.close(nodeParamsFowId);
    router.routerDelegate.addListener(onNavigate);
    manager
        .showFow<Map<String, Object?>>(
          id: nodeParamsFowId,
          semanticsLabel: context.l10n.nodeprogEditorParamsTitle,
          spec: spec,
          builder: (ctx, handle) => PluginParamsPanel(
            nodeType: n.type,
            title: n.title,
            initial: pluginParamsOf(n),
            onConfirm: (v) => handle.close(result: v),
            onCancel: () => handle.close(),
          ),
        )
        .then((v) {
          if (v == null || !mounted) return;
          final idx = n.inputs.indexWhere((p) => p.label == 'パラメーター');
          setState(() {
            _graph = NodeGraph(
              nodes: [
                for (final g in _graph.nodes)
                  g.id == n.id
                      ? g.copyWith(
                          inputs: idx < 0
                              ? [...g.inputs, NodePort(label: 'パラメーター', value: jsonEncode(v), dataType: '設定')]
                              : [for (var i = 0; i < g.inputs.length; i++) i == idx ? g.inputs[i].copyWith(value: jsonEncode(v)) : g.inputs[i]],
                        )
                      : g,
              ],
              edges: _graph.edges,
            );
          });
          _save();
        })
        .whenComplete(() => router.routerDelegate.removeListener(onNavigate));
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
        description: entry == null ? null : nodeDescription(ctx, entry),
        inputs: n.inputs,
        outputs: n.outputs,
        hasCondIn: n.hasCondIn,
        hasCondOut: n.hasCondOut,
      ),
    );
  }

  // ---- ポート座標(グラフ座標系)--------------------------------------------

  /// global → グラフ座標(キャンバス local からパンを引いて倍率で割る)。
  Offset _toGraph(Offset global) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return ((box == null ? global : box.globalToLocal(global)) - _pan) / _scale;
  }

  /// キャンバス local → グラフ座標。
  Offset _localToGraph(Offset local) => (local - _pan) / _scale;

  /// ドロップ位置に最も近い反対側ポートを拾う(30px 以内)。
  ({String node, int port})? _hitPort(Offset at, {required bool wantOutput, NodePort? from}) {
    ({String node, int port})? best;
    var bestD = 30.0;
    for (final n in _graph.nodes) {
      final ports = wantOutput ? n.outputs : n.inputs;
      for (var i = 0; i < ports.length; i++) {
        // 設定ポート (D-235 / D-236): テキスト系の出力を引いているときだけ落とし先になる(それ以外は隣を奪わない)。
        if (!wantOutput && ports[i].dataType == '設定' && !(from != null && settingsPortAccepts(from, ports[i]))) continue;
        final c = wantOutput ? NodeGeometry.outputCenter(n, i) : NodeGeometry.inputCenter(n, i);
        final d = (c - at).distance;
        if (d < bestD) {
          bestD = d;
          best = (node: n.id, port: i);
        }
      }
    }
    return best;
  }

  /// 条件接続部のヒット判定(30px 以内)。[wantOut] = 下辺(condOut)を探す
  /// (戻り値の port は分岐番号、上辺は常に 0)。
  ({String node, int port})? _hitCondPort(Offset at, {required bool wantOut}) {
    ({String node, int port})? best;
    var bestD = 30.0;
    for (final n in _graph.nodes) {
      if (wantOut ? n.condOutCount == 0 : !n.hasCondIn) continue;
      final branches = wantOut ? n.condOutCount : 1;
      for (var b = 0; b < branches; b++) {
        final c = wantOut ? NodeGeometry.condOutCenter(n, b) : NodeGeometry.condInCenter(n);
        final d = (c - at).distance;
        if (d < bestD) {
          bestD = d;
          best = (node: n.id, port: b);
        }
      }
    }
    return best;
  }

  void _connectCond(({String node, int port}) from, String toId) {
    if (from.node == toId) return;
    setState(() {
      _graph = NodeGraph(nodes: _graph.nodes, edges: [
        // 上辺は 1 本まで — 既存の親は上書き。
        for (final e in _graph.edges)
          if (!(e.cond && e.to == toId)) e,
        GraphEdge(from: from.node, fromPort: from.port, to: toId, toPort: 0, cond: true),
      ]);
    });
    _save();
  }

  void _disconnectCondIn(String toId) {
    final had = _graph.edges.any((e) => e.cond && e.to == toId);
    if (!had) return;
    setState(() {
      _graph = NodeGraph(nodes: _graph.nodes, edges: [for (final e in _graph.edges) if (!(e.cond && e.to == toId)) e]);
    });
    _save();
  }

  void _endDrag(Offset at) {
    final drag = _drag;
    if (drag == null) return;
    if (drag.cond) {
      final target = _hitCondPort(at, wantOut: !drag.isOutput);
      if (target != null) {
        if (drag.isOutput) {
          _connectCond((node: drag.node, port: drag.port), target.node);
        } else {
          _connectCond(target, drag.node);
        }
      }
    } else {
      final byIdAll = {for (final n in _graph.nodes) n.id: n};
      final fromPort = drag.isOutput ? byIdAll[drag.node]?.outputs.elementAtOrNull(drag.port) : null;
      final target = _hitPort(at, wantOutput: !drag.isOutput, from: fromPort);
      if (target != null) {
        if (drag.isOutput) {
          _connect((node: drag.node, port: drag.port), target);
        } else {
          _connect(target, (node: drag.node, port: drag.port));
        }
      } else if (drag.isOutput) {
        // クロック出力はノードのアイコンにも繋げる (D-095)。
        final byId = {for (final n in _graph.nodes) n.id: n};
        final out = byId[drag.node]?.outputs.elementAtOrNull(drag.port);
        if (out?.dataType == 'クロック') {
          String? best;
          var bestD = 30.0;
          for (final n in _graph.nodes) {
            if (n.id == drag.node) continue;
            final d = (NodeGeometry.iconCenter(n) - at).distance;
            if (d < bestD) {
              bestD = d;
              best = n.id;
            }
          }
          if (best != null) _connectClock((node: drag.node, port: drag.port), best);
        }
      }
    }
    setState(() => _drag = null);
  }

  // ---- build ---------------------------------------------------------------

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_selectedIds.isEmpty) return KeyEventResult.ignored;
      _removeSelected();
      return KeyEventResult.handled;
    }
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
      // ノード検索の再呼び出し (D-096): パレット FOW を閉じてしまっても
      // ここから開き直せる(開いていれば何もしない)。
      // … メニュー (D-101): タブの削除/名前変更/グラフのクリア。
      appBar: RasqPageHeader(
        title: _title,
        // このグラフの持ち主のアカウント (D-355): プラグインのノードはこのアカウントの版で動く。
        leadingAvatar: _ownerSession == null ? null : ownerSummaryOf(_ownerSession!),
        actions: [
          Builder(builder: (ctx) {
            return RasqIconButton(icon: Icons.more_horiz, tooltip: ctx.l10n.nodeprogEditorMoreTooltip, onPressed: () => _moreMenu(ctx));
          }),
        ],
        bottom: _scope.startsWith('tl.') || _scope.startsWith('trend') ? _tabBar() : null,
      ),
      // ノード検索の再呼び出し (D-096/D-101): FAB — パレット FOW が開いて
      // いる間はその下に隠れる位置。
      floatingActionButton: FloatingActionButton(
        // 画面ごとに違う Hero のタグ (D-374): 既定のタグは、タブの画面が同じルームに並ぶと重なる。
        heroTag: 'fab.nodeEditor',
        onPressed: _openPalette,
        tooltip: context.l10n.nodeprogEditorSearchNodesTooltip,
        shape: const CircleBorder(),
        child: const Icon(Icons.manage_search),
      ),
      body: DragTarget<NodeCatalogEntry>(
        onAcceptWithDetails: (d) => _addNode(d.data, _toGraph(d.offset) - const Offset(0, 10)),
        builder: (context, _, _) => Focus(
          focusNode: _canvasFocus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: ClipRect(
            child: Listener(
              // ホイール (D-235): ポインタ位置を中心に拡大 / 縮小。
              onPointerSignal: (e) {
                if (e is PointerScrollEvent) {
                  final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                  final local = box == null ? e.localPosition : box.globalToLocal(e.position);
                  _zoomTo(_scale * (e.scrollDelta.dy > 0 ? 0.9 : 1.1), focal: local);
                }
              },
              child: Stack(key: _canvasKey, clipBehavior: Clip.hardEdge, children: [
                // 空領域: ドラッグでキャンバス移動(範囲選択モードなら矩形で選ぶ)、ピンチで拡大 / 縮小、
                // タップで選択解除 + フォーカス、**長押しでカスタム関数の作成画面** (D-099)。
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _canvasFocus.requestFocus();
                      setState(() {
                        _selected = null;
                        _selectedIds.clear();
                      });
                    },
                    onLongPressStart: (d) => _createFunction(_toGraph(d.globalPosition)),
                    // ダブルタップ (D-236): 範囲選択モードの切り替え(ツールバーと同じ)。
                    onDoubleTap: () => setState(() => _selectMode = !_selectMode),
                    onScaleStart: (d) {
                      _scaleStart = _scale;
                      _focalStart = d.localFocalPoint;
                      _panStart = _pan;
                      if (_selectMode && d.pointerCount == 1) {
                        setState(() {
                          _marqueeStart = _localToGraph(d.localFocalPoint);
                          _marquee = Rect.fromPoints(_marqueeStart!, _marqueeStart!);
                        });
                      }
                    },
                    onScaleUpdate: (d) {
                      if (_marqueeStart != null) {
                        setState(() => _marquee = Rect.fromPoints(_marqueeStart!, _localToGraph(d.localFocalPoint)));
                        return;
                      }
                      if (d.pointerCount >= 2) {
                        final s = (_scaleStart * d.scale).clamp(_minScale, _maxScale);
                        setState(() {
                          _pan = d.localFocalPoint - (_focalStart - _panStart) * (s / _scaleStart);
                          _scale = s;
                        });
                      } else {
                        setState(() => _pan += d.focalPointDelta);
                      }
                    },
                    onScaleEnd: (_) {
                      final m = _marquee;
                      if (m != null) {
                        setState(() {
                          _selectedIds
                            ..clear()
                            ..addAll([for (final n in _graph.nodes) if (m.overlaps(NodeGeometry.cardRect(n))) n.id]);
                          _marquee = null;
                          _marqueeStart = null;
                        });
                      }
                    },
                  ),
                ),
                NodeGraphCanvas(
                  graph: _graph,
                  pan: _pan,
                  scale: _scale,
                  selected: {..._selectedIds, ?_selected},
                  iconOf: (n) => _catalogByType[n.type]?.icon ?? Icons.extension_outlined,
                  // プラグインのノード (D-355): このグラフの持ち主のアカウントと、そのアカウントで動く版。
                  badgeOf: _pluginBadge,
                  drag: _drag,
                  marquee: _marquee,
                  callbacks: NodeCanvasCallbacks(
                    onMenu: (n, global) => _nodeMenu(n, global),
                    onMove: (n, delta) => _moveNode(n.id, delta),
                    onMoveEnd: _save,
                    onEditValue: (n, i, rect) => _editValue(n, i, rect),
                    onTapInput: (n, i) => _disconnectInput(n.id, i),
                    onTapCondIn: (n) => _disconnectCondIn(n.id),
                    onTapIcon: (n) => _disconnectIcon(n.id),
                    onPortDragStart: (n, i, isOutput, global) => setState(() => _drag = (node: n.id, port: i, isOutput: isOutput, cond: false, pos: _toGraph(global))),
                    onCondDragStart: (n, isOut, branch, global) => setState(() => _drag = (node: n.id, port: branch, isOutput: isOut, cond: true, pos: _toGraph(global))),
                    onPortDragUpdate: (global) => setState(() => _drag = _drag == null ? null : (node: _drag!.node, port: _drag!.port, isOutput: _drag!.isOutput, cond: _drag!.cond, pos: _toGraph(global))),
                    onPortDragEnd: () => _endDrag(_drag?.pos ?? Offset.zero),
                  ),
                ),
                if (_loaded && _graph.nodes.isEmpty)
                  Positioned.fill(child: IgnorePointer(child: RasqEmptyView(title: context.l10n.nodeprogEditorInlineEmpty, hint: context.l10n.nodeprogEditorEmptyHint))),
                // ツールバー (D-235): 範囲選択 / 削除 / 整理整頓 / − / % / + / 全体。
                // ツールバー (D-236): RAi の入力タイルと同じく掴んで動かせる(既定は右上)。
                Positioned(
                  top: 8 + _toolbarShift.dy,
                  right: 8 - _toolbarShift.dx,
                  child: GestureDetector(
                    key: const ValueKey('nodes.toolbar'),
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (d) => setState(() {
                      final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                      final size = box?.size ?? const Size(360, 480);
                      _toolbarShift = Offset((_toolbarShift.dx + d.delta.dx).clamp(-(size.width - 60), 0.0), (_toolbarShift.dy + d.delta.dy).clamp(0.0, size.height - 60));
                    }),
                    onPanEnd: (_) => ref.read(settingsAreaProvider('nodeprog.ui').notifier).set('toolbar', {'dx': _toolbarShift.dx, 'dy': _toolbarShift.dy}),
                    child: _toolbar(context),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      elevation: 2,
      borderRadius: BorderRadius.circular(RasqSizes.radiusPill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          RasqIconButton(key: const ValueKey('nodes.select'), icon: _selectMode ? Icons.highlight_alt : Icons.highlight_alt_outlined, size: 18, tooltip: _selectMode ? l.nodeprogEditorToolbarSelectStop : l.nodeprogEditorToolbarSelect, color: _selectMode ? RasqColors.link : null, onPressed: () => setState(() => _selectMode = !_selectMode)),
          RasqIconButton(key: const ValueKey('nodes.deleteSelected'), icon: Icons.delete_outline, size: 18, tooltip: l.nodeprogEditorToolbarDeleteSelected, onPressed: _selectedIds.isEmpty ? null : _removeSelected),
          RasqIconButton(key: const ValueKey('nodes.tidy'), icon: Icons.auto_fix_high_outlined, size: 18, tooltip: l.nodeprogEditorToolbarTidy, onPressed: _graph.nodes.isEmpty ? null : _tidy),
          RasqIconButton(key: const ValueKey('nodes.zoomOut'), icon: Icons.remove, size: 18, tooltip: l.nodeprogEditorToolbarZoomOut, onPressed: () => _zoomTo(_scale / 1.25)),
          InkWell(
            key: const ValueKey('nodes.zoomReset'),
            onTap: () => _zoomTo(1.0),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('${(_scale * 100).round()}%', style: RasqTypography.caption)),
          ),
          RasqIconButton(key: const ValueKey('nodes.zoomIn'), icon: Icons.add, size: 18, tooltip: l.nodeprogEditorToolbarZoomIn, onPressed: () => _zoomTo(_scale * 1.25)),
          RasqIconButton(key: const ValueKey('nodes.fit'), icon: Icons.fit_screen_outlined, size: 18, tooltip: l.nodeprogEditorToolbarFit, onPressed: _graph.nodes.isEmpty ? null : _fitAll),
        ]),
      ),
    );
  }
}

/// パレット FOW (D-092): 検索ホームの入力欄と同じデザイン
/// ([RasqExpandableSearchBox])+ ノードタイル(1 行の入出力情報付き)。
/// タイルのタップで詳細情報、長押しドラッグでキャンバスへ(ドラッグ中は
/// FOW を最小表示へ折りたたむ)。
class _NodePalettePanel extends ConsumerStatefulWidget {
  const _NodePalettePanel({required this.spec, required this.scopeOf, required this.onAdd, required this.onCreateFunction});

  final FowSpec spec;

  /// 現在のエディタスコープ(コンポーザー専用ノードの出し分けに使う)。
  final String Function() scopeOf;
  final ValueChanged<NodeCatalogEntry> onAdd;

  /// カスタム関数の作成 (D-119): パレットの先頭タイルから作成画面を開く
  /// (キャンバスの空白長押しと同じダイアログ)。
  final VoidCallback onCreateFunction;

  @override
  ConsumerState<_NodePalettePanel> createState() => _NodePalettePanelState();
}

class _NodePalettePanelState extends ConsumerState<_NodePalettePanel> {
  final _search = TextEditingController();
  final _focus = FocusNode(debugLabel: 'nodePaletteSearch');
  final _barKey = GlobalKey();
  bool _toggled = false;
  bool _fitScheduled = false;
  /// 選んだジャンル。空 = すべて。
  String _genre = '';

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

  /// 最小段の高さをバーの実測に合わせる (D-093: 固定比だと低いウィンドウで
  /// 入力欄が隠れる)。コンポーザー stick のピッタリ実測と同じ作法。
  void _scheduleFit() {
    if (_fitScheduled || _focus.hasFocus || _toggled) return; // 展開中は測らない
    _fitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitScheduled = false;
      if (!mounted || _focus.hasFocus || _toggled) return;
      final bar = _barKey.currentContext?.size?.height;
      if (bar == null) return;
      final mq = MediaQuery.of(context);
      final avail = mq.size.height - (mq.viewInsets.bottom > 0 ? mq.viewInsets.bottom : fowDockInsetOf(context, ref.read(routerProvider)));
      if (avail <= 0) return;
      final spec = widget.spec;
      // バー + ハンドル 18 + 予備。
      final fit = ((bar + 18 + 2) / avail).clamp(spec.minHeightFactor, spec.maxHeightFactor).toDouble();
      if ((spec.heightStops.firstOrNull ?? 0) != fit) spec.heightStops = [fit, _paletteExpanded];
      final collapsed = spec.heightFactor.value < _paletteExpanded - 0.05;
      if (collapsed && !spec.userResized && (spec.heightFactor.value - fit).abs() > 0.005) {
        spec.heightFactor.value = fit;
      }
    });
  }

  /// 最小段(実測後は heightStops の先頭)。ドラッグ開始時の折りたたみ先。
  double get _collapsedStop => widget.spec.heightStops.firstOrNull ?? _paletteCollapsed;

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
    final l = context.l10n;
    final genres = ['', ...{for (final e in catalog) e.genre}];
    // スコープ限定ノード: ポスト先はコンポーザー (D-106)、関数入出力は
    // 関数の中身の編集画面 (D-118) だけに出す。
    bool scopeAllows(NodeCatalogEntry e) {
      final scope = widget.scopeOf();
      if (e.type == 'composer.target') return scope == 'composer';
      if (e.type == 'fn.input' || e.type == 'fn.output') return scope.startsWith('fn:');
      return true;
    }

    final entries = [
      for (final e in catalog)
        if (scopeAllows(e))
          if ((_genre.isEmpty || e.genre == _genre) && (query.isEmpty || e.title.contains(query) || (e.description ?? '').contains(query) || (e.detail ?? '').contains(query))) e,
    ];

    _scheduleFit();
    final bar = Padding(
        key: _barKey,
        padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, 6, RasqSpacing.sm, 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // RAi (未実装, D-093 でアセット化): 実装時にはここからノードを
          // 内部的に操作する想定。
          const RasqRaiButton(size: 28),
          const SizedBox(width: 2),
          Expanded(
            child: RasqExpandableSearchBox(
              expanded: _toggled || _focus.hasFocus,
              controller: _search,
              focusNode: _focus,
              hintText: l.nodeprogEditorPaletteSearchHint,
              onDropdownTap: () => setState(() => _toggled = !_toggled),
              filterChips: [
                RasqFilterChipItem(
                  label: l.nodeprogEditorPaletteSortChip,
                  dropdown: true,
                  onAnchorTap: (rect) => manager.showDropdown<String>(
                    id: 'nodeprog.sort',
                    ownerId: nodePaletteFowId,
                    anchor: rect,
                    dense: true,
                    items: [RasqDropdownItem(l.nodeprogEditorPaletteSortRelevance, 'relevance', checked: true)],
                  ),
                ),
                RasqFilterChipItem(
                  label: l.nodeprogEditorPaletteGenreChip(_genre.isEmpty ? l.nodeprogCatalogGenreSortDictionary : _genre),
                  dropdown: true,
                  selected: _genre.isNotEmpty,
                  onAnchorTap: (rect) async {
                    final pick = await manager.showDropdown<String>(
                      id: 'nodeprog.genre',
                      ownerId: nodePaletteFowId,
                      anchor: rect,
                      dense: true,
                      items: [for (final g in genres) RasqDropdownItem(g.isEmpty ? l.nodeprogEditorPaletteGenreAll : g, g, checked: g == _genre)],
                    );
                    if (pick != null) setState(() => _genre = pick);
                  },
                ),
              ],
              trailing: RasqIconButton(icon: Icons.settings_outlined, size: 18, tooltip: l.nodeprogEditorPaletteSettingsTooltip, onPressed: () {}),
            ),
          ),
        ]),
    );
    // カスタム関数の作成タイル (D-119): 空白長押しだけだと見つけにくいので、
    // 検索(パレット)の「関数」ジャンル/すべての先頭にも作成導線を置く。
    final showCreate = (_genre.isEmpty || _genre == l.nodeprogCatalogGenreFunction) && (query.isEmpty || l.nodeprogEditorCreateFunction.contains(query));

    // 最小表示(折りたたみ)時はバーだけをクリップ描画 — 端数ではみ出さない。
    return LayoutBuilder(builder: (context, c) {
      if (c.maxHeight < 130) {
        return SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: bar);
      }
      return Column(children: [
        bar,
        Expanded(
          child: entries.isEmpty && !showCreate
              ? RasqEmptyView(title: l.nodeprogEditorPaletteEmptyTitle, hint: l.nodeprogEditorPaletteEmptyHint)
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: RasqSpacing.sm),
                  itemCount: entries.length + (showCreate ? 1 : 0),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    if (showCreate && i == 0) {
                      return RasqPluginTile(
                        icon: Icons.add_circle_outline,
                        title: l.nodeprogEditorCreateFunction,
                        subtitle: l.nodeprogCatalogGenreFunction,
                        description: l.nodeprogEditorCreateFunctionDescription,
                        chevron: false,
                        onTap: widget.onCreateFunction,
                      );
                    }
                    return _tile(scheme, manager, entries[i - (showCreate ? 1 : 0)]);
                  },
                ),
        ),
      ]);
    });
  }

  Widget _tile(ColorScheme scheme, OverlayManager manager, NodeCatalogEntry e) {
    // ノードタイル (D-093): 「アクションバーをなくして > メニューがついた
    // 投稿タイルみたいなもの」 — サーバー/プラグイン表示と共用の
    // RasqPluginTile。入出力は 1 行 + 形式色ドット。
    final tile = RasqPluginTile(
      icon: e.icon,
      title: e.title,
      subtitle: context.l10n.nodeprogEditorTileSubtitle(e.author ?? context.l10n.nodeprogEditorBuiltinAuthor, e.genre),
      description: nodeDescription(context, e),
      detail: e.ioSummary,
      detailColorDots: e.typeDots,
      onTap: () => _showDetail(manager, e),
    );
    return LongPressDraggable<NodeCatalogEntry>(
      data: e,
      feedback: Material(
        color: scheme.surface,
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(opacity: 0.95, child: SizedBox(width: 300, child: tile)),
      ),
      // ドラッグ中は FOW を最小表示に折りたたむ(WF: 下側に stick)。
      onDragStarted: () {
        _focus.unfocus();
        widget.spec.heightFactor.value = _collapsedStop;
      },
      child: tile,
    );
  }

  /// タイルのクリック → ノードの詳細情報 (D-092)。
  void _showDetail(OverlayManager manager, NodeCatalogEntry e) {
    manager.showBottomSheet<void>(
      id: 'nodeprog.detail',
      title: e.title,
      ownerId: nodePaletteFowId,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _NodeInfoBody(author: e.author, genre: e.genre, description: nodeDescription(ctx, e), inputs: e.inputs, outputs: e.outputs, hasCondIn: e.hasCondIn, hasCondOut: e.hasCondOut),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
          child: FilledButton.icon(
            onPressed: () {
              manager.close('nodeprog.detail');
              widget.onAdd(e);
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text(ctx.l10n.nodeprogEditorAddToCanvas),
          ),
        ),
        // カスタム関数 (D-118): 中身(サブグラフ)の編集へ。
        if (e.type.startsWith('fn:'))
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
            child: TextButton.icon(
              onPressed: () {
                manager.close('nodeprog.detail');
                ref.read(routerProvider).push(Routes.nodes(e.type));
              },
              icon: const Icon(Icons.account_tree_outlined, size: 18),
              label: Text(ctx.l10n.nodeprogEditorEditFunctionBody),
            ),
          ),
        // カスタム関数 (D-099) は定義ごと消せる(置き済みノードは残り、
        // カタログ欠けとしてフォールバックアイコンになる)。
        if (e.type.startsWith('fn:'))
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
            child: TextButton(
              onPressed: () {
                manager.close('nodeprog.detail');
                final defs = ref.read(customFunctionsProvider);
                ref.read(settingsAreaProvider('nodeprog.functions').notifier).set('list', jsonEncode([for (final d in defs) if (d.id != e.type) d.toJson()]));
              },
              child: Text(ctx.l10n.nodeprogEditorDeleteFunction, style: RasqTypography.bodySmall.copyWith(color: RasqTokens.of(context).danger)),
            ),
          ),
      ]),
    );
  }
}

/// ノード情報の中身(詳細シートと「ノード情報」で共用)。
class _NodeInfoBody extends StatelessWidget {
  const _NodeInfoBody({this.author, this.genre, this.description, required this.inputs, required this.outputs, this.hasCondIn = false, this.hasCondOut = false});

  final String? author;
  final String? genre;
  final String? description;
  final List<NodePort> inputs;
  final List<NodePort> outputs;
  final bool hasCondIn;
  final bool hasCondOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
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
          Text([?author, if (genre != null) l.nodeprogEditorInfoGenre(genre!)].join(' · '), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        if (description != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(description!, style: RasqTypography.bodySmall)),
        if (inputs.isNotEmpty || hasCondIn) ...[
          Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text(l.nodeprogEditorCanvasInputs, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
          for (final p in inputs) port(p),
          if (hasCondIn) port(NodePort(label: l.nodeprogEditorInfoCondIn, dataType: '条件')),
        ],
        if (outputs.isNotEmpty || hasCondOut) ...[
          Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text(l.nodeprogEditorCanvasOutputs, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
          for (final p in outputs) port(p),
          if (hasCondOut) port(NodePort(label: l.nodeprogEditorInfoCondOut, dataType: '条件')),

        ],
      ]),
    );
  }
}


/// ノードの説明。開発者モードでは詳しい説明 (D-362)。
String? nodeDescription(BuildContext context, NodeCatalogEntry e) => e.detail != null && RasqDeveloperMode.of(context) ? e.detail : e.description;
