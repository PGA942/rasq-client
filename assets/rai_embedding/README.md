# 同梱の埋め込みモデル (D-522)

`text_tower_uint8.onnx` — RASQ MiniLM(文の塔、384 次元・正規化済み、35,430,217 バイト)。
pubspec の `platforms` で Web 版には入れない。ファイルが無いビルドは、従来どおり RASQ Central
(`/api/v1/models/minilm-mobilenet/onnx/text_tower_uint8.onnx`)から取る。

## 出どころ

- 元: ユーザーの Google Drive の `minilm-mobilenet/onnx/text_tower_int8.onnx`(MiniLM-Base の書き出し、2026-10-20 受領)
  sha256 `c1e195f051bacff40b74c44414847f484d56f413f4944c7d350e77daabfc6655`、35,430,217 バイト。
  前処理は同じフォルダの `preprocessing.json`(max_length 128 / pad_id 1 / attention_mask は float32 / 出力 384 次元・正規化済み)。
- 変換: `tool/requantize_uint8.py`(ConvInteger / MatMulInteger の int8 の重みと零点を +128 して uint8 に。値は変わらない)。
  端末の onnxruntime 1.15 は int8 の重みの ConvInteger を読めないため。
- 結果: sha256 `f867c2b1c46c952c3a6dccdbf54e092e3230f54e0ca1d752586fe4a931e76a7c`(`raiEmbeddingSpec.sha256`)。
- 同じ書き出しの画像の塔(RASQ MobileNet)も同じ手順で `image_tower_uint8.onnx`
  (sha256 `e7b2f08fea6e556290a03934cda8a1db8573a54aca3da999ad5cb5abd51659ca`、`postVisionEmbeddingSpec.sha256`)にして
  Central が配る(同梱しない)。
- 確かめ: test/rasq_minilm_test.dart(参照 = test/fixtures/rasq_minilm_reference.json を `tool/rasq_minilm_reference.py` で
  このモデルから作り直したもの。以前の参照は D-390 の別の uint8 量子化から作られていた)、test/rasq_mobilenet_test.dart。

置き直すときは `tool/fetch_embedding_model.sh <置き場 | Central の URL>`(sha256 を確かめる)。
