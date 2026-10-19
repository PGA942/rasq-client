import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import '../plugins/slot_plugins.dart';
import 'rasqpkg.dart' show parseStoreSlotSource;
import 'store_models.dart';
import 'store_providers.dart';
import 'store_widgets.dart';

/// インストール済み (D-256): ストアの掲載とは別のページ。
///
/// - 一覧([InstalledPluginsScreen])はストアにつながらなくても開ける(手元の記録だけで描く)。
/// - 1 件のページ([InstalledPluginScreen])は **手元の情報が主**: 見出し部(アイコン / 名前 / 開発者 / 概要 / 説明)、
///   インストール済みのバージョン、プライバシーと必要な権限、削除。ストアの掲載が**消えていても削除できる**。
///   掲載が生きていれば、新しい版の案内と「ストアのページを開く」を足す。
/// - 情報の出どころ: いまの掲載 → インストール時の写し([InstalledInfo])→ スロットに登録されているプラグインのマニフェスト
///   (権限の id だけ)の順。
class InstalledPluginsScreen extends ConsumerWidget {
  const InstalledPluginsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(installedPluginsProvider);
    return Scaffold(
      appBar: RasqPageHeader(title: context.l10n.storeInstalledTitle, onMore: () {}),
      body: installed.isEmpty
          ? RasqEmptyView(title: context.l10n.storeNoInstalledPlugins, hint: context.l10n.storeInstalledEmptyHint)
          : ListView(children: [
              for (final p in installed) ...[
                RasqPluginTile(
                  key: ValueKey('store.installed.${p.id}'),
                  icon: Icons.extension,
                  title: p.name.isEmpty ? p.id : p.name,
                  subtitle: context.l10n.storeInstalledItemSubtitle(p.version, p.id),
                  onTap: () => context.push(Routes.storeInstalledPlugin(p.id)),
                ),
                const Divider(height: 1),
              ],
            ]),
    );
  }
}

class InstalledPluginScreen extends ConsumerWidget {
  const InstalledPluginScreen({super.key, required this.pluginId});
  final String pluginId;

  static String _date(DateTime d) => d.millisecondsSinceEpoch == 0 ? appL10n.storeUnknown : '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final record = ref.watch(installedPluginsProvider).where((p) => p.id == pluginId).firstOrNull;
    if (record == null) {
      return Scaffold(appBar: RasqPageHeader(title: context.l10n.storeInstalledTitle, onMore: () {}), body: RasqEmptyView(title: context.l10n.storeNotInstalled, hint: context.l10n.storeInstalledMissingHint));
    }
    // いまの掲載(あれば)。無くても / つながらなくても、このページは手元の情報で描く。
    final live = ref.watch(storePluginProvider(pluginId));
    final detail = live.value;
    final info = record.info;
    // スロットに登録されているもの(この配布物から入った root / 子)。写しが無い古いインストールでは、権限はここから。
    final slots = [for (final p in ref.watch(slotPluginsProvider)) if (parseStoreSlotSource(p.source)?.pluginId == pluginId) p];
    final safety = detail?.safety ??
        info?.safety ??
        SafetyBlock(permissions: [for (final perm in {for (final p in slots) ...p.manifest.permissions}) PermissionEntry(perm, '')]);
    final name = detail?.name ?? (record.name.isEmpty ? pluginId : record.name);
    final developer = detail?.developerName ?? info?.developerName ?? '';
    final summary = detail?.summary ?? info?.summary ?? '';
    final description = detail?.description ?? info?.description ?? (slots.isEmpty ? '' : slots.first.manifest.description);
    final iconUrl = detail?.iconUrl ?? info?.iconUrl;
    final newer = detail != null && isNewerVersion(detail.version, record.version);
    final source = detail != null ? null : (info != null ? context.l10n.storeInstalledSourceSnapshot : (slots.isNotEmpty ? context.l10n.storeInstalledSourceManifest : null));

