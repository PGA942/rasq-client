import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/rasq_account.dart';
import '../plugins/slot_plugins.dart';
import '../store/store_models.dart';
import '../vc/astell_providers.dart';
import 'custom_astell.dart';
import 'custom_client.dart';
import 'custom_models.dart';
import 'custom_page.dart';
import 'custom_plugins_screen.dart';
import 'custom_profile.dart';

/// ストアのプラグインページの「共有」(D-357、Obsidian「ストアページのインストールボタンの横に共有ボタン」):
/// 参加中の AsTell のルームへ(ホスト = デプロイ / ほか = 提案)、自分のプロフィールに置く、招待コードを作る。
Future<void> showCustomPluginShareMenu(BuildContext context, WidgetRef ref, StorePluginDetail d, Rect anchor) async {
  final installed = registeredPagePlugin(ref.read(installedPagePluginsProvider), d.id);
  final decl = installed?.manifest.page;
  final room = ref.read(astellSessionProvider);
  final handle = ref.read(orgateAccountProvider).value?.handle;
  // 入れていなければ宣言が分からない: ルームへの提案だけ(デプロイの可否は Central が確かめる)。
  final canRoom = room != null && (decl == null || decl.allows(PluginPageDecl.surfaceAstell));
  final pick = await ref.read(overlayManagerProvider).showDropdown<String>(id: 'store.custom.share', anchor: anchor, items: [
    if (canRoom) RasqDropdownItem(room.isModerator ? '「${room.room.title}」に追加' : '「${room.room.title}」で提案', 'room'),
    if (installed != null && handle != null && decl!.allows(PluginPageDecl.surfaceProfile)) const RasqDropdownItem('プロフィールに置く', 'profile'),
    if (installed != null && decl!.isShared && decl.allows(PluginPageDecl.surfacePage)) const RasqDropdownItem('みんなで使う(招待コードを作る)', 'link'),
    if (!canRoom && installed == null) const RasqDropdownItem('インストールするとプロフィールや招待で共有できます', '', enabled: false),
  ]);
  if (pick == null || pick.isEmpty || !context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  void toast(String m) => messenger?.showSnackBar(SnackBar(content: Text(m)));
  switch (pick) {
    case 'room':
      final s = room!;
      if (s.isModerator) {
        final error = await deployToRoom(ref, roomId: s.room.id, pluginId: d.id, version: installed?.storeVersion);
        toast(error == null ? '「${d.name}」をルームに追加しました' : '追加できませんでした: $error');
      } else {
        proposeToRoom(ref, CustomPluginProposal(pluginId: d.id, version: installed?.storeVersion, name: d.name, mode: decl?.mode ?? PluginPageDecl.shared, icon: decl?.icon));
        toast('「${d.name}」をルームで提案しました');
      }
    case 'profile':
      final error = await setProfilePlugin(ref, handle: handle!, plugin: installed!, placed: true);
      toast(error == null ? 'プロフィールに置きました' : '置けませんでした: $error');
    case 'link':
      try {
        final s = await ref.read(customSessionClientProvider).create(pluginId: d.id, version: installed!.storeVersion, scope: 'link');
        if (context.mounted) context.push(Routes.customPage(d.id, CustomPageArgs(pluginId: d.id, version: s.version, sessionId: s.id).query));
      } catch (e) {
        toast('作れませんでした: $e');
      }
  }
}
