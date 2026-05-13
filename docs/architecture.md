# Luno Architecture

## Shape

Luno is split into two SwiftPM targets:

- `LunoEngineCore`: package format, local library, presets, display assignments, audio analysis/capture, performance policy, AppKit wallpaper windows, and Metal rendering.
- `LunoApp`: menu bar app, library window, sample package bootstrap, import/export actions, start-at-login action, and app-level persistence wiring.

This keeps the player engine reusable when a full editor or online sharing service is added later.

## Runtime Flow

1. `LunoApp` starts as an accessory app and creates a menu bar item.
2. Bundled samples are copied into Application Support if the local library is empty.
3. `LocalPackageLibrary` scans `.luno` directories and decodes `manifest.json`.
4. The library window lets the user choose a package, a target display, and simple preset values.
5. `WallpaperRuntime` creates a borderless non-interactive window for each selected display.
6. `MetalWallpaperRenderer` compiles the package shader and sends time, resolution, preset values, and audio features as uniforms.
7. `SystemAudioCaptureService` captures system audio through ScreenCaptureKit and updates `AudioFeatures`.

## Deferred Platform Work

The alpha deliberately does not include accounts, marketplace browsing, uploads, remote package trust, payment, moderation, or a node editor. The `.luno` package format is the handoff point for those systems.
