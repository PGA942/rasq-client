import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../backend/payments_api.dart' show paidFeaturesProvider;
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import '../custom/custom_page.dart' show registeredPagePlugin;
import '../custom/custom_plugins_screen.dart' show installedPagePluginsProvider;
import '../custom/custom_share.dart';
import 'release_fow.dart';
import 'store_models.dart';
import 'store_providers.dart';
import '../settings/settings_dsl.dart';
import '../theme/theme_packs.dart';
import 'store_install.dart';
import 'store_widgets.dart';

/// プラグインページ (M4 / D-120 → D-137 でワイヤーフレーム「全体像」の形に)。
///
/// 上から: 依存の注意 + インストール(ピル)/ バナー / アイコン + 名前 +
/// 提供元 + ブックマーク + … / 紹介文 / プレビュー(横スライド)/ 先月の DL 数
/// (折れ線)/ 評価(分布)/ **レビュー ›**(TL 上位 10 件)/ **アップデートと
/// バージョン ›**(タップで FOW)/ **プライバシーと必要な権限 ›**(権限タイプ
/// ごとのグループ)— 3 節は左右スライドのインラインフレーム / 互換性。
///
/// 常設安全性ブロック (D-033) は「プライバシーと必要な権限」の節に**畳まずに**
/// 残す。インストールは確認シート(InstallManifest の権限・配布物が根拠)→
/// SHA-512 + ed25519 検証(D-034)。
class PluginPageScreen extends ConsumerStatefulWidget {
  const PluginPageScreen({super.key, required this.pluginId});
  final String pluginId;
  @override
  ConsumerState<PluginPageScreen> createState() => _PluginPageScreenState();
}

class _PluginPageScreenState extends ConsumerState<PluginPageScreen> {
  bool _busy = false;
  bool _descriptionExpanded = false;

  void _toast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// インストール(版指定つき, D-137)。確認シート → 検証 → 登録([confirmAndInstallPlugin]、ストアホームのタイルの「入手」と共通)。
  Future<void> _install(StorePluginDetail d, {String? version}) async {
    final message = await confirmAndInstallPlugin(ref, d, version: version, onBusy: (busy) {
      if (mounted) setState(() => _busy = busy);
    });
    if (message != null) _toast(message);
  }

