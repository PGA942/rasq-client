import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../home/timeline_providers.dart' show customTimelinesProvider;
import '../settings/settings_dsl.dart';
import 'node_tabs.dart';
import 'tl_components.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _addAlgorithm() async {
    final manager = ref.read(overlayManagerProvider);
    final plugins = ref.read(customTimelinesProvider).value ?? const [];
    final pick = await manager.showBottomSheet<TlAlgorithmComponent>(
      id: 'tlconfig.addAlgo',
      title: 'アルゴリズムを追加',
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        RasqListTile(
            title: 'サジェスト',
            subtitle: '[キーワード/類似性] を [投稿内容/リアクション/会話内容] から',
            leading: const Icon(Icons.auto_awesome_outlined),
            onTap: () => manager.close('tlconfig.addAlgo', result: const TlAlgorithmComponent(type: 'suggest'))),
        RasqListTile(
            title: '時系列順',
            subtitle: '取得したままの時刻順に整えます',
            leading: const Icon(Icons.schedule),
            onTap: () => manager.close('tlconfig.addAlgo', result: const TlAlgorithmComponent(type: 'chrono'))),
        for (final p in plugins)
          RasqListTile(
              title: '${p.label}でソート',
              subtitle: 'カスタム(TLプラグイン)',
              leading: const Icon(Icons.extension_outlined),
              onTap: () => manager.close('tlconfig.addAlgo', result: TlAlgorithmComponent(type: 'plugin:${p.id}', pluginLabel: '${p.label}でソート'))),
      ]),
    );
    if (pick != null) _update(_cfg.copyWith(algorithms: [..._cfg.algorithms, pick]));
  }

  Future<void> _algorithmMenu(BuildContext anchorContext, int i) async {
    final pick = await _pickFrom(anchorContext, 'tlconfig.algoMenu', [if (i > 0) '上へ移動', if (i < _cfg.algorithms.length - 1) '下へ移動', '削除'], '');
    if (pick == null || !mounted) return;
    final list = [..._cfg.algorithms];
    switch (pick) {
      case '上へ移動':
        final a = list.removeAt(i);
        list.insert(i - 1, a);
      case '下へ移動':
        final a = list.removeAt(i);
        list.insert(i + 1, a);
      case '削除':
        list.removeAt(i);
    }
    _update(_cfg.copyWith(algorithms: list));
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
              const RasqSectionHeader(title: 'アルゴリズム', topMargin: 0),
              for (var i = 0; i < _cfg.algorithms.length; i++) _algorithmTile(i),
              _addTile('アルゴリズムを追加', _addAlgorithm),
              const RasqSectionHeader(title: 'SNSタイムライン'),
              Padding(
                padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
                child: Text('複数を重ねると 1 本に合流し、同じ投稿は 1 枚に畳まれます(タイルの ↓ でアカウント切替)。投稿加工プラグインは各タイムライン提供元(SNSプラグイン)側で適用されます。',
                    style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              ),
              for (var i = 0; i < _cfg.sources.length; i++) _sourceTile(i),
              _addTile('タイムラインを追加', () => _update(_cfg.copyWith(sources: [..._cfg.sources, const TlSourceComponent()]))),
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

  Widget _algorithmTile(int i) {
    final a = _cfg.algorithms[i];
    final subtitle = a.isPlugin ? 'TLプラグイン' : 'RASQ';
    final description = switch (a.type) {
      'chrono' => '取得したままの時刻順に整えます。',
      'suggest' => '${a.from}(${suggestFromKind(a.from) == 'myposts' ? '自分の投稿' : suggestFromKind(a.from) == 'myreplies' ? '自分の返信' : 'リアクションした投稿'})を基準に、${a.what}で合う投稿を先頭へ並べ替えます。',
      _ => '投稿リストをプラグインのソート(tl.sort)で並べ替えます。',
    };
    return Row(children: [
      Expanded(
        child: RasqPluginTile(
          icon: a.isPlugin ? Icons.extension_outlined : (a.isSuggest ? Icons.auto_awesome_outlined : Icons.schedule),
          title: a.title,
          subtitle: subtitle,
          description: description,
          chevron: false,
          onTap: a.isSuggest
              ? () async {
                  // なにを → なにから の順で選び直す(2 段ドロップダウン)。
                  final manager = ref.read(overlayManagerProvider);
                  final what = await manager.showBottomSheet<String>(
                    id: 'tlconfig.suggestWhat',
                    title: 'なにをサジェストする?',
                    builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final o in suggestWhatOptions) RasqListTile(title: o, onTap: () => manager.close('tlconfig.suggestWhat', result: o)),
                    ]),
                  );
                  if (what == null || !mounted) return;
                  final from = await manager.showBottomSheet<String>(
                    id: 'tlconfig.suggestFrom',
                    title: 'なにから読み取る?',
                    builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final o in suggestFromOptions) RasqListTile(title: o, onTap: () => manager.close('tlconfig.suggestFrom', result: o)),
                    ]),
                  );
                  if (from == null || !mounted) return;
                  _update(_cfg.copyWith(algorithms: [for (var k = 0; k < _cfg.algorithms.length; k++) k == i ? _cfg.algorithms[k].copyWith(what: what, from: from) : _cfg.algorithms[k]]));
                }
              : null,
        ),
      ),
      Builder(builder: (ctx) => RasqIconButton(icon: Icons.more_horiz, size: 18, tooltip: 'アルゴリズムの操作', onPressed: () => _algorithmMenu(ctx, i))),
      const SizedBox(width: RasqSpacing.sm),
    ]);
  }

  Widget _sourceTile(int i) {
    final s = _cfg.sources[i];
    final tlLabel = switch (s.tl) { 'social' => 'おすすめ', 'local' => 'ローカル', 'global' => 'グローバル', _ => 'フォロー中 (home)' };
    return Row(children: [
      Expanded(
        child: Builder(builder: (ctx) {
          return RasqPluginTile(
            icon: Icons.download_outlined,
            title: 'タイムラインを取得',
            subtitle: s.account.isEmpty ? '現在のアカウント' : s.account,
            description: 'TL: $tlLabel',
            chevron: true,
            onTap: () async {
              final tl = await _pickFrom(ctx, 'tlconfig.srcTl', ['home', 'social', 'local', 'global'], s.tl);
              if (tl == null || !mounted || !ctx.mounted) return;
              final acct = await _pickFrom(ctx, 'tlconfig.srcAcct', ['現在のアカウント', ..._accounts], s.account.isEmpty ? '現在のアカウント' : s.account);
              if (acct == null || !mounted) return;
              _update(_cfg.copyWith(sources: [
                for (var k = 0; k < _cfg.sources.length; k++) k == i ? s.copyWith(tl: tl, account: acct == '現在のアカウント' ? '' : acct) : _cfg.sources[k],
              ]));
            },
          );
        }),
      ),
      Builder(builder: (ctx) {
        return RasqIconButton(
          icon: Icons.more_horiz,
          size: 18,
          tooltip: 'タイムラインの操作',
          onPressed: () async {
            final pick = await _pickFrom(ctx, 'tlconfig.srcMenu', ['削除'], '');
            if (pick == '削除' && mounted && _cfg.sources.length > 1) {
              _update(_cfg.copyWith(sources: [for (var k = 0; k < _cfg.sources.length; k++) if (k != i) _cfg.sources[k]]));
            }
          },
        );
      }),
      const SizedBox(width: RasqSpacing.sm),
    ]);
  }
}
