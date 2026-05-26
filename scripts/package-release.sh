#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-${GITHUB_REF_NAME:-0.1.0}}"
VERSION="${VERSION#v}"

APP_PATH="$ROOT_DIR/.build/artifacts/Luno.app"
DIST_DIR="$ROOT_DIR/dist"
DMG_STAGING_DIR="$ROOT_DIR/.build/release-dmg"
DMG_NAME="Luno-v${VERSION}-macOS-arm64.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
CHECKSUMS_PATH="$DIST_DIR/SHA256SUMS"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

"$ROOT_DIR/scripts/build-app.sh"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app bundle was not built at $APP_PATH" >&2
  exit 1
fi

rm -rf "$DMG_STAGING_DIR"
mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_PATH" "$DMG_STAGING_DIR/Luno.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
  -volname "Luno" \
  -srcfolder "$DMG_STAGING_DIR" \
  -fs HFS+ \
  -ov \
  -format UDZO \
  "$DMG_PATH"

(
  cd "$DIST_DIR"
  shasum -a 256 "$DMG_NAME" > "$CHECKSUMS_PATH"
)

echo "Packaged $DMG_PATH"
echo "Wrote $CHECKSUMS_PATH"
