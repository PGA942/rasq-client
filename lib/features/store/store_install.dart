import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../backend/orgate_client.dart' show OrgateException, centralBaseUrlProvider;
import '../theme/theme_packs.dart';
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
    final bought = await showPurchaseSheet(manager, client, d, consoleUrl: ref.read(centralBaseUrlProvider)?.resolve('/console/points'));
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
  if (manifest == null) return version == null ? '構成を取得できませんでした' : 'Ver.$version の構成が見つかりませんでした';
  final bundle = manifest.bundle;
  final permissions = [
    for (final id in (manifest.manifest['permissions'] as List? ?? const []))
      if (id is String) d.safety.permissions.where((p) => p.permission == id).firstOrNull ?? PermissionEntry(id, ''),
  ];
  // インストール確認シート (D-033): 権限(種別ごと・用途理由つき)と配布物が根拠。
  final ok = await manager.showBottomSheet<bool>(
    id: 'store.install',
    title: '${d.name} ${manifest.version} をインストール',
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('このプラグインが使う権限', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
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
            if (manifest!.permissionsAdded.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('前のバージョンから増えた権限', style: RasqTypography.caption.copyWith(color: RasqTokens.of(ctx).danger)),
              for (final p in manifest.permissionsAdded) Text('${p.permission} — ${p.reason}', style: RasqTypography.bodySmall),
            ],
            const SizedBox(height: RasqSpacing.sm),
            if (bundle != null)
              // 署名の有無は正直に出す。モックストアや署名前の掲載物は
              // ハッシュ照合だけになる (D-034)。
              Text(
                  rasqDetail(
                      ctx,
                      '${(bundle.sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB ・ ${bundle.signature.isNotEmpty && manifest.storePublicKey.isNotEmpty ? 'ストアの署名あり' : 'ストアの署名なし'}',
                      '配布物: ${(bundle.sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB ・ SHA-512 ${bundle.sha512.substring(0, 16)}…'
                          ' ・ ${bundle.signature.isNotEmpty && manifest.storePublicKey.isNotEmpty ? 'ストア署名つき (ed25519)' : 'ストア署名なし(ハッシュ照合のみ)'}'),
                  style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
          child: FilledButton(onPressed: () => manager.close('store.install', result: true), child: const Text('インストールする')),
        ),
      ]);
    },
  );
  if (ok != true) return null; // 余白/スワイプで閉じた = キャンセル
  onBusy?.call(true);
  final outcome = await installed.install(d.id, version: version, activate: activate);
  onBusy?.call(false);
  if (outcome.error != null) return outcome.error;
  // 着せ替え (D-375): 入れたらそのまま使う。暗い / 明るいモード専用なら、いまのモードで効くかも添える。
  final pack = activate ? container.read(themePacksProvider).where((p) => p.id == d.id).firstOrNull : null;
  if (pack != null) {
    return switch (pack.theme['brightness']) {
      'dark' when brightness != Brightness.dark => '${d.name} を使います。暗いモードのときに効きます',
      'light' when brightness != Brightness.light => '${d.name} を使います。明るいモードのときに効きます',
      _ => '${d.name} を使います',
    };
  }
  return '${d.name} ${manifest.version} をインストールしました';
}

/// 購入シート (D-355): 値段(ポイント)、いまの残高、次に失効するポイント →「購入する」。足りなければ「Web コンソールでポイントを買う」
/// (Stripe、付与から 1 か月で失効)。戻り値 = 閉じた(買わない)は null、買えたら ''、買えなかったら理由。
Future<String?> showPurchaseSheet(OverlayManager manager, StoreClient client, StorePluginDetail d, {Uri? consoleUrl}) async {
  StorePoints points;
  try {
    points = await client.points();
  } catch (e) {
    return 'ポイントを確かめられませんでした(RASQ アカウントにログインしていますか?): $e';
  }
  final price = storePricePoints(d.price);
  final enough = points.balance >= price;
  final next = points.nextExpiring;
  String date(DateTime t) => '${t.year}/${t.month}/${t.day}';
  final go = await manager.showBottomSheet<String>(
    id: 'store.purchase',
    title: '${d.name} を購入',
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('$price ポイント', key: const ValueKey('store.purchase.price'), style: RasqTypography.title),
          const SizedBox(height: 4),
          Text('残り ${points.balance} ポイント${next == null ? '' : ' ・ ${date(next.expiresAt)} に ${next.remaining} ポイントが失効'}', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(rasqDetail(ctx, '買ったプラグインは、同じアカウントならどの端末でも使えます', '買ったプラグインは、同じ RASQ アカウントならどの端末でも入れられます。ポイントは有効期限の近いものから使います。'),
              style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: RasqSpacing.sm),
          if (enough)
            FilledButton(key: const ValueKey('store.purchase.buy'), onPressed: () => manager.close('store.purchase', result: 'buy'), child: Text('$price ポイントで購入する'))
          else ...[
            Text('ポイントが足りません(あと ${price - points.balance} ポイント)', style: RasqTypography.bodySmall.copyWith(color: scheme.error)),
            const SizedBox(height: RasqSpacing.xs),
            FilledButton.tonal(
              key: const ValueKey('store.purchase.console'),
              onPressed: consoleUrl == null ? null : () => manager.close('store.purchase', result: 'console'),
              child: const Text('Web コンソールでポイントを買う'),
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
    return r.purchased ? '' : '購入できませんでした';
  } on OrgateException catch (e) {
    return e.message;
  }
}
