import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import 'host_clips.dart';

/// 「クリップに追加」(D-032): 追加先の選択シート。ネイティブクリップ
/// (SNS 対応時のみ)とホスト横断クリップ(常時)を一つのシートに並べ、
/// 末尾に新規作成を置く。
Future<void> showAddToClipSheet(WidgetRef ref, Post post) async {
  // await 後に ref を触らない: シートが閉じる頃には呼び出し元ウィジェットが
  // 破棄されていることがある(「Looking up a deactivated widget's ancestor」)。
  final manager = ref.read(overlayManagerProvider);
  final session = ref.read(currentSnsSessionProvider);
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
    title: 'クリップに追加',
    builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
      for (final c in native)
        RasqListTile(
          title: c.name,
          subtitle: c.notesCount == null ? null : '${c.notesCount}件',
          leading: const Icon(Icons.collections_bookmark_outlined),
          onTap: () => manager.close('clip.add', result: c),
        ),
      for (final c in host)
        RasqListTile(
          title: c.name,
          subtitle: '${c.entries.length}件 ・ RASQ クリップ(SNS 横断)',
          leading: const Icon(Icons.workspaces_outlined),
          onTap: () => manager.close('clip.add', result: c),
        ),
      RasqListTile(title: '新しいクリップを作成', leading: const Icon(Icons.add), onTap: () => manager.close('clip.add', result: #create)),
      const SizedBox(height: RasqSpacing.md),
    ]),
  );
  if (picked == null) return;

  if (picked == #create) {
    await _createAndAdd(manager, session, hostStore, post);
  } else if (picked is ClipInfo) {
    await session?.addToClip(picked.id, post.id);
  } else if (picked is HostClip) {
    await hostStore.addPost(picked.id, post);
  }
}

/// 新規作成: 名前入力 → ネイティブ / RASQ(SNS 横断)の作成先を選んで追加。
Future<void> _createAndAdd(OverlayManager manager, SnsSession? session, HostClipsStore hostStore, Post post) async {
  final controller = TextEditingController();
  var toHost = session == null;
  final ok = await manager.showBottomSheet<bool>(
    id: 'clip.create',
    title: '新しいクリップ',
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'クリップ名')),
        ),
        if (session != null)
          RasqSwitchListTile(
            title: 'RASQ クリップ(SNS 横断)にする',
            subtitle: '端末に保存され、別の SNS の投稿も同じクリップへ入れられます',
            value: toHost,
            onChanged: (v) => setState(() => toHost = v),
          ),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: SizedBox(width: double.infinity, child: FilledButton(onPressed: () => manager.close('clip.create', result: true), child: const Text('作成して追加'))),
        ),
      ]),
    ),
  );
  final name = controller.text.trim();
  if (ok != true || name.isEmpty) return;
  if (toHost || session == null) {
    final clip = await hostStore.createClip(name);
    await hostStore.addPost(clip.id, post);
  } else {
    final clip = await session.createClip(name);
    await session.addToClip(clip.id, post.id);
  }
}
