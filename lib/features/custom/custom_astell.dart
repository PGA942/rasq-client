import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../plugins/slot_plugins.dart';
import '../vc/astell_models.dart';
import '../vc/astell_providers.dart';
import 'custom_client.dart';
import 'custom_models.dart';
import 'custom_page.dart';
import 'custom_plugins_screen.dart';

/// ルームにデプロイされているカスタムプラグイン(S-048、D-357)。WS の `custom` と手元の操作で取り直す。
final roomCustomSessionsProvider = FutureProvider.family<List<CustomSession>, String>((ref, roomId) async {
  ref.watch(astellCustomRevProvider);
  return ref.watch(customSessionClientProvider).list('room:$roomId');
});

/// ルームで使えるもの = 登録済みのページ型で `shared` かつ `astell` を開けるもの。
List<SlotPlugin> astellDeployablePlugins(List<SlotPlugin> pagePlugins) => [for (final p in pagePlugins) if (p.manifest.page?.allows(PluginPageDecl.surfaceAstell) == true) p];

/// ルームにデプロイ(ホスト = オーナー / モデレーター)。できたら一覧を取り直す。戻り = エラー(成功は null)。
Future<String?> deployToRoom(WidgetRef ref, {required String roomId, required String pluginId, String? version}) async {
  try {
    await ref.read(customSessionClientProvider).create(pluginId: pluginId, version: version, scope: 'room:$roomId');
    ref.read(astellCustomRevProvider.notifier).bump();
    return null;
  } catch (e) {
    return '$e';
  }
}

/// 参加者の「このプラグインを使いたい」をルームへ(共有 `kind: "plugin"`)。ホストはカードの「承認する」でデプロイする。
void proposeToRoom(WidgetRef ref, CustomPluginProposal p) => ref.read(astellSessionProvider.notifier).share('plugin', p.toPayload());

/// ルームのセッションのページを開く。
void openRoomCustomSession(BuildContext context, CustomSession s) =>
    context.push(Routes.customPage(s.pluginId, CustomPageArgs(pluginId: s.pluginId, version: s.version, surface: PluginPageDecl.surfaceAstell, sessionId: s.id, roomId: s.roomId).query));

