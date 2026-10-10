#!/bin/sh
# rasq-central のホームページ (S-095 / S-096) の端末のプレビューに貼る、アプリの画面のスクリーンショットを作り直す。
#
# 使い方: RASQ_PREVIEW_FONT=<NotoSansJP の .ttf> tool/preview/homeshots.sh [出力先]
#   出力先の既定は ../rasq-central/src/web/home(Central が include_bytes! で配る置き場)。
#
# 1. flutter test tool/preview/homeshots_test.dart --update-goldens → tool/preview/home_*.png
#    (スマホ: 780×1688 = 390×844 の 2 倍。タブレットの横向き(home_client.png): 1920×1200 = 1280×800 の 1.5 倍)
# 2. WebP(品質 80)に変換して出力先へ(home_client.png → client.webp)。cwebp があればそれを、無ければ Python の Pillow。
#    Central は WebP のヘッダーから大きさを読んで端末の種類(比率)を決めるので、名前と大きさを変えたら src/web/home.rs の
#    SHOTS とテストも揃える。1 枚 150 KB 以内(Central のテストが見る)。
#
# CI と同じコンテナ(rasq-flutter:3.47.2、隣に rasq-sdk-sample)で回す。Pillow は `pip3 install pillow`。
set -eu
cd "$(dirname "$0")/../.."
out="${1:-../rasq-central/src/web/home}"
: "${RASQ_PREVIEW_FONT:?RASQ_PREVIEW_FONT を日本語フォント(.ttf)へ向けてください}"
flutter test tool/preview/homeshots_test.dart --update-goldens
mkdir -p "$out"
for f in tool/preview/home_*.png; do
  name=$(basename "$f" .png)
  name=${name#home_}
  if command -v cwebp >/dev/null 2>&1; then
    cwebp -quiet -q 80 "$f" -o "$out/$name.webp"
  else
    python3 -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).convert("RGB").save(sys.argv[2], "WEBP", quality=80, method=6)' "$f" "$out/$name.webp"
  fi
  ls -l "$out/$name.webp"
done
