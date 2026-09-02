import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../../app/providers.dart';
import '../../app/router.dart' show Routes, routerProvider;
import '../../shell/headers.dart';
import '../home/timeline_providers.dart' show customTimelinesProvider;
import '../settings/settings_dsl.dart';
import '../store/store_client.dart' show storeSamplePluginId;
import 'node_tabs.dart';
import 'tl_components.dart';

/// コンポーネント追加パレット (D-122): ノード検索と同じ FOW。
const tlConfigPaletteFowId = 'fow.tlconfig.palette';

/// パラメーター編集 FOW (D-123): タイル + RRL 描画のパラメーター部。
const tlConfigParamsFowId = 'fow.tlconfig.params';

/// 自作リスト(リスト系ソースの候補)。
final _tlListNamesProvider = FutureProvider<List<String>>((ref) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  try {
    return [for (final l in await s.lists()) l.name];
  } catch (_) {
    return const [];
  }
});

/// タイムラインのカスタマイズ(簡略版, D-121 — ワイヤーフレーム
/// 「タイムラインのカスタマイズ」)。TL は **SNSタイムライン(取得元)** と
/// **アルゴリズム(上から順に適用)** のコンポーネント積みで組み、保存時に
/// 正準形ノードグラフへコンパイルする(実行系は従来のまま)。
/// 自由形のノードキャンバスは TL スコープでは**一旦無効化**(D-121)。
class TimelineConfigScreen extends ConsumerStatefulWidget {
  const TimelineConfigScreen({super.key, required this.scope});
  final String scope;
  @override
  ConsumerState<TimelineConfigScreen> createState() => _TimelineConfigScreenState();
}

class _TimelineConfigScreenState extends ConsumerState<TimelineConfigScreen> {
  late String _scope = widget.scope;
  TlConfig _cfg = const TlConfig();
  bool _loaded = false;

  /// tlcfg が無いのに graph がある = ノードエディタで手組みされた TL。
  /// このまま保存すると置き換えるので、バナーで明示する。
  bool _handEdited = false;

  /// グラフの持ち主アカウント(D-108: ノードエディタと同じ分離)。
  String? get _accountKey {
    if (_scope == 'tl.bundle') return null;
    if (_scope.startsWith('tl.node:')) {
      final owner = ref.read(allNodeTabsProvider).where((t) => 'tl.${t.$2.id}' == _scope).firstOrNull;
      if (owner != null) return owner.$1;
    }
    return ref.read(currentAccountProvider)?.key;
  }

  String get _area => nodeprogAreaFor(_accountKey, _scope);

  List<String> get _accounts => [for (final s in ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[]) '${s.account}'];

