# Audio Reactor Controls Design

Status: spec
Date: 2026-05-13
Target platform: macOS 15+
Owner: jidong

## Summary

Add a useful Audio Reactor panel to Luno's library window and make audio-reactive wallpapers visibly respond to music. The selected direction combines a global audio control panel with two visual overlays: a bass-driven center pulse ring and a spectrum/waveform visualizer. The goal is that turning on an audio-reactive wallpaper produces an obvious visual response without requiring the user to edit package files or guess at hidden values.

## Goals

- Add user-facing controls for audio reaction strength instead of hardcoded shader multipliers.
- Make bass hits visibly scale and glow a centered pulse ring.
- Add a spectrum visualizer overlay that can be shown on top of the active wallpaper.
- Keep controls simple enough for the current AppKit library window.
- Preserve the existing `.luno` package shader contract for bundled and third-party shaders.

## Non-Goals

- A full visual editor.
- Per-wallpaper custom UI layouts.
- Recording, saving, or exporting audio visualizations.
- Remote wallpaper marketplace behavior.
- A new permission model beyond the current ScreenCaptureKit audio capture behavior.

## User Experience

The library window gains an `Audio Reactor` section whenever the selected wallpaper declares audio bindings. The section exposes:

- `Audio Reactor`: on/off toggle for audio effects on the selected wallpaper.
- `Intensity`: global strength for audio-driven shader uniforms and overlays.
- `Response`: segmented control with `Soft`, `Punchy`, and `Hard`.
- `Bass Pulse`: strength of the center pulse ring.
- `Visualizer`: toggles for `Pulse Ring`, `Spectrum Bars`, and `Wave Line`.
- `Overlay Opacity`: opacity of visualizer overlays.

Default behavior should be clearly visible but not chaotic:

- Audio Reactor on.
- Intensity around 80%.
- Response set to Punchy.
- Pulse Ring on.
- Spectrum Bars on.
- Wave Line off.
- Overlay Opacity around 60%.

If a selected wallpaper does not declare audio bindings, the Audio Reactor section should be hidden or disabled with minimal explanatory text.

## Visual Behavior

### Bass Pulse Ring

The renderer draws a centered ring after the wallpaper shader renders. The ring:

- Scales with bass energy.
- Brightens with bass and RMS.
- Uses a soft glow so the response is visible on dark and image-based wallpapers.
- Fades by `Overlay Opacity`.

The ring is intended as the first obvious "music is driving this" signal.

### Spectrum Bars

The renderer draws a row of bars near the bottom of the wallpaper. The bars:

- Use spectrum bins from `AudioFeatures.spectrum`.
- Respect `Overlay Opacity`.
- Are capped to avoid covering too much of the wallpaper.
- Use a small fixed number of rendered bars, such as 32, even if the analyzer produces 64 bins.

### Wave Line

Wave Line uses the same downsampled spectrum data as Spectrum Bars and draws a continuous line instead of vertical bars. It ships in the first implementation, defaults off, and can be enabled independently from Spectrum Bars.

## Architecture

### Audio Preferences

Add a small persisted preferences model in `LunoEngineCore`, for example `AudioReactorPreferences`:

```swift
public struct AudioReactorPreferences: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var intensity: Double
    public var response: AudioReactorResponse
    public var bassPulseStrength: Double
    public var showsPulseRing: Bool
    public var showsSpectrumBars: Bool
    public var showsWaveLine: Bool
    public var overlayOpacity: Double
}
```

`LunoApp` owns the UI controls and persists this model similarly to existing preferences or presets. The renderer reads the latest preferences through a lightweight provider so slider and toggle changes update the active wallpaper without pressing `Apply` again.

### Audio Data

The wallpaper renderer currently receives `AudioScalars` for `rms`, `bass`, `mid`, and `treble`. The spectrum overlay needs full `AudioFeatures`, including `spectrum`.

Update the wallpaper audio provider from `AudioScalars` to `AudioFeatures`. The existing shader uniform fields remain scalar values, derived after applying Audio Reactor intensity and response shaping.

`SystemAudioCaptureService.features` should provide a real spectrum instead of a silent spectrum when the visualizer is enabled.

### Renderer

`MetalWallpaperRenderer` should keep the existing wallpaper shader as the base pass. After drawing the shader:

1. Read the latest audio snapshot.
2. Apply Audio Reactor preferences to calculate shaped RMS, bass, mid, treble, and overlay strengths.
3. Draw overlay primitives for the pulse ring, spectrum bars, and wave line.

The implementation should favor simple Metal draw calls or a small built-in overlay shader over changing every bundled sample shader. This makes the effect consistent across all wallpapers and avoids duplicating pulse/visualizer code in package shaders.

## Data Flow

```
SystemAudioCaptureService
  -> AudioFeatures(rms, bass, mid, treble, spectrum)
  -> AppDelegate audio provider
  -> WallpaperRuntime / MetalWallpaperRenderer
  -> scalar shader uniforms + built-in overlay draw
```

Audio Reactor preferences flow from the library window into the runtime when the user applies a wallpaper.
Preference edits also flow into the active renderer immediately through the preferences provider.

## Tests

Add focused tests where the code is testable without a running Metal view:

- Audio Reactor preference defaults and Codable round trip.
- Response shaping clamps output into safe ranges.
- Intensity scaling affects `rms`, `bass`, `mid`, and `treble` predictably.
- Spectrum downsampling from 64 analyzer bins to the renderer's bar count.
- Preferences provider updates are read by the active renderer without rebuilding shader parameter packs.

Run `swift test`. Also build the app with SwiftPM or Xcode if local tooling supports it, because Metal shader compile errors may not appear in unit tests.

## Risks

- ScreenCaptureKit still triggers macOS "currently sharing" UI while audio capture is running.
- Spectrum calculation is more expensive than four scalar bands, so the implementation should avoid unnecessary allocations in the render loop.
- A global overlay can clash visually with some wallpapers. Opacity controls and toggles are required so the user can tone it down.
- Live preference updates require a small AppKit-to-runtime callback path. Keep it focused on Audio Reactor preferences only.
