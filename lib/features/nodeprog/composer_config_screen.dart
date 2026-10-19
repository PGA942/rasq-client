import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../../backend/rasq_account.dart';
import '../../app/providers.dart';
import '../../app/router.dart' show Routes, routerProvider;
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import '../settings/settings_dsl.dart';
import '../compose/composer_learning.dart';
import 'node_tabs.dart';
import 'tl_components.dart';

/// コンポーザーのパラメーター FOW。
const composerConfigParamsFowId = 'fow.composerconfig.params';

/// 投稿先のカスタマイズ (D-126/D-131): **完全に別ページ**(タブ = アカウント、
/// 戻るで 1 ページ前へ)。対象は投稿内容(と内部フォーマットの適合)なので
/// **絞り込み系のみ**:
///
/// - **ポスト先の絞り込み**: サジェストのポスト先判定。ノード追加ボタンで
///   複数積める(かつ)。
/// - **フォーマット** (D-131: FOW ではなくページ内): 絞り込みに合わなかった
///   ときのバイパス書式(バイパスしない/注釈/フォロワー限定/連合なし)。
/// - **投稿加工(正規表現)**: 送信時の本文置換。ノード追加で複数。
/// - **連動投稿の届け方** (D-129) + **連動元のアカウント選択**(複数選択の
///   バンドルタイル、RASQ アカウント行なし)+ **連動の絞り込み**(連動投稿
///   だけに掛かる関門, F_target)。
class ComposerConfigScreen extends ConsumerStatefulWidget {
  const ComposerConfigScreen({super.key});
  @override
  ConsumerState<ComposerConfigScreen> createState() => _ComposerConfigScreenState();
}

class _ComposerConfigScreenState extends ConsumerState<ComposerConfigScreen> {
  Map<String, ComposerAccountFilter> _cfg = {};
  String _tab = '';
  bool _loaded = false;
  bool _handEdited = false;

  String get _area => nodeprogAreaFor(ref.read(currentAccountProvider)?.key, 'composer');
  /// RASQ アカウントのタブ (D-283)。ログインしているときだけ。条件に合うと、コンポーザーが RASQ 指定になる。
  String? get _rasqLabel => ref.read(orgateAccountProvider).value == null ? null : '${ref.read(rasqAccountProvider).account}';
  List<String> get _accounts => [for (final s in ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[]) '${s.account}', ?_rasqLabel];

  late final OverlayManager _manager;
  late final TextEditingController _fallbackCw = TextEditingController();

  @override
  void initState() {
    super.initState();
    _manager = ref.read(overlayManagerProvider);
    _load();
  }