  /// dispose 時に ref が使えないため、パレット FOW を閉じる用に保持。
  late final OverlayManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = ref.read(overlayManagerProvider);
    _load();
  }

  @override
  void dispose() {
    _manager.close(tlConfigPaletteFowId);
    _manager.close(tlConfigParamsFowId);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loaded = false;
      _handEdited = false;
    });
    try {
      final area = await ref.read(settingsAreaProvider(_area).future);
      final raw = area['tlcfg'];
      if (!mounted) return;
      if (raw is String) {
        setState(() {
          _cfg = TlConfig.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
          _loaded = true;
        });
        return;
      }
      final hasGraph = (await readNodeGraphRaw((a) => ref.read(settingsAreaProvider(a).future), _accountKey, _scope)) != null;
      if (!mounted) return;
      setState(() {
        _cfg = defaultTlConfig(_scope, bundleAccounts: _accounts);
        _handEdited = hasGraph;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _cfg = defaultTlConfig(_scope, bundleAccounts: _accounts);
          _loaded = true;
        });
      }
    }
  }

  /// 保存 = コンパイルしてノードグラフとして書く(実行系・クロック・
  /// 重複畳み込みは従来経路のまま)。
  Future<void> _save() async {
    final store = ref.read(settingsAreaProvider(_area).notifier);
    await store.set('tlcfg', jsonEncode(_cfg.toJson()));
    await store.set('graph', jsonEncode(compileTlConfig(_cfg, scope: _scope).toJson()));
    if (_scope == 'tl.bundle') await store.set('auto', null); // 編集 = 自動構成の管理から外す (D-114)
    if (mounted) setState(() => _handEdited = false);
  }

  void _update(TlConfig next) {
    setState(() => _cfg = next);
    _save();
  }

  void _switchScope(String next) {
    if (next == _scope) return;
    setState(() => _scope = next);
    _load();
  }

  // ---- タブ行(ノードエディタ D-101 と同じ作法)-----------------------------

  List<(String, String, bool)> _tabs() {
    final nodeTabs = ref.watch(nodeTabsProvider);
    final tabs = <(String, String, bool)>[
      ('tl.bundle', '総合', false),
      ('tl.social', 'おすすめ', false),
      ('tl.home', 'フォロー中', false),
      ('tl.relational', '関連', false),
      ('tl.local', 'ローカル', false),
      ('tl.global', 'グローバル', false),
      for (final t in nodeTabs) ('tl.${t.id}', t.label, true),
    ];
    if (!tabs.any((t) => t.$1 == _scope)) tabs.insert(0, (_scope, _scope.startsWith('tl.') ? _scope.substring(3) : _scope, false));
    return tabs;
  }

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
                        _renameTab(t.$1);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: _scope == t.$1 ? BoxDecoration(border: Border(bottom: BorderSide(color: tokens.link, width: 2))) : null,
                      child: Text(t.$2, style: RasqTypography.bodySmall.copyWith(fontWeight: _scope == t.$1 ? FontWeight.w700 : null, color: _scope == t.$1 ? tokens.link : scheme.onSurfaceVariant)),
                    ),
                  ),
              ]),
            ),
          ),
          RasqIconButton(icon: Icons.add, size: 20, tooltip: 'タブを追加', onPressed: _addTab),
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('決定')),
        ],
      ),
    );
    return ok == true ? controller.text.trim() : null;
  }

  Future<void> _addTab() async {
    final name = await _promptText('新しいタブ', hint: 'タブ名');
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
    final name = await _promptText('タブ名を変更', initial: cur.label);
    if (name == null || name.isEmpty || !mounted) return;
    await saveNodeTabs(ref, [for (final t in tabs) t.id == id ? NodeTab(id: id, label: name) : t]);
    setState(() {});
  }

  Future<void> _deleteTab(String scope) async {
    final id = scope.substring(3);
    final tabs = ref.read(nodeTabsProvider);
    if (!tabs.any((t) => t.id == id)) return; // 他アカウントのタブは消せない (D-108)
    await saveNodeTabs(ref, [for (final t in tabs) if (t.id != id) t]);
    final store = ref.read(settingsAreaProvider(_area).notifier);
    await store.set('graph', null);
    await store.set('tlcfg', null);
    if (mounted) _switchScope('tl.home');
  }

  Future<void> _moreMenu(BuildContext buttonContext) async {
    final manager = ref.read(overlayManagerProvider);
    final box = buttonContext.findRenderObject() as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final ownTab = _scope.startsWith('tl.node:') && ref.read(nodeTabsProvider).any((t) => 'tl.${t.id}' == _scope);
    final bundleTabs = ref.read(bundleNodeTabsVisibleProvider);
    final pick = await manager.showDropdown<String>(id: 'tlconfig.more', anchor: anchor, dense: true, items: [
      RasqDropdownItem('タブ名を変更', 'rename', enabled: ownTab),
      RasqDropdownItem('タブを削除', 'deleteTab', enabled: ownTab, destructive: true),
      const RasqDropdownItem('このTLの構成をリセット', 'reset'),
      // 自由形ノードキャンバス: 一旦無効化 (D-121 — ワイヤーフレーム指定)。
      const RasqDropdownItem('ノードの編集(調整中)', 'nodes', enabled: false),
      RasqDropdownItem('バンドルでノードTLを集合表示', 'bundleTabs', checked: bundleTabs),
    ]);
    if (!mounted) return;
    switch (pick) {
      case 'rename':
        await _renameTab(_scope);
      case 'deleteTab':
        await _deleteTab(_scope);
      case 'reset':
        final store = ref.read(settingsAreaProvider(_area).notifier);
        await store.set('graph', null);
        await store.set('tlcfg', null);
        if (mounted) await _load();
      case 'bundleTabs':
        await ref.read(settingsAreaProvider('nodeprog.prefs').notifier).set('bundleTabs', !bundleTabs);
    }
  }

  // ---- コンポーネント操作 ----------------------------------------------------

  Future<String?> _pickFrom(BuildContext anchorContext, String id, List<String> options, String current) async {
    final manager = ref.read(overlayManagerProvider);
    final box = anchorContext.findRenderObject() as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    return manager.showDropdown<String>(id: id, anchor: anchor, dense: true, items: [for (final o in options) RasqDropdownItem(o, o, checked: o == current)]);
  }

  /// コンポーネント追加 (D-122): ノード検索と同じ FOW パレットを開く。
  /// タイルはプラグインタイルデザインで、アルゴリズム側は入出力ではなく
  /// **ネイティブ対応の SNS プラグイン**を表示する。選択で追加して閉じる。
  void _openPalette({required bool algorithms}) {
    final manager = ref.read(overlayManagerProvider);
    if (manager.contains(tlConfigPaletteFowId)) manager.close(tlConfigPaletteFowId);
    final spec = FowSpec(
      type: FowPanelType.widget,
      initialHeightFactor: 0.5,
      minHeightFactor: 0.09,
      maxHeightFactor: 0.85,
      dockAboveFooter: true,
      heightStops: const [0.09, 0.5],
      freeAboveStops: true,
    );
    // ページ遷移で自動クローズ(ノードパレットと同じ作法, D-048)。
    final router = ref.read(routerProvider);
    void onNavigate() => manager.close(tlConfigPaletteFowId);
    router.routerDelegate.addListener(onNavigate);
    manager
        .showFow<void>(
          id: tlConfigPaletteFowId,
          semanticsLabel: 'プラグインノードを検索',
          spec: spec,
          builder: (ctx, handle) => _ComponentPalettePanel(
            spec: spec,
            algorithms: algorithms,
            onAddAlgorithm: (a) {
              manager.close(tlConfigPaletteFowId);
              _update(_cfg.copyWith(algorithms: [..._cfg.algorithms, a]));
            },
            onAddSource: (s) {
              manager.close(tlConfigPaletteFowId);
              _update(_cfg.copyWith(sources: [..._cfg.sources, s]));
            },
          ),
        )
        .whenComplete(() => router.routerDelegate.removeListener(onNavigate));
  }

  /// コンポーネントの見た目情報(タイル/詳細/並べ替え行で共用)。
  (IconData, String, String, String) _algoInfo(TlAlgorithmComponent a) => (
        a.isPlugin ? Icons.extension_outlined : (a.isSuggest ? Icons.auto_awesome_outlined : Icons.schedule),
        a.title,
        a.isPlugin ? 'TLプラグイン' : 'RASQ',
        switch (a.type) {
          'chrono' => '取得したままの時刻順に整えます。',
          'suggest' => '${a.from}(${suggestFromKind(a.from) == 'myposts' ? '自分の投稿' : suggestFromKind(a.from) == 'myreplies' ? '自分の返信' : 'リアクションした投稿'})を基準に、${a.what}で合う投稿を先頭へ並べ替えます。',
          _ => '投稿リストをプラグインのソート(tl.sort)で並べ替えます。',
        },
      );

  (IconData, String, String, String) _sourceInfo(TlSourceComponent s) => (
        s.isTrend ? Icons.travel_explore : (s.isList ? Icons.list_alt_outlined : Icons.download_outlined),
        s.isTrend ? '現在のトレンドTLを取得' : (s.isList ? 'リストTLを取得' : 'タイムラインを取得'),
        s.account.isEmpty ? '現在のアカウント' : s.account,
        'TL: ${s.isTrend ? 'トレンド上位タグの検索結果' : s.isList ? 'リスト: ${s.listName}' : switch (s.tl) { 'social' => 'おすすめ', 'local' => 'ローカル', 'global' => 'グローバル', _ => 'フォロー中 (home)' }}',
      );

  /// … メニュー (D-123): 詳細/一時的な無効化(解除)/ストアページ/削除。
  /// 並べ替えはアクションバー編集と同じシート([_openReorder])に移した。
  Future<void> _componentMenu(BuildContext anchorContext, {required bool algorithm, required int i}) async {
    final manager = ref.read(overlayManagerProvider);
    final box = anchorContext.findRenderObject() as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final enabled = algorithm ? _cfg.algorithms[i].enabled : _cfg.sources[i].enabled;
    final isPlugin = algorithm && _cfg.algorithms[i].isPlugin;
    final pick = await manager.showDropdown<String>(id: 'tlconfig.component', anchor: anchor, dense: true, items: [
      const RasqDropdownItem('詳細', 'info'),
      const RasqDropdownItem('パラメーターを編集', 'params'),
      RasqDropdownItem(enabled ? '一時的な無効化' : '無効化の解除', 'toggle'),
      // v1: TL プラグインは同梱 wasm サンプルの掲載ページへ (D-120 と同じ対応)。
      RasqDropdownItem('プラグインのストアページへ移動', 'store', enabled: isPlugin),
      const RasqDropdownItem('削除', 'delete', destructive: true),
    ]);
    if (pick == null || !mounted) return;
    switch (pick) {
      case 'info':
        _showComponentInfo(algorithm: algorithm, i: i);
      case 'params':
        _openParamsFow(algorithm: algorithm, index: i);
      case 'toggle':
        if (algorithm) {
          _update(_cfg.copyWith(algorithms: [for (var k = 0; k < _cfg.algorithms.length; k++) k == i ? _cfg.algorithms[k].copyWith(enabled: !enabled) : _cfg.algorithms[k]]));
        } else {
          _update(_cfg.copyWith(sources: [for (var k = 0; k < _cfg.sources.length; k++) k == i ? _cfg.sources[k].copyWith(enabled: !enabled) : _cfg.sources[k]]));
        }
      case 'store':
        ref.read(routerProvider).push(Routes.storePlugin(storeSamplePluginId));
      case 'delete':
        if (algorithm) {
          _update(_cfg.copyWith(algorithms: [for (var k = 0; k < _cfg.algorithms.length; k++) if (k != i) _cfg.algorithms[k]]));
        } else if (_cfg.sources.length > 1) {
          _update(_cfg.copyWith(sources: [for (var k = 0; k < _cfg.sources.length; k++) if (k != i) _cfg.sources[k]]));
        }
    }
  }

  void _showComponentInfo({required bool algorithm, required int i}) {
    final manager = ref.read(overlayManagerProvider);
    final (icon, title, subtitle, description) = algorithm ? _algoInfo(_cfg.algorithms[i]) : _sourceInfo(_cfg.sources[i]);
    final sns = [for (final p in ref.read(pluginRegistryProvider).plugins) p.manifest.name];
    manager.showBottomSheet<void>(
      id: 'tlconfig.info',
      title: title,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.page),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('提供: $subtitle', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: RasqSpacing.sm),
            Text(description, style: RasqTypography.bodySmall),
            const SizedBox(height: RasqSpacing.sm),
            Text('対応: ${sns.isEmpty ? '—' : sns.join('・')}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        );
      },
    );
  }

  /// パラメーター編集 FOW (D-123): 「>」/… の「パラメーターを編集」から。
  /// タイルヘッダー + **RRL で描いたパラメーター部**(設定 DSL と同じ部品)。
  void _openParamsFow({required bool algorithm, required int index}) {
    final manager = ref.read(overlayManagerProvider);
    if (manager.contains(tlConfigParamsFowId)) manager.close(tlConfigParamsFowId);
    final spec = FowSpec(
      type: FowPanelType.widget,
      initialHeightFactor: 0.55,
      minHeightFactor: 0.2,
      maxHeightFactor: 0.85,
      dockAboveFooter: true,
      heightStops: const [0.55],
      freeAboveStops: true,
    );
    final router = ref.read(routerProvider);
    void onNavigate() => manager.close(tlConfigParamsFowId);
    router.routerDelegate.addListener(onNavigate);
    manager
        .showFow<void>(
          id: tlConfigParamsFowId,
          semanticsLabel: 'ノードを設定',
          spec: spec,
          builder: (ctx, handle) => _ComponentParamsPanel(
            algorithm: algorithm,
            index: index,
            scope: _scope,
            cfgOf: () => _cfg,
            infoOf: (alg, i) => alg ? _algoInfo(_cfg.algorithms[i]) : _sourceInfo(_cfg.sources[i]),
            accounts: _accounts,
            onUpdate: _update,
          ),
        )
        .whenComplete(() => router.routerDelegate.removeListener(onNavigate));
  }

  /// 並べ替え (D-123): アクションバー編集 (D-025 系) と同じ UI —
  /// ドラッグで並び替え、目のトグルで一時的な無効化。即時反映。
  void _openReorder({required bool algorithms}) {
    final manager = ref.read(overlayManagerProvider);
    manager.showBottomSheet<void>(
      id: 'tlconfig.reorder',
      title: algorithms ? 'アルゴリズムの並べ替え' : 'タイムラインの並べ替え',
      builder: (_) => _ReorderSheetBody(
        algorithms: algorithms,
        cfgOf: () => _cfg,
        infoOf: (alg, i) => alg ? _algoInfo(_cfg.algorithms[i]) : _sourceInfo(_cfg.sources[i]),
        onUpdate: _update,
      ),
    );
  }

  // ---- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    ref.watch(sessionsProvider); // アカウント選択肢
    return Scaffold(
      appBar: RasqPageHeader(
        title: 'タイムラインをカスタマイズ',
        actions: [Builder(builder: (ctx) => RasqIconButton(icon: Icons.more_horiz, tooltip: 'その他', onPressed: () => _moreMenu(ctx)))],
        bottom: _tabBar(),
      ),
      body: !_loaded
          ? const RasqLoading()
          : ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.page), children: [
              // 説明バナー(ワイヤーフレーム: アルゴリズムは上から順に適用)。
              Container(
                margin: const EdgeInsets.all(RasqSpacing.sm),
                padding: const EdgeInsets.all(RasqSpacing.sm),
                decoration: BoxDecoration(color: tokens.link.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(RasqSizes.radiusSm)),
                child: Text('タイムラインのアルゴリズムや取り込み、表示するタイムラインなどを指定できます。アルゴリズムは上から順に適用されます。',
                    style: RasqTypography.caption.copyWith(color: tokens.link)),
              ),
              if (_handEdited)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
                  child: Text('この TL はノードエディタで編集されています。ここで変更すると簡易構成で置き換えます。',
                      style: RasqTypography.caption.copyWith(color: tokens.danger)),
                ),
              RasqSectionHeader(
                title: 'アルゴリズム',
                topMargin: 0,
                trailing: RasqIconButton(icon: Icons.swap_vert, size: 18, tooltip: 'アルゴリズムの並べ替え', onPressed: () => _openReorder(algorithms: true)),
              ),
              for (var i = 0; i < _cfg.algorithms.length; i++) _componentTile(algorithm: true, i: i),
              _addTile('アルゴリズムを追加', () => _openPalette(algorithms: true)),
              RasqSectionHeader(
                title: 'SNSタイムライン',
                trailing: RasqIconButton(icon: Icons.swap_vert, size: 18, tooltip: 'タイムラインの並べ替え', onPressed: () => _openReorder(algorithms: false)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
                child: Text('複数を重ねると 1 本に合流し、同じ投稿は 1 枚に畳まれます(タイルの ↓ でアカウント切替)。投稿加工プラグインは各タイムライン提供元(SNSプラグイン)側で適用されます。',
                    style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              ),
              for (var i = 0; i < _cfg.sources.length; i++) _componentTile(algorithm: false, i: i),
              _addTile('タイムラインを追加', () => _openPalette(algorithms: false)),
              const RasqSectionHeader(title: '自動更新'),
              Builder(builder: (ctx) {
                return RasqListTile(
                  title: '間隔: ${_cfg.clock.isEmpty ? 'なし' : _cfg.clock}',
                  leading: const Icon(Icons.schedule),
                  onTap: () async {
                    final pick = await _pickFrom(ctx, 'tlconfig.clock', ['なし', '15秒', '1分', '5分'], _cfg.clock.isEmpty ? 'なし' : _cfg.clock);
                    if (pick != null) _update(_cfg.copyWith(clock: pick == 'なし' ? '' : pick));
                  },
                );
              }),
            ]),
    );
  }

  Widget _addTile(String label, VoidCallback onTap) {
    final tokens = RasqTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.add, size: 18, color: tokens.link),
        label: Text(label, style: RasqTypography.bodySmall.copyWith(color: tokens.link)),
      ),
    );
  }

  /// コンポーネントタイル (D-123): タップ(>)= パラメーター編集 FOW、
  /// … = 詳細/無効化/ストア/削除。無効化中はグレー表示。
  Widget _componentTile({required bool algorithm, required int i}) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = algorithm ? _cfg.algorithms[i].enabled : _cfg.sources[i].enabled;
    final (icon, title, subtitle, description) = algorithm ? _algoInfo(_cfg.algorithms[i]) : _sourceInfo(_cfg.sources[i]);
    return Row(children: [
      Expanded(
        child: RasqPluginTile(
          leading: Icon(icon, size: 22, color: enabled ? null : scheme.onSurfaceVariant.withValues(alpha: 0.5)),
          title: title,
          subtitle: enabled ? subtitle : '$subtitle ・ 無効化中',
          description: description,
          chevron: true,
          onTap: () => _openParamsFow(algorithm: algorithm, index: i),
        ),
      ),
      Builder(
          builder: (ctx) => RasqIconButton(
              icon: Icons.more_horiz,
              size: 18,
              tooltip: algorithm ? 'アルゴリズムの操作' : 'タイムラインの操作',
              onPressed: () => _componentMenu(ctx, algorithm: algorithm, i: i))),
      const SizedBox(width: RasqSpacing.sm),
    ]);
  }
}