    Future<void> remove() async {
      final ok = await ref.read(overlayManagerProvider).showAlert(id: 'store.installed.remove', title: context.l10n.storeInstalledRemoveTitle, message: context.l10n.storeInstalledRemoveMessage(name), confirmText: context.l10n.storeRemove, cancelText: context.l10n.storeCancel, destructive: true);
      if (!ok || !context.mounted) return;
      await ref.read(installedPluginsProvider.notifier).uninstall(pluginId);
      if (context.mounted) context.pop();
    }

    return Scaffold(
      appBar: RasqPageHeader(title: context.l10n.storeInstalledTitle, onMore: () {}),
      body: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.lg), children: [
        // ── 見出し部(ストアのページの「プレビューより上」と同じ並び)──
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 64,
                height: 64,
                color: scheme.surfaceContainerHighest,
                child: iconUrl != null ? Image.network(webHtmlElementStrategy: rasqWebImageStrategy, '$iconUrl', fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.extension_outlined, size: 30)) : const Icon(Icons.extension_outlined, size: 30),
              ),
            ),
            const SizedBox(width: RasqSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700, fontSize: 18)),
                if (developer.isNotEmpty) Text(developer, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
                Text(pluginId, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        if (summary.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0), child: Text(summary, style: RasqTypography.body)),
        if (description.isNotEmpty && description != summary) Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0), child: Text(description, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))),
        // ── 掲載の状態 ──
        if (live.isLoading)
          const Padding(padding: EdgeInsets.all(RasqSpacing.page), child: LinearProgressIndicator())
        else if (detail == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
            child: Container(
              key: const ValueKey('store.installed.unlisted'),
              padding: const EdgeInsets.all(RasqSpacing.sm),
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
              child: Text(live.hasError ? context.l10n.storeInstalledOffline : context.l10n.storeInstalledUnlisted, style: RasqTypography.bodySmall),
            ),
          ),
        // ── インストール済みのバージョン ──
        RasqSectionHeader(title: context.l10n.storeInstalledVersionHeader),
        RasqListTile(
          key: const ValueKey('store.installed.version'),
          leading: const Icon(Icons.verified_outlined),
          title: 'v${record.version}',
          subtitle: context.l10n.storeInstalledAt(_date(record.installedAt)),
          detail: context.l10n.storeInstalledAtVerified(_date(record.installedAt), record.sha512.length > 16 ? '${record.sha512.substring(0, 16)}…' : record.sha512),
          chevron: false,
        ),
        if (newer)
          RasqListTile(
            key: const ValueKey('store.installed.update'),
            leading: Icon(Icons.system_update_alt, color: RasqColors.accent),
            title: context.l10n.storeInstalledNewerTitle(detail.version),
            subtitle: context.l10n.storeInstalledNewerSubtitle,
            onTap: () => context.push(Routes.storePlugin(pluginId)),
          ),
        if (slots.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0),
            child: Text(context.l10n.storeInstalledSlots({for (final p in slots) ...p.manifest.slots}.join(context.l10n.storeListSeparator)), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
        // ── 操作(権限の節は長くなるので、その上に置く)──
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
          child: Row(children: [
            if (detail != null) Expanded(child: OutlinedButton(key: const ValueKey('store.installed.openStore'), onPressed: () => context.push(Routes.storePlugin(pluginId)), child: Text(context.l10n.storeInstalledOpenStore))),
            if (detail != null) const SizedBox(width: RasqSpacing.sm),
            Expanded(child: FilledButton.tonal(key: const ValueKey('store.installed.remove'), onPressed: remove, style: FilledButton.styleFrom(foregroundColor: scheme.error), child: Text(context.l10n.storeRemove))),
          ]),
        ),
        // ── プライバシーと必要な権限 ──
        RasqSectionHeader(title: context.l10n.storePrivacyHeader),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (source != null) Text(source, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            SafetyDetail(key: const ValueKey('store.installed.safety'), safety: safety),
          ]),
        ),
      ]),
    );
  }
}
