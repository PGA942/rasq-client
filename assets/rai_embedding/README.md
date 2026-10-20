# 同梱の埋め込みモデル (D-522)

`text_tower_uint8.onnx` — RASQ MiniLM(文の塔、D-390 の uint8 で量子化し直した版、約 35 MB)。
`tool/fetch_embedding_model.sh` で置く。sha256 は `lib/features/rai/rai_embedding_model.dart` の
`raiEmbeddingSpec.sha256` と合わせる。pubspec の `platforms` で Web 版には入れない。
ファイルが無いビルドは、従来どおり RASQ Central(`/api/v1/models/minilm-mobilenet/onnx/text_tower_uint8.onnx`)から取る。
