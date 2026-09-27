import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../../shell/headers.dart';
import '../settings/settings_dsl.dart';
import 'store_home_screen.dart';
import 'store_models.dart';
import 'store_providers.dart';
import 'store_tile.dart';

/// プラグインを管理 (D-353、ワイヤーフレーム p.8「プラグイン管理画面」— 以前の案は FOW だったのをページに)。
/// ストアホームの右上の歯車から。上から:
/// - **アップデート**: インストール済みのプラグインごとに、アイコン / 名前 / 開発者、概要、**デプロイしたバージョン**
///   (いま入っている版 = 青、ストアに新しい版があれば灰色のチップ → ストアのページで入れ直す)。タップで 1 件のページ(D-256)。
/// - **プラグインのインポート**(開発中の wasm / .rasqpkg。審査を通っていないので注意つき)。
/// - **ホームの表示**: インストール済みもホームの列に出す。
/// - **ブックマーク**: タイルの横の列。
class StoreManageScreen extends ConsumerWidget {
  const StoreManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final installed = ref.watch(installedPluginsProvider);
    final bookmarks = ref.watch(storeHomeProvider).value?.bookmarks ?? const <StorePluginCard>[];
    final showInstalled = ref.watch(storeHomeShowInstalledProvider);
    return Scaffold(
      appBar: const RasqPageHeader(title: 'プラグインを管理', showMore: false),
      body: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.lg), children: [
        const RasqSectionHeader(title: 'アップデート', topMargin: 0),
        if (installed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
            child: Text('インストール済みのプラグインはありません', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
          )
        else
          for (final p in installed) ...[_InstalledBlock(record: p), const Divider(height: 1)],
        RasqListTile(
          key: const ValueKey('store.manage.import'),
          leading: const Icon(Icons.warning_amber_rounded, color: RasqColors.warning),
          title: 'プラグインのインポート',
          subtitle: '開発中の wasm / .rasqpkg を入れる(審査を通っていません)',
          onTap: () => context.push(Routes.wasmDev),
        ),
        const RasqSectionHeader(title: 'ホームの表示'),
        RasqSwitchListTile(
          key: const ValueKey('store.manage.showInstalled'),
          title: 'インストール済みもホームに出す',
          subtitle: '今週のトレンド / 新着の列に、入れたプラグインも並べます',
          value: showInstalled,
          onChanged: (v) => ref.read(settingsAreaProvider(storeHomeArea).notifier).set('showInstalled', v),
        ),
        if (bookmarks.isNotEmpty) StoreTileRow(key: const ValueKey('store.manage.bookmarks'), title: 'ブックマーク', cards: bookmarks, installed: {for (final p in installed) p.id}),
      ]),
    );
  }
}

/// インストール済み 1 件(ワイヤーフレームのブロック)。情報はストアの掲載 → インストール時の写しの順。
class _InstalledBlock extends ConsumerWidget {
  const _InstalledBlock({required this.record});
  final InstalledPlugin record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final detail = ref.watch(storePluginProvider(record.id)).value;
    final info = record.info;
    final name = detail?.name ?? (record.name.isEmpty ? record.id : record.name);
    final developer = detail?.developerName ?? info?.developerName ?? '';
    final summary = detail?.summary ?? info?.summary ?? '';
    final iconUrl = detail?.iconUrl ?? info?.iconUrl;
    final newer = detail != null && detail.version.isNotEmpty && detail.version != record.version ? detail.version : null;
    return InkWell(
      key: ValueKey('store.manage.installed.${record.id}'),
      onTap: () => context.push(Routes.storeInstalledPlugin(record.id)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: 44,
                child: iconUrl != null
                    ? Image.network(webHtmlElementStrategy: rasqWebImageStrategy, '$iconUrl', fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: storeTileColor(record.id), child: const Icon(Icons.extension_outlined)))
                    : ColoredBox(color: storeTileColor(record.id), child: const Icon(Icons.extension_outlined, color: Color(0xFF1B1B1F))),
              ),
            ),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text([if (developer.isNotEmpty) developer, if (detail != null) detail.origin.label].join(' ・ '), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
          if (summary.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(summary, style: RasqTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(height: RasqSpacing.xs),
          Text('デプロイしたバージョン', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _VersionChip(key: ValueKey('store.manage.version.${record.id}'), label: record.version, selected: true)),
            const SizedBox(width: RasqSpacing.xs),
            Expanded(
              child: newer == null
                  ? _VersionChip(label: detail == null ? 'ストアに接続できません' : '最新です', selected: false, muted: true)
                  : _VersionChip(
                      key: ValueKey('store.manage.update.${record.id}'),
                      label: '$newer に更新',
                      selected: false,
                      onTap: () => context.push(Routes.storePlugin(record.id)),
                    ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({super.key, required this.label, required this.selected, this.muted = false, this.onTap});
  final String label;
  final bool selected;
  final bool muted;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? RasqColors.link.withValues(alpha: 0.85) : scheme.surfaceContainerHighest;
    final fg = selected ? Colors.white : (muted ? scheme.onSurfaceVariant : scheme.onSurface);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: RasqTypography.bodySmall.copyWith(color: fg, fontWeight: selected ? FontWeight.w700 : null)),
        ),
      ),
    );
  }
}