/// コンポーネント追加パレット (D-122): ノード検索と同じ FOW + 検索欄。
/// タイルは**プラグインタイルデザイン**(ワイヤーフレームと同じ内部配置 —
/// アイコン/名前/提供元/説明/詳細行)で、ホバー中もこの表示のまま。
/// 詳細行は入出力ではなく**ネイティブ対応の SNS プラグイン**。
class _ComponentPalettePanel extends ConsumerStatefulWidget {
  const _ComponentPalettePanel({required this.spec, required this.algorithms, required this.onAddAlgorithm, required this.onAddSource});

  final FowSpec spec;

  /// true = アルゴリズム側、false = タイムライン(取得元)側。
  final bool algorithms;
  final ValueChanged<TlAlgorithmComponent> onAddAlgorithm;
  final ValueChanged<TlSourceComponent> onAddSource;

  @override
  ConsumerState<_ComponentPalettePanel> createState() => _ComponentPalettePanelState();
}

class _PaletteItem {
  const _PaletteItem({required this.icon, required this.title, required this.subtitle, required this.description, required this.supported, required this.add});
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;

  /// ネイティブ対応の SNS プラグイン名(詳細行に出す)。
  final List<String> supported;
  final VoidCallback add;
}

class _ComponentPalettePanelState extends ConsumerState<_ComponentPalettePanel> {
  final _search = TextEditingController();
  final _focus = FocusNode();

