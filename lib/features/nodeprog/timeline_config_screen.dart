import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession, SnsSession, TimelineKind;
import 'package:rrl_core/rrl_core.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../../app/providers.dart';
import '../plugins/slot_plugins.dart';
import '../../app/router.dart' show Routes, routerProvider;
import '../../shell/headers.dart';
import '../home/timeline_providers.dart' show customTimelinesProvider;
import '../settings/settings_dsl.dart';
import '../store/store_client.dart' show storeSamplePluginId;
import 'node_tabs.dart';
import 'tl_config_store.dart';
import '../trend/tendency_fows.dart';
import '../trend/tendency_profile.dart';
import '../collections/rasq_collections.dart' show hasRasqAccountProvider;
import '../collections/rasq_list_picker.dart';
import 'plugin_node_badge.dart' show ownerSummaryOf;
import 'tl_components.dart';

/// コンポーネント追加パレット (D-122): ノード検索と同じ FOW。
const tlConfigPaletteFowId = 'fow.tlconfig.palette';

/// パラメーター編集 FOW (D-123): タイル + RRL 描画のパラメーター部。
const tlConfigParamsFowId = 'fow.tlconfig.params';

/// DM の相手(DM 取得タイルの候補, D-127)。
final _tlDmPeersProvider = FutureProvider<List<String>>((ref) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  try {
    return [for (final r in await s.dmRooms()) r.peer.handle];
  } catch (_) {
    return const [];
  }
});

/// 自作リスト(リスト系ソースの候補)。
/// アカウント表記(`@handle@instance`)→ セッション (D-194)。無ければ現在のセッション。
SnsSession? tlSessionForLabel(Ref ref, String label) {
  final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
  final s = sessions.where((x) => '${x.account}' == label || x.account.key == label).firstOrNull;
  if (s == null) return ref.watch(currentSnsSessionProvider);
  return ref.watch(sessionForAccountProvider(s.account.key));
}

/// アカウントごとのリスト (D-194)。取れない SNS は空。
final tlListsProvider = FutureProvider.family<List<UserListInfo>, String>((ref, account) async {
  final s = tlSessionForLabel(ref, account);
  if (s == null) return const [];
  try {
    return await s.lists();
  } catch (_) {
    return const [];
  }
});

/// アカウントごとの基本 TL (D-194): SNS プラグインの宣言(`sns.timelines`)から。
final tlTimelinesProvider = Provider.family<List<TimelineKind>, String>((ref, account) {
  final s = tlSessionForLabel(ref, account);
  return s?.timelines ?? const [TimelineKind.home, TimelineKind.social, TimelineKind.local, TimelineKind.global];
});

/// カスタムフィードの検索 (D-194: Bluesky)。
final tlFeedSearchProvider = FutureProvider.family<List<FeedInfo>, ({String account, String query})>((ref, key) async {
  final s = tlSessionForLabel(ref, key.account);
  if (s == null) return const [];
  try {
    return await s.searchFeeds(key.query);
  } catch (_) {
    return const [];
  }
});

/// Bluesky のアカウント表記 (D-194: カスタムフィードはいまのところ Bluesky だけ)。
final tlBlueskyAccountsProvider = Provider<List<String>>((ref) => [
      for (final s in ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[])
        if (s.account.kind == SnsKind.bluesky) '${s.account}',
    ]);

/// タイムラインのカスタマイズ(簡略版, D-121 — ワイヤーフレーム
/// 「タイムラインのカスタマイズ」)。TL は **SNSタイムライン(取得元)** と
/// **アルゴリズム(上から順に適用)** のコンポーネント積みで組み、保存時に
/// 正準形ノードグラフへコンパイルする(実行系は従来のまま)。
/// 自由形のノードキャンバスは TL スコープでは**一旦無効化**(D-121)。
///
/// [temporary] (D-338) = タブの ↓ で開く**一時変更 FOW** の中身として使う: 画面の枠(ヘッダー)を出さず(検索欄と
/// 決定 / キャンセルは FOW の側、D-341)、変更は保存せず [tlTemporaryConfigsProvider] に書く(「この内容で保存」で初めて
/// 保存した構成になる)。[tabs] = 並べるタブ((スコープ, 名前)。省略時は既定の並び)。[scopeSync] = 開いているタブを外
/// (ホームのタブ、FOW の検索欄)と揃える口。
class TimelineConfigScreen extends ConsumerStatefulWidget {
  const TimelineConfigScreen({super.key, required this.scope, this.temporary = false, this.tabs, this.scopeSync});
  final String scope;
  final bool temporary;
  final List<(String, String)>? tabs;
  final ValueNotifier<String?>? scopeSync;
  @override
  ConsumerState<TimelineConfigScreen> createState() => _TimelineConfigScreenState();
}

class _TimelineConfigScreenState extends ConsumerState<TimelineConfigScreen> {
  late String _scope = widget.scope;
  TlConfig _cfg = const TlConfig();
  bool _loaded = false;


