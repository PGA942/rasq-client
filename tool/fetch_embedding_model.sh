#!/usr/bin/env bash
# 同梱の RASQ MiniLM(文の塔)を assets/rai_embedding/ に置く (D-522)。
# 使い方: tool/fetch_embedding_model.sh <置き場のディレクトリ | Central の URL>
#   例: tool/fetch_embedding_model.sh /workspace/models/minilm-mobilenet
#       tool/fetch_embedding_model.sh https://central.example.jp
# 置いたあと sha256 を出し、lib/features/rai/rai_embedding_model.dart の raiEmbeddingSpec.sha256 と比べる
# (未記入なら、書く値として出す)。
set -euo pipefail
cd "$(dirname "$0")/.."
src="${1:?置き場のディレクトリか Central の URL を渡してください}"
rel=minilm-mobilenet/onnx/text_tower_uint8.onnx
dest=assets/rai_embedding/text_tower_uint8.onnx
case "$src" in
  http://*|https://*) curl -L --fail --progress-bar -o "$dest.part" "${src%/}/api/v1/models/$rel" ;;
  *)
    f="$src/onnx/text_tower_uint8.onnx"
    [ -f "$f" ] || f="$src/text_tower_uint8.onnx"
    cp "$f" "$dest.part" ;;
esac
mv "$dest.part" "$dest"
got=$(sha256sum "$dest" | cut -d' ' -f1)
want=$(grep -A12 '^const raiEmbeddingSpec' lib/features/rai/rai_embedding_model.dart | sed -n "s/^ *sha256: '\([0-9a-f]*\)'.*/\1/p")
ls -la "$dest"
echo "sha256 $got"
if [ -z "$want" ]; then
  echo "raiEmbeddingSpec.sha256 が未記入です。確かめたうえで次を書いてください: sha256: '$got',"
elif [ "$want" != "$got" ]; then
  echo "sha256 が違います(期待 $want)" >&2; rm -f "$dest"; exit 1
else
  echo "sha256 OK"
fi