  /// ジャンルチップ (D-123): 提供元(RASQ/TLプラグイン/SNSプラグイン/
  /// リスト系)で絞り込む。ノードパレットと同じチップ UI。
  String _genre = 'すべて';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<_PaletteItem> _items() {
    // ネイティブ対応 SNS プラグイン: 組み込みは登録済みプラグイン全部、
    // TL プラグインは宣言元(現在の wasm セッションのプラグイン)。
    final registry = ref.watch(pluginRegistryProvider);
    final allSns = [for (final p in registry.plugins) p.manifest.name];
    final sessionPluginId = ref.watch(currentSnsSessionProvider)?.pluginId;
    final sessionSns = [registry.plugin(sessionPluginId ?? '')?.manifest.name ?? sessionPluginId ?? '—'];
    if (widget.algorithms) {
      final plugins = ref.watch(customTimelinesProvider).value ?? const [];
      return [
        _PaletteItem(
            icon: Icons.auto_awesome_outlined,
            title: 'サジェスト',
            subtitle: 'RASQ',
            description: '[キーワード/類似性] を [投稿内容/リアクション/会話内容] から読み取り、合う投稿を先頭へ並べ替えます。',
            supported: allSns,
            add: () => widget.onAddAlgorithm(const TlAlgorithmComponent(type: 'suggest'))),
        _PaletteItem(
            icon: Icons.schedule,
            title: '時系列順',
            subtitle: 'RASQ',
            description: '取得したままの時刻順に整えます。',
            supported: allSns,
            add: () => widget.onAddAlgorithm(const TlAlgorithmComponent(type: 'chrono'))),
        for (final p in plugins)
          _PaletteItem(
              icon: Icons.extension_outlined,
              title: '${p.label}でソート',
              subtitle: 'TLプラグイン',
              description: '投稿リストをプラグインのソート(tl.sort)で並べ替えます。',
              supported: sessionSns,
              add: () => widget.onAddAlgorithm(TlAlgorithmComponent(type: 'plugin:${p.id}', pluginLabel: '${p.label}でソート'))),
      ];
    }
    // タイムライン側 (D-122): [タイムライン, リスト系, 現在のトレンドTL] に絞る。
    final lists = ref.watch(_tlListNamesProvider).value ?? const <String>[];
    return [
      _PaletteItem(
          icon: Icons.download_outlined,
          title: 'タイムライン',
          subtitle: 'SNSプラグイン',
          description: 'SNS の基本タイムライン(フォロー中/おすすめ/ローカル/グローバル)を取り込みます。種類とアカウントは追加後のタイルで選べます。',
          supported: allSns,
          add: () => widget.onAddSource(const TlSourceComponent(tl: 'home'))),
      for (final name in lists)
        _PaletteItem(
            icon: Icons.list_alt_outlined,
            title: 'リスト: $name',
            subtitle: 'リスト系',
            description: '自作リスト「$name」のタイムラインを取り込みます。',
            supported: sessionSns,
            add: () => widget.onAddSource(TlSourceComponent(tl: 'list:$name'))),
      _PaletteItem(
          icon: Icons.travel_explore,
          title: '現在のトレンドTL',
          subtitle: 'RASQ',
          description: 'いまのトレンド上位タグの検索結果を 1 本に合流して取り込みます。',
          supported: allSns,
          add: () => widget.onAddSource(const TlSourceComponent(tl: 'trend'))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.read(overlayManagerProvider);
    final query = _search.text.trim();
    final all = _items();
    final genres = ['すべて', ...{for (final e in all) e.subtitle}];
    final items = [
      for (final e in all)
        if (_genre == 'すべて' || e.subtitle == _genre)
          if (query.isEmpty || e.title.contains(query) || e.description.contains(query) || e.subtitle.contains(query)) e,
    ];
    final bar = Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, 6, RasqSpacing.sm, 6),
      child: RasqExpandableSearchBox(
        expanded: _focus.hasFocus,
        controller: _search,
        focusNode: _focus,
        hintText: 'プラグインノードを検索',
        filterChips: [
          RasqFilterChipItem(
            label: '並び替え: 関連順',
            dropdown: true,
            onAnchorTap: (rect) => manager.showDropdown<String>(
              id: 'tlconfig.palette.sort',
              ownerId: tlConfigPaletteFowId,
              anchor: rect,
              dense: true,
              items: const [RasqDropdownItem('関連順', 'relevance', checked: true)],
            ),
          ),
          RasqFilterChipItem(
            label: 'ジャンル: $_genre',
            dropdown: true,
            selected: _genre != 'すべて',
            onAnchorTap: (rect) async {
              final pick = await manager.showDropdown<String>(
                id: 'tlconfig.palette.genre',
                ownerId: tlConfigPaletteFowId,
                anchor: rect,
                dense: true,
                items: [for (final g in genres) RasqDropdownItem(g, g, checked: g == _genre)],
              );
              if (pick != null && mounted) setState(() => _genre = pick);
            },
          ),
        ],
      ),
    );
    // 最小表示(折りたたみ)時はバーだけ(ノードパレットと同じ作法)。
    return LayoutBuilder(builder: (context, c) {
      if (c.maxHeight < 130) {
        return SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: bar);
      }
      return Column(children: [
        bar,
        Expanded(
          child: items.isEmpty
              ? const RasqEmptyView(title: 'コンポーネントが見つかりません', hint: '検索ワードを変えてみてください')
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: RasqSpacing.sm),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return RasqPluginTile(
                      icon: e.icon,
                      title: e.title,
                      subtitle: e.subtitle,
                      description: e.description,
                      // 入出力の代わりにネイティブ対応の SNS プラグイン (D-122)。
                      detail: '対応: ${e.supported.isEmpty ? '—' : e.supported.join('・')}',
                      chevron: false,
                      onTap: e.add,
                    );
                  },
                ),
        ),
      ]);
    });
  }
}

