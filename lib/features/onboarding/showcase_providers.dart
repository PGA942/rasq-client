import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/rasq_collections_api.dart';
import '../../backend/server_info_api.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../rai/rai_embedding_model.dart';
import 'showcase_genres.dart';

/// オンボーディングのタイルの見本の投稿 (D-412)。
///
/// **どこで選ぶか**: 公開の投稿を取ってきて、出してはいけないもの(返信 / CW / センシティブ / ボット / 連合先 / メンション …)を落とし、
/// 強い順に並べるのは **Central**(S-072 `GET /servers/{host}/showcase`、トークン無し・サーバーごとに 15 分、全員で 1 回の取得を分け合う)。
/// **ジャンルの判定と最後の 3 件の選び**は**端末**(RASQ MiniLM が入っていればそれ、無ければ語の辞書)。Central にはモデルを
/// 回す仕組みが無く、MiniLM は端末で RAi の検索と共用しているため。見守り (D-307) の判定も端末で重ねる。

/// ジャンルの判定(RASQ MiniLM が端末に入っているときだけモデルを使う。ダウンロードは促さない)。
final showcaseClassifierProvider = FutureProvider<ShowcaseGenreClassifier>((ref) async {
  final st = ref.watch(raiEmbeddingStatusProvider).value;
  if (st != null && st.ready) {
    try {
      final e = await ref.watch(raiEmbeddingModelProvider).embedder();
      if (e != null && ShowcaseGenreClassifier.isRasqMiniLm(e)) return ShowcaseGenreClassifier(embedder: e);
    } catch (e) {
      debugPrint('showcase classifier: $e');
    }
  }
  return ShowcaseGenreClassifier();
});

/// 1 枚のタイルに出す見本の数。
const showcasePostsPerTile = 3;

/// サーバーの見本の投稿(選んだ 3 件まで。取れない = 空)。
final serverShowcasePicksProvider = FutureProvider.family<List<ShowcasePick>, String>((ref, host) async {
  final showcase = await ref.watch(serverShowcaseProvider(host).future);
  if (showcase == null || showcase.posts.isEmpty) return const [];
  final classifier = await ref.watch(showcaseClassifierProvider.future);
  return selectShowcasePosts(showcase.posts, classifier, max: showcasePostsPerTile, gate: ref.watch(childGateProvider));
});

/// オンボーディングに出す RASQ リスト: 公開リストの人気順(Central の検索、匿名で読める)から、人のいるもの・見守りで隠れないものを 4 つまで。
final onboardingRasqListsProvider = FutureProvider<List<RasqCollection>>((ref) async {
  final api = ref.watch(rasqCollectionsApiProvider);
  if (api == null) return const [];
  final gate = ref.watch(childGateProvider);
  try {
    final found = await api.search('', kind: RasqCollectionKind.list, limit: 8);
    return [
      for (final c in found)
        if (c.isPublic && c.itemCount > 0 && !gate.collectionHidden('${c.name}\n${c.description ?? ''}')) c,
    ].take(4).toList();
  } catch (e) {
    debugPrint('onboarding lists: $e');
    return const [];
  }
});

/// RASQ リストの見本の投稿: 公開のスナップショット(`refresh=false` = SNS を叩かない)から、サーバーと同じ選び方で 3 件まで。
/// 強さはスナップショットの数(リアクション / リノート / 返信)から。
final rasqListShowcasePicksProvider = FutureProvider.family<List<ShowcasePick>, String>((ref, id) async {
  final api = ref.watch(rasqCollectionsApiProvider);
  if (api == null) return const [];
  try {
    final detail = await api.get(id, refresh: false);
    final members = {for (final i in detail.items) i.key: i};
    final candidates = [
      for (final p in detail.posts)
        () {
          final post = p.toPost(members[p.memberKey]);
          final n = [...post.counts.values, ...post.reactions.values].fold<int>(0, (a, b) => a + b);
          return ShowcaseCandidate(post: post, score: math.log(1 + n), source: 'list');
        }(),
    ];
    final classifier = await ref.watch(showcaseClassifierProvider.future);
    return await selectShowcasePosts(candidates, classifier, max: showcasePostsPerTile, gate: ref.watch(childGateProvider));
  } catch (e) {
    debugPrint('list showcase $id: $e');
    return const [];
  }
});
