import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import 'host_clips.dart';
import '../../l10n/l10n.dart';

/// 「クリップに追加」(D-032): 追加先の選択シート。ネイティブクリップ
/// (SNS 対応時のみ)とホスト横断クリップ(常時)を一つのシートに並べ、
/// 末尾に新規作成を置く。
/// [session] = ネイティブクリップを引くセッション(投稿詳細のブックマークの長押し D-342 は、その投稿のアカウントのもの)。
/// 省略時は現在のアカウント。すでに入っている RASQ クリップは「追加済み」で押せない。
Future<void> showAddToClipSheet(WidgetRef ref, Post post, {SnsSession? session}) async {
  // await 後に ref を触らない: シートが閉じる頃には呼び出し元ウィジェットが
  // 破棄されていることがある(「Looking up a deactivated widget's ancestor」)。
  final manager = ref.read(overlayManagerProvider);
  session ??= ref.read(currentSnsSessionProvider);
  final messenger = ref.read(rootMessengerKeyProvider).currentState;
  final hostStore = ref.read(hostClipsProvider.notifier);
  final hostClips = ref.read(hostClipsProvider).value ?? const <HostClip>[];
  List<ClipInfo> native = const [];
  if (session != null) {
    try {
      native = await session.clips();
    } on UnsupportedError {
      native = const [];
    } catch (_) {
      native = const [];
    }
  }
  final host = hostClips;

  final picked = await manager.showBottomSheet<Object>(
    id: 'clip.add',
    title: appL10n.clipsAddTitle,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      for (final c in native)
        RasqListTile(
          title: c.name,
          subtitle: c.notesCount == null ? null : ctx.l10n.clipsPostCount(c.notesCount!),
          leading: const Icon(Icons.collections_bookmark_outlined),
          onTap: () => manager.close('clip.add', result: c),
        ),
      for (final c in host)
        if (c.entries.any((e) => e.postKey == post.key))
          RasqListTile(
            key: ValueKey('clip.add.host.${c.id}'),
            title: c.name,
            subtitle: c.isPublished ? ctx.l10n.clipsAddAddedHostPublished : ctx.l10n.clipsAddAddedHost,
            leading: const Icon(Icons.workspaces_outlined),
            trailing: const Icon(Icons.check, size: 18),
          )
        else
          RasqListTile(
            key: ValueKey('clip.add.host.${c.id}'),
            title: c.name,
            subtitle: c.isPublished ? ctx.l10n.clipsAddHostRowPublished(c.entries.length) : ctx.l10n.clipsAddHostRow(c.entries.length),
            leading: const Icon(Icons.workspaces_outlined),
            onTap: () => manager.close('clip.add', result: c),
          ),
      RasqListTile(title: ctx.l10n.clipsAddCreate, leading: const Icon(Icons.add), onTap: () => manager.close('clip.add', result: #create)),
      const SizedBox(height: RasqSpacing.md),
    ]),
  );
  if (picked == null) return;

  try {
    if (picked == #create) {
      final name = await _createAndAdd(manager, session, hostStore, post);
      if (name != null) messenger?.showSnackBar(SnackBar(content: Text(appL10n.clipsAdded(name))));
    } else if (picked is ClipInfo) {
      await session?.addToClip(picked.id, post.id);
      messenger?.showSnackBar(SnackBar(content: Text(appL10n.clipsAdded(picked.name))));
    } else if (picked is HostClip) {
      await hostStore.addPost(picked.id, post);
      messenger?.showSnackBar(SnackBar(content: Text(appL10n.clipsAdded(picked.name))));
    }
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(appL10n.clipsAddFailed(e is StateError ? e.message : '$e'))));
  }
}

/// 新規作成: 名前 + 説明文(任意)→ ネイティブ / RASQ(SNS 横断)の作成先を
/// 選んで追加。説明文はクリップページのヘッダー(EventStyleHeader)に出る。
Future<String?> _createAndAdd(OverlayManager manager, SnsSession? session, HostClipsStore hostStore, Post post) async {
  final controller = TextEditingController();
  final descController = TextEditingController();
  var toHost = session == null;
  final ok = await manager.showBottomSheet<bool>(
    id: 'clip.create',
    title: appL10n.clipsCreateTitle,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: context.l10n.clipsCreateNameHint)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: TextField(controller: descController, maxLines: 2, minLines: 1, decoration: InputDecoration(hintText: context.l10n.clipsCreateDescriptionHint)),
        ),
        if (session != null)
          RasqSwitchListTile(
            title: context.l10n.clipsCreateHost,
            subtitle: context.l10n.clipsCreateHostSubtitle,
            value: toHost,
            onChanged: (v) => setState(() => toHost = v),
          ),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: SizedBox(width: double.infinity, child: FilledButton(onPressed: () => manager.close('clip.create', result: true), child: Text(context.l10n.clipsCreateAndAdd))),
        ),
      ]),
    ),
  );
  final name = controller.text.trim();
  final description = descController.text.trim().isEmpty ? null : descController.text.trim();
  if (ok != true || name.isEmpty) return null;
  if (toHost || session == null) {
    final clip = await hostStore.createClip(name, description: description);
    await hostStore.addPost(clip.id, post);
  } else {
    final clip = await session.createClip(name, description: description);
    await session.addToClip(clip.id, post.id);
  }
  return name;
}