/// パラメーター編集 FOW の中身 (D-123): タイルヘッダー + **RRL で描いた
/// パラメーター部**(設定 DSL と同じ L2 部品 — SectionHeader/RadioListTile)。
/// ワイヤーフレーム「ノードを設定」の形。プラグイン側の RRL 設定ページは
/// ストア統合(ノード定義配布)でここに差し込まれる。
class _ComponentParamsPanel extends StatefulWidget {
  const _ComponentParamsPanel(
      {required this.algorithm, required this.index, required this.scope, required this.cfgOf, required this.infoOf, required this.accounts, required this.onUpdate});

  final bool algorithm;
  final int index;
  final String scope;
  final TlConfig Function() cfgOf;
  final (IconData, String, String, String) Function(bool algorithm, int i) infoOf;
  final List<String> accounts;
  final ValueChanged<TlConfig> onUpdate;

  @override
  State<_ComponentParamsPanel> createState() => _ComponentParamsPanelState();
}

class _ComponentParamsPanelState extends State<_ComponentParamsPanel> {
  RrlNode _radio(String key, String label, String value) =>
      RrlNode(t: 'RadioListTile', k: key, p: {'title': label, 'value': value, 'group': '\$.settings.$key'}, on: const {'change': 'settings.set'});

  RrlNode _section(String title) => RrlNode(t: 'SectionHeader', p: {'title': title});

