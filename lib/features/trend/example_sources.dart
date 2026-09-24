import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../plugins/slot_plugins.dart';
import '../store/store_models.dart';
import '../store/store_providers.dart' show installedPluginsProvider, storeClientProvider;
import 'example_match.dart';
import 'example_picker.dart';
import 'genre_topics.dart';

/// 例から選ぶ (D-314) の候補の出どころ: 最近のアクション / 入れているプラグイン / クリップ / リスト / ストアの掲載。
/// 自分のトレンドは前の 4 つ、保護者の設定はストアも足す(保護者自身のものから選ぶ)。

/// クリップ / リストは、先頭の何件の中身を読むか(読むのは最初の [_collectionLimit] 個だけ)。
const _collectionPosts = 5;
const _collectionLimit = 12;

String _postText(Post p) => '${p.body} ${p.quote?.body ?? ''}';

/// クリップ / リストの名前 + 説明。
String collectionMetaText(String name, String? description) => '$name ${description ?? ''}'.trim();

/// 投稿の話題(`topicsOf`)を候補に。
ExampleCandidate topicCandidate(GenreTopic t) => ExampleCandidate(
      example: ContentExample(kind: ExampleKind.post, ref: t.representative.key, text: exampleTextOf([for (final p in t.posts.take(3)) _postText(p)])),
      posts: t.posts,
      genres: t.genres,
    );

ExampleCandidate pluginCandidate({required String id, required String name, String description = '', List<String> slots = const []}) => ExampleCandidate(
      example: ContentExample(kind: ExampleKind.plugin, ref: id, text: exampleTextOf(pluginExamplePieces(name: name, description: description, slots: slots))),
      title: name.isEmpty ? id : name,
      subtitle: description,
      tags: slots,
    );

ExampleCandidate collectionCandidate({required ExampleKind kind, required String id, required String name, String? description, List<Post> posts = const []}) => ExampleCandidate(
      example: ContentExample(kind: kind, ref: id, text: exampleTextOf([collectionMetaText(name, description), for (final p in posts) _postText(p)])),
      title: name,
      subtitle: description,
      posts: posts,
    );

/// 最近のアクション(リアクションした投稿を類似話題でまとめたもの)。
Future<List<ExampleCandidate>> recentActionCandidates(WidgetRef ref) async {
  final session = ref.read(currentSnsSessionProvider);
  if (session == null) return const [];
  final reacted = (await session.reactedPosts(limit: 40)).items;
  return [for (final t in topicsOf(reacted, top: reacted.length)) topicCandidate(t)];
}

/// 入れているプラグイン: スロットプラグイン(マニフェスト)+ ストアから入れた(スロットでない)もの。
List<ExampleCandidate> installedPluginCandidates(WidgetRef ref) {
  final slots = ref.read(slotPluginsProvider);
  final seen = <String>{};
  return [
    for (final p in slots)
      if (seen.add(p.id)) pluginCandidate(id: p.id, name: p.manifest.name, description: p.manifest.description, slots: p.manifest.slots),
    for (final ip in ref.read(installedPluginsProvider))
      if (seen.add(ip.id)) pluginCandidate(id: ip.id, name: ip.name, description: [ip.info?.summary ?? '', ip.info?.description ?? ''].where((s) => s.isNotEmpty).join(' ')),
  ];
}

/// 対応していない SNS(`UnsupportedError`)は空。
Future<List<T>> _orEmpty<T>(Future<List<T>> Function() f) async {
  try {
    return await f();
  } on UnsupportedError {
    return const [];
  }
}

Future<List<Post>> _firstPosts(Future<Page<Post>> Function() f) async {
  try {
    return (await f()).items.take(_collectionPosts).toList();
  } catch (_) {
    return const []; // 読めなければ名前と説明だけで比べる
  }
}

/// 自分のクリップ(含まれる投稿の先頭つき)。
Future<List<ExampleCandidate>> clipCandidates(WidgetRef ref) async {
  final session = ref.read(currentSnsSessionProvider);
  if (session == null) return const [];
  final clips = await _orEmpty(session.clips);
  return Future.wait([
    for (final c in clips.take(_collectionLimit))
      _firstPosts(() => session.clipNotes(c.id, limit: _collectionPosts)).then((posts) => collectionCandidate(kind: ExampleKind.clip, id: c.id, name: c.name, description: c.description, posts: posts)),
  ]);
}

/// 自分のリスト(リストのタイムラインの先頭つき)。
Future<List<ExampleCandidate>> listCandidates(WidgetRef ref) async {
  final session = ref.read(currentSnsSessionProvider);
  if (session == null) return const [];
  final lists = await _orEmpty(session.lists);
  return Future.wait([
    for (final l in lists.take(_collectionLimit))
      _firstPosts(() => session.timeline(TimelineKind.list(l.id, l.name), limit: _collectionPosts)).then((posts) => collectionCandidate(kind: ExampleKind.list, id: l.id, name: l.name, description: l.description, posts: posts)),
  ]);
}

/// ストアの掲載(検索。空なら一覧)。
Future<List<ExampleCandidate>> storeCandidates(WidgetRef ref, String query) async {
  final cards = await ref.read(storeClientProvider).search(query);
  return [for (final StorePluginCard c in cards.take(30)) pluginCandidate(id: c.id, name: c.name, description: c.summary)];
}

/// 自分の出どころ(最近のアクション / プラグイン / クリップ / リスト)。[recent] は開く前に読んだ最近のアクション。
List<ExampleSource> ownExampleSources(WidgetRef ref, {List<ExampleCandidate>? recent}) => [
      ExampleSource(
        id: 'actions',
        label: '最近のアクション',
        load: (_) => recentActionCandidates(ref),
        preloaded: recent,
        emptyTitle: '最近のアクションがありません',
        emptyHint: 'リアクションやブックマークをすると、ここから選べます',
      ),
      ExampleSource(id: 'plugins', label: 'プラグイン', load: (_) async => installedPluginCandidates(ref), emptyTitle: '入れているプラグインはありません'),
      ExampleSource(id: 'clips', label: 'クリップ', load: (_) => clipCandidates(ref), emptyTitle: 'クリップはありません'),
      ExampleSource(id: 'lists', label: 'リスト', load: (_) => listCandidates(ref), emptyTitle: 'リストはありません'),
    ];

/// ストアの出どころ(保護者の設定)。
ExampleSource storeExampleSource(WidgetRef ref) =>
    ExampleSource(id: 'store', label: 'ストア', load: (q) => storeCandidates(ref, q), searchHint: 'ストアを探す(空 = 一覧)', emptyTitle: '見つかりませんでした');
