# 同梱の埋め込みモデル (D-522 / D-558)

- `text_tower_uint8.onnx` — **RAM pico txt**(もと RASQ MiniLM、文の塔、D-390 の uint8 で量子化し直した版、約 35 MB)。RAi の検索と投稿の本文。
- `image_tower_uint8.onnx` — **RAM pico img**(もと RASQ MobileNet、画像の塔、約 32 MB)。投稿の画像(文と同じ空間)。

`tool/fetch_embedding_model.sh` で 2 つとも置く。sha256 は `lib/features/rai/rai_embedding_model.dart` の
`raiEmbeddingSpec.sha256` / `postVisionEmbeddingSpec.sha256` と合わせる。pubspec の `platforms` で Web 版には入れない。
ファイルが無いビルドは、従来どおり RASQ Central(`/api/v1/models/minilm-mobilenet/onnx/…`)から取る。