  (Map<String, Object?>, RrlNode) _paramsOf(TlConfig cfg) {
    if (widget.algorithm) {
      final a = cfg.algorithms[widget.index];
      if (a.isSuggest) {
        return (
          {'what': a.what, 'from': a.from},
          RrlNode(t: 'Column', c: [
            _section('なにをサジェストする?'),
            for (final o in suggestWhatOptions) _radio('what', o, o),
            _section('なにから読み取る?'),
            for (final o in suggestFromOptions) _radio('from', o, o),
          ]),
        );
      }
      return (
        const {},
        RrlNode(t: 'Column', c: [
          RrlNode(t: 'Text', p: {
            'text': a.isPlugin ? 'このプラグインのパラメーター(RRL 設定ページ)は、ノード定義の配布(ストア統合)でここに表示されます。' : '時系列順にパラメーターはありません。'
          }),
        ]),
      );
    }
    final s = cfg.sources[widget.index];
    return (
      {'tl': s.tl, 'account': s.account.isEmpty ? '現在のアカウント' : s.account},
      RrlNode(t: 'Column', c: [
        if (!s.isTrend && !s.isList) ...[
          _section('TL 種別'),
          _radio('tl', 'フォロー中 (home)', 'home'),
          _radio('tl', 'おすすめ (social)', 'social'),
          _radio('tl', 'ローカル (local)', 'local'),
          _radio('tl', 'グローバル (global)', 'global'),
        ],
        _section('アカウント'),
        _radio('account', '現在のアカウント', '現在のアカウント'),
        for (final a in widget.accounts) _radio('account', a, a),
      ]),
    );
  }

