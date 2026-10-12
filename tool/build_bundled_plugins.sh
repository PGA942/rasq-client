#!/usr/bin/env bash
# アプリに同梱するプラグインを、ソースから作り直す (D-393)。
#
#   tool/build_bundled_plugins.sh [SDK_DIR] [SAMPLES_DIR]
#
# - SDK_DIR     = rasq-sdk-sample の checkout(既定 ../rasq-sdk-sample)。SNS / 関連 TL / hello の wasm と、`rasq` CLI を作る。
# - SAMPLES_DIR = plugin-sample の各リポジトリを並べたディレクトリ(既定 ../plugin-sample-repos)。
#                 中の <repo>/ は `rasq` ワークスペース(rasq.toml)。`rasq build --raw --no-sign` で作る。
# - 作ったものを assets/plugins/ に置き、**出どころ(リポジトリ / コミット / 版 / sha256)を assets/plugins/SOURCES.json に書く**。
#   アプリのストア(同梱の掲載)は、版をこのファイルから読む。
# - checkout の中身をそのまま使う(このスクリプトはブランチを切り替えない)。未コミットの変更があれば SOURCES.json に dirty と書く。
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
SDK_DIR="$(cd "${1:-$HERE/../rasq-sdk-sample}" && pwd)"
SAMPLES_DIR="$(cd "${2:-$HERE/../plugin-sample-repos}" && pwd)"
OUT="$HERE/assets/plugins"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v python3 >/dev/null || { echo "python3 が要ります" >&2; exit 1; }
rustup target list --installed | grep -q wasm32-unknown-unknown || rustup target add wasm32-unknown-unknown

# ── 出どころの記録(アセット名 → JSON 1 行)──
# ビルドの前に見る(ビルドは dist を書き換えるので、あとから見ると必ず変更ありになる)。
is_dirty() { [ -n "$(git -C "$1" status --porcelain --untracked-files=no)" ] && echo true || echo false; }
record() { # asset repo_dir version dirty
  local asset="$1" dir="$2" version="$3" dirty="$4"
  local remote commit sha
  remote="$(git -C "$dir" config --get remote.origin.url 2>/dev/null | sed -E 's#//[^@/]+@#//#' || true)"
  commit="$(git -C "$dir" rev-parse HEAD)"
  sha="$(sha256sum "$OUT/$asset" | cut -d' ' -f1)"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$asset" "$remote" "$commit" "$version" "$sha" "$dirty" >> "$TMP/sources.tsv"
}

# ── 1. rasq-sdk-sample: SNS / 関連 TL / hello と rasq CLI ──
echo "== rasq-sdk-sample ($(git -C "$SDK_DIR" rev-parse --short HEAD))"
SDK_DIRTY="$(is_dirty "$SDK_DIR")"
(cd "$SDK_DIR/rust" && cargo build --release -q -p rasq-cli)
RASQ="$SDK_DIR/rust/target/release/rasq"
for crate in misskey-wasm-sample mastodon-wasm bluesky-wasm mixi2-wasm relational-wasm hello-rasq-plugin; do
  (cd "$SDK_DIR/rust" && cargo build --release -q --target wasm32-unknown-unknown -p "$crate")
  asset="${crate//-/_}.wasm"
  cp "$SDK_DIR/rust/target/wasm32-unknown-unknown/release/$asset" "$OUT/$asset"
  version="$(cd "$SDK_DIR/rust" && cargo metadata --no-deps --format-version 1 | python3 -c "import json,sys; print(next(p['version'] for p in json.load(sys.stdin)['packages'] if p['name']=='$crate'))")"
  record "$asset" "$SDK_DIR" "$version" "$SDK_DIRTY"
  echo "   $asset $version"
done

# ── 2. plugin-sample の各リポジトリ: rasq build ──
# repo → 同梱のアセット名(テーマは .rasqpkg そのもの)
while IFS=' ' read -r repo asset; do
  [ -z "$repo" ] && continue
  dir="$SAMPLES_DIR/$repo"
  [ -f "$dir/rasq.toml" ] || { echo "!! $dir に rasq.toml がありません(rasq ワークスペースではない)" >&2; exit 1; }
  echo "== $repo ($(git -C "$dir" rev-parse --short HEAD))"
  dirty="$(is_dirty "$dir")"
  case "$asset" in
    theme_*.rasqpkg)
      # 着せ替えは絵だけの配布物で、作るたびにバイト列が変わる(tar の時刻)。コミット済みの dist をそのまま使う。
      id="sample.${asset%.rasqpkg}"; id="${id/theme_/theme-}"
      pkg="$(git -C "$dir" ls-files "dist/$id-*.rasqpkg" | head -1)"
      [ -n "$pkg" ] || { echo "!! $dir/dist に $id の配布物がありません" >&2; exit 1; }
      pkg="$dir/$pkg"
      cp "$pkg" "$OUT/$asset" ;;
    *)
      (cd "$dir" && "$RASQ" build --raw --no-sign >/dev/null)
      cp "$dir/dist/$asset" "$OUT/$asset"
      pkg="$(ls "$dir"/dist/*.rspkg "$dir"/dist/*.rasqpkg 2>/dev/null | head -1)" ;;
  esac
  # 版 = 配布物の名前 <id>-<版>.rspkg(旧 .rasqpkg)から。
  version="$(basename "$(basename "$pkg" .rasqpkg)" .rspkg | sed -E 's/^.*-([0-9][^-]*(-[^-]+)?)$/\1/')"
  record "$asset" "$dir" "$version" "$dirty"
  echo "   $asset $version"
done <<'EOF'
astell-plugin astell_plugin.wasm
composer-media-plugin composer_media_plugin.wasm
composer-text-plugin composer_text_plugin.wasm
custom-page-plugin custom_page_plugin.wasm
custom-plugin-paint custom_plugin_paint.wasm
media-draw-plugin media_draw_plugin.wasm
media-fullscreen-plugin media_fullscreen_plugin.wasm
media-process-plugin media_process_plugin.wasm
media-transform-plugin media_transform_plugin.wasm
post-action-plugin post_action_plugin.wasm
post-process-plugin post_process_plugin.wasm
post-share-plugin post_share_plugin.wasm
timeline-plugin timeline_plugin.wasm
trend-plugin trend_plugin.wasm
theme-plugin theme_starry.rasqpkg
theme-plugin theme_rasq.rasqpkg
EOF

# ── 3. SOURCES.json ──
python3 - "$TMP/sources.tsv" "$OUT/SOURCES.json" <<'PY'
import json, sys
assets = {}
for line in open(sys.argv[1], encoding='utf-8'):
    asset, repo, commit, version, sha, dirty = line.rstrip('\n').split('\t')
    assets[asset] = {'repo': repo, 'commit': commit, 'version': version, 'sha256': sha, **({'dirty': True} if dirty == 'true' else {})}
json.dump({'schema': 'rasq.bundled-plugins/1', 'generatedBy': 'tool/build_bundled_plugins.sh', 'assets': dict(sorted(assets.items()))},
          open(sys.argv[2], 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
open(sys.argv[2], 'a').write('\n')
PY
echo "== assets/plugins/SOURCES.json に $(python3 -c "import json;print(len(json.load(open('$OUT/SOURCES.json'))['assets']))") 件を書きました"
