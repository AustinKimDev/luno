# Luno

Luno is a macOS-only live background player prototype. It targets macOS 15+ and focuses on the local player path first: menu bar app, per-display Metal shader wallpapers, simple preset editing, local `.luno` packages, and system-audio-reactive uniforms.

Online accounts, uploads, ratings, payments, moderation, and marketplace hosting are intentionally out of scope for this alpha.

## Build

```bash
swift build
swift test
```

Run directly from SwiftPM:

```bash
swift run Luno
```

Build an `.app` bundle:

```bash
scripts/build-app.sh
open .build/artifacts/Luno.app
```

The first launch imports the bundled `Aurora Field` sample package into:

```text
~/Library/Application Support/Luno/Packages
```

## Current Features

- Menu bar resident macOS app.
- Library window with package selection, display selection, import/export, and parameter controls.
- One wallpaper window per display, positioned behind normal app windows near desktop level.
- Runtime Metal shader compilation from `.luno` packages.
- Simple preset values for float, bool, color, and enum parameters.
- Per-display assignment persistence.
- System audio capture through ScreenCaptureKit on macOS 15+, converted into shader uniforms.
- Balanced performance policy: 30fps by default, with tested support for 60fps high-quality mode.

## Package Format

See [docs/package-format.md](docs/package-format.md).

## Architecture

See [docs/architecture.md](docs/architecture.md).
