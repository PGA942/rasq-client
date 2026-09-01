import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../shell/headers.dart';
import 'store_models.dart';
import 'store_providers.dart';

/// プラグインページ (M4 / D-120): プレビュー情報 + **常設安全性ブロック**
/// (SafetyBlock, D-033)+ 互換性 + リリースノート + レビュー。インストールは
/// 確認シート(構成 = InstallManifest の権限・配布物が根拠)→ SHA-512 検証。
class PluginPageScreen extends ConsumerStatefulWidget {
  const PluginPageScreen({super.key, required this.pluginId});
  final String pluginId;
  @override
  ConsumerState<PluginPageScreen> createState() => _PluginPageScreenState();
}

class _PluginPageScreenState extends ConsumerState<PluginPageScreen> {
  bool _busy = false;

  Future<void> _install(StorePluginDetail d) async {
    void toast(String message) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }

    final manager = ref.read(overlayManagerProvider);
    final manifest = await ref.read(storeManifestProvider(widget.pluginId).future);
    if (!mounted) return;
    if (manifest == null) {
      toast('構成を取得できませんでした');
      return;
    }
    final bundle = manifest.artifacts.where((a) => a.kind == 'bundle').firstOrNull;
    // インストール確認シート (D-033): 権限(用途理由つき)と配布物が根拠。
    final ok = await manager.showBottomSheet<bool>(
      id: 'store.install',
      title: '${d.name} をインストール',
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('このプラグインが使う権限', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              for (final p in d.safety.permissions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.key_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${p.permission} — ${p.reason}', style: RasqTypography.bodySmall)),
                  ]),
                ),
              if (manifest.permissionsAdded.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('前のバージョンから増えた権限', style: RasqTypography.caption.copyWith(color: RasqTokens.of(ctx).danger)),
                for (final p in manifest.permissionsAdded) Text('${p.permission} — ${p.reason}', style: RasqTypography.bodySmall),
              ],
              const SizedBox(height: RasqSpacing.sm),
              if (bundle != null)
                Text('配布物: ${(bundle.sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB ・ SHA-512 ${bundle.sha512.substring(0, 16)}… ・ ストア署名つき',
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
    if (ok != true || !mounted) return; // 余白/スワイプで閉じた = キャンセル
    setState(() => _busy = true);
    final error = await ref.read(installedPluginsProvider.notifier).install(widget.pluginId);
    if (!mounted) return;
    setState(() => _busy = false);
    toast(error ?? '${d.name} をインストールしました(SHA-512 検証済み)');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final detail = ref.watch(storePluginProvider(widget.pluginId));
    final installed = ref.watch(installedPluginsProvider).where((p) => p.id == widget.pluginId).firstOrNull;

    return Scaffold(
      appBar: RasqPageHeader(title: 'プラグイン', onMore: () {}),
      body: detail.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqEmptyView(title: 'ストアに接続できませんでした', hint: '$e'),
        data: (d) {
          if (d == null) return const RasqEmptyView(title: 'このプラグインは見つかりませんでした', hint: '取り下げられた可能性があります');
          final reviews = ref.watch(storeReviewsProvider(d.id)).value ?? const <StoreReview>[];
          final releases = ref.watch(storeReleasesProvider(d.id)).value ?? const <ReleaseNote>[];
          return ListView(children: [
            // ヘッダー: アイコン + 名前/提供元 + 数値行。
            Padding(
              padding: const EdgeInsets.all(RasqSpacing.page),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.extension_outlined, size: 30),
                ),
                const SizedBox(width: RasqSpacing.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.name, style: RasqTypography.title),
                    Text('${d.developerName} ・ ${d.origin.label}', style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text('★${d.rating.toStringAsFixed(1)} ・ ${d.downloads} DL ・ ${d.sizeMb.toStringAsFixed(1)}MB ・ v${d.version}${d.channel == 'beta' ? ' (β)' : ''}',
                        style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                  ]),
                ),
              ]),
            ),
            // 状態バナー(警告/停止/失効/更新あり)。
            if (d.status != PluginStatus.published)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
                padding: const EdgeInsets.all(RasqSpacing.sm),
                decoration: BoxDecoration(
                  color: (d.status.isCaution ? tokens.danger : tokens.link).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(RasqSizes.radiusSm),
                ),
                child: Text('状態: ${d.status.label}', style: RasqTypography.bodySmall.copyWith(color: d.status.isCaution ? tokens.danger : tokens.link)),
              ),
            // インストール/削除。
            Padding(
              padding: const EdgeInsets.all(RasqSpacing.page),
              child: installed == null
                  ? FilledButton(
                      // 停止/失効は新規インストール不可(警告はバナー明示の上で可)。
                      onPressed: _busy || (d.status.isCaution && d.status != PluginStatus.warning) ? null : () => _install(d),
                      child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(d.price == 0 ? 'インストール' : '¥${d.price.toStringAsFixed(0)} で購入'),
                    )
                  : Row(children: [
                      Expanded(child: Text('インストール済み v${installed.version}(SHA-512 検証済み)', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))),
                      OutlinedButton(
                        onPressed: _busy ? null : () => ref.read(installedPluginsProvider.notifier).uninstall(d.id),
                        child: const Text('削除'),
                      ),
                    ]),
            ),
            // 常設安全性ブロック (D-033): 折りたたまない。
            const RasqSectionHeader(title: '権限と安全性', topMargin: 0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final p in d.safety.permissions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.key_outlined, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${p.permission} — ${p.reason}', style: RasqTypography.bodySmall)),
                    ]),
                  ),
                if (d.safety.externalHosts.isNotEmpty) Text('外部通信先: ${d.safety.externalHosts.join('、')}', style: RasqTypography.bodySmall),
                if (d.safety.dataHandling.isNotEmpty) Text('データの扱い: ${d.safety.dataHandling}', style: RasqTypography.bodySmall),
                Text(
                  [
                    if (d.safety.crashFreeRate != null) '正常起動率 ${(d.safety.crashFreeRate! * 100).toStringAsFixed(1)}%',
                    d.safety.backgroundExecution ? 'バックグラウンド実行あり' : 'バックグラウンド実行なし',
                    if (d.safety.usesGpu) 'GPU 使用',
                    d.safety.adPlacements.isEmpty ? '広告なし' : '広告あり',
                  ].join(' ・ '),
                  style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (d.safety.rasqFeatures.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('利用する RASQ 機能: ${d.safety.rasqFeatures.join('、')}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                  ),
              ]),
            ),
            const RasqSectionHeader(title: '互換性'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
              child: Text(
                [
                  if (d.compatibility.rasqVersion.isNotEmpty) 'RASQ ${d.compatibility.rasqVersion}',
                  if (d.compatibility.os.isNotEmpty) d.compatibility.os.join('/'),
                  if (d.compatibility.requiredRuntimes.isNotEmpty) 'ランタイム: ${d.compatibility.requiredRuntimes.join('、')}',
                  if (d.compatibility.requiresPlugins.isNotEmpty) '必要プラグイン: ${d.compatibility.requiresPlugins.join('、')}',
                ].join(' ・ '),
                style: RasqTypography.bodySmall,
              ),
            ),
            const RasqSectionHeader(title: '説明'),
            Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text(d.description, style: RasqTypography.bodySmall)),
            if (releases.isNotEmpty) ...[
              const RasqSectionHeader(title: 'リリースノート'),
              for (final r in releases.take(3))
                Padding(
                  padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('v${r.version}${r.channel == 'beta' ? ' (β)' : ''}', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                    Text(r.notes, style: RasqTypography.bodySmall),
                    if (r.permissionsAdded.isNotEmpty)
                      Text('権限の追加: ${[for (final p in r.permissionsAdded) p.permission].join('、')}(自動更新は停止されます)',
                          style: RasqTypography.caption.copyWith(color: tokens.danger)),
                  ]),
                ),
            ],
            if (reviews.isNotEmpty) ...[
              const RasqSectionHeader(title: 'レビュー'),
              for (final r in reviews.take(3))
                Padding(
                  padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${'★' * r.rating}${r.verifiedUse ? ' ・ 実利用済み' : ''}${r.usedVersion.isEmpty ? '' : ' ・ v${r.usedVersion}'}',
                        style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                    Text(r.body, style: RasqTypography.bodySmall),
                    if (r.developerReply != null)
                      Padding(
                        padding: const EdgeInsets.only(left: RasqSpacing.md, top: 2),
                        child: Text('開発者: ${r.developerReply}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                      ),
                  ]),
                ),
            ],
            const SizedBox(height: RasqSpacing.page),
          ]);
        },
      ),
    );
  }
}
