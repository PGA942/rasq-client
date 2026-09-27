import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../backend/orgate_client.dart' show OrgateException;
import 'store_models.dart';
import 'store_providers.dart';

/// インストール(版指定つき, D-137): 確認シート(InstallManifest の権限・配布物が根拠)→ SHA-512 + ed25519 検証 → 登録。
/// プラグインページの「インストール」とストアホームのタイルの「入手 / 更新」(D-354)で共通。
/// 戻り値 = 伝える文(スナックバー)。確認シートを閉じた(キャンセル)ら null。[onBusy] は検証と登録の間 true。
Future<String?> confirmAndInstallPlugin(WidgetRef ref, StorePluginDetail d, {String? version, void Function(bool busy)? onBusy}) async {
  final manager = ref.read(overlayManagerProvider);
  // await のあとに ref(呼び出し元のウィジェット)を触らない: 先に取っておく。
  final installed = ref.read(installedPluginsProvider.notifier);
  final InstallManifest? manifest;
  try {
    manifest = await ref.read(storeClientProvider).manifest(d.id, version: version);
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
              Text('配布物: ${(bundle.sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB ・ SHA-512 ${bundle.sha512.substring(0, 16)}…'
                  ' ・ ${bundle.signature.isNotEmpty && manifest.storePublicKey.isNotEmpty ? 'ストア署名つき (ed25519)' : 'ストア署名なし(ハッシュ照合のみ)'}',
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
  final outcome = await installed.install(d.id, version: version);
  onBusy?.call(false);
  return outcome.error ?? '${d.name} ${manifest.version} をインストールしました(${outcome.verification?.message ?? 'SHA-512 検証済み'})';
}
