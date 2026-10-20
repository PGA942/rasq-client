import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../backend/rasq_account.dart' show orgateAccountProvider;
import '../../backend/rasq_collections_api.dart';
import '../../l10n/l10n.dart';
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;

/// RASQ リスト / 公開した RASQ クリップ (D-343/D-344) のプロバイダーと、追加 / 作成のシート。

/// RASQ アカウントに入っているか(RASQ リストを作る / フォローするのに要る)。
final hasRasqAccountProvider = Provider<bool>((ref) => ref.watch(orgateAccountProvider).value != null && ref.watch(rasqCollectionsApiProvider) != null);

/// 自分のコレクション(種類ごと)。Central が無い / 未ログインなら空。
final myRasqCollectionsProvider = FutureProvider.family<List<RasqCollection>, RasqCollectionKind>((ref, kind) async {
  final api = ref.watch(rasqCollectionsApiProvider);
  if (api == null || !ref.watch(hasRasqAccountProvider)) return const [];
  try {
    return await api.mine(kind);
  } catch (e) {
    debugPrint('rasq collections: $e');
    return const [];
  }
});

/// フォローしているコレクション。
final followingRasqCollectionsProvider = FutureProvider<List<RasqCollection>>((ref) async {
  final api = ref.watch(rasqCollectionsApiProvider);
  if (api == null || !ref.watch(hasRasqAccountProvider)) return const [];
  try {
    return await api.following();
  } catch (e) {
    debugPrint('rasq collections following: $e');
    return const [];
  }
});

/// RASQ アカウントの公開コレクション(アカウントページのタブ)。
final accountRasqCollectionsProvider = FutureProvider.autoDispose.family<List<RasqCollection>, ({String handle, RasqCollectionKind kind})>((ref, k) async {
  final api = ref.watch(rasqCollectionsApiProvider);
  if (api == null) return const [];
  return api.ofAccount(k.handle, k.kind);
});

/// 詳細(ページを開いたとき)。資格のある人なら、Central がこの読み込みで取り直す。
final rasqCollectionProvider = FutureProvider.autoDispose.family<RasqCollectionDetail, String>((ref, idOrCode) async {
  final api = ref.watch(rasqCollectionsApiProvider);
  if (api == null) throw StateError(appL10n.collectionsNoServer);
  return api.get(idOrCode);
});

/// 概要だけ(投稿に埋めたタイル)。**取り直さない**(`refresh=false`)— TL を流しただけで SNS を叩かないように。
final rasqCollectionSummaryProvider = FutureProvider.autoDispose.family<RasqCollection?, String>((ref, idOrCode) async {
  final api = ref.watch(rasqCollectionsApiProvider);
  if (api == null) return null;
  try {
    return (await api.get(idOrCode, refresh: false)).collection;
  } catch (_) {
    return null;
  }
});

/// 一覧の読み直し(作成 / 削除 / フォローのあと)。
void invalidateRasqCollections(WidgetRef ref) {
  ref.invalidate(myRasqCollectionsProvider);
  ref.invalidate(followingRasqCollectionsProvider);
}

/// 新しい RASQ リスト: 名前 + 説明(任意)+ 公開するか。作ったものを返す(やめたら null)。
Future<RasqCollection?> showCreateRasqListSheet(WidgetRef ref) async {
  final manager = ref.read(overlayManagerProvider);
  final api = ref.read(rasqCollectionsApiProvider);
  final messenger = ref.read(rootMessengerKeyProvider).currentState;
  if (api == null) {
    messenger?.showSnackBar(SnackBar(content: Text(appL10n.collectionsCreateNeedsAccount)));
    return null;
  }
  final name = TextEditingController();
  final desc = TextEditingController();
  var isPublic = false;
  final ok = await manager.showBottomSheet<bool>(
    id: 'rasqList.create',
    title: appL10n.collectionsCreateTitle,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: TextField(key: const ValueKey('rasqList.create.name'), controller: name, autofocus: true, maxLength: 60, decoration: InputDecoration(hintText: context.l10n.collectionsListNameHint)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: TextField(controller: desc, maxLines: 2, minLines: 1, maxLength: 500, decoration: InputDecoration(hintText: context.l10n.collectionsDescriptionHint)),
        ),
        RasqSwitchListTile(
          key: const ValueKey('rasqList.create.public'),
          title: context.l10n.collectionsPublishSwitch,
          subtitle: context.l10n.collectionsPublishSwitchSubtitle,
          value: isPublic,
          onChanged: (v) => setState(() => isPublic = v),
        ),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(key: const ValueKey('rasqList.create.ok'), onPressed: () => manager.close('rasqList.create', result: true), child: Text(context.l10n.collectionsCreateButton)),
          ),
        ),
      ]),
    ),
  );
  final n = name.text.trim();
  if (ok != true || n.isEmpty) return null;
  try {
    final c = await api.create(RasqCollectionKind.list, n, description: desc.text.trim().isEmpty ? null : desc.text.trim(), isPublic: isPublic);
    ref.invalidate(myRasqCollectionsProvider(RasqCollectionKind.list));
    return c;
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(appL10n.collectionsCreateFailed(e is StateError ? e.message : '$e'))));
    return null;
  }
}

