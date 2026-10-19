import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../backend/orgate_client.dart' show OrgateException, centralBaseUrlProvider;
import '../../backend/payments_api.dart';
import '../../l10n/l10n.dart';
import '../theme/theme_packs.dart';
import 'plugin_scope.dart';
import 'store_client.dart';
import 'store_models.dart';
import 'store_providers.dart';

/// インストール(版指定つき, D-137): 確認シート(InstallManifest の権限・配布物が根拠)→ SHA-512 + ed25519 検証 → 登録。
/// プラグインページの「インストール」とストアホームのタイルの「入手 / 更新」(D-354)で共通。
/// 戻り値 = 伝える文(スナックバー)。確認シートを閉じた(キャンセル)ら null。[onBusy] は検証と登録の間 true。
/// [activate] = false: 入れて控えるだけ(既定の版は変えない、D-355 の「ほかの版を入れる」)。
Future<String?> confirmAndInstallPlugin(WidgetRef ref, StorePluginDetail d, {String? version, bool activate = true, void Function(bool busy)? onBusy}) async {
  final manager = ref.read(overlayManagerProvider);
  // await のあとに ref(呼び出し元のウィジェット)を触らない: 先に取っておく。
  final installed = ref.read(installedPluginsProvider.notifier);
  final client = ref.read(storeClientProvider);
  final container = ProviderScope.containerOf(ref.context, listen: false);
  final brightness = Theme.of(ref.context).brightness;
  // 有料で買っていなければ、先に購入 (D-355)。買わずに閉じたら何もしない。
  if (d.needsPurchase) {
    final consoleUrl = ref.read(centralBaseUrlProvider)?.resolve('/console/points');
    // 公開テストでは有料の機能が止まっている (D-401): シートは「使えません」だけ(買えない、コンソールへも誘わない)。
    final paid = (await container.read(paymentsConfigProvider.future)).paidFeatures;
    final bought = await showPurchaseSheet(manager, client, d, consoleUrl: consoleUrl, paidFeatures: paid);
    if (bought == null) return null;
    if (bought.isNotEmpty) return bought; // 買えなかった理由
    // 買った: ページの「購入済み」と残高を読み直す。
    container.invalidate(storePluginProvider(d.id));
    container.invalidate(storePointsProvider);
  }
  final InstallManifest? manifest;
  try {
    manifest = await client.manifest(d.id, version: version);
  } on OrgateException catch (e) {
    return e.message;
  }
  if (manifest == null) return version == null ? appL10n.storeInstallManifestUnavailable : appL10n.storeManifestVersionNotFound(version);
  final bundle = manifest.bundle;
  final permissions = [
    for (final id in (manifest.manifest['permissions'] as List? ?? const []))
      if (id is String) d.safety.permissions.where((p) => p.permission == id).firstOrNull ?? PermissionEntry(id, ''),
  ];
  // 最後に許可した内容から広がるもの(セキュリティ確認 2026-10-09 の [8]): 端末の記録と比べる。初めて入れるなら出さない(全部が新しい)。
  final scope = PluginScope.of([manifest.manifest]);
  final prev = container.read(installedPluginsProvider).where((p) => p.id == d.id).firstOrNull;
  final widened = prev == null ? const <String>[] : scope.wideningOver(prev.approvedScope);
  // インストール確認シート (D-033): 権限(種別ごと・用途理由つき)と配布物が根拠。
  final ok = await manager.showBottomSheet<bool>(
    id: 'store.install',
    title: appL10n.storeInstallSheetTitle(d.name, manifest.version),
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final storeAdded = manifest!.permissionsAdded;
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ctx.l10n.storeInstallPermissionsHeader, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            for (final g in PermissionKind.group(permissions)) ...[
              Text(g.kind.label, style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700)),
              for (final p in g.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: RasqSpacing.sm),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.key_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(p.reason.isEmpty ? p.permission : '${p.permission} — ${p.reason}', style: RasqTypography.bodySmall)),
                  ]),
                ),
            ],
            if (scope.hosts.isNotEmpty || scope.instance) ...[
              const SizedBox(height: 4),
              Text(ctx.l10n.storeInstallHostsHeader, style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700)),
              Text([...scope.hosts, if (scope.instance) ctx.l10n.storeInstallLoginInstance].join(ctx.l10n.storeListSeparator), style: RasqTypography.bodySmall),
            ],
            if (widened.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(prev?.approvedScope == null ? ctx.l10n.storeInstallScopeNoRecord : ctx.l10n.storeInstallScopeWidened,
                  key: const ValueKey('store.install.widened'), style: RasqTypography.caption.copyWith(color: RasqTokens.of(ctx).danger)),
              for (final w in widened) Text(w, style: RasqTypography.bodySmall),
            ] else if (storeAdded.isNotEmpty) ...[
              // ストアの差分(直前の公開版から)は参考。判断は端末の記録で行う。
              const SizedBox(height: 4),
              Text(ctx.l10n.storeInstallPermissionsAdded, style: RasqTypography.caption.copyWith(color: RasqTokens.of(ctx).danger)),
              for (final p in storeAdded) Text('${p.permission} — ${p.reason}', style: RasqTypography.bodySmall),
            ],
            const SizedBox(height: RasqSpacing.sm),
            if (bundle != null)
              // 署名の有無は正直に出す。モックストアや署名前の掲載物は
              // ハッシュ照合だけになる (D-034)。
              Text(
                  rasqDetail(
                      ctx,
                      ctx.l10n.storeInstallBundleSummary((bundle.sizeBytes / (1024 * 1024)).toStringAsFixed(1),
                          bundle.signature.isNotEmpty && manifest.storePublicKey.isNotEmpty ? ctx.l10n.storeInstallSignedShort : ctx.l10n.storeInstallUnsignedShort),
                      ctx.l10n.storeInstallBundleDetail((bundle.sizeBytes / (1024 * 1024)).toStringAsFixed(1), bundle.sha512.substring(0, 16),
                          bundle.signature.isNotEmpty && manifest.storePublicKey.isNotEmpty ? ctx.l10n.storeInstallSignedDetail : ctx.l10n.storeInstallUnsignedDetail)),
                  style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
          child: FilledButton(onPressed: () => manager.close('store.install', result: true), child: Text(ctx.l10n.storeInstallConfirm)),
        ),
      ]);
    },
  );
  if (ok != true) return null; // 余白/スワイプで閉じた = キャンセル
  onBusy?.call(true);
  // 確認シートで見た内容を許した(この版の内容を最後の承認として控える)。版と配布物のダイジェストも渡し、
  // シートを開いている間にストアの最新版 / 配布物が変わっていたら入れない(セキュリティ確認 2026-10-09 の [14])。
  final outcome = await installed.install(d.id, version: manifest.version, activate: activate, consent: PluginConsent(version: manifest.version, sha512: bundle?.sha512));
  onBusy?.call(false);
  if (outcome.error != null) return outcome.error;
  // 着せ替え (D-375): 入れたらそのまま使う。暗い / 明るいモード専用なら、いまのモードで効くかも添える。
  final pack = activate ? container.read(themePacksProvider).where((p) => p.id == d.id).firstOrNull : null;
  if (pack != null) {
    return switch (pack.theme['brightness']) {
      'dark' when brightness != Brightness.dark => appL10n.storeInstallThemeDarkOnly(d.name),
      'light' when brightness != Brightness.light => appL10n.storeInstallThemeLightOnly(d.name),
      _ => appL10n.storeInstallThemeApplied(d.name),
    };
  }
  return appL10n.storeInstallDone(d.name, manifest.version);
}

