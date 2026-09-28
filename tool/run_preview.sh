#!/usr/bin/env bash
# プレビュー録画用: テスト用の接続先(ダミーの SNS + デモの Central、D-359 / D-360)を焼き込んで起動する。
#
#   tool/run_preview.sh [-d <device>] [--address <ダミー環境のアドレス>] [flutter run のほかの引数…]
#
# ダミー環境は rasq-preview-assets の `dummy/run_all.sh`(録画開始の予約は `--start-at 19:00`)。
# アプリの設定 → RASQ サーバー →「テスト用の接続先」でも同じことができる(ビルドし直さずに切り替えたいとき)。
set -euo pipefail
ADDR="127.0.0.1"
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --address) ADDR="$2"; shift ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done
cd "$(dirname "$0")/.."
exec flutter run "${ARGS[@]}" \
  --dart-define=RASQ_DEV_SNS_BASE="misskey.rasq.test=http://$ADDR:9101,mstdn.rasq.test=http://$ADDR:9102,bsky.rasq.test=http://$ADDR:9103" \
  --dart-define=RASQ_CENTRAL_URL="http://$ADDR:8080"