  void _apply(String key, Object? value) {
    final cfg = widget.cfgOf();
    if (widget.algorithm) {
      final next = [
        for (var k = 0; k < cfg.algorithms.length; k++)
          k == widget.index ? cfg.algorithms[k].copyWith(what: key == 'what' ? '$value' : null, from: key == 'from' ? '$value' : null) : cfg.algorithms[k],
      ];
      widget.onUpdate(cfg.copyWith(algorithms: next));
    } else {
      final next = [
        for (var k = 0; k < cfg.sources.length; k++)
          k == widget.index
              ? cfg.sources[k].copyWith(tl: key == 'tl' ? '$value' : null, account: key == 'account' ? ('$value' == '現在のアカウント' ? '' : '$value') : null)
              : cfg.sources[k],
      ];
      widget.onUpdate(cfg.copyWith(sources: next));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.cfgOf();
    final inRange = widget.algorithm ? widget.index < cfg.algorithms.length : widget.index < cfg.sources.length;
    if (!inRange) return const SizedBox.shrink();
    final (icon, title, subtitle, description) = widget.infoOf(widget.algorithm, widget.index);
    final (values, root) = _paramsOf(cfg);
    final host = RrlHost(
      // 疑似 instanceScope(設定 DSL D-031 と同じ作法): ホスト静的ページ。
      instanceScope: 'rasq.host.tlconfig:-:0:${widget.scope}.${widget.algorithm ? 'algo' : 'src'}.${widget.index}',
      scope: RrlScope({'settings': values}),
      onEvent: (nodeId, kind, {String? fn, Map<String, Object?> payload = const {}}) {
        if (fn == 'settings.set') _apply(nodeId.split(':').last, payload['value']);
      },
    );
    return Column(children: [
      RasqPluginTile(icon: icon, title: title, subtitle: subtitle, description: description, chevron: false),
      const Divider(height: 1),
      Expanded(child: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.sm), children: [RrlRenderer(node: root, host: host)])),
    ]);
  }
}

