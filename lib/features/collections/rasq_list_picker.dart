import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show TimelineKind;

import '../../app/providers.dart';
import '../../backend/rasq_collections_api.dart';
import '../home/timeline_providers.dart';
import '../nodeprog/tl_components.dart';
import '../nodeprog/tl_config_store.dart';
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import 'rasq_collections.dart';

/// RASQ リストを選ぶ / 取り込む (D-346/D-347)。タイムラインの取り込み元に選べるのは、**リスト内の人の情報を取れる**
/// (`canFetch`: 作った人 / 入っているサーバーのアカウントがある / 入っている人をフォローしている、Central S-044)リストだけ。

/// 候補: 語が空 = 自分のリスト + フォロー中のリスト、語があれば公開リストの検索(名前 / 説明 / `@handle` / 共有 URL・コード)。
final rasqListCandidatesProvider = FutureProvider.autoDispose.family<List<RasqCollection>, String>((ref, query) async {
  final api = ref.watch(rasqCollectionsApiProvider);
  if (api == null || !ref.watch(hasRasqAccountProvider)) return const [];
  final q = query.trim();
  try {
    if (q.isEmpty) {
      final mine = await ref.watch(myRasqCollectionsProvider(RasqCollectionKind.list).future);
      final following = await ref.watch(followingRasqCollectionsProvider.future);
      return [...mine, for (final c in following) if (c.kind == RasqCollectionKind.list && !mine.any((m) => m.id == c.id)) c];
    }
    return await api.search(q);
  } catch (e) {
    debugPrint('rasq list search: $e');
    return const [];
  }
});

/// 取れないときの説明。
const rasqListNotFetchableHint = 'リスト内の人の情報を取れるアカウントがありません(入っている人と同じサーバーのアカウントか、入っている人のフォローが要ります)';

/// 選べるか確かめる。一覧で確かめていない(`canFetchChecked: false`)なら詳細を引いて確かめる。
/// 選べるなら、作った人でもフォロー中でもないリストは**フォローする**(見たときに新しくなる = 取り直しの資格、S-042)。
/// 戻り値 = (選べたリスト, だめな理由)。RAi の関数 (D-348) からも使う。
Future<(RasqCollection?, String?)> checkRasqListFetchable(ProviderContainer c, RasqCollection list) async {
  final api = c.read(rasqCollectionsApiProvider);
  if (api == null) return (null, 'RASQ アカウントのサーバーが設定されていません');
  try {
    var ok = list.isOwner || list.canFetch == true;
    var following = list.following;
    if (!ok && (!list.canFetchChecked || list.canFetch == null)) {
      // `refresh=false` では「入っている人をフォローしている」をネットワークで確かめないので、ふつうの詳細を引く
      // (取り直しは、資格 = フォロー中の人にしか起きない)。
      final d = await api.get(list.code ?? list.id);
      ok = d.isOwner || d.canFetch;
      following = d.following;
    }
    if (!ok) return (null, rasqListNotFetchableHint);
    if (!list.isOwner && !following) {
      await api.follow(list.id, on: true);
      c.invalidate(myRasqCollectionsProvider);
      c.invalidate(followingRasqCollectionsProvider);
    }
    return (list, null);
  } catch (e) {
    return (null, '確かめられませんでした: $e');
  }
}

/// [checkRasqListFetchable] の画面版(だめな理由はスナックバー)。
Future<RasqCollection?> ensureRasqListFetchable(WidgetRef ref, RasqCollection list) async {
  final messenger = ref.read(rootMessengerKeyProvider).currentState;
  final (ok, reason) = await checkRasqListFetchable(ProviderScope.containerOf(ref.context), list);
  if (reason != null) {
    messenger?.clearSnackBars();
    messenger?.showSnackBar(SnackBar(content: Text(reason)));
  }
  return ok;
}

/// 候補の列(TL カスタマイズの「ノードを設定」FOW / リストのインポート)。[trailing] を渡すと行の右に置く(インポートの「取り込む」)。
class RasqListCandidates extends ConsumerWidget {
  const RasqListCandidates({super.key, required this.query, this.selectedId, this.onPick, this.onOpen, this.trailing, this.emptyText});
  final String query;
  final String? selectedId;
  final ValueChanged<RasqCollection>? onPick;

  /// 行のタップ([onPick] が無いとき。インポートではリストのページへ)。
  final ValueChanged<RasqCollection>? onOpen;
  final Widget Function(RasqCollection c)? trailing;
  final String? emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final res = ref.watch(rasqListCandidatesProvider(query));
    return res.when(
      loading: () => const Padding(padding: EdgeInsets.all(RasqSpacing.page), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) => Column(mainAxisSize: MainAxisSize.min, children: [
        if (items.isEmpty) Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(emptyText ?? (query.trim().isEmpty ? 'RASQ リストはまだありません' : '見つかりません'), style: RasqTypography.caption)),
        for (final c in items)
          Opacity(
            opacity: c.canFetch == false && c.canFetchChecked ? 0.5 : 1,
            child: RasqListTile(
              key: ValueKey('rasqList.pick.${c.id}'),
              title: c.name,
              subtitle: [
                '${c.itemCount}人',
                if (!c.isOwner) '@${c.owner.handle}',
                if (c.isOwner) '自分のリスト' else if (c.following) 'フォロー中',
                if (c.canFetch == false && c.canFetchChecked) '取れません',
              ].join(' ・ '),
              leading: onPick == null ? const Icon(Icons.people_alt_outlined, size: 20) : Icon(selectedId == c.id ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: selectedId == c.id ? scheme.primary : null),
              trailing: trailing?.call(c),
              chevron: false,
              onTap: onPick != null ? () => onPick!(c) : (onOpen == null ? null : () => onOpen!(c)),
            ),
          ),
      ]),
    );
  }
}

/// 「タイムラインに取り込む」(D-347): ホームの TL カスタマイズの取り込み元に RASQ リストを足す(カスタムフィードの取り込み D-227 と同じ保存先)。
/// 取れないリストは足さない。作った人でもフォロー中でもなければ、フォローもする。戻り値 = 伝える文と、足したか。RAi の関数 (D-348) からも使う。
Future<(String, bool)> importRasqListToHomeWith(ProviderContainer c, RasqCollection list) async {
  final acc = c.read(currentAccountProvider);
  if (acc == null) return ('ログインしていません', false);
  final (ok, reason) = await checkRasqListFetchable(c, list);
  if (ok == null) return ('「${list.name}」は取り込めません(${reason ?? rasqListNotFetchableHint})', false);
  final added = await addTlSource(c, acc.key, 'tl.home', TlSourceComponent(tl: '$rasqListKindPrefix${list.id}', label: list.name));
  if (!added) return ('「${list.name}」はもうホームのタイムラインに入っています', false);
  c.invalidate(timelineProvider(TimelineKind.home));
  return ('「${list.name}」をホームのタイムラインに取り込みました(タブ行の歯車で確認できます)', true);
}

/// [importRasqListToHomeWith] の画面版。
Future<String> importRasqListToHome(WidgetRef ref, RasqCollection list) async => (await importRasqListToHomeWith(ProviderScope.containerOf(ref.context), list)).$1;
