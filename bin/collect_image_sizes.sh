#!/usr/bin/env bash
# collect_image_sizes.sh docker image inspect で各ランタイムイメージのサイズ (バイト) を取得し
# JSON へ書き出す。クラウドでは ECR からの pull 時間・ストレージ・転送コストに直結するため、
# スループットとは別軸の運用コスト指標として記録する。ホスト側 (docker が見える環境) で実行する。
set -euo pipefail

out="${1:-results/image_sizes.json}"
mkdir -p "$(dirname "$out")"

mri_image="ruby-vs-truffleruby-bench/ruby34"
truffleruby_image="ruby-vs-truffleruby-bench/truffleruby34"

image_size() {
  local size
  size=$(docker image inspect "$1" --format '{{.Size}}' 2>/dev/null)
  if [[ -n "$size" && "$size" =~ ^[0-9]+$ ]]; then
    echo "$size"
  else
    echo "null"
  fi
}

mri_size="$(image_size "$mri_image")"
truffleruby_size="$(image_size "$truffleruby_image")"

# mri と mri-yjit は同一イメージを共有するため同じサイズになる。
cat >"$out" <<JSON
{
  "schema_version": 1,
  "images": {
    "mri": { "image": "${mri_image}", "size_bytes": ${mri_size} },
    "mri-yjit": { "image": "${mri_image}", "size_bytes": ${mri_size} },
    "truffleruby": { "image": "${truffleruby_image}", "size_bytes": ${truffleruby_size} }
  }
}
JSON

echo "wrote $out"
