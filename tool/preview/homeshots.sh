#!/bin/sh
# rasq-central のホームページ (S-095 / S-096 / S-098 / S-101 / S-103) の端末のプレビューに貼る、アプリの画面のスクリーンショットと
# RAi の節の見本のアニメーションを作り直す。
#
# 使い方: RASQ_PREVIEW_FONT=<NotoSansJP の .ttf> tool/preview/homeshots.sh [出力先]
#   出力先の既定は ../rasq-central/src/web/home(Central が include_bytes! で配る置き場)。
#
# 1. flutter test tool/preview/homeshots_test.dart --update-goldens → tool/preview/home_*.png
#    静止画(8 枚):
#      スマホ(縦、780×1688 = 390×844 の 2 倍): onboarding / timeline / account / astell_listen
#      タブレットの横向き(1920×1200 = 1280×800 の 1.5 倍): onboarding_wide / client
#      タブレットの縦向き(1200×1920 = 800×1280 の 1.5 倍、1 カラム): account_tall / astell_listen_tall
#    RAi の見本のキーフレーム (D-464): rai_guide_00〜07 / rai_guide_tall_00〜07(案内「TL にリストを設定」)、
#      rai_chat_00〜05 / rai_chat_tall_00〜05(アシスタントの RAi との会話「ハロー、RAi さん」)
# 2. WebP(品質 80)に変換して出力先へ(home_client.png → client.webp)。
#    - 静止画はそのまま。RAi の節の静止版 rai.webp / rai_tall.webp は、案内の 2 コマ目(「タイムラインを追加」を指す)。
#    - キーフレームは見本ごとに 1 本の animated WebP(無限ループ、コマごとの表示時間は下の GUIDE_MS / CHAT_MS):
#      rai_guide.webp / rai_guide_tall.webp / rai_chat.webp / rai_chat_tall.webp。
#    cwebp / img2webp(libwebp)があればそれを、無ければ Python の Pillow。
#    Central は WebP のヘッダーから大きさを、ANMF チャンクからコマ数と表示時間を読み、端末の種類(比率)と向きを決めるので、
#    名前と大きさを変えたら src/web/home.rs の SHOTS / LOOPS と節の割り当て(section)とテストも揃える。
#    静止画は 1 枚 150 KB 以内、animated WebP は 1 本 400 KB 以内(Central のテストが見る)。
#
# CI と同じコンテナ(rasq-flutter:3.47.2、隣に rasq-sdk-sample)で 1 を回し、2 は libwebp のあるところで(例:
# `docker run --rm -v "$PWD":/w -w /w alpine sh -c 'apk add libwebp-tools && SKIP_FLUTTER=1 tool/preview/homeshots.sh out'`)。
# Pillow は `pip3 install pillow`。SKIP_FLUTTER=1 なら 1 を飛ばして、いまある PNG から 2 だけ行う。
set -eu
cd "$(dirname "$0")/../.."
out="${1:-../rasq-central/src/web/home}"
# コマごとの表示時間(ミリ秒)。案内は 8 コマ(質問 → ∨ → 追加 → 一覧 → リスト → 戻る → 決定 → 結果)、会話は 6 コマ。
GUIDE_MS="1600 2200 2400 2000 1800 2000 2000 2400"
CHAT_MS="1400 1600 1000 700 700 3200"
if [ "${SKIP_FLUTTER:-}" != 1 ]; then
  : "${RASQ_PREVIEW_FONT:?RASQ_PREVIEW_FONT を日本語フォント(.ttf)へ向けてください}"
  flutter test tool/preview/homeshots_test.dart --update-goldens
fi
mkdir -p "$out"

still() { # PNG → WebP
  if command -v cwebp >/dev/null 2>&1; then
    cwebp -quiet -q 80 "$1" -o "$2"
  else
    python3 -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).convert("RGB").save(sys.argv[2], "WEBP", quality=80, method=6)' "$1" "$2"
  fi
  ls -l "$2"
}

anim() { # 名前 表示時間… → <名前>.webp(home_<名前>_00.png から順に)
  name=$1
  shift
  if command -v img2webp >/dev/null 2>&1; then
    args=""
    i=0
    for d in "$@"; do
      args="$args -d $d tool/preview/$(printf 'home_%s_%02d.png' "$name" "$i")"
      i=$((i + 1))
    done
    # shellcheck disable=SC2086 # args は空白で区切った引数の並び(ファイル名に空白は無い)。
    img2webp -loop 0 -lossy -q 80 -m 6 $args -o "$out/$name.webp" >/dev/null
  else
    python3 - "$name" "$out/$name.webp" "$@" <<'PY'
import sys
from PIL import Image
name, dst, ms = sys.argv[1], sys.argv[2], [int(x) for x in sys.argv[3:]]
frames = [Image.open(f"tool/preview/home_{name}_{i:02d}.png").convert("RGB") for i in range(len(ms))]
frames[0].save(dst, "WEBP", save_all=True, append_images=frames[1:], duration=ms, loop=0, quality=80, method=6)
PY
  fi
  ls -l "$out/$name.webp"
}

for f in tool/preview/home_*.png; do
  name=$(basename "$f" .png)
  name=${name#home_}
  case "$name" in
    rai_guide_* | rai_chat_*) continue ;;
  esac
  still "$f" "$out/$name.webp"
done
still tool/preview/home_rai_guide_02.png "$out/rai.webp"
still tool/preview/home_rai_guide_tall_02.png "$out/rai_tall.webp"
# shellcheck disable=SC2086 # 表示時間の並びを引数に分ける。
anim rai_guide $GUIDE_MS
# shellcheck disable=SC2086
anim rai_guide_tall $GUIDE_MS
# shellcheck disable=SC2086
anim rai_chat $CHAT_MS
# shellcheck disable=SC2086
anim rai_chat_tall $CHAT_MS
