import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../home/material_icons.dart';
import '../plugins/slot_plugins.dart';
import 'custom_client.dart';
import 'custom_models.dart';
import 'custom_page.dart';
import 'custom_plugins_screen.dart';

/// RASQ アカウントのページに置いたカスタムプラグイン(`GET /accounts/{handle}/pages`、S-048、D-357)。
final profileCustomPagesProvider = FutureProvider.family<List<CustomProfilePage>, String>((ref, handle) => ref.watch(customSessionClientProvider).profilePages(handle));

/// プロフィールに置けるもの = 登録済みのページ型で `profile` を開けるもの。
List<SlotPlugin> profilePlaceablePlugins(List<SlotPlugin> pagePlugins) => [for (final p in pagePlugins) if (p.manifest.page?.allows(PluginPageDecl.surfaceProfile) == true) p];

/// 自分のページに置く / 外す。shared は持ち主のプロフィールごとのセッションを作っておく(訪問者はそこへ入る)。
Future<String?> setProfilePlugin(WidgetRef ref, {required String handle, required SlotPlugin plugin, required bool placed}) async {
  final client = ref.read(customSessionClientProvider);
  final id = plugin.storePluginId ?? plugin.id;
  try {
    final now = await client.profilePages(handle);
    final items = [for (final p in now) if (p.pluginId != id) (pluginId: p.pluginId, version: p.version)];
    if (placed) {
      if (items.length >= 8) return 'ページに置けるのは 8 個までです';
      items.add((pluginId: id, version: plugin.storeVersion));
    }
    await client.setMyPages(items);
    if (placed && plugin.manifest.page?.isShared == true) await client.create(pluginId: id, version: plugin.storeVersion, scope: 'profile');
    ref.invalidate(profileCustomPagesProvider(handle));
    return null;
  } catch (e) {
    return '$e';
  }
}

/// アカウントページの「ページ」タブ (D-357)。置いたカスタムプラグインのタイル → そのページ。持ち主は「ページを編集」。
class CustomProfilePagesTab extends ConsumerWidget {
  const CustomProfilePagesTab({super.key, required this.handle, this.accountId, required this.isMine});
  final String handle;
  final String? accountId;
  final bool isMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final pages = ref.watch(profileCustomPagesProvider(handle));
    final items = pages.value ?? const <CustomProfilePage>[];
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      if (pages.isLoading && !pages.hasValue)
        const Padding(padding: EdgeInsets.all(RasqSpacing.lg), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
      else if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: Text(
            pages.hasError ? '読み込めませんでした: ${pages.error}' : (isMine ? 'カスタムプラグインを置くと、訪れた人がここから開けます。' : 'ページはまだありません。'),
            style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      for (final p in items)
        RasqListTile(
          key: ValueKey('rasqPage.custom.${p.pluginId}'),
          leading: Icon(materialIconByName(p.icon) ?? Icons.dashboard_customize_outlined),
          title: p.name,
          subtitle: p.isShared ? (p.sessionId == null ? 'みんなで使う(まだ始まっていません)' : 'みんなで使う') : '1 人で使う',
          onTap: () => context.push(Routes.customPage(
                p.pluginId,
                CustomPageArgs(pluginId: p.pluginId, version: p.version, surface: PluginPageDecl.surfaceProfile, sessionId: p.sessionId, profileHandle: handle, profileAccountId: accountId).query,
              )),
        ),
      if (isMine)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Builder(
              builder: (bctx) => OutlinedButton.icon(
                key: const ValueKey('rasqPage.custom.edit'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('ページを編集'),
                onPressed: () async {
                  final box = bctx.findRenderObject() as RenderBox?;
                  final anchor = box == null ? const Rect.fromLTWH(0, 0, 1, 1) : box.localToGlobal(Offset.zero) & box.size;
                  final candidates = profilePlaceablePlugins(ref.read(installedPagePluginsProvider));
                  final placed = {for (final p in items) p.pluginId};
                  final pick = await ref.read(overlayManagerProvider).showDropdown<String>(id: 'rasqPage.custom.edit', anchor: anchor, items: [
                    for (final p in candidates) RasqDropdownItem(p.manifest.page?.title ?? p.manifest.name, p.storePluginId ?? p.id, checked: placed.contains(p.storePluginId ?? p.id)),
                    const RasqDropdownItem('ストアで探す', '\u0000store'),
                  ]);
                  if (pick == null || !context.mounted) return;
                  if (pick == '\u0000store') {
                    context.push(Routes.storeSearch());
                    return;
                  }
                  final plugin = candidates.firstWhere((p) => (p.storePluginId ?? p.id) == pick);
                  final error = await setProfilePlugin(ref, handle: handle, plugin: plugin, placed: !placed.contains(pick));
                  if (error != null && context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('変えられませんでした: $error')));
                },
              ),
            ),
          ),
        ),
    ]);
  }
}