/// ユーザーを RASQ リストに足す (D-343)。[via] = このユーザーを見ているアカウント(id はそのサーバーのもの)。
/// 自分のリストを並べ、末尾に「新しいリストを作成」。
Future<void> showAddToRasqListSheet(WidgetRef ref, UserSummary user, {required AccountId via}) async {
  final manager = ref.read(overlayManagerProvider);
  final api = ref.read(rasqCollectionsApiProvider);
  final messenger = ref.read(rootMessengerKeyProvider).currentState;
  if (api == null) {
    messenger?.showSnackBar(SnackBar(content: Text(appL10n.collectionsUseNeedsAccount)));
    return;
  }
  List<RasqCollection> lists;
  try {
    lists = await api.mine(RasqCollectionKind.list);
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(appL10n.collectionsLoadListsFailed(e is StateError ? e.message : '$e'))));
    return;
  }
  final picked = await manager.showBottomSheet<Object>(
    id: 'rasqList.add',
    title: appL10n.collectionsAddToListTitle,
    builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
      for (final l in lists)
        RasqListTile(
          key: ValueKey('rasqList.add.${l.id}'),
          title: l.name,
          subtitle: l.isPublic ? appL10n.collectionsAddToListSubtitlePublic(l.itemCount) : appL10n.collectionsAddToListSubtitlePrivate(l.itemCount),
          leading: const Icon(Icons.people_alt_outlined),
          onTap: () => manager.close('rasqList.add', result: l),
        ),
      RasqListTile(key: const ValueKey('rasqList.add.create'), title: appL10n.collectionsCreateNewList, leading: const Icon(Icons.add), onTap: () => manager.close('rasqList.add', result: #create)),
      const SizedBox(height: RasqSpacing.md),
    ]),
  );
  if (picked == null) return;
  final target = picked == #create ? await showCreateRasqListSheet(ref) : picked as RasqCollection;
  if (target == null) return;
  try {
    final added = await addRasqListMember(api, target.id, user, via: via);
    messenger?.clearSnackBars();
    messenger?.showSnackBar(SnackBar(content: Text(added ? appL10n.collectionsAddedTo(target.name) : appL10n.collectionsAlreadyIn(target.name))));
    ref.invalidate(myRasqCollectionsProvider(RasqCollectionKind.list));
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(appL10n.collectionsAddFailed(e is StateError ? e.message : '$e'))));
  }
}

/// 読んで(取り直さずに)1 人足して置き換える。入っていたら false。
Future<bool> addRasqListMember(RasqCollectionsApi api, String id, UserSummary user, {required AccountId via}) async {
  final detail = await api.get(id, refresh: false);
  final item = RasqCollectionItem.member(user, via: via);
  if (detail.items.any((i) => i.key == item.key)) return false;
  await api.putItems(id, [for (final i in detail.items) i.toJson(), item.toJson()]);
  return true;
}

/// 1 人外す(作った人だけ)。
Future<void> removeRasqListMember(RasqCollectionsApi api, String id, String key) async {
  final detail = await api.get(id, refresh: false);
  await api.putItems(id, [for (final i in detail.items) if (i.key != key) i.toJson()]);
}
