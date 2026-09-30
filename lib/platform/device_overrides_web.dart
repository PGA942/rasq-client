import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:plugin_runtime/plugin_runtime.dart' show rasqZstdWarmUp;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:web/web.dart' as web;

import '../features/emoji/emoji_index_providers.dart';
import '../backend/orgate_client.dart' show centralBaseUrlProvider;
import '../features/rai/rai_embedding_model.dart';
import '../features/relational/post_embeddings.dart';
import '../session/central_vault_storage.dart';
import '../session/session_providers.dart';
import '../session/session_storage.dart';
import 'web/web_embedding_model.dart';

/// Web 版 (D-295): 端末内のモデル(RAi の LLM / 埋め込み / 絵文字の画像検索)は載らない。既定の「使えない」のまま。
///
/// 保存先: flutter_secure_storage の Web 実装は WebCrypto を使うので、**安全なコンテキスト(https / localhost)でしか動かない**。
/// 開発用に http で開いたとき(tailnet のアドレスなど)だけ、localStorage にそのまま置く代わりを使う。本番は https で配ること。
List<Override> deviceOverrides() => [
      // SNS のログイン情報は Central の保管庫へ (D-300)。ブラウザに置くのは RASQ のトークンなど、それ以外だけ。
      // 端末内の埋め込みモデル (D-302): onnxruntime-web でブラウザの中で回す。LLM は載らない(既定の「使えない」のまま)。
      raiEmbeddingModelProvider.overrideWith((ref) => WebRaiEmbeddingModel(central: () => ref.read(centralBaseUrlProvider))),
      // 投稿の画像 (D-390): RASQ MobileNet(文と同じ空間)。
      postVisionModelProvider.overrideWith((ref) => WebRaiEmbeddingModel(spec: postVisionEmbeddingSpec, central: () => ref.read(centralBaseUrlProvider))),
      postImageEmbedderLoaderProvider.overrideWithValue((model) async {
        if (model is! WebRaiEmbeddingModel) return null;
        final e = await WebEmojiImageEmbedder.load(model);
        return e == null ? null : (embedder: e, dispose: e.dispose);
      }),
      emojiTextModelProvider.overrideWith((_) => WebRaiEmbeddingModel(spec: raiSiglip2EmbeddingSpec)),
      emojiVisionModelProvider.overrideWith((_) => WebRaiEmbeddingModel(spec: emojiVisionEmbeddingSpec)),
      emojiImageEmbedderLoaderProvider.overrideWithValue((model) async {
        if (model is! WebRaiEmbeddingModel) return null;
        final e = await WebEmojiImageEmbedder.load(model);
        return e == null ? null : (embedder: e, dispose: e.dispose);
      }),
      sessionStorageProvider.overrideWith((ref) => CentralVaultSessionStorage(ref, web.window.isSecureContext ? SecureSessionStorage() : _InsecureWebSessionStorage())),
    ];

class _InsecureWebSessionStorage implements SessionStorage {
  _InsecureWebSessionStorage() {
    debugPrint('RASQ: 安全でないコンテキスト (http) で開いています。ログイン情報は暗号化せずに localStorage へ置きます(開発用)。本番は https で配ってください。');
  }
  static const _prefix = 'rasq.insecure.';

  @override
  Future<String?> read(String key) async => web.window.localStorage.getItem('$_prefix$key');
  @override
  Future<void> write(String key, String value) async => web.window.localStorage.setItem('$_prefix$key', value);
  @override
  Future<void> delete(String key) async => web.window.localStorage.removeItem('$_prefix$key');
}

/// 起動時の支度 (D-299): .rasqpkg(zstd 圧縮 tar)を開くための zstd の wasm を読み込んでおく(失敗しても起動は続ける。ストアからの導入だけが断られる)。
Future<void> prepareDeviceRuntime() async {
  try {
    final data = await rootBundle.load('assets/web/zstd.wasm');
    await rasqZstdWarmUp(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  } catch (e) {
    debugPrint('RASQ: zstd の wasm を読み込めませんでした: $e');
  }
}
