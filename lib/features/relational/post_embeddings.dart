import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../backend/limited_http.dart';
import '../emoji/emoji_image_embedder.dart';
import '../emoji/emoji_index_providers.dart' show EmojiImageEmbedderLoader;
import '../rai/rai_embedding_model.dart';
import '../rai/rai_reference.dart' show NgramRaiEmbedder, RaiEmbedder;

/// 投稿の埋め込み (D-390): **端末で**、本文は RASQ MiniLM(RAi の検索と共用)、画像は RASQ MobileNet で埋め込む。
/// 2 つは同じ 384 次元の空間なので、画像のある投稿は本文と画像を混ぜた 1 本のベクトルにできる。
///
/// 関連 TL(著者の関心の移動平均 + コミュニティ)と、TL のアルゴリズム(似ている投稿 / 好みのベクトル)が使う。
/// 以前は ML ゲートウェイ(サーバーの SigLIP)が要り、無ければ語の一致だけだった。ゲートウェイがあればそちらが先。
class PostEmbedder {
  PostEmbedder({required this.text, this.image, required this.fetch, this.imageWeight = 0.35, this.cacheSize = 512});

  final RaiEmbedder text;

  /// 画像の塔(入れていなければ null = 本文だけ)。
  final EmojiImageEmbedder? image;

  /// 画像を取ってくる(失敗 / 大きすぎれば null)。
  final Future<Uint8List?> Function(Uri url) fetch;

  /// 本文と画像を混ぜるときの画像の重み(本文が空なら画像だけ)。
  final double imageWeight;
  final int cacheSize;

  final _imageCache = <String, List<double>?>{};

  /// 文の埋め込み(TL のアルゴリズムの参照文など)。
  Future<List<List<double>>> embedTexts(List<String> texts) => text.embed(texts);

  /// 投稿の画像のうち、埋め込みに使う 1 枚(最初の画像 / GIF、動画はサムネイル)。無ければ null。
  static Uri? imageOf(Post p) {
    for (final m in p.media) {
      switch (m.type) {
        case MediaType.image || MediaType.gif:
          return m.thumbnailUrl ?? m.url;
        case MediaType.video:
          if (m.thumbnailUrl != null) return m.thumbnailUrl;
        case MediaType.file:
          break;
      }
    }
    return null;
  }

  /// 投稿 → ベクトル(正規化済み)。並びは渡した順。
  Future<List<List<double>>> embedPosts(List<Post> posts) async {
    final texts = await text.embed([for (final p in posts) p.body]);
    final img = image;
    if (img == null) return texts;
    final urls = [for (final p in posts) imageOf(p)?.toString()];
    final missing = {for (final u in urls) if (u != null && !_imageCache.containsKey(u)) u}.toList();
    if (missing.isNotEmpty) {
      final bytes = await Future.wait([for (final u in missing) fetch(Uri.parse(u))]);
      final have = [for (var i = 0; i < missing.length; i++) if (bytes[i] != null) i];
      final vectors = have.isEmpty ? const <List<double>?>[] : await img.embedImages([for (final i in have) bytes[i]!]);
      for (var i = 0; i < missing.length; i++) {
        _imageCache[missing[i]] = null;
      }
      for (var k = 0; k < have.length && k < vectors.length; k++) {
        _imageCache[missing[have[k]]] = vectors[k];
      }
      while (_imageCache.length > cacheSize) {
        _imageCache.remove(_imageCache.keys.first);
      }
    }
    return [
      for (var i = 0; i < posts.length; i++) mix(texts[i], urls[i] == null ? null : _imageCache[urls[i]], bodyEmpty: posts[i].body.trim().isEmpty, imageWeight: imageWeight),
    ];
  }

  /// 本文と画像を混ぜる(正規化)。画像が無ければ本文、本文が空なら画像。
  static List<double> mix(List<double> text, List<double>? image, {required bool bodyEmpty, double imageWeight = 0.35}) {
    if (image == null || image.length != text.length) return text;
    if (bodyEmpty) return image;
    return NgramRaiEmbedder.normalize([for (var d = 0; d < text.length; d++) text[d] * (1 - imageWeight) + image[d] * imageWeight]);
  }
}

/// 投稿の画像の埋め込み器を読む(実機では main が差し替える。既定 = 使えない)。
final postImageEmbedderLoaderProvider = Provider<EmojiImageEmbedderLoader>((_) => (_) async => null);

/// 投稿の画像の上限。
const postImageMaxBytes = 4 * 1024 * 1024;

/// 投稿の画像を取ってくる(テストでは差し替える)。4 MiB 超と失敗は null。
/// 本文は上限までしか読まない(超えたら読むのをやめて通信を切る、セキュリティ確認 2026-10-09 の [18])。
final postImageFetcherProvider = Provider<Future<Uint8List?> Function(Uri url)>((ref) => (url) async {
      try {
        final res = await getLimited(url, maxBytes: postImageMaxBytes, timeout: const Duration(seconds: 10));
        return res.statusCode == 200 && res.bodyBytes.isNotEmpty ? res.bodyBytes : null;
      } catch (_) {
        return null;
      }
    });

/// 端末の投稿の埋め込み器。文のモデル(RAi の検索と同じ)を入れていなければ null(語の一致に縮退)。
/// 画像の塔を入れていれば、画像も混ぜる。
final postEmbedderProvider = FutureProvider<PostEmbedder?>((ref) async {
  final st = ref.watch(raiEmbeddingStatusProvider).value;
  if (st == null || !st.ready) return null;
  final model = ref.watch(raiEmbeddingModelProvider);
  if (model.spec.kind != RaiEmbeddingKind.rasqText) return null; // 画像と同じ空間の文のモデルだけ
  final text = await model.embedder();
  if (text == null) return null;
  EmojiImageEmbedder? image;
  if (ref.watch(postVisionStatusProvider).value?.ready ?? false) {
    final loaded = await ref.watch(postImageEmbedderLoaderProvider)(ref.watch(postVisionModelProvider));
    if (loaded != null) {
      image = loaded.embedder;
      ref.onDispose(loaded.dispose);
    }
  }
  return PostEmbedder(text: text, image: image, fetch: ref.watch(postImageFetcherProvider));
});