  @override
  void dispose() {
    _manager.close(composerConfigParamsFowId);
    _fallbackCw.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loaded = false;
      _handEdited = false;
    });
    try {
      final area = await ref.read(settingsAreaProvider(_area).future);
      if (!mounted) return;
      final raw = area['composercfg'];
      final cfg = <String, ComposerAccountFilter>{};
      if (raw is String) {
        (jsonDecode(raw) as Map).cast<String, Object?>().forEach((k, v) => cfg[k] = ComposerAccountFilter.fromJson((v as Map).cast<String, Object?>()));
      }
      setState(() {
        _cfg = cfg;
        // RASQ アカウント(バンドル)で見ているときは、RASQ のタブから (D-283)。それ以外は、いま見ている SNS アカウントのタブから。
        final bundle = ref.read(sessionsProvider).value?.bundleView ?? false;
        final preferred = bundle ? _rasqLabel : '${ref.read(currentAccountProvider) ?? ''}';
        _tab = _accounts.contains(_tab) ? _tab : (_accounts.contains(preferred) ? preferred! : (_accounts.firstOrNull ?? ''));
        _fallbackCw.text = (cfg[_tab] ?? const ComposerAccountFilter()).fallbackCw;
        _handEdited = raw is! String && area['graph'] is String;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _save() async {
    final store = ref.read(settingsAreaProvider(_area).notifier);
    await store.set('composercfg', jsonEncode({for (final e in _cfg.entries) e.key: e.value.toJson()}));
    await store.set('graph', jsonEncode(compileComposerConfig(_cfg, _accounts).toJson()));
    if (mounted) setState(() => _handEdited = false);
  }

  void _update(String account, ComposerAccountFilter next) {
    setState(() => _cfg = {..._cfg, account: next});
    _save();
  }

  ComposerAccountFilter get _current => _cfg[_tab] ?? const ComposerAccountFilter();

  Future<void> _moreMenu(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox;
    final pick = await _manager.showDropdown<String>(
      id: 'composerconfig.more',
      anchor: box.localToGlobal(Offset.zero) & box.size,
      dense: true,
      items: [
        RasqDropdownItem(context.l10n.nodeprogComposerResetConfig, 'reset'),
        // グラフカスタマイズ (D-124): 手を入れた構成は自動構成の対象外。
        RasqDropdownItem(context.l10n.nodeprogTimelineEditAsGraph, 'nodes'),
      ],
    );
    if (!mounted) return;
    switch (pick) {
      case 'reset':
        final store = ref.read(settingsAreaProvider(_area).notifier);
        await store.set('graph', null);
        await store.set('composercfg', null);
        if (mounted) await _load();
      case 'nodes':
        await ref.read(routerProvider).push(Routes.nodes('composer'));
        if (mounted) await _load();
    }
  }

  PreferredSizeWidget _tabBar() {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    return PreferredSize(
      preferredSize: const Size.fromHeight(40),
      child: Container(
        height: 40,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
          child: Row(children: [
            for (final a in _accounts)
              InkWell(
                onTap: () => setState(() {
                  _tab = a;
                  _fallbackCw.text = (_cfg[a] ?? const ComposerAccountFilter()).fallbackCw;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: _tab == a ? BoxDecoration(border: Border(bottom: BorderSide(color: tokens.link, width: 2))) : null,
                  child: Text(a, style: RasqTypography.bodySmall.copyWith(fontWeight: _tab == a ? FontWeight.w700 : null, color: _tab == a ? tokens.link : scheme.onSurfaceVariant)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  /// 学習ループの状況 (D-132): 確定投稿の件数と最終更新。
  Widget _learnCaption(ColorScheme scheme) {
    final accKey = ref.read(currentAccountProvider)?.key;
    final area = ref.watch(settingsAreaProvider(storageSafeAreaFor(accKey))).value ?? const <String, Object?>{};
    final slot = area[composerLearnSlot(_tab)];
    if (slot is! Map) {
      return RasqCaption(
        context.l10n.nodeprogComposerLearnNone,
        detail: context.l10n.nodeprogComposerLearnNoneDetail,
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
      );
    }
    final count = (slot['count'] as num?)?.toInt() ?? 0;
    return RasqCaption(
      context.l10n.nodeprogComposerLearnCount(count),
      detail: context.l10n.nodeprogComposerLearnCountDetail(count),
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
    );
  }

  /// 連動 (→ このアカウント) の実績 (D-132: 正例/負例の分離記録)。
  Widget _relationCaption(ColorScheme scheme) {
    final relations = (ref.watch(settingsAreaProvider('composer.learn')).value ?? const <String, Object?>{})['relations'];
    if (relations is! Map) return const SizedBox.shrink();
    final (pos, neg) = composerRelationStats(relations.cast<String, Object?>(), _tab);
    if (pos == 0 && neg == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0),
      child: Text(context.l10n.nodeprogComposerRelationStats(pos, neg), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
    );
  }

  Widget _addNodeButton(String label, VoidCallback onTap) {
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    ref.watch(sessionsProvider);
    final f = _current;
    return Scaffold(
      appBar: RasqPageHeader(
        title: context.l10n.nodeprogEditorTitleComposer,
        actions: [Builder(builder: (ctx) => RasqIconButton(icon: Icons.more_horiz, tooltip: ctx.l10n.nodeprogEditorMoreTooltip, onPressed: () => _moreMenu(ctx)))],
        bottom: _tabBar(),
      ),
      body: !_loaded
          ? const RasqLoading()
          : _tab.isEmpty
              ? RasqEmptyView(title: context.l10n.nodeprogComposerNoAccounts, hint: context.l10n.nodeprogComposerNoAccountsHint)
              : ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.page), children: [
                  RasqNotice(
                    margin: const EdgeInsets.all(RasqSpacing.sm),
                    text: context.l10n.nodeprogComposerBanner,
                    detail: context.l10n.nodeprogComposerBannerDetail,
                  ),
                  if (_handEdited)
                    RasqNotice.warning(
                      margin: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: RasqSpacing.xs),
                      text: context.l10n.nodeprogComposerHandEdited,
                      detail: context.l10n.nodeprogComposerHandEditedDetail,
                    ),
                  // ---- ポスト先の絞り込み(ノード追加で複数 = かつ, D-131)----
                  RasqSectionHeader(title: context.l10n.nodeprogComposerFiltersHeader, topMargin: 0),
                  _learnCaption(scheme),
                  _filterTile(scheme, f),
                  for (var i = 0; i < f.extraFilters.length; i++) _extraFilterTile(scheme, f, i, linked: false),
                  _addNodeButton(context.l10n.nodeprogTimelineAddNode, () => _update(_tab, f.copyWith(extraFilters: [...f.extraFilters, const ComposerFilterSpec()]))),
                  // ---- フォーマット (D-131: FOW ではなくページ内)------------
                  RasqSectionHeader(title: context.l10n.nodeprogComposerFormatHeader),
                  RasqCaption(
                    context.l10n.nodeprogComposerFormatCaption,
                    detail: context.l10n.nodeprogComposerFormatCaptionDetail,
                    padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
                  ),
                  _formatBlock(f),
                  // ---- 投稿加工(正規表現、ノード追加で複数, D-130/D-131)----
                  RasqSectionHeader(title: context.l10n.nodeprogCatalogComposerRegexTitle),
                  _regexTile(scheme, f),
                  for (var i = 0; i < f.extraRegexes.length; i++) _extraRegexTile(scheme, f, i),
                  _addNodeButton(context.l10n.nodeprogTimelineAddNode, () => _update(_tab, f.copyWith(extraRegexes: [...f.extraRegexes, const ComposerRegexSpec()]))),
                  // RASQ のタブでは、RASQ への連動投稿を設定で有効にしているときだけ (D-286)。
                  if (_tab != _rasqLabel || (ref.watch(settingsAreaProvider('composer.prefs')).value ?? const {})['rasqLinked'] == true) ...[
                  // ---- 連動投稿の届け方 (D-129/D-131) ------------------------
                  RasqSectionHeader(title: context.l10n.nodeprogComposerDeliveryHeader),
                  RasqCaption(
                    context.l10n.nodeprogComposerDeliveryCaption,
                    detail: context.l10n.nodeprogComposerDeliveryCaptionDetail,
                    padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
                  ),
                  Builder(builder: (ctx) {
                    return RasqListTile(
                      title: ctx.l10n.nodeprogComposerDeliveryTitle(composerDeliveryLabel(f.delivery)),
                      leading: const Icon(Icons.send_time_extension_outlined),
                      onTap: () async {
                        final box = ctx.findRenderObject() as RenderBox;
                        final pick = await _manager.showDropdown<String>(
                          id: 'composerconfig.delivery',
                          anchor: box.localToGlobal(Offset.zero) & box.size,
                          dense: true,
                          items: [for (final d in composerDeliveryOptions) RasqDropdownItem(composerDeliveryLabel(d), d, checked: d == f.delivery)],
                        );
                        if (pick != null && mounted) _update(_tab, _current.copyWith(delivery: pick));
                      },
                    );
                  }),
                  // 連動元のアカウント選択 (D-131): バンドルタイル型・複数選択
                  // (RASQ アカウント行は表示しない)。
                  Padding(
                    padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
                    child: Text(context.l10n.nodeprogComposerLinkSourcesLabel, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                  _linkSourcesTile(scheme, tokens, f),
                  _relationCaption(scheme),
                  // 連動の絞り込み (D-131: F_target — 連動投稿だけに掛かる)。
                  RasqCaption(
                    context.l10n.nodeprogComposerLinkFiltersCaption,
                    detail: context.l10n.nodeprogComposerLinkFiltersCaptionDetail,
                    padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
                  ),
                  for (var i = 0; i < f.linkFilters.length; i++) _extraFilterTile(scheme, f, i, linked: true),
                  _addNodeButton(context.l10n.nodeprogTimelineAddNode, () => _update(_tab, f.copyWith(linkFilters: [...f.linkFilters, const ComposerFilterSpec()]))),
                  ],
                ]),
    );
  }

  // ---- タイル群 ---------------------------------------------------------------

  Widget _filterTile(ColorScheme scheme, ComposerAccountFilter f) {
    return Row(children: [
      Expanded(
        child: RasqPluginTile(
          leading: Icon(Icons.filter_alt_outlined, size: 22, color: f.enabled ? null : scheme.onSurfaceVariant.withValues(alpha: 0.5)),
          title: f.title,
          subtitle: f.enabled ? _tab : _tab + context.l10n.nodeprogTimelineDisabledSuffix,
          description: f.enabled
              ? context.l10n.nodeprogComposerFilterDescription(
                  f.from == '投稿内容'
                      ? context.l10n.nodeprogComposerFilterBasisPosts
                      : f.from == 'リアクション'
                          ? context.l10n.nodeprogTimelineSuggestFromReacted
                          : context.l10n.nodeprogComposerFilterBasisReplies,
                  f.what)
              : context.l10n.nodeprogComposerFilterDisabled,
          chevron: true,
          onTap: () => _openParams(mode: 'filter'),
        ),
      ),
      Builder(builder: (ctx) => _menuButton(ctx, mode: 'filter', enabled: f.enabled)),
      const SizedBox(width: RasqSpacing.sm),
    ]);
  }

  /// 追加ノード/連動絞り込みのタイル (D-131): タップで FOW 編集、… は削除。
  Widget _extraFilterTile(ColorScheme scheme, ComposerAccountFilter f, int i, {required bool linked}) {
    final spec = linked ? f.linkFilters[i] : f.extraFilters[i];
    return Row(children: [
      Expanded(
        child: RasqPluginTile(
          icon: linked ? Icons.fork_right : Icons.filter_alt_outlined,
          title: spec.title,
          subtitle: linked ? context.l10n.nodeprogComposerLinkOnlySubtitle(_tab) : context.l10n.nodeprogComposerAndSubtitle(_tab),
          description: linked ? context.l10n.nodeprogComposerLinkFilterDescription : context.l10n.nodeprogComposerAndDescription,
          chevron: true,
          onTap: () => _openParams(mode: linked ? 'linkfilter' : 'extrafilter', extraIndex: i),
        ),
      ),
      RasqIconButton(
        icon: Icons.close,
        size: 18,
        tooltip: context.l10n.nodeprogComposerDeleteNode,
        onPressed: () => _update(
            _tab,
            linked
                ? f.copyWith(linkFilters: [for (var k = 0; k < f.linkFilters.length; k++) if (k != i) f.linkFilters[k]])
                : f.copyWith(extraFilters: [for (var k = 0; k < f.extraFilters.length; k++) if (k != i) f.extraFilters[k]])),
      ),
      const SizedBox(width: RasqSpacing.sm),
    ]);
  }

  Widget _regexTile(ColorScheme scheme, ComposerAccountFilter f) {
    return Row(children: [
      Expanded(
        child: RasqPluginTile(
          leading: Icon(Icons.find_replace, size: 22, color: f.regexEnabled ? null : scheme.onSurfaceVariant.withValues(alpha: 0.5)),
          title: context.l10n.nodeprogCatalogComposerRegexTitle,
          subtitle: f.regexEnabled ? _tab : _tab + context.l10n.nodeprogTimelineDisabledSuffix,
          description: f.regexEnabled && f.regexPattern.isNotEmpty
              ? context.l10n.nodeprogComposerRegexDescription(f.regexPattern, f.regexReplace)
              : context.l10n.nodeprogComposerRegexDescriptionEmpty,
          chevron: true,
          onTap: () => _openParams(mode: 'regex'),
        ),
      ),
      Builder(builder: (ctx) => _menuButton(ctx, mode: 'regex', enabled: f.regexEnabled)),
      const SizedBox(width: RasqSpacing.sm),
    ]);
  }

  Widget _extraRegexTile(ColorScheme scheme, ComposerAccountFilter f, int i) {
    final spec = f.extraRegexes[i];
    return Row(children: [
      Expanded(
        child: RasqPluginTile(
          icon: Icons.find_replace,
          title: spec.pattern.isEmpty ? context.l10n.nodeprogComposerRegexUnset : context.l10n.nodeprogComposerRegexRule(spec.pattern, spec.replace),
          subtitle: context.l10n.nodeprogComposerExtraNodeSubtitle(_tab),
          description: context.l10n.nodeprogComposerExtraRegexDescription,
          chevron: true,
          onTap: () => _openParams(mode: 'extraregex', extraIndex: i),
        ),
      ),
      RasqIconButton(
        icon: Icons.close,
        size: 18,
        tooltip: context.l10n.nodeprogComposerDeleteNode,
        onPressed: () => _update(_tab, f.copyWith(extraRegexes: [for (var k = 0; k < f.extraRegexes.length; k++) if (k != i) f.extraRegexes[k]])),
      ),
      const SizedBox(width: RasqSpacing.sm),
    ]);
  }

  /// フォーマット (D-131): ページ内の RRL ラジオ(FOW にしない)。
  /// 「バイパスしない」= フォールバック無効(有効トグルは廃止)。
  Widget _formatBlock(ComposerAccountFilter f) {
    final value = f.fallbackEnabled ? f.fallbackFormat : 'バイパスしない';
    final host = RrlHost(
      instanceScope: 'rasq.host.composerconfig:-:0:format.$_tab',
      scope: RrlScope({
        'settings': {'fallbackFormat': value},
      }),
      onEvent: (nodeId, kind, {String? fn, Map<String, Object?> payload = const {}}) {
        if (fn != 'settings.set') return;
        final v = '${payload['value']}';
        _update(_tab, v == 'バイパスしない' ? _current.copyWith(fallbackEnabled: false) : _current.copyWith(fallbackEnabled: true, fallbackFormat: v));
      },
    );
    RrlNode radio(String label) =>
        RrlNode(t: 'RadioListTile', k: 'fallbackFormat', p: {'title': label, 'value': label, 'group': r'$.settings.fallbackFormat'}, on: const {'change': 'settings.set'});
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RrlRenderer(
        node: RrlNode(t: 'Column', c: [for (final o in const ['バイパスしない', '注釈を付ける', 'フォロワー限定', '連合なし']) radio(o)]),
        host: host,
      ),
      if (f.fallbackEnabled && f.fallbackFormat == '注釈を付ける')
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
          child: TextField(
            controller: _fallbackCw,
            style: RasqTypography.bodySmall,
            decoration: InputDecoration(labelText: context.l10n.nodeprogComposerCwLabel, isDense: true),
            onChanged: (v) => _update(_tab, _current.copyWith(fallbackCw: v.trim())),
          ),
        ),
    ]);
  }

  /// 連動元のアカウント選択 (D-131): バンドルタイル型(RASQ 行なし)・
  /// 複数選択。すべてチェック = 制限なし(`['*']`)。
  Widget _linkSourcesTile(ColorScheme scheme, RasqTokens tokens, ComposerAccountFilter f) {
    final others = [for (final a in _accounts) if (a != _tab && a != _rasqLabel) a];
    bool checkedOf(String a) => f.linkAllowedFrom(a);
    void toggle(String a) {
      final next = {for (final o in others) o: checkedOf(o)};
      next[a] = !(next[a] ?? true);
      final selected = [for (final e in next.entries) if (e.value) e.key];
      _update(_tab, _current.copyWith(linkSources: selected.length == others.length ? const ['*'] : selected));
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(RasqSpacing.md, RasqSpacing.xs, RasqSpacing.md, 0),
      decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (others.isEmpty)
          Padding(
            padding: const EdgeInsets.all(RasqSpacing.md),
            child: Text(context.l10n.nodeprogComposerNoOtherAccounts, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
        for (final a in others)
          InkWell(
            onTap: () => toggle(a),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: 6),
              child: Row(children: [
                Expanded(child: Text(a, style: RasqTypography.bodySmall, overflow: TextOverflow.ellipsis)),
                Icon(checkedOf(a) ? Icons.check_circle_outline : Icons.radio_button_unchecked, size: 16, color: checkedOf(a) ? tokens.link : scheme.onSurfaceVariant.withValues(alpha: 0.4)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _menuButton(BuildContext ctx, {required String mode, required bool enabled}) {
    return RasqIconButton(
      icon: Icons.more_horiz,
      size: 18,
      tooltip: mode == 'regex' ? context.l10n.nodeprogComposerRegexMenuTooltip : context.l10n.nodeprogComposerFilterMenuTooltip,
      onPressed: () async {
        final box = ctx.findRenderObject() as RenderBox;
        final pick = await _manager.showDropdown<String>(
          id: 'composerconfig.menu',
          anchor: box.localToGlobal(Offset.zero) & box.size,
          dense: true,
          items: [
            RasqDropdownItem(context.l10n.nodeprogTimelineMenuEditParams, 'params'),
            RasqDropdownItem(enabled ? context.l10n.nodeprogTimelineMenuDisable : context.l10n.nodeprogTimelineMenuEnable, 'toggle'),
          ],
        );
        if (!mounted) return;
        final f = _current;
        if (pick == 'params') _openParams(mode: mode);
        if (pick == 'toggle') {
          _update(_tab, mode == 'regex' ? f.copyWith(regexEnabled: !enabled) : f.copyWith(enabled: !enabled));
        }
      },
    );
  }

  /// パラメーター FOW (D-124 作法): 決定 = 確定 / キャンセル・FOW 外 = 巻き戻し。
  void _openParams({required String mode, int extraIndex = -1}) {
    final manager = _manager;
    if (manager.contains(composerConfigParamsFowId)) manager.close(composerConfigParamsFowId);
    final spec = FowSpec(
      type: FowPanelType.interstitial,
      initialHeightFactor: 0.85,
      minHeightFactor: 0.2,
      maxHeightFactor: 0.85,
      dockAboveFooter: true,
      heightStops: const [0.85],
      freeAboveStops: true,
    );
    final account = _tab;
    final before = _cfg[account] ?? const ComposerAccountFilter();
    manager
        .showFow<bool>(
          id: composerConfigParamsFowId,
          semanticsLabel: context.l10n.nodeprogEditorParamsTitle,

          spec: spec,
          builder: (ctx, handle) => _ComposerParamsPanel(
            account: account,
            mode: mode,
            extraIndex: extraIndex,
            filterOf: () => _cfg[account] ?? const ComposerAccountFilter(),
            onUpdate: (f) => _update(account, f),
            onConfirm: () => manager.close(composerConfigParamsFowId, result: true),
            onCancel: () => manager.close(composerConfigParamsFowId),
          ),
        )
        .then((ok) {
      if (ok != true && mounted) _update(account, before); // 巻き戻し
    });
  }
}

/// パラメーターパネル: 有効トグル + パラメーター(RRL 描画 — 設定 DSL の
/// 部品)。mode = 'filter' | 'extrafilter' | 'linkfilter' | 'regex' |
/// 'extraregex'([extraIndex] は追加ノード/連動絞り込みの番号)。
class _ComposerParamsPanel extends StatefulWidget {
  const _ComposerParamsPanel(
      {required this.account,
      required this.mode,
      required this.extraIndex,
      required this.filterOf,
      required this.onUpdate,
      required this.onConfirm,
      required this.onCancel});

  final String account;
  final String mode;
  final int extraIndex;
  final ComposerAccountFilter Function() filterOf;
  final ValueChanged<ComposerAccountFilter> onUpdate;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  State<_ComposerParamsPanel> createState() => _ComposerParamsPanelState();
}

class _ComposerParamsPanelState extends State<_ComposerParamsPanel> {
  late final TextEditingController _pattern = TextEditingController(text: _regexSpec().pattern);
  late final TextEditingController _replace = TextEditingController(text: _regexSpec().replace);

  ComposerRegexSpec _regexSpec() {
    final f = widget.filterOf();
    if (widget.mode == 'extraregex' && widget.extraIndex < f.extraRegexes.length) return f.extraRegexes[widget.extraIndex];
    return ComposerRegexSpec(pattern: f.regexPattern, replace: f.regexReplace);
  }

  ComposerFilterSpec _filterSpec() {
    final f = widget.filterOf();
    return switch (widget.mode) {
      'extrafilter' when widget.extraIndex < f.extraFilters.length => f.extraFilters[widget.extraIndex],
      'linkfilter' when widget.extraIndex < f.linkFilters.length => f.linkFilters[widget.extraIndex],
      _ => ComposerFilterSpec(what: f.what, from: f.from),
    };
  }

  @override
  void dispose() {
    _pattern.dispose();
    _replace.dispose();
    super.dispose();
  }

  RrlNode _radio(String key, String label, String value) =>
      RrlNode(t: 'RadioListTile', k: key, p: {'title': label, 'value': value, 'group': '\$.settings.$key'}, on: const {'change': 'settings.set'});

  void _applyFilter({String? what, String? from}) {
    final f = widget.filterOf();
    switch (widget.mode) {
      case 'extrafilter':
        widget.onUpdate(f.copyWith(extraFilters: [
          for (var k = 0; k < f.extraFilters.length; k++) k == widget.extraIndex ? f.extraFilters[k].copyWith(what: what, from: from) : f.extraFilters[k],
        ]));
      case 'linkfilter':
        widget.onUpdate(f.copyWith(linkFilters: [
          for (var k = 0; k < f.linkFilters.length; k++) k == widget.extraIndex ? f.linkFilters[k].copyWith(what: what, from: from) : f.linkFilters[k],
        ]));
      default:
        widget.onUpdate(f.copyWith(what: what, from: from));
    }
    setState(() {});
  }

  void _applyRegex({String? pattern, String? replace}) {
    final f = widget.filterOf();
    if (widget.mode == 'extraregex') {
      widget.onUpdate(f.copyWith(extraRegexes: [
        for (var k = 0; k < f.extraRegexes.length; k++) k == widget.extraIndex ? f.extraRegexes[k].copyWith(pattern: pattern, replace: replace) : f.extraRegexes[k],
      ]));
    } else {
      widget.onUpdate(f.copyWith(regexPattern: pattern, regexReplace: replace));
    }
  }

  bool get _isRegex => widget.mode == 'regex' || widget.mode == 'extraregex';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final f = widget.filterOf();
    final spec = _filterSpec();
    final l = context.l10n;
    final root = _isRegex
        ? (widget.mode == 'regex'
            ? RrlNode(t: 'Column', c: [
                RrlNode(t: 'SwitchListTile', k: 'regexEnabled', p: {'title': l.nodeprogComposerParamsRegexEnabled, 'subtitle': l.nodeprogComposerParamsRegexEnabledSubtitle, 'value': '\$.settings.regexEnabled'}, on: const {'change': 'settings.set'}),
              ])
            : RrlNode(t: 'Column', c: [RrlNode(t: 'Text', p: {'text': l.nodeprogComposerParamsExtraRegex})]))
        : RrlNode(t: 'Column', c: [
            if (widget.mode == 'filter')
              RrlNode(t: 'SwitchListTile', k: 'enabled', p: {'title': l.nodeprogComposerParamsFilterEnabled, 'subtitle': l.nodeprogComposerParamsFilterEnabledSubtitle, 'value': '\$.settings.enabled'}, on: const {'change': 'settings.set'}),
            RrlNode(t: 'SectionHeader', p: {'title': l.nodeprogComposerParamsWhat}),
            for (final o in suggestWhatOptions) _radio('what', o, o),
            RrlNode(t: 'SectionHeader', p: {'title': l.nodeprogTimelineParamsSuggestFrom}),
            // 学習プロファイル (D-132): 確定投稿の学習ループが基準になる。
            for (final o in composerSuggestFromOptions) _radio('from', o, o),
          ]);
    final host = RrlHost(
      instanceScope: 'rasq.host.composerconfig:-:0:${widget.account}.${widget.mode}.${widget.extraIndex}',
      scope: RrlScope({
        'settings': {'enabled': f.enabled, 'what': spec.what, 'from': spec.from, 'regexEnabled': f.regexEnabled},
      }),
      onEvent: (nodeId, kind, {String? fn, Map<String, Object?> payload = const {}}) {
        if (fn != 'settings.set') return;
        final key = nodeId.split(':').last;
        final v = payload['value'];
        switch (key) {
          case 'enabled':
            widget.onUpdate(f.copyWith(enabled: v == true));
          case 'regexEnabled':
            widget.onUpdate(f.copyWith(regexEnabled: v == true));
          case 'what':
            _applyFilter(what: '$v');
          case 'from':
            _applyFilter(from: '$v');
        }
        setState(() {});
      },
    );
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 2, RasqSpacing.page, 0),
        child: Row(children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onCancel,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), alignment: Alignment.centerLeft),
                child: Text(l.nodeprogEditorCancelButton, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ),
          ),
          Text(l.nodeprogEditorParamsTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onConfirm,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), alignment: Alignment.centerRight),
                child: Text(l.nodeprogEditorConfirmButton, style: RasqTypography.bodySmall.copyWith(color: tokens.link)),
              ),
            ),
          ),
        ]),
      ),
      RasqPluginTile(
        icon: _isRegex ? Icons.find_replace : (widget.mode == 'linkfilter' ? Icons.fork_right : Icons.filter_alt_outlined),
        title: _isRegex ? l.nodeprogCatalogComposerRegexTitle : (widget.mode == 'linkfilter' ? l.nodeprogCatalogComposerLinkgateTitle : spec.title),
        subtitle: widget.account,
        description: _isRegex
            ? l.nodeprogComposerParamsRegexDescription
            : widget.mode == 'linkfilter'
                ? rasqDetail(context, l.nodeprogComposerParamsLinkFilterDescription, l.nodeprogComposerParamsLinkFilterDetail)
                : l.nodeprogComposerParamsFilterDescription,
        chevron: false,
      ),
      const Divider(height: 1),
      Expanded(
        child: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.sm), children: [
          RrlRenderer(node: root, host: host),
          // 正規表現の欄 (D-130): RRL に Input 部品が入るまでのネイティブ欄。
          if (_isRegex) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
              child: TextField(
                controller: _pattern,
                style: RasqTypography.bodySmall,
                decoration: InputDecoration(labelText: l.nodeprogComposerParamsPatternLabel, hintText: l.nodeprogComposerParamsPatternHint, isDense: true),
                onChanged: (v) => _applyRegex(pattern: v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
              child: TextField(
                controller: _replace,
                style: RasqTypography.bodySmall,
                decoration: InputDecoration(labelText: l.nodeprogComposerParamsReplaceLabel, isDense: true),

                onChanged: (v) => _applyRegex(replace: v),
              ),
            ),
          ],
        ]),
      ),
    ]);
  }
}
