import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/emoji/emoji_image_embedder.dart';
import 'package:rasq_client/features/rai/rai_reference.dart';
import 'package:rasq_client/features/relational/post_embeddings.dart';
import 'package:rasq_client/features/relational/relational_ml.dart';
import 'package:rasq_models/rasq_models.dart';

/// 投稿の埋め込み (D-390): 端末で、本文(RASQ MiniLM)と画像(RASQ MobileNet、同じ空間)を混ぜる。
class _Text implements RaiEmbedder {
  @override
  String get name => 'fake-text';
  final calls = <List<String>>[];
  @override
  Future<List<List<double>>> embed(List<String> texts) async {
    calls.add(texts);
    return [for (final t in texts) t.contains('ロケット') ? [1.0, 0.0, 0.0] : (t.contains('ごはん') ? [0.0, 1.0, 0.0] : [0.0, 0.0, 1.0])];
  }
}

class _Image implements EmojiImageEmbedder {
  @override
  String get name => 'fake-image';
  int calls = 0;
  @override
  Future<List<List<double>?>> embedImages(List<Uint8List> encoded) async {
    calls++;
    // 1 バイト目 = 1 ならロケットの写真、2 ならごはんの写真。
    return [for (final e in encoded) e.first == 1 ? [1.0, 0.0, 0.0] : [0.0, 1.0, 0.0]];
  }
}

void main() {
  const account = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'yamada');
  Post post(String id, String author, String body, {String? image, MediaType type = MediaType.image, Duration age = Duration.zero}) => Post(
        id: id,
        account: account,
        author: UserSummary(id: author, account: account, displayName: author),
        createdAt: DateTime(2026, 9, 30).subtract(age),
        body: body,
        media: [if (image != null) MediaItem(id: 'm$id', type: type, url: Uri.parse('https://img.test/$image'), thumbnailUrl: type == MediaType.video ? Uri.parse('https://img.test/thumb-$image') : null)],
      );

  test('画像は 1 枚目(動画はサムネイル)、混ぜ方(本文が空なら画像だけ、画像が無ければ本文)', () {
    expect(PostEmbedder.imageOf(post('a', 'x', 'y', image: 'p.png')).toString(), 'https://img.test/p.png');
    expect(PostEmbedder.imageOf(post('a', 'x', 'y', image: 'v.mp4', type: MediaType.video)).toString(), 'https://img.test/thumb-v.mp4');
    expect(PostEmbedder.imageOf(post('a', 'x', 'y')), isNull);
    expect(PostEmbedder.mix([1, 0], null, bodyEmpty: false), [1, 0]);
    expect(PostEmbedder.mix([1, 0], [0, 1], bodyEmpty: true), [0, 1]);
    final m = PostEmbedder.mix([1, 0], [0, 1], bodyEmpty: false, imageWeight: 0.35);
    expect(m[0], greaterThan(m[1]), reason: '本文が主');
    expect(m[0] * m[0] + m[1] * m[1], closeTo(1, 1e-9), reason: '正規化');
  });

  test('本文と画像を混ぜる。画像は一度取ったら覚える、取れなければ本文だけ', () async {
    final text = _Text();
    final image = _Image();
    final fetched = <String>[];
    final e = PostEmbedder(
      text: text,
      image: image,
      fetch: (url) async {
        fetched.add(url.path);
        if (url.path.contains('broken')) return null;
        return Uint8List.fromList([url.path.contains('rocket') ? 1 : 2]);
      },
    );
    final posts = [post('1', 'a', 'ロケット', image: 'rocket.png'), post('2', 'b', '', image: 'rice.png'), post('3', 'c', 'ごはん', image: 'broken.png'), post('4', 'd', 'ごはん')];
    final v = await e.embedPosts(posts);
    expect(v[0], [1.0, 0.0, 0.0], reason: '本文も画像もロケット');
    expect(v[1], [0.0, 1.0, 0.0], reason: '本文が空 → 画像だけ');
    expect(v[2], [0.0, 1.0, 0.0], reason: '画像が取れない → 本文だけ');
    expect(v[3], [0.0, 1.0, 0.0]);
    await e.embedPosts(posts.take(2).toList());
    expect(fetched.where((p) => p.contains('rocket')).length, 1, reason: '覚えている');
    expect(image.calls, 1);
  });

  test('関連 TL (D-390): ゲートウェイが無くても、端末の埋め込みで著者の関心とコミュニティが分かる', () async {
    final e = PostEmbedder(text: _Text(), image: _Image(), fetch: (url) async => Uint8List.fromList([url.path.contains('rocket') ? 1 : 2]));
    final pipeline = RelationalMlPipeline(embedPosts: e.embedPosts);
    final followees = [
      post('r1', 'rocketA', '#daily ロケットの話', age: const Duration(minutes: 5)),
      post('r2', 'rocketB', '#daily', image: 'rocket.png', age: const Duration(minutes: 4)), // 本文ではなく写真がロケット
      post('f1', 'foodC', '#daily ごはん', age: const Duration(minutes: 3)),
      post('f2', 'foodD', '#daily', image: 'rice.png', age: const Duration(minutes: 2)),
    ];
    final r = await pipeline.analyze(followees);
    int? c(int i) => r.communityOf[followees[i].author.key];
    expect(c(0), isNotNull);
    expect(c(0), c(1), reason: '写真の中身でロケットの仲間');
    expect(c(2), c(3));
    expect(c(0), isNot(c(2)));
    expect(r.postSimilarity(followees[0], followees[1]), greaterThan(r.postSimilarity(followees[0], followees[3])));
  });
}
