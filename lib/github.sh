#!/usr/bin/env bash
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$LIB_DIR/common.sh"

pb_download_version() {
  local version="$1" outdir="$2"
  local arch zip url tmp
  arch="$(arch_tag)"
  zip="pocketbase_${version}_${arch}.zip"
  url="https://github.com/pocketbase/pocketbase/releases/download/v${version}/${zip}"

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "$outdir"

  echo "Downloading PocketBase v${version} (${arch})"
  curl -fsSL "$url" -o "$tmp/$zip" || die "Download failed: $url"
  unzip -o "$tmp/$zip" -d "$tmp/unz" >/dev/null
  [[ -f "$tmp/unz/pocketbase" ]] || die "Binary not found in archive."

  install -m 0755 "$tmp/unz/pocketbase" "$outdir/pocketbase"
  rm -rf "$tmp"
  trap - EXIT
}
