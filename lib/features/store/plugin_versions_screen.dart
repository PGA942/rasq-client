import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import 'store_install.dart';
import 'store_models.dart';
import 'store_providers.dart';

/// アカウントごとにバージョンを設定 (D-355、ワイヤーフレーム p.8)。
/// - **入っている版**: 版ごとの行(既定の印、使っているアカウントの数)。… = 既定にする / 消す(使っていない版だけ)。
/// - **ほかの版を入れる**: ストアのリリース(入っていない版)→「入れる」= 確認シート → 検証 → 入れて控える(既定は変えない)。
/// - **アカウントごと**: SNS アカウントごとに、使う版(「既定に従う」か、入っている版)。そのアカウントで動くスロットプラグイン / ノードの
///   並べ替えはその版になる。着せ替え / 素材は端末全体で 1 つなので、この節は出さない。
class PluginVersionsScreen extends ConsumerWidget {
  const PluginVersionsScreen({super.key, required this.pluginId});
  final String pluginId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final record = ref.watch(installedPluginsProvider).where((p) => p.id == pluginId).firstOrNull;
    if (record == null) {
      return Scaffold(appBar: const RasqPageHeader(title: 'アカウントごとにバージョンを設定', showMore: false), body: const RasqEmptyView(title: 'インストールされていません'));
    }
    final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    final releases = ref.watch(storeReleasesProvider(pluginId)).value ?? const <ReleaseNote>[];
    final installedVersions = {for (final v in record.allVersions) v.version};
    final notInstalled = [for (final r in releases) if (!installedVersions.contains(r.version)) r];
    final isPack = record.pluginType == StorePluginType.theme || record.pluginType == StorePluginType.assets;
    final notifier = ref.read(installedPluginsProvider.notifier);
    final messenger = ref.read(rootMessengerKeyProvider).currentState;
    void report(String? error, String ok) => messenger?.showSnackBar(SnackBar(content: Text(error ?? ok)));
    String label(InstalledVersion v) => '${v.version}${v.isPreview ? ' (Pre)' : ''}';

