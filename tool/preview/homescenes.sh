#!/bin/sh
# rasq-central のホームページの「アプリの中の動き」(D-466、Central S-107 のプレイヤー)のシーンを撮り直す。
#
# 使い方: RASQ_PREVIEW_FONT=<NotoSansJP の .ttf> [RASQ_PAINT_RSPKG=<sample.paint-0.1.0.rspkg>] tool/preview/homescenes.sh [出力先]
#   出力先の既定は ../rasq-central/src/web/home/scenes(Central が配る置き場)。
#
# 1. flutter test tool/preview/homescenes_test.dart → build/homescenes/
#      scenes.json(台本、schema `rasq.home-scenes/1`)と <シーン>/<端末>/<nn>.png(端末の物理 px のコマ)
#    シーン: rai(phone / tablet)、client(tabletWide / phone)、account(tablet / phone)、astell(tablet / phone)。
#    中身と台本の読み方はテストの先頭と scenes.json の notes。
# 2. コマを WebP(lossy、品質 80。1 枚 150 KB を超えたら品質を下げて撮り直す)にして、台本と一緒に出力先へ。
#    出力先は丸ごと作り直す(前のコマを残さない。scenes.json の無い既存のディレクトリには書かない)。
#    シーン / 端末ごとの合計も出す(目安 1.2 MB 以内)。
# 3. SHEETS=<ディレクトリ> なら、見直し用のコンタクトシート(tool/preview/homescenes_sheet.py、Pillow)も作る。
#
# CI と同じコンテナ(rasq-flutter:3.47.2、隣に rasq-sdk-sample)で 1 を回し、2 / 3 は libwebp / Pillow のあるところで(例:
# `docker run --rm -v "$PWD":/w -w /w alpine sh -c 'apk add libwebp-tools py3-pillow && SKIP_FLUTTER=1 SHEETS=sheets tool/preview/homescenes.sh out'`)。
# cwebp が無ければ Python の Pillow で変換する。SKIP_FLUTTER=1 なら 1 を飛ばして、いまある build/homescenes から 2 以降だけ。
set -eu
cd "$(dirname "$0")/../.."
out="${1:-../rasq-central/src/web/home/scenes}"
src=build/homescenes
max=153600
if [ "${SKIP_FLUTTER:-}" != 1 ]; then
  : "${RASQ_PREVIEW_FONT:?RASQ_PREVIEW_FONT を日本語フォント(.ttf)へ向けてください}"
  rm -rf "$src"
  flutter test tool/preview/homescenes_test.dart
fi
[ -f "$src/scenes.json" ] || {
  echo "$src/scenes.json がありません(先にテストを回してください)" >&2
  exit 1
}
if [ -d "$out" ] && [ -n "$(ls -A "$out")" ] && [ ! -f "$out/scenes.json" ]; then
  echo "$out は空でなく、scenes.json もありません(別の置き場を消さないよう止めます)" >&2
  exit 1
fi
rm -rf "$out"
mkdir -p "$out"

webp() { # PNG → WebP。150 KB を超えたら品質を下げる。
  for q in 80 72 64 56 48 40; do
    if command -v cwebp >/dev/null 2>&1; then
      cwebp -quiet -q "$q" -m 6 "$1" -o "$2"
    else
      python3 -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).convert("RGB").save(sys.argv[2], "WEBP", quality=int(sys.argv[3]), method=6)' "$1" "$2" "$q"
    fi
    [ "$(wc -c <"$2")" -le "$max" ] && return 0
  done
  echo "注意: $2 は品質 40 でも 150 KB を超えています" >&2
}

find "$src" -name '*.png' | sort | while read -r f; do
  rel=${f#"$src"/}
  dst="$out/${rel%.png}.webp"
  mkdir -p "$(dirname "$dst")"
  webp "$f" "$dst"
done
cp "$src/scenes.json" "$out/scenes.json"

# シーン / 端末ごとの合計。
for d in "$out"/*/*/; do
  total=$(cat "$d"*.webp | wc -c)
  printf '%-24s %3d コマ %8d バイト\n' "${d#"$out"/}" "$(ls "$d" | wc -l)" "$total"
  [ "$total" -le 1258291 ] || echo "注意: ${d#"$out"/} は 1.2 MB を超えています" >&2
done

if [ -n "${SHEETS:-}" ]; then
  python3 tool/preview/homescenes_sheet.py "$out" "$SHEETS" ${RASQ_PREVIEW_FONT:+"$RASQ_PREVIEW_FONT"}
fi
