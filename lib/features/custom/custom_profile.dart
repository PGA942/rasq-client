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
import '../../backend/orgate_client.dart' show OrgateException;
import '../../l10n/l10n.dart';
import '../profile/rasq_pages.dart';

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
      if (items.length >= 8) return appL10n.customProfileLimit;
      items.add((pluginId: id, version: plugin.storeVersion));
    }
    await client.setMyPages(items);
    if (placed && plugin.manifest.page?.isShared == true) await client.create(pluginId: id, version: plugin.storeVersion, scope: 'profile');
    ref.invalidate(profileCustomPagesProvider(handle));
    return null;
  } catch (e) {
    return e is StateError ? e.message : '$e';
  }
}

/// アカウントページの「ページ」タブ (D-357 → D-446 RASQ のページ)。並び:
/// 1. ストアのカスタムプラグイン(置いたもの)。持ち主には、面 `profile.host` を宣言したものの**ホスト用ページ**も。
/// 2. Markdown ページ(公開したもの。持ち主には端末の下書きも「下書き」の印で)。
/// 3. 自作プラグイン(制限モード。訪れた人の端末では同意のうえ一時的に動かす)。
/// 持ち主は「+ 追加」(FOW): Markdown ページを書く / 自作プラグインを置く / ストアのカスタムプラグインを置く・外す。
class CustomProfilePagesTab extends ConsumerWidget {
  const CustomProfilePagesTab({super.key, required this.handle, this.accountId, required this.isMine});
  final String handle;
  final String? accountId;
  final bool isMine;

  void _refresh(WidgetRef ref) {
    ref.invalidate(profileCustomPagesProvider(handle));
    ref.invalidate(rasqMdPagesProvider(handle));
    ref.invalidate(rasqSideloadPagesProvider(handle));
  }

  /// 自作プラグインを開く: 入れ物を Central から取り、同意のうえ制限モードで一時的に動かす。
  void _openSideload(BuildContext context, WidgetRef ref, RasqSideloadPage p) {
    final api = ref.read(rasqPagesApiProvider);
    if (api == null) return;
    final args = CustomPageArgs(
      pluginId: p.pluginId,
      version: p.version,
      surface: PluginPageDecl.surfaceProfile,
      profileHandle: handle,
      profileAccountId: accountId,
      package: () => api.sideloadPackage(handle, p.id),
      packageSource: '$rasqPageSourcePrefix${p.id}',
    );
    context.push(Routes.customPage(p.pluginId, args.query), extra: args);
  }