/// 並べ替えシート (D-123): アクションバー編集と同じ UI — ドラッグで
/// 並び替え、目のトグルで一時的な無効化(解除)。即時反映 + 永続化。
class _ReorderSheetBody extends StatefulWidget {
  const _ReorderSheetBody({required this.algorithms, required this.cfgOf, required this.infoOf, required this.onUpdate});

  final bool algorithms;
  final TlConfig Function() cfgOf;
  final (IconData, String, String, String) Function(bool algorithm, int i) infoOf;
  final ValueChanged<TlConfig> onUpdate;

  @override
  State<_ReorderSheetBody> createState() => _ReorderSheetBodyState();
}

class _ReorderSheetBodyState extends State<_ReorderSheetBody> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cfg = widget.cfgOf();
    final count = widget.algorithms ? cfg.algorithms.length : cfg.sources.length;

    Widget row(int i) {
      final enabled = widget.algorithms ? cfg.algorithms[i].enabled : cfg.sources[i].enabled;
      final (icon, title, subtitle, _) = widget.infoOf(widget.algorithms, i);
      return RasqListTile(
        key: ValueKey('reorder$i'),
        title: title,
        subtitle: subtitle,
        leading: Icon(icon, size: 22, color: enabled ? scheme.onSurface : scheme.onSurfaceVariant),
        chevron: false,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          RasqIconButton(
            icon: enabled ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
            tooltip: enabled ? '一時的な無効化' : '無効化の解除',
            onPressed: () {
              if (widget.algorithms) {
                widget.onUpdate(cfg.copyWith(algorithms: [for (var k = 0; k < cfg.algorithms.length; k++) k == i ? cfg.algorithms[k].copyWith(enabled: !enabled) : cfg.algorithms[k]]));
              } else {
                widget.onUpdate(cfg.copyWith(sources: [for (var k = 0; k < cfg.sources.length; k++) k == i ? cfg.sources[k].copyWith(enabled: !enabled) : cfg.sources[k]]));
              }
              setState(() {});
            },
          ),
          Icon(Icons.drag_handle, size: 20, color: scheme.onSurfaceVariant),
        ]),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: true,
        onReorderItem: (from, to) {
          if (widget.algorithms) {
            final list = [...cfg.algorithms];
            final moved = list.removeAt(from);
            list.insert(to.clamp(0, list.length), moved);
            widget.onUpdate(cfg.copyWith(algorithms: list));
          } else {
            final list = [...cfg.sources];
            final moved = list.removeAt(from);
            list.insert(to.clamp(0, list.length), moved);
            widget.onUpdate(cfg.copyWith(sources: list));
          }
          setState(() {});
        },
        children: [for (var i = 0; i < count; i++) row(i)],
      ),
    ]);
  }
}
