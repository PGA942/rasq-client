import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router.dart';
import '../../backend/orgate_client.dart' show centralBaseUrlProvider;
import '../../shell/headers.dart';
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import '../settings/settings_dsl.dart';
import 'store_home_screen.dart';
import 'store_install.dart';
import 'store_models.dart';
import 'store_providers.dart';
import 'store_tile.dart';

/// プラグインを管理 (D-353、ワイヤーフレーム p.8「プラグイン管理画面」— 以前の案は FOW だったのをページに)。
/// ストアホームの右上の歯車から。上から:
/// - **アップデート**: アップデートの設定 ›(D-356)、インストール済みのプラグインごとに、アイコン / 名前 / 開発者、概要、**デプロイしたバージョン**
///   (既定の版 = 青、2 つ目 = ストアの新しい版の「更新」/ 入れてある新しい版の「切り替え」/ ほかに入っている版)と
///   「アカウントごとにバージョンを設定 ›」(D-355)。タップで 1 件のページ(D-256)。
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
        RasqListTile(
          key: const ValueKey('store.manage.updateSettings'),
          leading: const Icon(Icons.tune),
          title: 'アップデートの設定',
          subtitle: 'SNS / アクション / ビューごとに、おまかせ・インストールだけ・手動 ・ 更新ログ',
          onTap: () => context.push(Routes.storeUpdateSettings),
        ),
        // ポイント (D-355): 有料プラグインを買う。買うのは Web コンソール(Stripe)。
        Builder(builder: (context) {
          final points = ref.watch(storePointsProvider).value;
          final next = points?.nextExpiring;
          final console = ref.watch(centralBaseUrlProvider)?.resolve('/console/points');
          return RasqListTile(
            key: const ValueKey('store.manage.points'),
            leading: const Icon(Icons.toll_outlined),
            title: points == null ? 'ポイント' : 'ポイント ${points.balance}',
            subtitle: points == null
                ? 'RASQ アカウントにログインすると使えます'
                : next == null
                    ? 'Web コンソールで買えます(付与から 2 か月で失効)'
                    : '${next.expiresAt.month}/${next.expiresAt.day} に ${next.remaining} ポイントが失効 ・ Web コンソールで買う',
            onTap: console == null ? null : () => launchUrl(console, mode: LaunchMode.externalApplication),
          );
        }),
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
        if (bookmarks.isNotEmpty) StoreTileRow(key: const ValueKey('store.manage.bookmarks'), title: 'ブックマーク', cards: bookmarks, installed: {for (final p in installed) p.id: p.version}),
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
    final tint = storeTileColor(detail?.pluginType ?? StorePluginType.other, scheme);
    final newer = detail != null && detail.version.isNotEmpty && detail.version != record.version ? detail.version : null;
    // 2 つ目のチップ: ストアの新しい版(入っていれば「切り替え」= 既定にする、無ければ「更新」= 確認シート → 入れて既定に)、
    // 無ければほかに入っている版、それも無ければ「最新です」。
    final others = [for (final v in record.allVersions) if (v.version != record.version) v];
    final Widget second;
    if (newer != null && record.versionInfo(newer) != null) {
      second = _VersionChip(
        key: ValueKey('store.manage.switch.${record.id}'),
        label: '$newer に切り替え',
        selected: false,
        onTap: () async {
          final error = await ref.read(installedPluginsProvider.notifier).setDefaultVersion(record.id, newer);
          ref.read(rootMessengerKeyProvider).currentState?.showSnackBar(SnackBar(content: Text(error ?? '$newer を既定の版にしました')));
        },
      );
    } else if (newer != null) {
      second = _VersionChip(
        key: ValueKey('store.manage.update.${record.id}'),
        label: '$newer に更新',
        selected: false,
        onTap: () async {
          final messenger = ref.read(rootMessengerKeyProvider).currentState;
          final msg = await confirmAndInstallPlugin(ref, detail!, version: newer);
          if (msg != null) messenger?.showSnackBar(SnackBar(content: Text(msg)));
        },
      );
    } else if (others.isNotEmpty) {
      second = _VersionChip(label: others.first.version, selected: false, onTap: () => context.push(Routes.storePluginVersions(record.id)));
    } else {
      second = _VersionChip(label: detail == null ? 'ストアに接続できません' : '最新です', selected: false, muted: true);
    }
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
                    ? Image.network(webHtmlElementStrategy: rasqWebImageStrategy, '$iconUrl', fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: tint, child: const Icon(Icons.extension_outlined)))
                    : ColoredBox(color: tint, child: const Icon(Icons.extension_outlined)),
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
          // デプロイしたバージョン(左)と「アカウントごとにバージョンを設定 ›」(右)、ワイヤーフレームの並び (D-355)。
          Row(children: [
            Expanded(child: Text('デプロイしたバージョン', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
            InkWell(
              key: ValueKey('store.manage.versions.${record.id}'),
              onTap: () => context.push(Routes.storePluginVersions(record.id)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(record.accountVersions.isEmpty ? 'アカウントごとにバージョンを設定' : 'アカウントごと(${record.accountVersions.length} 件指定)', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                const Icon(Icons.chevron_right, size: 16),
              ]),
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _VersionChip(key: ValueKey('store.manage.version.${record.id}'), label: record.version, selected: true)),
            const SizedBox(width: RasqSpacing.xs),
            Expanded(child: second),
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