  Future<void> _sideloadMenu(BuildContext context, WidgetRef ref, RasqSideloadPage p, Rect anchor) async {
    final l10n = context.l10n;
    final pick = await ref.read(overlayManagerProvider).showDropdown<String>(id: 'rasqPage.sideload.menu', anchor: anchor, dense: true, items: [
      RasqDropdownItem(l10n.customProfileSideloadReplace, 'replace'),
      RasqDropdownItem(l10n.customProfileSideloadRemove, 'delete', destructive: true),
    ]);
    if (pick == null || !context.mounted) return;
    if (pick == 'replace') return uploadRasqSideloadPage(context, ref, onDone: () => _refresh(ref));
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(rasqPagesApiProvider)?.deleteSideload(p.id);
      _refresh(ref);
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(l10n.customProfileRemoveFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final pages = ref.watch(profileCustomPagesProvider(handle));
    final items = pages.value ?? const <CustomProfilePage>[];
    final md = ref.watch(rasqMdPagesProvider(handle)).value ?? const <RasqMdPageInfo>[];
    final sideload = ref.watch(rasqSideloadPagesProvider(handle)).value ?? const <RasqSideloadPage>[];
    // 持ち主の下書き(まだ公開していない / 公開後に書き直しているもの)。
    final drafts = isMine ? ref.watch(rasqPageDraftsProvider) : const <String, RasqPageDraft>{};
    final unpublished = [for (final d in drafts.values) if (!md.any((m) => m.id == d.id)) d];
    // ホスト用ページ: 置いたストアのカスタムプラグインのうち、入れていて `profile.host` を宣言したもの(本人だけ)。
    final installed = isMine ? ref.watch(installedPagePluginsProvider) : const <SlotPlugin>[];
    SlotPlugin? hostOf(CustomProfilePage p) => installed.where((x) => (x.storePluginId ?? x.id) == p.pluginId && (x.manifest.page?.allows(PluginPageDecl.surfaceProfileHost) ?? false)).firstOrNull;
    final empty = items.isEmpty && md.isEmpty && sideload.isEmpty && unpublished.isEmpty;
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      if (pages.isLoading && !pages.hasValue)
        const Padding(padding: EdgeInsets.all(RasqSpacing.lg), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
      else if (empty)
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: Text(
            pages.hasError ? l10n.customLoadFailed('${pages.error}') : (isMine ? l10n.customProfileEmptyMine : l10n.customProfileEmpty),
            style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      for (final p in items) ...[
        RasqListTile(
          key: ValueKey('rasqPage.custom.${p.pluginId}'),
          leading: Icon(materialIconByName(p.icon) ?? Icons.dashboard_customize_outlined),
          title: p.name,
          subtitle: p.isShared ? (p.sessionId == null ? l10n.customProfileSharedNotStarted : l10n.customProfileShared) : l10n.customSolo,
          onTap: () => context.push(Routes.customPage(
                p.pluginId,
                CustomPageArgs(pluginId: p.pluginId, version: p.version, surface: PluginPageDecl.surfaceProfile, sessionId: p.sessionId, profileHandle: handle, profileAccountId: accountId).query,
              )),
        ),
        if (hostOf(p) case final host?)
          RasqListTile(
            key: ValueKey('rasqPage.host.${p.pluginId}'),
            leading: const Padding(padding: EdgeInsets.only(left: RasqSpacing.md), child: Icon(Icons.admin_panel_settings_outlined)),
            title: l10n.customProfileHostPage(host.manifest.page?.title ?? host.manifest.name),
            subtitle: l10n.customProfileHostPageSubtitle,
            onTap: () => context.push(Routes.customPage(
                  p.pluginId,
                  CustomPageArgs(pluginId: p.pluginId, version: p.version, surface: PluginPageDecl.surfaceProfileHost, sessionId: p.sessionId, profileHandle: handle, profileAccountId: accountId).query,
                )),
          ),
      ],
      for (final m in md)
        RasqListTile(
          key: ValueKey('rasqPage.md.${m.id}'),
          leading: const Icon(Icons.article_outlined),
          title: m.title,
          subtitle: drafts.containsKey(m.id) ? l10n.customProfileMdPageWithDraft : l10n.customProfileMdPage,
          onTap: () => context.push(Routes.rasqMdPage(handle, m.id, mine: isMine)),
        ),
      for (final d in unpublished)
        RasqListTile(
          key: ValueKey('rasqPage.draft.${d.id}'),
          leading: Icon(Icons.edit_note, color: scheme.onSurfaceVariant),
          title: d.title.isEmpty ? l10n.customProfileUntitled : d.title,
          subtitle: l10n.customProfileDraft,
          onTap: () => context.push(Routes.rasqMdPageEdit(d.id)),
        ),
      for (final p in sideload)
        Builder(
          builder: (tctx) => RasqListTile(
            key: ValueKey('rasqPage.sideload.${p.id}'),
            leading: const Icon(Icons.science_outlined),
            title: p.name,
            subtitle: l10n.customProfileSideloadSubtitle(p.version),
            onTap: () => _openSideload(context, ref, p),
            trailing: isMine
                ? RasqIconButton(
                    key: ValueKey('rasqPage.sideload.${p.id}.more'),
                    icon: Icons.more_horiz,
                    size: 18,
                    tooltip: l10n.customMenu,
                    onPressed: () {
                      final box = tctx.findRenderObject() as RenderBox;
                      _sideloadMenu(context, ref, p, box.localToGlobal(Offset.zero) & box.size);
                    },
                  )
                : null,
          ),
        ),
      if (isMine)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('rasqPage.add'),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.customProfileAdd),
              onPressed: () => showRasqPageAddFow(context, ref, handle: handle, placed: {for (final p in items) p.pluginId}, onChanged: () => _refresh(ref)),
            ),
          ),
        ),
    ]);
  }
}

