#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-${GITHUB_REF_NAME:-0.1.0}}"
VERSION="${VERSION#v}"

APP_PATH="$ROOT_DIR/.build/artifacts/Luno.app"
DIST_DIR="$ROOT_DIR/dist"
ZIP_NAME="Luno-v${VERSION}-macOS-arm64.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
CHECKSUMS_PATH="$DIST_DIR/SHA256SUMS"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

"$ROOT_DIR/scripts/build-app.sh"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app bundle was not built at $APP_PATH" >&2
  exit 1
fi

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

(
  cd "$DIST_DIR"
  shasum -a 256 "$ZIP_NAME" > "$CHECKSUMS_PATH"
)

echo "Packaged $ZIP_PATH"
echo "Wrote $CHECKSUMS_PATH"