/// 入っている版を使い始める前の確認(セキュリティ確認 2026-10-09 の [8]): 最後に許可した内容より広がるなら、広がるものを見せて確かめる。
/// 戻り値 = null: やめた。広がらなければ確かめずに `consent: null`、確かめたら `consent` つき(その版の内容を最後の承認として控える)。
Future<({PluginConsent? consent})?> confirmVersionScope(OverlayManager manager, InstalledPlugins notifier, String pluginId, String version) async {
  final widened = notifier.versionWidening(pluginId, version);
  if (widened.isEmpty) return (consent: null);
  final ok = await manager.showAlert(
    id: 'store.versions.scope',
    title: appL10n.storeVersionScopeTitle(version),
    message: widened.join('\n'),
    confirmText: appL10n.storeVersionScopeConfirm,
    cancelText: appL10n.storeVersionScopeCancel,
  );
  return ok ? (consent: const PluginConsent()) : null;
}

/// 購入シート (D-355): 値段(ポイント)、いまの残高、次に失効するポイント →「購入する」。足りなければ「Web コンソールでポイントを買う」
/// (Stripe、付与から 1 か月で失効)。戻り値 = 閉じた(買わない)は null、買えたら ''、買えなかったら理由。
/// [paidFeatures] = false(公開テスト、D-401)/ サーバーが `paid_features_disabled` で断った: 値段と
/// 「公開テストでは有料プラグインは使えません」だけを出し、購入のボタンは押せない(コンソールへの案内も出さない)。
Future<String?> showPurchaseSheet(OverlayManager manager, StoreClient client, StorePluginDetail d, {Uri? consoleUrl, bool paidFeatures = true}) async {
  final price = storePricePoints(d.price);
  if (!paidFeatures) return _showPaidDisabledSheet(manager, d, price);
  StorePoints points;
  try {
    points = await client.points();
  } catch (e) {
    if (isPaidFeaturesDisabled(e)) return _showPaidDisabledSheet(manager, d, price);
    return appL10n.storePurchasePointsFailed('$e');
  }
  final enough = points.balance >= price;
  final next = points.nextExpiring;
  String date(DateTime t) => '${t.year}/${t.month}/${t.day}';
  final go = await manager.showBottomSheet<String>(
    id: 'store.purchase',
    title: appL10n.storePurchaseTitle(d.name),
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(ctx.l10n.storePurchasePrice(price), key: const ValueKey('store.purchase.price'), style: RasqTypography.title),
          const SizedBox(height: 4),
          Text(next == null ? ctx.l10n.storePurchaseBalance(points.balance) : ctx.l10n.storePurchaseBalanceExpiring(points.balance, date(next.expiresAt), next.remaining), style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(rasqDetail(ctx, ctx.l10n.storePurchaseCaption, ctx.l10n.storePurchaseCaptionDetail),
              style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: RasqSpacing.sm),
          if (enough)
            FilledButton(key: const ValueKey('store.purchase.buy'), onPressed: () => manager.close('store.purchase', result: 'buy'), child: Text(ctx.l10n.storePurchaseBuy(price)))
          else ...[
            Text(ctx.l10n.storePurchaseShort(price - points.balance), style: RasqTypography.bodySmall.copyWith(color: scheme.error)),
            const SizedBox(height: RasqSpacing.xs),
            FilledButton.tonal(
              key: const ValueKey('store.purchase.console'),
              onPressed: consoleUrl == null ? null : () => manager.close('store.purchase', result: 'console'),
              child: Text(ctx.l10n.storePurchaseConsole),
            ),
          ],
        ]),
      );
    },
  );
  if (go == 'console' && consoleUrl != null) {
    await launchUrl(consoleUrl, mode: LaunchMode.externalApplication);
    return null;
  }
  if (go != 'buy') return null;
  try {
    final r = await client.purchase(d.id);
    return r.purchased ? '' : appL10n.storePurchaseFailed;
  } on OrgateException catch (e) {
    return isPaidFeaturesDisabled(e) ? paidFeaturesDisabledMessage : e.message;
  }
}

/// 有料の機能が止まっているときの購入シート (D-401)。閉じるだけ(戻り値は null = 買わない)。
Future<String?> _showPaidDisabledSheet(OverlayManager manager, StorePluginDetail d, int price) async {
  await manager.showBottomSheet<String>(
    id: 'store.purchase',
    title: appL10n.storePurchaseTitle(d.name),
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(ctx.l10n.storePurchasePrice(price), key: const ValueKey('store.purchase.price'), style: RasqTypography.title.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(paidFeaturesDisabledMessage, key: const ValueKey('store.purchase.disabled'), style: RasqTypography.bodySmall.copyWith(color: scheme.error)),
          const SizedBox(height: RasqSpacing.sm),
          FilledButton(key: const ValueKey('store.purchase.buy'), onPressed: null, child: Text(ctx.l10n.storePurchaseBuy(price))),
        ]),
      );
    },
  );
  return null;
}