/// 自作プラグインを置く (D-446): 配布物を選んで Central へ上げる(ページ型・`profile` の面・solo だけ。Central が確かめる)。
Future<void> uploadRasqSideloadPage(BuildContext context, WidgetRef ref, {required VoidCallback onDone}) async {
  final api = ref.read(rasqPagesApiProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  if (api == null) {
    messenger?.showSnackBar(SnackBar(content: Text(l10n.customProfileLoginToPlace)));
    return;
  }
  final bytes = await ref.read(rasqPagePackagePickerProvider)();
  if (bytes == null) return;
  try {
    final p = await api.uploadSideload(bytes);
    onDone();
    messenger?.showSnackBar(SnackBar(content: Text(l10n.customProfileSideloadPlaced(p.name))));
  } on OrgateException catch (e) {
    // 理由は Central の名前つきの理由(`400 not_profile_page` / `409 sideload_page_limit` / `400 invalid_package`)で見る (D-503)。
    messenger?.showSnackBar(SnackBar(content: Text(switch (e) {
      _ when e.isReason('not_profile_page', legacyText: 'not_profile_page') => l10n.customProfileSideloadErrorNotProfilePage,
      _ when e.isReason('sideload_page_limit', legacyText: 'sideload_page_limit') => l10n.customProfileSideloadErrorLimit,
      _ when e.isReason('invalid_package', legacyText: 'invalid_package') => l10n.customProfileSideloadErrorInvalidPackage,
      _ => l10n.customPlaceFailed(e.message),
    })));
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(l10n.customPlaceFailed('$e'))));
  }
}

/// 「+ 追加」の FOW (D-446、前はドロップダウン): Markdown ページを書く / 自作プラグインを置く / ストアのカスタムプラグイン(置く / 外す)。
Future<void> showRasqPageAddFow(BuildContext context, WidgetRef ref, {required String handle, required Set<String> placed, required VoidCallback onChanged}) async {
  final manager = ref.read(overlayManagerProvider);
  final l10n = context.l10n;
  const id = 'rasqPage.add.fow';
  if (manager.contains(id)) return;
  await manager.showFow<void>(
    id: id,
    spec: FowSpec(title: l10n.customProfileAddTitle, cancelText: l10n.customClose, initialHeightFactor: 0.7, maxHeightFactor: 0.9, maxWidth: 600),
    semanticsLabel: l10n.customProfileAddTitle,
    builder: (fctx, _) => Consumer(builder: (cctx, ref, _) {
      final candidates = profilePlaceablePlugins(ref.watch(installedPagePluginsProvider));
      void close() => manager.close(id);
      return ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.lg), children: [
        RasqListTile(
          key: const ValueKey('rasqPage.add.md'),
          leading: const Icon(Icons.article_outlined),
          title: l10n.customProfileAddMd,
          subtitle: l10n.customProfileAddMdSubtitle,
          onTap: () {
            close();
            context.push(Routes.rasqMdPageEdit(newRasqPageId()));
          },
        ),
        RasqListTile(
          key: const ValueKey('rasqPage.add.sideload'),
          leading: const Icon(Icons.science_outlined),
          title: l10n.customProfileAddSideload,
          subtitle: l10n.customProfileAddSideloadSubtitle,
          onTap: () {
            close();
            uploadRasqSideloadPage(context, ref, onDone: onChanged);
          },
        ),
        RasqSectionHeader(title: l10n.customProfileAddStoreSection),
        if (candidates.isEmpty)
          RasqCaption(l10n.customProfileAddStoreEmpty, padding: EdgeInsets.symmetric(horizontal: RasqSpacing.page)),
        for (final p in candidates)
          Builder(builder: (_) {
            final key = p.storePluginId ?? p.id;
            final on = placed.contains(key);
            return RasqListTile(
              key: ValueKey('rasqPage.add.store.$key'),
              leading: Icon(materialIconByName(p.manifest.page?.icon) ?? Icons.dashboard_customize_outlined),
              title: p.manifest.page?.title ?? p.manifest.name,
              subtitle: [on ? l10n.customProfileAddStorePlaced : l10n.customProfileAddStoreTapToPlace, if (p.manifest.page?.allows(PluginPageDecl.surfaceProfileHost) ?? false) l10n.customProfileAddStoreHasHostPage].join(l10n.customListSeparator),
              trailing: Icon(on ? Icons.check_circle : Icons.add_circle_outline),
              onTap: () async {
                close();
                final error = await setProfilePlugin(ref, handle: handle, plugin: p, placed: !on);
                onChanged();
                if (error != null && context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l10n.customProfileChangeFailed(error))));
              },
            );
          }),
        RasqListTile(
          key: const ValueKey('rasqPage.add.storeSearch'),
          leading: const Icon(Icons.storefront_outlined),
          title: l10n.customSearchStore,
          onTap: () {
            close();
            context.push(Routes.storeSearch());
          },
        ),
      ]);
    }),
  );
}
