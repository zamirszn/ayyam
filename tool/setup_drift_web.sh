#!/usr/bin/env bash
set -euo pipefail

drift_version="2.35.3"
drift_archive_sha256="3179e7323b36d1852b42997b92ac72e8abcb61b1d58cfa8c6da9b540ab02a540"
drift_assets_dir="$(mktemp -d /tmp/ayyam-drift-web.XXXXXX)"
trap 'rm -rf "$drift_assets_dir"' EXIT

drift_archive="$drift_assets_dir/drift.tar.gz"
curl -fsSL \
  "https://pub.dev/api/archives/drift-${drift_version}.tar.gz" \
  -o "$drift_archive"
printf '%s  %s\n' "$drift_archive_sha256" "$drift_archive" | sha256sum -c -
tar -xzf "$drift_archive" -C "$drift_assets_dir"

install -m 0644 "$drift_assets_dir/drift_worker.js" web/drift_worker.js
install -m 0644 \
  "$drift_assets_dir/extension/devtools/build/sqlite3.wasm" \
  web/sqlite3.wasm
