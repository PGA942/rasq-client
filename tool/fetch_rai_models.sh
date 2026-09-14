#!/usr/bin/env bash
# RAi のローカルモデルを取得して gzip で assets/rai_models/ に同梱する (D-216)。
# 使い方: tool/fetch_rai_models.sh [qwen3.5-2b|agents-a1-4b|qwen3.5-0.8b ...](省略 = 3 つ全部)
set -euo pipefail
cd "$(dirname "$0")/.."
dest=assets/rai_models
mkdir -p "$dest"
declare -A urls=(
  [qwen3.5-2b]="https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf"
  [agents-a1-4b]="https://huggingface.co/bartowski/InternScience_Agents-A1-4B-GGUF/resolve/main/InternScience_Agents-A1-4B-Q4_K_M.gguf"
  [qwen3.5-0.8b]="https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf"
)
targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=(qwen3.5-2b agents-a1-4b qwen3.5-0.8b)
for t in "${targets[@]}"; do
  url="${urls[$t]:-}"
  [ -z "$url" ] && { echo "unknown model: $t" >&2; exit 1; }
  file="$(basename "$url")"
  if [ -f "$dest/$file.gz" ]; then echo "skip $file.gz (exists)"; continue; fi
  echo "fetch $file"
  curl -L --fail --progress-bar ${HF_TOKEN:+-H "Authorization: Bearer $HF_TOKEN"} -o "$dest/$file" "$url"
  echo "gzip $file"
  gzip -6 -f "$dest/$file"
done
ls -la "$dest"
