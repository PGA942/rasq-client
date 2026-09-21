#!/bin/sh
# Web 版を、ヘッドレス Chrome で開いて確かめる (D-303)。コンソールの中身を出し、画面の写真を撮る。
#
#   flutter build web --profile --source-maps   # 名前の残るビルド(release でもよい)
#   docker run --rm -v ~/work:/w -v /tmp/out:/s -e PAGE='#/rai' -w /w/rasq-client rasq-flutter:3.47.2 sh tool/web/webshot.sh
#
# 写真は /s/shot.png。イメージ (.docker-flutter) には Chrome が入っている。
cd "$(dirname "$0")/../../build/web" || exit 1
python3 -m http.server 8090 >/dev/null 2>&1 &
sleep 2
google-chrome --headless=new --no-sandbox --disable-gpu --disable-dev-shm-usage --enable-unsafe-swiftshader \
  --window-size="${W:-1280},${H:-900}" --screenshot="${OUT:-/s/shot.png}" \
  --enable-logging=stderr --v=0 --virtual-time-budget="${BUDGET:-30000}" \
  "http://127.0.0.1:8090/${PAGE:-}" 2>&1 >/dev/null \
  | grep -E "CONSOLE" | sed -E 's/^\[[^]]*\] //; s/, source: [^ ]+ \([0-9]+\)$//' | grep -viE "swiftshader|GL Driver|Injecting" | head -30
chmod 666 "${OUT:-/s/shot.png}" 2>/dev/null