    return Scaffold(
      appBar: RasqPageHeader(title: record.name.isEmpty ? record.id : record.name, showMore: false),
      body: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.lg), children: [
        const RasqSectionHeader(title: '入っている版', topMargin: 0),
        for (final v in record.allVersions)
          Builder(builder: (ctx) {
            final isDefault = v.version == record.version;
            final users = record.accountVersions.values.where((x) => x == v.version).length;
            return RasqListTile(
              key: ValueKey('store.versions.installed.${v.version}'),
              leading: Icon(isDefault ? Icons.radio_button_checked : Icons.radio_button_off, color: isDefault ? RasqColors.link : null),
              title: label(v),
              subtitle: [
                if (isDefault) '既定の版',
                if (users > 0) '$users アカウントが使用中',
                '入れた日 ${v.installedAt.year}/${v.installedAt.month}/${v.installedAt.day}',
              ].join(' ・ '),
              chevron: false,
              trailing: RasqIconButton(
                key: ValueKey('store.versions.menu.${v.version}'),
                icon: Icons.more_horiz,
                size: 20,
                tooltip: 'メニュー',
                onPressed: () async {
                  final box = ctx.findRenderObject() as RenderBox?;
                  final anchor = box == null ? const Rect.fromLTWH(0, 0, 1, 1) : Rect.fromLTWH(box.localToGlobal(Offset.zero).dx + box.size.width - 48, box.localToGlobal(Offset.zero).dy, 40, box.size.height);
                  final pick = await ref.read(overlayManagerProvider).showDropdown<String>(id: 'store.versions.menu', anchor: anchor, items: [
                    RasqDropdownItem('既定の版にする', 'default', enabled: !isDefault),
                    RasqDropdownItem('この版を消す', 'remove', destructive: true, enabled: !record.usedVersions.contains(v.version)),
                  ]);
                  if (pick == 'default') {
                    final ok = await confirmVersionScope(ref.read(overlayManagerProvider), notifier, pluginId, v.version);
                    if (ok != null) report(await notifier.setDefaultVersion(pluginId, v.version, consent: ok.consent), '${v.version} を既定の版にしました');
                  }
                  if (pick == 'remove') report(await notifier.removeVersion(pluginId, v.version), '${v.version} を消しました');
                },
              ),
            );
          }),
        if (notInstalled.isNotEmpty) ...[
          const RasqSectionHeader(title: 'ほかの版を入れる'),
          for (final r in notInstalled)
            RasqListTile(
              key: ValueKey('store.versions.release.${r.version}'),
              leading: const Icon(Icons.download_outlined),
              title: '${r.version}${r.channel != 'stable' ? ' (Pre)' : ''}',
              subtitle: [
                if (r.notes.isNotEmpty) r.notes.split('\n').first,
                if (r.permissionsAdded.isNotEmpty) '権限が増えます',
              ].join(' ・ '),
              chevron: false,
              trailing: TextButton(
                key: ValueKey('store.versions.install.${r.version}'),
                onPressed: () async {
                  final d = await ref.read(storeClientProvider).plugin(pluginId);
                  if (d == null) return report('このプラグインは見つかりませんでした', '');
                  if (!context.mounted) return;
                  final msg = await confirmAndInstallPlugin(ref, d, version: r.version, activate: false);
                  if (msg != null) report(null, msg);
                },
                child: const Text('入れる'),
              ),
            ),
        ],
        if (!isPack) ...[
          const RasqSectionHeader(title: 'アカウントごと'),
          const RasqCaption(
            'アカウントごとに、使う版を選べます',
            detail: 'そのアカウントを使っている間、スロットプラグインとノードの並べ替えは、ここで選んだ版で動きます。',
            padding: EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          ),
          for (final s in sessions)
            Builder(builder: (ctx) {
              final chosen = record.accountVersions[s.account.key];
              return RasqListTile(
                key: ValueKey('store.versions.account.${s.account.key}'),
                leading: RasqAvatar(imageUrl: s.avatarUrl, size: 32, fallbackLabel: s.displayName ?? s.account.handle),
                title: s.displayName ?? '@${s.account.handle}',
                subtitle: '${s.account}',
                chevron: false,
                trailing: OutlinedButton(
                  key: ValueKey('store.versions.account.pick.${s.account.key}'),
                  onPressed: () async {
                    final box = ctx.findRenderObject() as RenderBox?;
                    final anchor = box == null ? const Rect.fromLTWH(0, 0, 1, 1) : Rect.fromLTWH(box.localToGlobal(Offset.zero).dx + box.size.width - 160, box.localToGlobal(Offset.zero).dy, 150, box.size.height);
                    final pick = await ref.read(overlayManagerProvider).showDropdown<String>(id: 'store.versions.account', anchor: anchor, items: [
                      RasqDropdownItem('既定に従う(${record.version})', '', checked: chosen == null),
                      for (final v in record.allVersions) RasqDropdownItem(label(v), v.version, checked: chosen == v.version),
                    ]);
                    if (pick == null) return;
                    final ok = pick.isEmpty ? (consent: null) : await confirmVersionScope(ref.read(overlayManagerProvider), notifier, pluginId, pick);
                    if (ok == null) return;
                    report(await notifier.setAccountVersion(pluginId, s.account.key, pick.isEmpty ? null : pick, consent: ok.consent), pick.isEmpty ? '${s.account} は既定の版に従います' : '${s.account} は $pick を使います');
                  },
                  child: Text(chosen ?? '既定(${record.version})'),
                ),
              );
            }),
        ] else
          Padding(
            padding: const EdgeInsets.all(RasqSpacing.page),
            child: Text('着せ替え / ステッカー・素材は端末全体で 1 つの版を使います(既定の版)。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
      ]),
    );
  }
}
