#!/usr/bin/env bash
# Web クライアントを、Central の `/app/` で配る形に作る (D-456 / rasq-central S-092)。
#
#   RASQ_CENTRAL_URL=https://central.example ORGATE_BASE_URL=https://orgate.example tool/web/build_web.sh [追加の flutter の引数…]
#
# - `flutter build web --release --base-href /app/`。出力は build/web。それを Central の `CENTRAL_WEB_APP_DIR` に置く
#   (compose ならボリュームでマウント)。Central は `/app/` の下の無いパス(アプリの中の場所)を index.html に落とす。
# - 接続先は env から `--dart-define` で焼き込む(空なら渡さない = 設定画面の「接続先」/ ORGATE の流用)。
#   RASQ_CENTRAL_URL / ORGATE_BASE_URL / RASQ_ML_BASE_URL / RASQ_ADSENSE_CLIENT / RASQ_ADSENSE_SLOT。
# - BASE_HREF で `/app/` 以外にもできる(先頭と末尾の `/` が要る)。Central は `/app/` 固定なので、ふだんは変えない。
# - 開発用の http の Central を指すときは、ブラウザの安全なコンテキストの制限(localStorage へ逃がす保存、D-295)に注意。
set -euo pipefail

HERE="$(cd "$(dirname "$0")/../.." && pwd)"
BASE_HREF="${BASE_HREF:-/app/}"
case "$BASE_HREF" in
  /*/ | /) ;;
  *) echo "BASE_HREF は / で始まり / で終わる形に(今: $BASE_HREF)" >&2; exit 1 ;;
esac

defines=()
for k in RASQ_CENTRAL_URL ORGATE_BASE_URL RASQ_ML_BASE_URL RASQ_ADSENSE_CLIENT RASQ_ADSENSE_SLOT; do
  v="${!k:-}"
  if [ -n "$v" ]; then defines+=("--dart-define=$k=$v"); fi
done

cd "$HERE"
flutter build web --release --base-href "$BASE_HREF" ${defines[@]+"${defines[@]}"} "$@"
echo "build/web を CENTRAL_WEB_APP_DIR に置いてください(base href: $BASE_HREF)"
