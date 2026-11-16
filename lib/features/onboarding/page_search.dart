import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../backend/link_match_api.dart' show isRateLimited;
import '../../backend/onboarding_discover_api.dart';
import '../../backend/rasq_account_page_api.dart' show RasqAccountPost, RasqPostAuthor;

/// 「この画面を探す」(D-552) の、囲みと検索の中身(画面は `page_search_screen.dart`)。
///
/// 囲みごとに、**文字**(囲みの中のページの文字。直せる)か **画像**(囲みを切り抜いて、クラウドの RAi の視覚で言葉にする)で探す。
/// 画像は重いので **1 回に [pageSearchMaxImages] 枚まで**、同時に送るのも同じ数まで(Central の側にも同時の上限がある、S-129)。
/// 探す先: RASQ のユーザー(`/accounts/search`)と投稿(`/search/posts`)、RASQ リストとサーバー(`/onboarding/discover/content`)。

/// 1 回の検索で、画像で探せる囲みの数(同時に送る数でもある)。
const pageSearchMaxImages = 3;

/// 囲みの数の上限。
const pageSearchMaxRegions = 8;

/// 検索の言葉の数の上限(1 つの言葉ごとにユーザーと投稿を引く)。
const pageSearchMaxTerms = 8;

/// 囲み 1 つ。[rect] はページの座標(CSS の画素)。
@immutable
class PageRegion {
  const PageRegion({required this.id, required this.rect, this.query = '', this.byImage = false, this.edited});
  final int id;
  final ui.Rect rect;

  /// 検索文字列(文字で探すとき)。はじめは囲みの中のページの文字。
  final String query;

  /// 画像で探す。
  final bool byImage;

  /// 画像エディターで直した画像(あれば、切り抜きの代わりにこれを送る)。
  final Uint8List? edited;

  PageRegion copyWith({ui.Rect? rect, String? query, bool? byImage, Uint8List? edited, bool clearEdited = false}) =>
      PageRegion(id: id, rect: rect ?? this.rect, query: query ?? this.query, byImage: byImage ?? this.byImage, edited: clearEdited ? null : (edited ?? this.edited));

  /// 探せる状態か(文字なら検索文字列が要る)。
  bool get searchable => byImage || query.trim().isNotEmpty;
}

/// 検索に渡すもの 1 つ(文字か画像)。
@immutable
class PageSearchInput {
  const PageSearchInput.text(this.text) : image = null;
  const PageSearchInput.image(Uint8List this.image) : text = '';
  final String text;
  final Uint8List? image;
}

@immutable
class PageSearchOutcome {
  const PageSearchOutcome({this.accounts = const [], this.posts = const [], this.lists = const [], this.servers = const [], this.terms = const [], this.dummy = false, this.failedImages = 0});
  final List<RasqPostAuthor> accounts;
  final List<RasqAccountPost> posts;
  final List<ListHit> lists;
  final List<ServerHit> servers;

  /// 探した言葉(画面に出す)。
  final List<String> terms;

  /// Central の外のサービスが未設定で、見本の結果が混ざっている。
  final bool dummy;

  /// 言葉にできなかった画像の数。
  final int failedImages;

  bool get isEmpty => accounts.isEmpty && posts.isEmpty && lists.isEmpty && servers.isEmpty;
}

/// 文字 / 画像 / URL → リスト・サーバー・探す言葉(`POST /onboarding/discover/content`)。
typedef PageContentSearch = Future<ContentDiscoverResult> Function({List<List<int>> frames, String? text, Uri? url});

final _handle = RegExp(r'@([A-Za-z0-9_]{2,30})');

/// 文字の検索文字列 → 探す言葉(そのもの + 中の @ハンドル)。
List<String> pageSearchTermsOfText(String text) {
  final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return const [];
  return [t.runes.length <= 64 ? t : String.fromCharCodes(t.runes.take(64)), for (final m in _handle.allMatches(t)) m.group(1)!];
}

/// RAi が画像から作った言葉 → 探す言葉(キーワード 3 つまで + 短ければ文も)。
List<String> pageSearchTermsOfQuery(DiscoverQuery q) => [
      ...q.keywords.where((k) => k.trim().isNotEmpty).take(3),
      if (q.text.trim().isNotEmpty && q.text.trim().runes.length <= 30) q.text.trim(),
    ];

