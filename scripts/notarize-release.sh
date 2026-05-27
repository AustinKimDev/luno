#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-${GITHUB_REF_NAME:-0.1.0}}"
VERSION="${VERSION#v}"

DMG_PATH="$ROOT_DIR/dist/Luno-v${VERSION}-macOS-arm64.dmg"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "error: DMG not found at $DMG_PATH" >&2
  exit 1
fi

: "${APPLE_ID:?Set APPLE_ID to the Apple ID email used for notarization}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to your Apple Developer Team ID}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD to an app-specific password}"

xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --wait

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl -a -vvv -t open --context context:primary-signature "$DMG_PATH"