  /// DM スコープ (D-127): tl.dm = 共通設定(カスタム未設定の全 DM ページに
  /// 適用)、`tl.dm:<peer>` / `tl.chat:<peer>` = そのページだけの設定。
  bool get _isDmScope => _scope == 'tl.dm' || _scope.startsWith('tl.dm:') || _scope.startsWith('tl.chat:');

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
    widget.scopeSync?.addListener(_onScopeSync);
    _load();
  }

  @override
  void dispose() {
    widget.scopeSync?.removeListener(_onScopeSync);
    _manager.close(tlConfigPaletteFowId);
    _manager.close(tlConfigParamsFowId);
    super.dispose();
  }

  /// 外(ホームのタブ)で TL が切り替わったら、こちらも合わせる。
  void _onScopeSync() {
    final next = widget.scopeSync?.value;
    if (next != null && next != _scope && mounted) _switchScope(next);
  }

  Future<void> _load() async {
    setState(() {
      _loaded = false;
      _handEdited = false;
    });
    // 一時変更中 (D-338) ならその構成から。
    if (widget.temporary) {
      if (ref.read(tlTemporaryConfigsProvider)[_scope] case final temp?) {
        setState(() {
          _cfg = temp;
          _loaded = true;
        });
        return;
      }
    }
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
    // 一時変更 (D-338): 保存せず、TL にだけ効かせる。
    if (widget.temporary) {
      ref.read(tlTemporaryConfigsProvider.notifier).set(_scope, _cfg);
      return;
    }
    await _persist();
  }

  Future<void> _persist() async {
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
    widget.scopeSync?.value = next;
    _load();
  }

  /// 一時変更を保存する (D-338): 保存した構成を置き換え、一時変更は外す。
  Future<void> _saveTemporary() async {
    await _persist();
    ref.read(tlTemporaryConfigsProvider.notifier).clear(_scope);
  }

  /// 一時変更を外して、保存した構成に戻す (D-338)。
  Future<void> _revertTemporary() async {
    ref.read(tlTemporaryConfigsProvider.notifier).clear(_scope);
    await _load();
  }

  // ---- タブ行(ノードエディタ D-101 と同じ作法)-----------------------------

  List<(String, String, bool)> _tabs() {
    // DM (D-127): 共通(tl.dm)と各ページ(tl.dm:<peer>)は単独タブ。
    if (_isDmScope) return [(_scope, _scope == 'tl.dm' ? 'DM(共通)' : 'このDM', false)];
    // トレンドのエディタは ノート/フォロー中/ユーザー (D-107/D-124)。
    if (_scope.startsWith('trend')) {
      return const [('trend', 'ノート', false), ('trend.following', 'フォロー中', false), ('trend.users', 'ユーザー', false)];
    }
    final order = ref.watch(tlTabOrderProvider);
    final nodeTabs = ref.watch(nodeTabsProvider);
    if (widget.tabs case final given?) {
      final own = {for (final t in nodeTabs) 'tl.${t.id}'};
      return applyTlTabOrder([for (final (sc, label) in given) (sc, label, own.contains(sc))], (t) => t.$1, order);
    }
    final tabs = <(String, String, bool)>[
      ('tl.bundle', '総合', false),
      ('tl.social', 'おすすめ', false),
      ('tl.home', 'フォロー中', false),
      ('tl.relational', '関連', false),
      ('tl.local', 'ローカル', false),
      ('tl.global', 'グローバル', false),
      for (final t in nodeTabs) ('tl.${t.id}', t.label, true),
    ];
    if (!tabs.any((t) => t.$1 == _scope)) {
      final base = _scope.startsWith('tl.') ? _scope.substring(3) : _scope;
      tabs.insert(0, (_scope, base.startsWith('list:') ? 'このリスト' : base, false));
    }
    return applyTlTabOrder(tabs, (t) => t.$1, order);
  }

  /// タブを並べ替えられるか (D-339): TL のタブが 2 つ以上のとき(DM / トレンドのエディタは固定)。
  bool _canReorderTabs(List<(String, String, bool)> tabs) => !_isDmScope && !_scope.startsWith('trend') && tabs.length > 1;

  /// タブの並びを保存する (D-339)。ホームのタブもこの順になる。
  Future<void> _reorderTabs(List<(String, String, bool)> tabs, int from, int to) async {
    final list = [...tabs];
    final moved = list.removeAt(from);
    list.insert(to.clamp(0, list.length), moved);
    // 既に保存した並びにあって、ここに無いスコープ(他の画面のタブ)は後ろに残す。
    final shown = {for (final t in list) t.$1};
    await saveTlTabOrder(ref, [for (final t in list) t.$1, for (final sc in ref.read(tlTabOrderProvider)) if (!shown.contains(sc)) sc]);
  }

  /// タブの並べ替えシート (D-339): アルゴリズムの並べ替えと同じ見た目(ドラッグで並べ替え、即時反映)。
  void _openTabReorder() {
    ref.read(overlayManagerProvider).showBottomSheet<void>(
          id: 'tlconfig.tabs.reorder',
          title: 'タブの並べ替え',
          builder: (_) => Consumer(builder: (ctx, ref, _) {
            final tabs = _tabs();
            final scheme = Theme.of(ctx).colorScheme;
            return ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorderItem: (from, to) => _reorderTabs(tabs, from, to),
              children: [
                for (final t in tabs)
                  RasqListTile(
                    key: ValueKey('tlconfig.tabs.row.${t.$1}'),
                    title: t.$2,
                    leading: Icon(t.$3 ? Icons.account_tree_outlined : Icons.view_stream_outlined, size: 22),
                    chevron: false,
                    trailing: Icon(Icons.drag_handle, size: 20, color: scheme.onSurfaceVariant),
                  ),
              ],
            );
          }),
        );
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
          // タブは長押しでつかんで左右へ動かせる (D-339)。並びはホームのタブにも効く。
          Expanded(
            child: ReorderableListView.builder(
              key: const ValueKey('tlconfig.tabs'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
              buildDefaultDragHandles: false,
              itemCount: tabs.length,
              onReorderItem: (from, to) => _reorderTabs(tabs, from, to),
              proxyDecorator: (child, _, _) => Material(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(RasqSizes.radiusSm), elevation: 2, child: child),
              itemBuilder: (context, i) {
                final t = tabs[i];
                final tab = InkWell(
                  key: ValueKey('tlconfig.tab.${t.$1}'),
                  onTap: () {
                    if (t.$1 != _scope) {
                      _switchScope(t.$1);
                    } else if (t.$3 && !widget.temporary) {
                      _renameTab(t.$1);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: _scope == t.$1 ? BoxDecoration(border: Border(bottom: BorderSide(color: tokens.link, width: 2))) : null,
                    child: Text(t.$2, style: RasqTypography.bodySmall.copyWith(fontWeight: _scope == t.$1 ? FontWeight.w700 : null, color: _scope == t.$1 ? tokens.link : scheme.onSurfaceVariant)),
                  ),
                );
                return _canReorderTabs(tabs) ? ReorderableDelayedDragStartListener(key: ValueKey('tlconfig.tabdrag.${t.$1}'), index: i, child: tab) : KeyedSubtree(key: ValueKey('tlconfig.tabdrag.${t.$1}'), child: tab);
              },
            ),
          ),
          if (_canReorderTabs(tabs)) RasqIconButton(icon: Icons.swap_horiz, size: 20, tooltip: 'タブの並べ替え', onPressed: _openTabReorder),
          if (_scope.startsWith('tl.') && !_isDmScope && !widget.temporary) RasqIconButton(icon: Icons.add, size: 20, tooltip: 'タブを追加', onPressed: _addTab),
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
      // グラフカスタマイズ (D-124): ノードの調節はグラフ形式の編集に。
      // グラフで手を入れた TL はプラグインの自動構成の対象外(簡易側は
      // 置き換え警告バナー)。
      const RasqDropdownItem('グラフで編集', 'nodes'),
      RasqDropdownItem('バンドルでノードTLを集合表示', 'bundleTabs', checked: bundleTabs),
    ]);
    if (!mounted) return;
    switch (pick) {
      case 'rename':
        await _renameTab(_scope);
      case 'deleteTab':
        await _deleteTab(_scope);
      case 'nodes':
        await ref.read(routerProvider).push(Routes.nodes(_scope));
        if (mounted) await _load(); // グラフ編集から戻ったら手組み状態を反映
      case 'reset':
        final store = ref.read(settingsAreaProvider(_area).notifier);
        await store.set('graph', null);
        await store.set('tlcfg', null);
        await store.set('composercfg', null);
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
    // インタースティシャル (D-124): FOW 外(スクリム)タップでキャンセル。
    // 高さはとりあえず最大段まで — サイズ配列(コンテンツ/プラグインからの
    // 段の受け渡し)は RRL 設定ページの配布と一緒に繋ぐ。
    final spec = FowSpec(
      type: FowPanelType.interstitial,
      initialHeightFactor: 0.85,
      minHeightFactor: 0.2,
      maxHeightFactor: 0.85,
      dockAboveFooter: true,
      heightStops: const [0.85],
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
            dmOnly: _isDmScope,
            onAddAlgorithm: (a) {
              manager.close(tlConfigPaletteFowId);
              _update(_cfg.copyWith(algorithms: [..._cfg.algorithms, a]));
            },
            onPickGenres: () {
              manager.close(tlConfigPaletteFowId);
              if (!_cfg.algorithms.any((a) => a.isTendency)) _update(_cfg.copyWith(algorithms: [..._cfg.algorithms, const TlAlgorithmComponent(type: 'tendency')]));
              _tendencyAction('pick');
            },
            onAddSource: (s) {
              manager.close(tlConfigPaletteFowId);
              _update(_cfg.copyWith(sources: [..._cfg.sources, s]));
            },
          ),
        )
        .whenComplete(() => router.routerDelegate.removeListener(onNavigate));
  }

  /// プラグインのアルゴリズムの副題 (D-355): この構成の持ち主のアカウントで動く版。
  String _pluginVersionLabel(TlAlgorithmComponent a) {
    if (!a.type.startsWith('plugin:slot:')) return 'TLプラグイン';
    final pluginId = a.type.substring('plugin:slot:'.length).split(':').first;
    final p = ref.read(slotPluginsProvider.notifier).active(accountKey: _accountKey).where((x) => x.id == pluginId).firstOrNull;
    final v = p?.storeVersion;
    return v == null ? 'TLプラグイン' : 'TLプラグイン ・ v$v';
  }

  /// コンポーネントの見た目情報(タイル/詳細/並べ替え行で共用)。
  (IconData, String, String, String) _algoInfo(TlAlgorithmComponent a) => (
        a.isPlugin ? Icons.extension_outlined : (a.isSuggest ? Icons.auto_awesome_outlined : a.isTendency ? Icons.tune : Icons.schedule),
        a.title,
        a.isPlugin ? _pluginVersionLabel(a) : 'RASQ',
        switch (a.type) {
          'chrono' => '取得したままの時刻順に整えます。',
          'tendency' => 'トレンドプロファイル(指向性/刺激性・好きなジャンル)に合わない投稿を除外し、適合度順に並べます。',
          'suggest' => '${a.from}(${suggestFromKind(a.from) == 'myposts' ? '自分の投稿' : suggestFromKind(a.from) == 'myreplies' ? '自分の返信' : 'リアクションした投稿'})を基準に、${a.what}で合う投稿を先頭へ並べ替えます。',
          _ => '投稿リストをプラグインのソート(tl.sort)で並べ替えます。',
        },
      );

  (IconData, String, String, String) _sourceInfo(TlSourceComponent s) {
    final kinds = ref.read(tlTimelinesProvider(s.account));
    final tlLabel = kinds.where((k) => k.id == s.tl).firstOrNull?.label ?? switch (s.tl) { 'social' => 'おすすめ', 'local' => 'ローカル', 'global' => 'グローバル', 'home' => 'フォロー中 (home)', _ => s.tl };
    if (s.isRasq) return (Icons.hub_outlined, 'RASQ の投稿を取得', 'RASQ', 'TL: 自分とフォロー中の RASQ アカウントの投稿');
    if (s.isRasqList) return (Icons.people_alt_outlined, 'RASQ リストを取得', 'RASQ', 'RASQ リスト: ${s.label.isNotEmpty ? s.label : (s.rasqListId.isEmpty ? '未選択' : s.rasqListId)}');
    return (
      s.isSelf
          ? Icons.sync_alt
          : s.isDm
              ? Icons.mail_outline
              : s.isFeed
                  ? Icons.rss_feed
                  : (s.isTrend ? Icons.travel_explore : (s.isList ? Icons.list_alt_outlined : Icons.download_outlined)),
      s.isSelf ? 'このタイムラインを取得' : (s.isDm ? 'DM取得' : (s.isTrend ? '現在のトレンドTLを取得' : (s.isFeed ? 'カスタムフィードを取得' : (s.isList ? 'リストTLを取得' : 'タイムラインを取得')))),
      s.isSelf ? 'RASQ' : (s.account.isEmpty ? '(現在のアカウント)' : s.account),
      'TL: ${s.isSelf ? 'この画面の基礎タイムライン(検索結果/欄の投稿)' : s.isDm ? 'DM: @${s.dmPeer}' : s.isTrend ? 'トレンド上位タグの検索結果' : s.isFeed ? 'フィード: ${s.label.isNotEmpty ? s.label : (s.feedUri.isEmpty ? '未選択' : s.feedUri)}' : s.isList ? 'リスト: ${s.listName.isEmpty ? '未選択' : s.listName}' : tlLabel}',
    );
  }

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

  /// パラメーター編集 FOW (D-123/D-124): 「>」/… の「パラメーターを編集」
  /// から。タイルヘッダー + **RRL で描いたパラメーター部**(設定 DSL と同じ
  /// 部品)。ヘッダーは絵文字ピッカーの作法 — **キャンセル = 巻き戻し /
  /// 決定 = 確定**。FOW 外(スクリム)タップはキャンセル扱い。
  void _openParamsFow({required bool algorithm, required int index}) {
    final manager = ref.read(overlayManagerProvider);
    if (manager.contains(tlConfigParamsFowId)) manager.close(tlConfigParamsFowId);
    // 高さはとりあえず最大段まで(サイズ配列の受け渡しは RRL 設定ページの
    // 配布と一緒に)。
    final spec = FowSpec(
      type: FowPanelType.interstitial,
      initialHeightFactor: 0.85,
      minHeightFactor: 0.2,
      maxHeightFactor: 0.85,
      dockAboveFooter: true,
      heightStops: const [0.85],
      freeAboveStops: true,
    );
    final router = ref.read(routerProvider);
    void onNavigate() => manager.close(tlConfigParamsFowId);
    router.routerDelegate.addListener(onNavigate);
    final before = _cfg; // キャンセル/FOW 外タップの巻き戻し先
    manager
        .showFow<bool>(
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
            onConfirm: () => manager.close(tlConfigParamsFowId, result: true),
            onCancel: () => manager.close(tlConfigParamsFowId),
            onTendencyAction: _tendencyAction,
          ),
        )
        .then((ok) {
          if (ok != true && mounted) _update(before); // 決定以外は巻き戻す
        })
        .whenComplete(() => router.routerDelegate.removeListener(onNavigate));
  }

  /// 指向性/刺激性の部品のオプション (D-153/D-157): プロファイル編集の FOW を開く。
  Future<void> _tendencyAction(String which) async {
    switch (which) {
      case 'tendency':
        await openTendencyFow(context, ref);
      case 'genres':
        await openGenreFow(context, ref);
      case 'pick':
        final base = await ref.read(tendencyProfileProvider.future);
        if (!mounted) return;
        final picked = await openGenrePickFow(context, ref, base: base);
        if (picked != null) await saveTendencyProfileFrom(ref, picked);
    }
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
    ref.watch(sessionsProvider); // アカウント選択肢
    if (widget.temporary) return _temporaryBody();
    return Scaffold(
      appBar: RasqPageHeader(
        title: 'タイムラインをカスタマイズ',
        // この構成の持ち主のアカウント (D-355): プラグインのアルゴリズムはこのアカウントの版で動く。
        leadingAvatar: (() {
          final key = _accountKey;
          final s = key == null ? null : ref.read(sessionsProvider).value?.sessions.where((x) => x.account.key == key).firstOrNull;
          return s == null ? null : ownerSummaryOf(s);
        })(),
        actions: [Builder(builder: (ctx) => RasqIconButton(icon: Icons.more_horiz, tooltip: 'その他', onPressed: () => _moreMenu(ctx)))],
        bottom: _tabBar(),
      ),
      body: !_loaded
          ? const RasqLoading()
          : ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.page), children: [
              // 説明バナー(ワイヤーフレーム: アルゴリズムは上から順に適用)。
              _banner(
                _scope == 'tl.dm'
                    ? 'DM のメイン設定です。個別設定のない全ての DM ページに適用されます。アルゴリズムは上から順に適用されます。'
                    : _isDmScope
                        ? 'この DM ページだけの設定です(保存すると DM 共通設定より優先されます)。アルゴリズムは上から順に適用されます。'
                        : 'タイムラインのアルゴリズムや取り込み、表示するタイムラインなどを指定できます。アルゴリズムは上から順に適用されます。',
              ),
              ..._components(),
            ]),
    );
  }

  Widget _banner(String text, {List<Widget> actions = const []}) {
    final tokens = RasqTokens.of(context);
    return Container(
      margin: const EdgeInsets.all(RasqSpacing.sm),
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(color: tokens.link.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(RasqSizes.radiusSm)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text, style: RasqTypography.caption.copyWith(color: tokens.link)),
        if (actions.isNotEmpty) Align(alignment: Alignment.centerRight, child: Wrap(spacing: RasqSpacing.xs, children: actions)),
      ]),
    );
  }

  /// 一時変更 FOW の中身 (D-338/D-341): タブ行 → 一時変更の案内 → 同じ部品の積み(検索欄と決定 / キャンセルは FOW の側)。
  Widget _temporaryBody() {
    final changed = ref.watch(tlTemporaryConfigsProvider.select((m) => m.containsKey(_scope)));
    // プラグインが並べる TL(custom:)は構成を持たない: 探すだけ。
    final searchOnly = _scope.startsWith('tl.custom:');
    return Material(
      type: MaterialType.transparency,
      child: Column(children: [
        _tabBar(),
        Expanded(
          child: !_loaded
              ? const RasqLoading()
              : ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.page), children: [
                  if (searchOnly)
                    _banner('このタイムラインはプラグインが並べています。ここでは探すことだけできます。')
                  else if (changed)
                    _banner(
                      'このタイムラインを一時的に変えています(保存していません)。',
                      actions: [
                        TextButton(key: const ValueKey('tl.temp.revert'), onPressed: _revertTemporary, child: const Text('元に戻す')),
                        TextButton(key: const ValueKey('tl.temp.save'), onPressed: _saveTemporary, child: const Text('この内容で保存')),
                      ],
                    )
                  else
                    _banner('ここでの変更はこのタイムラインに一時的に効きます。保存するまで、元の設定は変わりません。'),
                  if (!searchOnly) ..._components(),
                ]),
        ),
      ]),
    );
  }

  /// アルゴリズム / SNS タイムライン / 自動更新の部品の積み(画面と一時変更 FOW で共用)。
  List<Widget> _components() {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    return [
      if (_handEdited)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
          child: Text('この TL はノードエディタで編集されています。ここで変更すると簡易構成で置き換えます。', style: RasqTypography.caption.copyWith(color: tokens.danger)),
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
    ];
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
  const _ComponentPalettePanel({required this.spec, required this.algorithms, required this.onAddAlgorithm, required this.onAddSource, this.dmOnly = false, this.onPickGenres});

  /// アクションからジャンルを選択 (D-157)。null なら出さない。
  final VoidCallback? onPickGenres;

  final FowSpec spec;

  /// true = アルゴリズム側、false = タイムライン(取得元)側。
  final bool algorithms;

  /// DM スコープ (D-127): 取得元は DM 取得用のタイルだけ表示する。
  final bool dmOnly;
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

  /// ∨ で開いたままにする (D-227: フォーカスの変化で組み直していなかったのでチップの列が出ず、
  /// 「並び替え」「ジャンル」のドロップダウンが押せなかった)。
  bool _filterOpen = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
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
            icon: Icons.filter_alt_outlined,
            title: '絞り込み',
            subtitle: 'RASQ',
            description: '[キーワード/類似性] を [投稿内容/リアクション/会話内容] から読み取り、合わない投稿を除外します(サジェストと同じパラメーター)。',
            supported: allSns,
            add: () => widget.onAddAlgorithm(const TlAlgorithmComponent(type: 'filter'))),
        _PaletteItem(
            icon: Icons.manage_search,
            title: '検索絞り込み',
            subtitle: 'RASQ',
            description: 'このページの検索ワード/タグ(または指定ワード)に合う投稿だけ通します。',
            supported: allSns,
            add: () => widget.onAddAlgorithm(const TlAlgorithmComponent(type: 'queryfilter'))),
        _PaletteItem(
            icon: Icons.tune,
            title: '指向性/刺激性',
            subtitle: 'RASQ',
            description: 'トレンドプロファイル(好きなジャンル/方向性・指向性のしきい値・刺激性の上限)に合わない投稿を除外し、適合度順に並べます。プロファイルは検索ホームのトレンド ⚙ で編集します。',
            supported: allSns,
            add: () => widget.onAddAlgorithm(const TlAlgorithmComponent(type: 'tendency'))),
        // アクションからジャンルを選択 (D-157): 部品ではなくプロファイルの編集。
        // 指向性/刺激性の部品が無ければ足してから開く。
        if (widget.onPickGenres != null)
          _PaletteItem(
              icon: Icons.thumbs_up_down_outlined,
              title: 'アクションからジャンルを選択',
              subtitle: 'RASQ',
              description: 'リアクションした投稿を類似した話題でまとめ、話題性の強いものから「好き / 好きではない」で好きなジャンルを決めます(指向性/刺激性の部品がこのプロファイルを使います)。',
              supported: allSns,
              add: () => widget.onPickGenres!()),
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
    // DM スコープ (D-127): DM 取得用のタイルだけ。
    if (widget.dmOnly) {
      final peers = ref.watch(_tlDmPeersProvider).value ?? const <String>[];
      return [
        _PaletteItem(
            icon: Icons.sync_alt,
            title: 'このDM',
            subtitle: 'RASQ',
            description: 'この DM ページのメッセージをそのまま取り込みます(共通設定ではそれぞれのページの DM)。',
            supported: allSns,
            add: () => widget.onAddSource(const TlSourceComponent(tl: 'self'))),
        for (final peer in peers)
          _PaletteItem(
              icon: Icons.mail_outline,
              title: 'DM: @$peer',
              subtitle: 'DM取得',
              description: '@$peer との DM を取り込みます。',
              supported: sessionSns,
              add: () => widget.onAddSource(TlSourceComponent(tl: 'dm:$peer'))),
      ];
    }
    // タイムライン側 (D-122 → D-194): [タイムライン, リストTL, カスタムフィード(Bluesky), 現在のトレンドTL]
    // (+ このタイムライン = 基礎 TL の自己参照, D-124)。種類 / アカウント / リストは追加後のタイルで選ぶ。
    final current = '${ref.watch(currentAccountProvider) ?? ''}';
    final firstTl = ref.watch(tlTimelinesProvider(current)).firstOrNull?.id ?? 'home';
    final bluesky = ref.watch(tlBlueskyAccountsProvider);
    return [
      _PaletteItem(
          icon: Icons.sync_alt,
          title: 'このタイムライン',
          subtitle: 'RASQ',
          description: 'この画面の基礎タイムライン(タブ/検索結果/リスト/欄の投稿)をそのまま取り込みます。',
          supported: allSns,
          add: () => widget.onAddSource(const TlSourceComponent(tl: 'self'))),
      // RASQ の投稿 (D-283): SNS のアカウントではなく、RASQ アカウント(Central)のフィード。
      _PaletteItem(
          icon: Icons.hub_outlined,
          title: 'RASQ の投稿',
          subtitle: 'RASQ',
          description: '自分とフォロー中の RASQ アカウントの投稿 / リブロードを取り込みます。SNS の投稿と同じタイムラインに混ぜられます。',
          supported: allSns,
          add: () => widget.onAddSource(const TlSourceComponent(tl: rasqPostsKind))),
      _PaletteItem(
          icon: Icons.download_outlined,
          title: 'タイムライン',
          subtitle: 'SNSプラグイン',
          description: 'アカウントの基本タイムラインを取り込みます。種類はその SNS が出せるもの(フォロー中 / ローカル / グローバル / Discover …)から、アカウントと合わせて追加後のタイルで選べます。',
          supported: allSns,
          add: () => widget.onAddSource(TlSourceComponent(tl: firstTl, account: current))),
      _PaletteItem(
          icon: Icons.list_alt_outlined,
          title: 'リストTL',
          subtitle: 'リスト系',
          description: 'アカウントと、そのアカウントに含まれるリストのタイムラインを取り込みます(追加後のタイルで選択)。',
          supported: sessionSns,
          add: () => widget.onAddSource(TlSourceComponent(tl: 'list:', account: current))),
      if (bluesky.isNotEmpty)
        _PaletteItem(
            icon: Icons.rss_feed,
            title: 'カスタムフィード(Bluesky)',
            subtitle: 'リスト系',
            description: 'Bluesky のカスタムフィードを検索して取り込みます(SNS を跨いだリストは「RASQ リスト」)。',
            supported: [for (final p in ref.read(pluginRegistryProvider).plugins) if (p.kind == SnsKind.bluesky) p.manifest.name],
            add: () => widget.onAddSource(TlSourceComponent(tl: 'feed:', account: bluesky.first))),
      // RASQ リスト (D-346): SNS を跨いだ人のリスト(Central)。リスト内の人の情報を取れるリストだけ選べる。
      if (ref.read(hasRasqAccountProvider))
        _PaletteItem(
            icon: Icons.people_alt_outlined,
            title: 'RASQ リスト',
            subtitle: 'リスト系',
            description: 'RASQ リスト(Misskey / Mastodon / Bluesky の人を 1 つにまとめたリスト)の投稿を取り込みます。自分のリスト・フォロー中のリストから選ぶか、公開リストを検索します。選べるのは、リスト内の人の情報を取れる(同じサーバーのアカウントがある / 入っている人をフォローしている)リストだけです。',
            supported: allSns,
            add: () => widget.onAddSource(const TlSourceComponent(tl: rasqListKindPrefix))),
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
        expanded: _filterOpen || _focus.hasFocus,
        controller: _search,
        focusNode: _focus,
        hintText: 'プラグインノードを検索',
        onDropdownTap: () => setState(() => _filterOpen = !_filterOpen),
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
class _ComponentParamsPanel extends ConsumerStatefulWidget {
  const _ComponentParamsPanel(
      {required this.algorithm,
      required this.index,
      required this.scope,
      required this.cfgOf,
      required this.infoOf,
      required this.accounts,
      required this.onUpdate,
      required this.onConfirm,
      required this.onCancel,
      this.onTendencyAction});

  /// 指向性/刺激性の部品のオプション (D-157): 'tendency' / 'genres' / 'pick'。
  final ValueChanged<String>? onTendencyAction;

  final bool algorithm;
  final int index;
  final String scope;
  final TlConfig Function() cfgOf;
  final (IconData, String, String, String) Function(bool algorithm, int i) infoOf;
  final List<String> accounts;
  final ValueChanged<TlConfig> onUpdate;

  /// 決定/キャンセル (D-124: 絵文字ピッカーの作法 — キャンセル = 巻き戻し)。
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  ConsumerState<_ComponentParamsPanel> createState() => _ComponentParamsPanelState();
}

class _ComponentParamsPanelState extends ConsumerState<_ComponentParamsPanel> {
  late final TextEditingController _query = TextEditingController(
      text: widget.algorithm && widget.index < widget.cfgOf().algorithms.length ? widget.cfgOf().algorithms[widget.index].query : '');

  /// スロットの TL プラグイン (D-169): `tl.params` の RRL 設定ページと既定値。
  Future<({RrlNode root, Map<String, Object?> defaults})?>? _pluginParams;

  ({RrlNode root, Map<String, Object?> defaults})? _loadedPluginParams;

  @override
  void initState() {
    super.initState();
    final cfg = widget.cfgOf();
    if (widget.algorithm && widget.index < cfg.algorithms.length && cfg.algorithms[widget.index].type.startsWith('plugin:slot:')) {
      final id = cfg.algorithms[widget.index].type.substring('plugin:slot:'.length); // <pluginId>:<tlId>
      final parts = id.split(':');
      final plugin = ref.read(activeSlotPluginsProvider).where((p) => p.id == parts.first).firstOrNull;
      if (plugin != null && parts.length >= 2) {
        _pluginParams = ref.read(slotPluginsProvider.notifier).tlParams(plugin, parts.sublist(1).join(':')).then((v) {
          if (mounted) setState(() => _loadedPluginParams = v);
          return v;
        });
      }
    }
  }

  final _feedQuery = TextEditingController();
  final _rasqListQuery = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    _feedQuery.dispose();
    _rasqListQuery.dispose();
    super.dispose();
  }

  RrlNode _radio(String key, String label, String value) =>
      RrlNode(t: 'RadioListTile', k: key, p: {'title': label, 'value': value, 'group': '\$.settings.$key'}, on: const {'change': 'settings.set'});

  RrlNode _section(String title) => RrlNode(t: 'SectionHeader', p: {'title': title});

  (Map<String, Object?>, RrlNode) _paramsOf(TlConfig cfg) {
    if (widget.algorithm) {
      final a = cfg.algorithms[widget.index];
      if (a.hasSuggestParams) {
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
      // スロットの TL プラグイン (D-169): プラグインの RRL 設定ページを差し込む。
      final pp = _loadedPluginParams;
      if (a.type.startsWith('plugin:slot:')) {
        if (pp != null) return ({...pp.defaults, ...a.params}, pp.root);
        return (
          const {},
          RrlNode(t: 'Column', c: [RrlNode(t: 'Text', p: {'text': _pluginParams == null ? 'このプラグインは登録されていません(ストアから入れ直してください)。' : 'パラメーターを読み込んでいます…'})]),
        );
      }
      return (
        const {},
        RrlNode(t: 'Column', c: [
          RrlNode(t: 'Text', p: {
            'text': a.isPlugin
                ? 'このプラグインのパラメーター(RRL 設定ページ)は、ノード定義の配布(ストア統合)でここに表示されます。'
                : a.isQueryFilter
                    ? 'ワードが空のときは、このページの検索ワード/タグで絞り込みます。ワードは下の欄で指定できます。'
                    : a.isTendency
                        ? 'storage.safe のトレンドプロファイルを使います。下のオプションから指向性/刺激性・好きなジャンル・アクションからのジャンル選択を編集できます(検索ホームのトレンド ⚙ と同じもの)。'
                        : '時系列順にパラメーターはありません。'
          }),
        ]),
      );
    }
    final s = cfg.sources[widget.index];
    if (s.isRasq) {
      return (
        const {},
        const RrlNode(t: 'Column', c: [
          RrlNode(t: 'Text', p: {'text': '自分とフォロー中の RASQ アカウントの投稿 / リブロードを取り込みます。RASQ アカウントにログインしているときだけ流れます。パラメーターはありません。'}),
        ]),
      );
    }
    if (s.isRasqList) {
      return (
        const {},
        const RrlNode(t: 'Column', c: [
          RrlNode(t: 'Text', p: {'text': 'RASQ リストの投稿を取り込みます(Central が、見たときにリスト内の人の投稿を集めます)。下の欄で、自分のリスト・フォロー中のリストから選ぶか、公開リストを検索して選びます。選ぶと、そのリストをフォローします。'}),
        ]),
      );
    }
    if (s.isSelf) {
      return (
        const {},
        const RrlNode(t: 'Column', c: [
          RrlNode(t: 'Text', p: {'text': 'この画面の基礎タイムラインをそのまま取り込みます。パラメーターはありません。'}),
        ]),
      );
    }
    // アカウント (D-194): 「現在のアカウント」表記は無し。空(従来設定)は現在のアカウントとして扱う。
    final current = '${ref.watch(currentAccountProvider) ?? ''}';
    final account = s.account.isEmpty ? current : s.account;
    final accounts = s.isFeed ? ref.watch(tlBlueskyAccountsProvider) : widget.accounts;
    final kinds = ref.watch(tlTimelinesProvider(account));
    final lists = s.isList ? (ref.watch(tlListsProvider(account)).value ?? const <UserListInfo>[]) : const <UserListInfo>[];
    return (
      {'tl': s.tl, 'account': account},
      RrlNode(t: 'Column', c: [
        _section('アカウント'),
        for (final a in accounts) _radio('account', a, a),
        if (!s.isTrend && !s.isList && !s.isDm && !s.isFeed) ...[
          _section('TL 種別(この SNS が出せるもの)'),
          for (final k in kinds) _radio('tl', k.label, k.id),
        ],
        if (s.isList) ...[
          _section('リスト(このアカウントのもの)'),
          if (lists.isEmpty) RrlNode(t: 'Text', p: {'text': 'このアカウントにはリストがありません(または取得できません)。'}),
          for (final l in lists) _radio('tl', l.name, 'list:${l.name}'),
        ],
        if (s.isFeed) _section('カスタムフィード(下の欄で検索して選ぶ)'),
      ]),
    );
  }

  void _apply(String key, Object? value) {
    final cfg = widget.cfgOf();
    if (widget.algorithm) {
      final a = cfg.algorithms[widget.index];
      final next = [
        for (var k = 0; k < cfg.algorithms.length; k++)
          k == widget.index
              ? (a.isPlugin
                  ? a.copyWith(params: {...a.params, key: value}) // プラグインのパラメーター (D-169)
                  : a.copyWith(what: key == 'what' ? '$value' : null, from: key == 'from' ? '$value' : null))
              : cfg.algorithms[k],
      ];
      widget.onUpdate(cfg.copyWith(algorithms: next));
    } else {
      final cur = cfg.sources[widget.index];
      var updated = cur.copyWith(tl: key == 'tl' ? '$value' : null, account: key == 'account' ? '$value' : null, label: key == 'label' ? '$value' : null);
      if (key == 'account') {
        // アカウントを変えたら、その SNS に無い TL 種別 / 他アカウントのリストは選び直し (D-194)。
        if (!cur.isTrend && !cur.isList && !cur.isDm && !cur.isFeed && !cur.isSelf && !cur.isRasqList) {
          final kinds = ref.read(tlTimelinesProvider('$value'));
          if (kinds.isNotEmpty && !kinds.any((k) => k.id == cur.tl)) updated = updated.copyWith(tl: kinds.first.id);
        } else if (cur.isList) {
          updated = updated.copyWith(tl: 'list:');
        } else if (cur.isFeed) {
          updated = updated.copyWith(tl: 'feed:', label: '');
        }
      }
      final next = [for (var k = 0; k < cfg.sources.length; k++) k == widget.index ? updated : cfg.sources[k]];
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
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    return Column(children: [
      // 決定/キャンセルヘッダー (D-124: 絵文字ピッカー/コンポーザー D-052 と
      // 同じ配置 — キャンセル(左)/タイトル(太字・中央)/決定(右))。
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 2, RasqSpacing.page, 0),
        child: Row(children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onCancel,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), alignment: Alignment.centerLeft),
                child: Text('キャンセル', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ),
          ),
          Text('ノードを設定', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onConfirm,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), alignment: Alignment.centerRight),
                child: Text('決定', style: RasqTypography.bodySmall.copyWith(color: tokens.link)),
              ),
            ),
          ),
        ]),
      ),
      RasqPluginTile(icon: icon, title: title, subtitle: subtitle, description: description, chevron: false),
      const Divider(height: 1),
      Expanded(
        child: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.sm), children: [
          RrlRenderer(node: root, host: host),
          // 検索絞り込み (D-125): ワード指定(RRL の Input 部品が入るまでの
          // ネイティブ欄。空 = このページの検索ワード/タグ)。
          // 指向性/刺激性 (D-157): プロファイル編集のオプション。
          if (widget.algorithm && widget.index < cfg.algorithms.length && cfg.algorithms[widget.index].isTendency && widget.onTendencyAction != null) ...[
            RasqWarningListTile(title: 'トレンドの指向性/刺激性', onTap: () => widget.onTendencyAction!('tendency')),
            RasqListTile(title: '好きなジャンル/方向性', onTap: () => widget.onTendencyAction!('genres')),
            RasqListTile(title: 'アクションからジャンルを選択', subtitle: '類似した話題でまとめて、話題性の強いものから', onTap: () => widget.onTendencyAction!('pick')),
          ],
          // RASQ リストの検索 (D-346)。空 = 自分のリスト + フォロー中。取れないリストは選べない。
          if (!widget.algorithm && widget.index < cfg.sources.length && cfg.sources[widget.index].isRasqList) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
              child: TextField(
                key: const ValueKey('tlcfg.rasqlist.search'),
                controller: _rasqListQuery,
                style: RasqTypography.bodySmall,
                decoration: const InputDecoration(labelText: 'RASQ リストを検索(名前 / @作った人 / 共有リンク)', isDense: true, prefixIcon: Icon(Icons.search, size: 18)),
                onChanged: (_) => setState(() {}),
              ),
            ),
            RasqListCandidates(
              query: _rasqListQuery.text,
              selectedId: cfg.sources[widget.index].rasqListId,
              onPick: (c) async {
                final ok = await ensureRasqListFetchable(ref, c);
                if (ok == null || !mounted) return;
                _apply('tl', '$rasqListKindPrefix${c.id}');
                _apply('label', c.name);
              },
            ),
          ],
          // カスタムフィードの検索 (D-194: Bluesky)。結果をタップで選ぶ。
          if (!widget.algorithm && widget.index < cfg.sources.length && cfg.sources[widget.index].isFeed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
              child: TextField(
                key: const ValueKey('tlcfg.feed.search'),
                controller: _feedQuery,
                style: RasqTypography.bodySmall,
                decoration: const InputDecoration(labelText: 'フィードを検索', isDense: true, prefixIcon: Icon(Icons.search, size: 18)),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Builder(builder: (context) {
              final src = cfg.sources[widget.index];
              final acct = src.account.isEmpty ? '${ref.watch(currentAccountProvider) ?? ''}' : src.account;
              final feeds = ref.watch(tlFeedSearchProvider((account: acct, query: _feedQuery.text.trim())));
              return feeds.when(
                loading: () => const Padding(padding: EdgeInsets.all(RasqSpacing.page), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))),
                error: (_, _) => const SizedBox.shrink(),
                data: (items) => Column(children: [
                  if (items.isEmpty) Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('見つかりません', style: RasqTypography.caption)),
                  for (final f in items)
                    RasqListTile(
                      key: ValueKey('tlcfg.feed.${f.uri}'),
                      title: f.name,
                      subtitle: f.description ?? f.uri,
                      leading: Icon(src.feedUri == f.uri ? Icons.radio_button_checked : Icons.radio_button_off, size: 20),
                      chevron: false,
                      onTap: () {
                        _apply('tl', 'feed:${f.uri}');
                        _apply('label', f.name);
                      },
                    ),
                ]),
              );
            }),
          ],
          if (widget.algorithm && widget.index < cfg.algorithms.length && cfg.algorithms[widget.index].isQueryFilter)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
              child: TextField(
                controller: _query,
                style: RasqTypography.bodySmall,
                decoration: const InputDecoration(labelText: '検索ワード(空 = このページの検索ワード)', isDense: true),
                onChanged: (v) {
                  final c = widget.cfgOf();
                  widget.onUpdate(c.copyWith(algorithms: [
                    for (var k = 0; k < c.algorithms.length; k++) k == widget.index ? c.algorithms[k].copyWith(query: v.trim()) : c.algorithms[k],
                  ]));
                },
              ),
            ),
          // 除外 (D-227): ワードを含む投稿を落とす(ネタバレなどのワードミュート)。
          if (widget.algorithm && widget.index < cfg.algorithms.length && cfg.algorithms[widget.index].isQueryFilter)
            RasqSwitchListTile(
              key: const ValueKey('tlcfg.queryfilter.exclude'),
              title: 'このワードを含む投稿を除外する',
              subtitle: 'オフなら含む投稿だけ通します',
              value: cfg.algorithms[widget.index].exclude,
              onChanged: (v) {
                final c = widget.cfgOf();
                widget.onUpdate(c.copyWith(algorithms: [
                  for (var k = 0; k < c.algorithms.length; k++) k == widget.index ? c.algorithms[k].copyWith(exclude: v) : c.algorithms[k],
                ]));
              },
            ),
        ]),
      ),
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