/// 同時に [limit] 個まで走らせる(順番は保つ)。
Future<List<T>> runLimited<T>(List<Future<T> Function()> tasks, int limit) async {
  final out = List<T?>.filled(tasks.length, null);
  var next = 0;
  Future<void> worker() async {
    while (next < tasks.length) {
      final i = next++;
      out[i] = await tasks[i]();
    }
  }

  await Future.wait([for (var i = 0; i < limit && i < tasks.length; i++) worker()]);
  return out.cast<T>();
}

/// 囲みを探す。画像は [maxImages] 枚まで(超えた分は探さない)、同時に送るのも [maxImages] まで。回数 / 同時の上限(429)は少し待って送り直す。
Future<PageSearchOutcome> runPageSearch({
  required List<PageSearchInput> inputs,
  Uri? url,
  required PageContentSearch content,
  required Future<List<RasqPostAuthor>> Function(String term) searchAccounts,
  required Future<List<RasqAccountPost>> Function(String term) searchPosts,
  int maxImages = pageSearchMaxImages,
  Duration retryWait = const Duration(seconds: 5),
}) async {
  final texts = [for (final i in inputs) if (i.image == null && i.text.trim().isNotEmpty) i.text.trim()];
  final images = [for (final i in inputs) if (i.image != null) i.image!].take(maxImages).toList();
  final lists = <String, ListHit>{};
  final servers = <String, ServerHit>{};
  final terms = <String>[];
  var dummy = false;
  var failedImages = 0;
  void addTerms(Iterable<String> ts) {
    for (final t in ts) {
      if (terms.length < pageSearchMaxTerms && !terms.any((x) => x.toLowerCase() == t.toLowerCase())) terms.add(t);
    }
  }

  void take(ContentDiscoverResult r) {
    for (final l in r.lists) {
      lists.putIfAbsent(l.id, () => l);
    }
    for (final s in r.servers) {
      servers.putIfAbsent(s.host, () => s);
    }
    if (r.mode == 'dummy') dummy = true;
  }

  Future<ContentDiscoverResult?> ask({List<List<int>> frames = const [], String? text}) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await content(frames: frames, text: text, url: url);
      } catch (e) {
        if (!isRateLimited(e) || attempt >= 3) {
          debugPrint('page search content: $e');
          return null;
        }
        await Future<void>.delayed(retryWait);
      }
    }
  }

  // 文字はそのまま言葉に。
  for (final t in texts) {
    addTerms(pageSearchTermsOfText(t));
  }
  // 画像は 1 枚ずつ言葉にする(同時に maxImages まで)。
  final seen = await runLimited([for (final img in images) () => ask(frames: [img])], maxImages);
  for (final r in seen) {
    if (r == null) {
      failedImages++;
      continue;
    }
    take(r);
    addTerms(pageSearchTermsOfQuery(r.query));
  }
  // 文字の囲みは、まとめて 1 回だけリスト / サーバーを探す。
  if (texts.isNotEmpty) {
    final r = await ask(text: texts.join('\n'));
    if (r != null) take(r);
  }
  // 言葉ごとに、RASQ のユーザーと投稿。
  final accounts = <String, RasqPostAuthor>{};
  final posts = <String, RasqAccountPost>{};
  await Future.wait([
    for (final t in terms) ...[
      () async {
        try {
          for (final a in await searchAccounts(t)) {
            accounts.putIfAbsent(a.handle, () => a);
          }
        } catch (e) {
          debugPrint('page search accounts: $e');
        }
      }(),
      () async {
        try {
          for (final p in await searchPosts(t)) {
            posts.putIfAbsent(p.id, () => p);
          }
        } catch (e) {
          debugPrint('page search posts: $e');
        }
      }(),
    ],
  ]);
  return PageSearchOutcome(accounts: accounts.values.toList(), posts: posts.values.toList(), lists: lists.values.toList(), servers: servers.values.toList(), terms: terms, dummy: dummy, failedImages: failedImages);
}
