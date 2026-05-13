#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_DIR="$ROOT_DIR/.build/artifacts/Luno.app"
rm -rf "$APP_DIR"
find "$ROOT_DIR/.build" -path '*/release/Luno.app' -prune -exec rm -rf {} + 2>/dev/null || true

swift build -c release

BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/release"
if [[ ! -x "$BUILD_DIR/Luno" ]]; then
  BUILD_DIR="$ROOT_DIR/.build/release"
fi
if [[ ! -x "$BUILD_DIR/Luno" ]]; then
  echo "error: release executable was not built" >&2
  exit 1
fi

CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/Luno" "$MACOS_DIR/Luno"
if [[ -d "$BUILD_DIR/Luno_LunoApp.bundle" ]]; then
  cp -R "$BUILD_DIR/Luno_LunoApp.bundle" "$RESOURCES_DIR/Luno_LunoApp.bundle"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Luno</string>
  <key>CFBundleIdentifier</key>
  <string>com.luno.Luno</string>
  <key>CFBundleName</key>
  <string>Luno</string>
  <key>CFBundleDisplayName</key>
  <string>Luno</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSScreenCaptureUsageDescription</key>
  <string>Luno captures system audio to drive audio-reactive live backgrounds.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Luno reads the currently playing track from Music and Spotify so the wallpaper widget can show what you're listening to.</string>
</dict>
</plist>
PLIST

if [[ -z "${LUNO_CODESIGN_IDENTITY:-}" ]]; then
  LUNO_CODESIGN_IDENTITY="$(
    security find-identity -v -p codesigning \
      | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' \
      | head -n 1
  )"
fi

if [[ -z "${LUNO_CODESIGN_IDENTITY:-}" ]]; then
  LUNO_CODESIGN_IDENTITY="-"
fi

codesign --force --options runtime --sign "$LUNO_CODESIGN_IDENTITY" "$APP_DIR"
codesign --verify --strict --deep --verbose=2 "$APP_DIR"

echo "Built and signed $APP_DIR with identity: $LUNO_CODESIGN_IDENTITY"