/// 共有のカード `kind: "plugin"` を押した: デプロイ済みなら開く、ホストなら承認(デプロイ)、ほかは待つ。
Future<void> openCustomPluginShare(BuildContext context, WidgetRef ref, AstellShare share, AstellSessionState s) async {
  final p = CustomPluginProposal.fromPayload(share.payload);
  if (p == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final deployed = (await ref.read(roomCustomSessionsProvider(s.room.id).future)).where((x) => x.pluginId == p.pluginId).firstOrNull;
  if (!context.mounted) return;
  if (deployed != null) return openRoomCustomSession(context, deployed);
  if (!s.isModerator) {
    messenger?.showSnackBar(SnackBar(content: Text('「${p.name}」はホストの承認を待っています')));
    return;
  }
  final ok = await ref.read(overlayManagerProvider).showAlert(
        id: 'astell.custom.approve',
        title: '「${p.name}」をこのルームで使いますか?',
        message: '${share.displayName} さんからの提案です。承認すると、参加している全員が開けるようになります(インストールしていない人は、開くときに一時的に読み込みます)。',
        confirmText: '承認する',
        cancelText: 'やめる',
      );
  if (!ok) return;
  final error = await deployToRoom(ref, roomId: s.room.id, pluginId: p.pluginId, version: p.version);
  messenger?.showSnackBar(SnackBar(content: Text(error == null ? '「${p.name}」をルームに追加しました' : '追加できませんでした: $error')));
}

/// ルームにプラグインを足す: ホストはデプロイ、ほかは提案。候補 = 登録済みで AsTell に対応したもの。
Future<void> pickCustomPluginForRoom(BuildContext context, WidgetRef ref, AstellSessionState s, Rect anchor) async {
  final candidates = astellDeployablePlugins(ref.read(installedPagePluginsProvider));
  final pick = await ref.read(overlayManagerProvider).showDropdown<String>(id: 'astell.custom.pick', anchor: anchor, items: [
    for (final p in candidates) RasqDropdownItem(p.manifest.page?.title ?? p.manifest.name, p.storePluginId ?? p.id),
    const RasqDropdownItem('ストアで探す', '\u0000store'),
  ]);
  if (pick == null || !context.mounted) return;
  if (pick == '\u0000store') {
    context.push(Routes.storeSearch());
    return;
  }
  final p = candidates.where((x) => (x.storePluginId ?? x.id) == pick).first;
  final name = p.manifest.page?.title ?? p.manifest.name;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (s.isModerator) {
    final error = await deployToRoom(ref, roomId: s.room.id, pluginId: pick, version: p.storeVersion);
    messenger?.showSnackBar(SnackBar(content: Text(error == null ? '「$name」をルームに追加しました' : '追加できませんでした: $error')));
  } else {
    proposeToRoom(ref, CustomPluginProposal(pluginId: pick, version: p.storeVersion, name: name, icon: p.manifest.page?.icon));
    messenger?.showSnackBar(SnackBar(content: Text('「$name」を提案しました(ホストが承認すると使えます)')));
  }
}

/// ルーム FOW の「ルーム」タブの節 (D-357): デプロイされているもの(開く / ホストは閉じる)+ 足す。
class AstellCustomPluginsSection extends ConsumerWidget {
  const AstellCustomPluginsSection({super.key, required this.session});
  final AstellSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = session;
    final list = ref.watch(roomCustomSessionsProvider(s.room.id));
    final sessions = list.value ?? const <CustomSession>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (list.isLoading && !list.hasValue)
        const Padding(padding: EdgeInsets.all(RasqSpacing.sm), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
      else if (sessions.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Text(
            list.hasError ? '読み込めませんでした: ${list.error}' : 'このルームで動くプラグインはまだありません。${s.isModerator ? '下の「プラグインを追加」から足せます。' : '「プラグインを提案」でホストに頼めます。'}',
            style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      for (final x in sessions)
        RasqListTile(
          key: ValueKey('astell.custom.${x.pluginId}'),
          leading: const Icon(Icons.dashboard_customize_outlined),
          title: x.title,
          subtitle: '${x.participantCount} 人が使用中${x.ownerHandle == null ? '' : ' ・ @${x.ownerHandle} が追加'}',
          chevron: false,
          onTap: () => openRoomCustomSession(context, x),
          trailing: s.isModerator
              ? Builder(
                  builder: (bctx) => RasqIconButton(
                    key: ValueKey('astell.custom.more.${x.pluginId}'),
                    icon: Icons.more_horiz,
                    size: 20,
                    tooltip: 'メニュー',
                    onPressed: () async {
                      final box = bctx.findRenderObject() as RenderBox?;
                      final anchor = box == null ? const Rect.fromLTWH(0, 0, 1, 1) : box.localToGlobal(Offset.zero) & box.size;
                      final pick = await ref.read(overlayManagerProvider).showDropdown<String>(id: 'astell.custom.menu', anchor: anchor, items: const [
                        RasqDropdownItem('開く', 'open'),
                        RasqDropdownItem('ルームから外す', 'close', destructive: true),
                      ]);
                      if (!context.mounted) return;
                      if (pick == 'open') openRoomCustomSession(context, x);
                      if (pick == 'close') {
                        try {
                          await ref.read(customSessionClientProvider).close(x.id);
                        } catch (_) {}
                        ref.read(astellCustomRevProvider.notifier).bump();
                      }
                    },
                  ),
                )
              : null,
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Builder(
            builder: (bctx) => OutlinedButton.icon(
              key: const ValueKey('astell.custom.add'),
              icon: const Icon(Icons.add, size: 18),
              label: Text(s.isModerator ? 'プラグインを追加' : 'プラグインを提案'),
              onPressed: () {
                final box = bctx.findRenderObject() as RenderBox?;
                final anchor = box == null ? const Rect.fromLTWH(0, 0, 1, 1) : box.localToGlobal(Offset.zero) & box.size;
                pickCustomPluginForRoom(context, ref, s, anchor);
              },
            ),
          ),
        ),
      ),
    ]);
  }
}