  /// ヘッダーの … メニュー(ワイヤーフレーム: レビューを投稿 / リンクをコピー /
  /// 共有 / … / プラグインを報告)。フォロー/ミュート/ブロックはクリエイター
  /// アカウント (RASQ アカウント) の関係 API が無いのでまだ出さない。
  Future<void> _more(StorePluginDetail d, Rect anchor) async {
    final manager = ref.read(overlayManagerProvider);
    // レビューはインストールしたプラグインにだけ (D-515)。入れていなければ押せない(押せない理由はレビューの枠に出る)。
    final canReview = ref.read(installedPluginsProvider).any((p) => p.id == d.id);
    final pick = await manager.showDropdown<String>(id: 'store.plugin.more', anchor: anchor, tetherAnchorChild: const Icon(Icons.more_horiz, size: 22), items: [
      RasqDropdownItem(context.l10n.storePageMenuPostReview, 'review', enabled: canReview),
      RasqDropdownItem(context.l10n.storeCopyLink, 'copy'),
      RasqDropdownItem(context.l10n.storeShare, 'share'),
      RasqDropdownItem(context.l10n.storePageMenuReport, 'report', destructive: true, enabled: d.supportUrl != null),
    ]);
    if (!mounted) return;
    switch (pick) {
      case 'review':
        await openReviewComposer(context, ref, detail: d);
      case 'copy':
      case 'share':
        // 共有シート(OS)は share_plus 未導入なのでリンクのコピーで代替する。
        await Clipboard.setData(ClipboardData(text: 'rasq://store/plugin/${Uri.encodeComponent(d.id)}'));
        _toast(appL10n.storePageLinkCopied);
      case 'report':
        // 報告は開発者のサポート窓口へ(ストア側の通報 API は M4 後段)。
        if (d.supportUrl != null) await launchUrl(d.supportUrl!, mode: LaunchMode.externalApplication);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(storePluginProvider(widget.pluginId));
    return Scaffold(
      appBar: RasqPageHeader(title: context.l10n.storePageTitle, onMore: () {}),
      body: detail.when(
        loading: () => const RasqLoading(),
        // 掲載が無い / つながらないときも、インストール済みなら手元の情報のページ(削除もそこ)へ行ける (D-256)。
        error: (e, _) => _missing(context.l10n.storeConnectFailed, '$e'),
        data: (d) => d == null ? _missing(context.l10n.storePluginNotFound, context.l10n.storePageMaybeWithdrawn) : _page(d),
      ),
    );
  }

  Widget _missing(String title, String hint) {
    final installed = ref.watch(installedPluginsProvider).any((p) => p.id == widget.pluginId);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      RasqEmptyView(title: title, hint: hint),
      if (installed)
        Padding(
          padding: const EdgeInsets.only(top: RasqSpacing.md),
          child: FilledButton(key: const ValueKey('store.plugin.openInstalled'), onPressed: () => context.push(Routes.storeInstalledPlugin(widget.pluginId)), child: Text(context.l10n.storePageOpenInstalled)),
        ),
    ]);
  }

  Widget _page(StorePluginDetail d) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final installedList = ref.watch(installedPluginsProvider);
    final installed = installedList.where((p) => p.id == widget.pluginId).firstOrNull;
    final topReviews = ref.watch(storeTopReviewsProvider(d.id)).value ?? const <StoreReview>[];
    final allReviews = ref.watch(storeReviewsProvider(d.id)).value ?? const <StoreReview>[];
    final releases = ref.watch(storeReleasesProvider(d.id)).value ?? const <ReleaseNote>[];
    final missingDeps = [for (final id in d.compatibility.requiresPlugins) if (!installedList.any((p) => p.id == id)) id];
    final histogram = d.ratingHistogram.length == 5 ? d.ratingHistogram : StoreReview.histogram(allReviews);
    // 公開テストでは有料の機能が止まっている (D-401): 買っていない有料のものは、金額を出して押せない。
    final buyBlocked = d.needsPurchase && !ref.watch(paidFeaturesProvider);
    final canInstall = !_busy && !buyBlocked && !(d.status.isCaution && d.status != PluginStatus.warning);

    return ListView(children: [
      // ── 依存の注意 + インストール(ピル) ─────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 依存の注意(未導入の必要プラグインをリンク)。インストール済みでも
              // 依存が欠けていれば出し続ける。
              if (missingDeps.isNotEmpty)
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(context.l10n.storePageRequiresPrefix, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                  for (final (i, id) in missingDeps.indexed) ...[
                    if (i > 0) Text(' / ', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                    InkWell(
                      onTap: () => context.push(Routes.storePlugin(id)),
                      child: Text(id, style: RasqTypography.caption.copyWith(color: tokens.link)),
                    ),
                  ],
                  Text(context.l10n.storePageRequiresSuffix, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                ]),
              if (installed != null)
                Text(rasqDetail(context, context.l10n.storePageInstalledVersion(installed.version), context.l10n.storePageInstalledVersionVerified(installed.version)), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))
              else if (missingDeps.isEmpty)
                Text(
                  [
                    d.price == 0 ? context.l10n.storeFree : context.l10n.storePriceYen(d.price.toStringAsFixed(0)),
                    '${d.sizeMb.toStringAsFixed(1)}MB',
                    'v${d.version}${d.channel == 'beta' ? ' (β)' : ''}',
                    if (d.hasAds) context.l10n.storeHasAds,
                    if (buyBlocked) context.l10n.storeBuyDisabled,
                  ].join(context.l10n.storeDotSeparator),
                  key: const ValueKey('store.plugin.priceLine'),
                  style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
                ),
            ]),
          ),
          const SizedBox(width: RasqSpacing.sm),
          if (installed == null)
            FilledButton(
              // 停止/失効は新規インストール不可(警告はバナー明示の上で可)。
              onPressed: canInstall ? () => _install(d) : null,
              style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.lg)),
              child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(d.price == 0 ? context.l10n.storePageInstall : context.l10n.storePageBuy(d.price.toStringAsFixed(0))),
            )
          else ...[
            // カスタムプラグイン (D-357): 入っていれば「開く」。
            if (d.pluginType == StorePluginType.custom && registeredPagePlugin(ref.watch(installedPagePluginsProvider), d.id) != null) ...[
              FilledButton(
                key: const ValueKey('store.plugin.openCustom'),
                onPressed: () => context.push(Routes.customPage(d.id)),
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                child: Text(context.l10n.storeOpen),
              ),
              const SizedBox(width: RasqSpacing.xs),
            ],
            // 着せ替え (D-375): 入っていれば「使う」/ 使用中。
            if (ref.watch(themePacksProvider).any((p) => p.id == d.id)) ...[
              if (ref.watch(activeThemeIdProvider) == d.id)
                OutlinedButton(key: const ValueKey('store.theme.inUse'), onPressed: null, style: const ButtonStyle(shape: WidgetStatePropertyAll(StadiumBorder())), child: Text(context.l10n.storePageThemeInUse))
              else
                FilledButton(
                  key: const ValueKey('store.theme.use'),
                  onPressed: () => ref.read(settingsAreaProvider(themeSettingsArea).notifier).set('id', d.id),
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  child: Text(context.l10n.storePageThemeUse),
                ),
              const SizedBox(width: RasqSpacing.xs),
            ],
            OutlinedButton(
              onPressed: _busy ? null : () => ref.read(installedPluginsProvider.notifier).uninstall(d.id),
              style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
              child: Text(context.l10n.storeRemove),
            ),
          ],
          // カスタムプラグインの「共有」(Obsidian: インストールボタンの横に共有ボタン)。
          if (d.pluginType == StorePluginType.custom)
            Builder(
              builder: (bctx) => RasqIconButton(
                key: const ValueKey('store.plugin.share'),
                icon: Icons.ios_share,
                tooltip: context.l10n.storeShare,
                onPressed: () {
                  final box = bctx.findRenderObject() as RenderBox;
                  showCustomPluginShareMenu(context, ref, d, box.localToGlobal(Offset.zero) & box.size);
                },
              ),
            ),
        ]),
      ),
      // ── バナー ───────────────────────────────────────────────────────
      _Banner(url: d.bannerUrl),
      // ── アイコン + 名前 + 提供元 + ブックマーク + … ───────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.sm, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: d.iconUrl != null ? Image.network(webHtmlElementStrategy: rasqWebImageStrategy, d.iconUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.extension_outlined, size: 30)) : const Icon(Icons.extension_outlined, size: 30),
          ),
          const SizedBox(width: RasqSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, style: RasqTypography.title),
              Text([d.developerName.isEmpty ? context.l10n.storePageUnknownDeveloper : d.developerName, d.origin.label].join(context.l10n.storeDotSeparator), style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(context.l10n.storePageRatingDownloads(d.rating.toStringAsFixed(1), _formatDownloads(d.downloads)), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ),
          _BookmarkButton(pluginId: d.id),
          Builder(
            builder: (ctx) => RasqIconButton(
              icon: Icons.more_horiz,
              tooltip: context.l10n.storeMenu,
              onPressed: () {
                final box = ctx.findRenderObject() as RenderBox;
                _more(d, box.localToGlobal(Offset.zero) & box.size);
              },
            ),
          ),
        ]),
      ),
      // ── 紹介文(+ 説明の展開) ─────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.summary, style: RasqTypography.body),
          if (d.description.isNotEmpty)
            InkWell(
              onTap: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: RasqSpacing.xs),
                child: Text(
                  d.description,
                  style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: _descriptionExpanded ? null : 2,
                  overflow: _descriptionExpanded ? null : TextOverflow.ellipsis,
                ),
              ),
            ),
        ]),
      ),
      // ── 状態バナー(警告/停止/失効/更新あり/β) ─────────────────────────
      if (d.status != PluginStatus.published)
        Container(
          margin: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          padding: const EdgeInsets.all(RasqSpacing.sm),
          decoration: BoxDecoration(
            color: (d.status.isCaution ? tokens.danger : tokens.link).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(RasqSizes.radiusSm),
          ),
          child: Text(context.l10n.storePageStatus(d.status.label), style: RasqTypography.bodySmall.copyWith(color: d.status.isCaution ? tokens.danger : tokens.link)),
        ),
      // ── プレビュー(横スライド) ──────────────────────────────────────
      StoreFrameSectionHeader(title: context.l10n.storePagePreview),
      // 高さは見ている画像の縦横比に合わせる (D-374)。
      StorePreviewStrip(images: d.screenshots, placeholder: _PreviewPlaceholder(name: d.name)),
      // ── 先月のダウンロード数 / 評価 ──────────────────────────────────
      if (d.downloadsLastMonth != null)
        _StatBlock(
          title: context.l10n.storePageDownloadsLastMonth,
          value: _formatDownloads(d.downloadsLastMonth!),
          chart: DownloadsSparkline(values: d.downloadHistory),
        ),
      _StatBlock(
        title: context.l10n.storeRatingLabel,
        value: d.rating == 0 ? '—' : d.rating.toStringAsFixed(1),
        chart: RatingHistogram(histogram: histogram),
      ),
      // ── レビュー ›(TL 上位 10 件) ────────────────────────────────────
      StoreFrameSectionHeader(
        title: context.l10n.storeReviewsTitle,
        onTap: () => context.push(Routes.storePluginReviews(d.id)),
        trailing: Text(context.l10n.storePageReviewCount(allReviews.length), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
      ),
      StoreFrameStrip(
        height: 176,
        children: topReviews.isEmpty
            ? [
                StoreFrameCard(
                  showChevron: false,
                  header: Text(context.l10n.storeReviewsEmpty, style: RasqTypography.listTile),
                  // インストールしていなければ、書く欄の代わりに案内 (D-515)。
                  body: installed == null ? const StoreReviewNeedsInstallNote() : Text(context.l10n.storePageReviewsEmptyBody, style: RasqTypography.caption),
                  footer: installed == null
                      ? null
                      : Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => openReviewComposer(context, ref, detail: d), child: Text(context.l10n.storeReviewWrite))),
                ),
              ]
            : [
                for (final r in topReviews)
                  StoreReviewFrame(pluginId: d.id, review: r, onTap: () => context.push(Routes.storePluginReviews(d.id))),
              ],
      ),
      if (installed == null && topReviews.isNotEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0),
          child: StoreReviewNeedsInstallNote(),
        ),
      // ── アップデートとバージョン ›(タップで FOW) ─────────────────────
      StoreFrameSectionHeader(title: context.l10n.storePageUpdatesHeader, onTap: releases.isEmpty ? null : () => _showAllReleases(d, releases, installed)),
      StoreFrameStrip(
        height: 150,
        children: releases.isEmpty
            ? [
                StoreFrameCard(
                  showChevron: false,
                  header: Text('v${d.version}', style: RasqTypography.listTile),
                  body: Text(context.l10n.storePageNoReleaseNotes, style: RasqTypography.caption),
                ),
              ]
            : [
                for (final r in releases)
                  StoreFrameCard(
                    onTap: () => openReleaseFow(ref, detail: d, release: r, installed: installed, onInstall: (v) => _install(d, version: v)),
                    header: Text('${d.name} ${r.version}${r.channel == 'beta' ? ' Pre' : ''}', style: RasqTypography.listTile, maxLines: 1, overflow: TextOverflow.ellipsis),
                    headerTrailing: installed?.version == r.version
                        ? Padding(padding: const EdgeInsets.only(right: RasqSpacing.xs), child: Text(context.l10n.storeInUse, style: RasqTypography.caption.copyWith(color: tokens.link)))
                        : null,
                    body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Text(r.notes, style: RasqTypography.caption.copyWith(height: 1.5), overflow: TextOverflow.fade)),
                      if (r.permissionsAdded.isNotEmpty)
                        Text(context.l10n.storePermissionsAddedList([for (final p in r.permissionsAdded) p.permission].join(context.l10n.storeListSeparator)), style: RasqTypography.caption.copyWith(color: tokens.danger), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
              ],
      ),
      // ── プライバシーと必要な権限 ›(権限タイプごとのグループ) ────────
      StoreFrameSectionHeader(title: context.l10n.storePrivacyHeader, onTap: () => _showSafetyDetail(d)),
      StoreFrameStrip(
        height: 150,
        children: [
          for (final g in PermissionKind.group(d.safety.permissions))
            StoreFrameCard(
              onTap: () => _showSafetyDetail(d),
              header: Text(g.kind.label, style: RasqTypography.listTile),
              body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final p in g.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('${p.permission} — ${p.reason}', style: RasqTypography.caption.copyWith(height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
              ]),
            ),
          if (d.safety.permissions.isEmpty)
            StoreFrameCard(
              showChevron: false,
              header: Text(context.l10n.storePagePermissionsHeader, style: RasqTypography.listTile),
              body: Text(context.l10n.storePageNoPermissions, style: RasqTypography.caption),
            ),
          // 常設安全性ブロックの残り (D-033): 外部通信とデータ / 実行環境。
          StoreFrameCard(
            onTap: () => _showSafetyDetail(d),
            header: Text(context.l10n.storeSafetyExternalHeader, style: RasqTypography.listTile),
            body: Text(
              [
                d.safety.externalHosts.isEmpty ? context.l10n.storeSafetyNoHosts : context.l10n.storeSafetyHosts(d.safety.externalHosts.join(context.l10n.storeListSeparator)),
                if (d.safety.dataHandling.isNotEmpty) d.safety.dataHandling,
                if (d.safety.externalSdks.isNotEmpty) context.l10n.storeSafetySdks(d.safety.externalSdks.join(context.l10n.storeListSeparator)),
              ].join('\n'),
              style: RasqTypography.caption.copyWith(height: 1.4),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          StoreFrameCard(
            onTap: () => _showSafetyDetail(d),
            header: Text(context.l10n.storeSafetyRuntimeHeader, style: RasqTypography.listTile),
            body: Text(
              [
                if (d.safety.crashFreeRate != null) context.l10n.storeSafetyCrashFree((d.safety.crashFreeRate! * 100).toStringAsFixed(1)),
                d.safety.backgroundExecution ? context.l10n.storeSafetyBackground : context.l10n.storeSafetyNoBackground,
                d.safety.usesGpu ? context.l10n.storeSafetyGpu : context.l10n.storeSafetyNoGpu,
                d.safety.adPlacements.isEmpty ? context.l10n.storeSafetyNoAds : context.l10n.storeSafetyAds(d.safety.adPlacements.join(context.l10n.storeListSeparator)),
              ].join('\n'),
              style: RasqTypography.caption.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
      // ── 互換性 ───────────────────────────────────────────────────────
      RasqSectionHeader(title: context.l10n.storePageCompatibilityHeader),
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            [
              if (d.compatibility.rasqVersion.isNotEmpty) 'RASQ ${d.compatibility.rasqVersion}',
              if (d.compatibility.os.isNotEmpty) d.compatibility.os.join('/'),
              if (d.compatibility.requiredRuntimes.isNotEmpty) context.l10n.storePageRuntimes(d.compatibility.requiredRuntimes.join(context.l10n.storeListSeparator)),
              if (d.compatibility.requiresPlugins.isNotEmpty) context.l10n.storePageRequiredPlugins(d.compatibility.requiresPlugins.join(context.l10n.storeListSeparator)),
              if (d.compatibility.conflictsWith.isNotEmpty) context.l10n.storePageConflicts(d.compatibility.conflictsWith.join(context.l10n.storeListSeparator)),
            ].join(context.l10n.storeDotSeparator),
            style: RasqTypography.bodySmall,
          ),
          if (d.safety.rasqFeatures.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(context.l10n.storePageRasqFeatures(d.safety.rasqFeatures.join(context.l10n.storeListSeparator)), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ),
        ]),
      ),
      const SizedBox(height: RasqSpacing.xl),
    ]);
  }

  /// 「アップデートとバージョン ›」: 全版の一覧シート。各行 → FOW。
  Future<void> _showAllReleases(StorePluginDetail d, List<ReleaseNote> releases, InstalledPlugin? installed) async {
    final manager = ref.read(overlayManagerProvider);
    final pick = await manager.showBottomSheet<ReleaseNote>(
      id: 'store.releases',
      title: appL10n.storePageVersionsTitle,
      builder: (ctx) => ListView(shrinkWrap: true, children: [
        for (final r in releases)
          RasqPluginTile(
            icon: r.channel == 'beta' ? Icons.science_outlined : Icons.new_releases_outlined,
            title: '${r.version}${r.channel == 'beta' ? ' (β)' : ''}',
            subtitle: ['${r.publishedAt.year}/${r.publishedAt.month}/${r.publishedAt.day}', if (installed?.version == r.version) ctx.l10n.storeInUse].join(ctx.l10n.storeDotSeparator),
            description: r.notes,
            detail: r.permissionsAdded.isEmpty ? null : ctx.l10n.storePermissionsAddedList([for (final p in r.permissionsAdded) p.permission].join(ctx.l10n.storeListSeparator)),
            detailColorDots: [if (r.permissionsAdded.isNotEmpty) RasqTokens.of(ctx).danger],
            onTap: () => manager.close('store.releases', result: r),
          ),
      ]),
    );
    if (pick == null || !mounted) return;
    await openReleaseFow(ref, detail: d, release: pick, installed: installed, onInstall: (v) => _install(d, version: v));
  }

  /// 「プライバシーと必要な権限 ›」: 常設安全性ブロックの全文(グループ順)。
  Future<void> _showSafetyDetail(StorePluginDetail d) async {
    final manager = ref.read(overlayManagerProvider);
    await manager.showBottomSheet<void>(
      id: 'store.safety',
      title: appL10n.storePrivacyHeader,
      builder: (ctx) {
        return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.page), child: SafetyDetail(safety: d.safety));
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.url});
  final Uri? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 110,
      width: double.infinity,
      child: url != null
          ? Image.network(webHtmlElementStrategy: rasqWebImageStrategy, url.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder(scheme))
          : _placeholder(scheme),
    );
  }

  Widget _placeholder(ColorScheme scheme) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [scheme.primaryContainer, scheme.surfaceContainerHighest], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
      );
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: scheme.outline), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.image_outlined, size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: RasqSpacing.xs),
          Text(context.l10n.storePageNoPreview(name), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// 「先月のダウンロード数 / 評価」: 見出し、左に大きな数値、右にグラフ。
class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.title, required this.value, required this.chart});
  final String title;
  final String value;
  final Widget chart;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.lg, RasqSpacing.page, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: RasqTypography.sectionHeader),
          const SizedBox(height: RasqSpacing.xs),
          SizedBox(
            height: 92,
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              SizedBox(width: 120, child: Text(value, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, height: 1.1), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: RasqSpacing.md),
              Expanded(child: chart),
            ]),
          ),
        ]),
      );
}

String _formatDownloads(int n) => n >= 10000 ? appL10n.storeDownloadsTenThousands((n / 10000).toStringAsFixed(1)) : '$n';

/// ストアのブックマーク (D-033 `/me/bookmarks`)。RASQ アカウントに紐づく
/// サーバー側の状態なので、接続していないときは出さない。
class _BookmarkButton extends ConsumerWidget {
  const _BookmarkButton({required this.pluginId});
  final String pluginId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(centralConfiguredProvider)) return const SizedBox.shrink();
    final marked = ref.watch(storeBookmarksProvider).value?.contains(pluginId) ?? false;
    return IconButton(
      tooltip: marked ? context.l10n.storePageBookmarkRemove : context.l10n.storePageBookmarkAdd,
      icon: Icon(marked ? Icons.bookmark : Icons.bookmark_border),
      onPressed: () => ref.read(storeBookmarksProvider.notifier).toggle(pluginId).catchError((Object e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.storePageBookmarkFailed('$e'))));
      }),
    );
  }
}
