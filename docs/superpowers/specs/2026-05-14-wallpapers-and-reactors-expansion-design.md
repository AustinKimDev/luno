# Wallpapers and Audio Reactors Expansion

## Goal

Add 8 new modern wallpapers and 8 new audio reactor presets to the Luno sample library, plus the controls needed to make album-cover-derived reactor colors remain visible against album-reactive backgrounds.

## Scope

### In scope

- 8 new bundled `.luno` wallpaper packages (4 themes × 2 each).
- 8 new built-in `AudioReactorStylePresetID` cases with full palette/spectrum/ring/wave defaults.
- A new three-mode `AudioReactorAlbumColorMode` enum applied when the reactor palette source is `albumArtwork`.
- Auto contrast algorithm (luma/hue/saturation correction) used by `contrast` mode.
- Vivid mode (channel-specific lightness/saturation lock).
- Four new reactor options: `mirrored` (spectrum), `colorCycle` (style-level hue rotation over time), `beatGate` (preferences-level), `motionTrail` (style-level temporal EMA).
- Settings UI: a segmented "Match / Contrast / Vivid" control under the Album palette source; an "Advanced" disclosure group exposing the four new options.
- Backwards-compatible decoding (new fields default to safe values so existing JSON loads cleanly).

### Out of scope

- Reworking `LunoShaderUniforms` layout (existing slots are sufficient).
- New wallpaper manifest schema features beyond what existing `parameters` already allows.
- A standalone "audio reactivity" slider at the wallpaper level (rejected during design — overlaps with reactor `intensity`).
- True off-screen motion blur (would require additional accumulation texture). The `motionTrail` option uses an in-shader EMA approximation only.
- Onboarding/preview imagery beyond a single `preview.png` per package.

## Wallpapers (8 new)

All packages bundle as `Sources/LunoApp/Resources/SamplePackages/<Name>.luno/` with `manifest.json` + entry `.metal` + `preview.png`. All consume the existing `LunoUniforms` (time, resolution, audio, parameter0, colorParameter0..3, albumColor0..3).

### Cyberpunk / Neon

**1. Synthwave Horizon** (`com.luno.samples.synthwave-horizon`, `Synthwave.metal`)

- Infinite perspective grid receding to a neon-gradient horizon with a sun circle and horizontal scan bands.
- Bass pumps grid line brightness; treble jitters sun line. RMS expands horizon glow.
- Parameters: `speed`, `horizonY` (0.3–0.7), `gridDensity` (8–32), `tintStrength`, `brightness`, `saturation`, `tint` (default `#FF3DA1`).

**2. Glitch District** (`com.luno.samples.glitch-district`, `Glitch.metal`)

- Soft city silhouette in distance with floating hologram glyph layers; chromatic RGB scanline split. Mid-energy controls drift; treble triggers brief tearing.
- Parameters: `speed`, `glitchAmount` (0–1, default 0.35), `scanlineDensity` (60–240), `tintStrength`, `brightness`, `saturation`, `tint` (default `#3DFFE7`).

### Minimal / Geometric

**3. Iso Tower** (`com.luno.samples.iso-tower`, `IsoTower.metal`)

- Very dark backdrop with thin isometric architectural line art (parallax stacked frames). Bass adds a barely-visible glow pulse; otherwise serene.
- Parameters: `speed`, `lineWeight` (0.4–1.6), `glowAmount` (0–1, default 0.4), `tintStrength`, `brightness`, `saturation`, `tint` (default `#9FB6D6`).

**4. Quiet Lattice** (`com.luno.samples.quiet-lattice`, `QuietLattice.metal`)

- Sparse depth-shaded dot grid with one slow horizontal traversal line. Audio only modulates the line's brightness and faint dot bloom near it.
- Parameters: `speed`, `dotDensity` (16–64), `depthBlur` (0–1, default 0.55), `tintStrength`, `brightness`, `saturation`, `tint` (default `#FFFFFF`).

### Organic flow

**5. Ink Plume** (`com.luno.samples.ink-plume`, `InkPlume.metal`)

- Procedural fluid sim approximation (curl noise) of dark ink dropped into water; treble swirls, rms expands plume size.
- Parameters: `speed`, `inkDensity` (0.2–1.5), `swirlAmount` (0–1, default 0.6), `tintStrength`, `brightness`, `saturation`, `tint` (default `#1F8FFF`).

**6. Velvet Tide** (`com.luno.samples.velvet-tide`, `VelvetTide.metal`)

- Stacked silk-wave layers slowly translating; bass adds gentle vertical breathing.
- Parameters: `speed`, `layers` (3–8, integer), `softness` (0–1, default 0.65), `tintStrength`, `brightness`, `saturation`, `tint` (default `#A87BFF`).

### Album-reactive

**7. Vinyl Echo** (`com.luno.samples.vinyl-echo`, `VinylEcho.metal`)

- Rotating LP record with concentric grooves on a desk-light vignette. Label color from album `primary`; outer ring picks up `secondary`; grooves deepen with bass.
- Parameters: `rotationSpeed`, `grooveDensity` (40–160), `labelGlow` (0–1, default 0.6), `tintStrength`, `brightness`, `saturation`, `tint` (default `#000000` — minimal manual tint by default).

**8. Cover Bloom** (`com.luno.samples.cover-bloom`, `CoverBloom.metal`)

- Centered radial bloom rendered entirely from album `background/primary/secondary/highlight`, with treble-driven filament rays and rms-driven outer halo.
- Parameters: `bloomRadius` (0.3–1.2), `filamentDensity` (0–1, default 0.55), `tintStrength`, `brightness`, `saturation`, `tint` (default `#FFFFFF`).

## Reactor presets (8 new)

Add to `AudioReactorStylePresetID`. Each preset returns from `AudioReactorStyle.preset(_:)`. Default `palette.source = .manual`; default `albumColorMode = .contrast` (irrelevant when manual, applies when user flips source).

| ID | Layout | Palette | Spectrum key params | Ring key params | Wave key params |
|----|--------|---------|---------------------|------------------|------------------|
| `halo` | circle | indigo/violet/white | bars 24, height 0.18, glow 0.4 | radius 0.4, thickness 0.06, glow 0.95 | thickness 0.005, amp 0.2 |
| `cascade` | bottom | electric blue/magenta | bars 96, width 0.62, mirrored=true, spacing 0.18, glow 0.85 | thin, low glow | thin, low amp |
| `ribbon` | arc | rose/peach/cream | bars 32, glow 0.3 | thin | thickness 0.018, amp 0.9, smoothing 0.55 |
| `pulse` | bottom | cobalt/cyan | bars 40, height 0.32, width 0.3 | radius 0.32, thickness 0.022, glow 0.9 | thickness 0.01, amp 0.4 |
| `spectro` | bottom | green/lime/white | bars 84, width 0.18, height 0.95, spacing 0.55, roundness 0.05 | thin, low glow | thin, low amp |
| `crystal` | arc | cyan/white/sky | bars 56, roundness 0.0, height 0.4, smoothing 0.2 | thin | thin, low amp |
| `nebula` | circle | violet/teal/lilac | bars 32, glow 0.95, smoothing 0.92 | radius 0.42, thickness 0.012, softness 0.95 | thickness 0.007, amp 0.35 |
| `vapor` | bottom | pastel pink/lavender | bars 32, height 0.18, glow 0.55, smoothing 0.85 | thin, low glow | thickness 0.022, amp 0.7, smoothing 0.9 |

Style fields are always set (presets cannot turn an overlay off — that's controlled by `showsPulseRing` / `showsSpectrumBars` / `showsWaveLine` on `AudioReactorPreferences`). "Thin, low glow / low amp" means the style is configured so the channel reads as quiet even when the user toggles it on.

Exact float values land during implementation; the table sets the variance contract so each preset is visually distinct.

## Album-color contrast modes

### Enum

```swift
public enum AudioReactorAlbumColorMode: String, Codable, CaseIterable, Sendable {
    case match     // current behavior — album colors used directly
    case contrast  // auto luma/hue correction (default)
    case vivid     // hue from album, lightness/saturation forced
}
```

Added as a new field on `AudioReactorPalette`:

```swift
public var albumColorMode: AudioReactorAlbumColorMode  // default: .contrast
```

`AudioReactorPalette.resolved(with:)` branches on `source` and `albumColorMode`. When `source == .manual`, `albumColorMode` is ignored.

### Contrast algorithm

Applied per channel (primary, secondary, accent, glow) after pulling from `AlbumPalette`:

1. **Luma collision**: compute reactor channel luma and album `background` luma. If `|Δ| < 0.18`, shift reactor luma by `±0.35` in the direction that increases contrast (clamped to `[0, 1]`).
2. **Hue collision (primary only)**: convert primary to HSL. If `|hueΔ|` with album primary `< 30°` AND `|satΔ| < 0.2`, rotate hue by `+120°` or `-120°` — pick the one that maximizes distance from album `secondary` hue.
3. **Saturation floor**: if post-correction saturation `< 0.35`, clamp to `0.55`.
4. **Glow lock**: glow channel always clamped to luma `≥ 0.85` (rim light stays near-white regardless of album).

### Vivid algorithm

Take only hue from album palette; force lightness/saturation:

| Channel | Hue from | Sat | Lightness |
|---------|----------|-----|-----------|
| primary | album primary | 1.0 | 0.78 |
| secondary | album secondary | 1.0 | 0.65 |
| accent | album highlight | 0.95 | 0.55 |
| glow | album highlight | 0.5 | 0.95 |

### Match

Existing `resolved(with:)` behavior preserved.

### HSL utility

Add private RGB↔HSL helpers inside `AudioReactorPreferences.swift` (no external dep, ≤ 50 lines). Used only by the contrast/vivid paths.

## New reactor options

### `mirrored: Bool`

- Location: `AudioReactorSpectrumStyle`. Default `false`.
- Effect: for `bottom` layout, spectrum is mirrored about `x = bottomRailStart + bottomRailWidth * 0.5` (left half index increases toward center, right half mirrors). For `arc`, reflects across the arc midpoint angle. For `circle`, ignored.
- Implementation: shader-side branch in `lunoOverlayFragment` spectrum block.

### `colorCycle: Double` (0–1)

- Location: `AudioReactorStyle`. Default `0.0`.
- Effect: when `> 0`, the resolved palette has a global hue rotation `= time * (colorCycle * 0.628)` rad applied before being passed to the overlay shader. `1.0 ≈ 10 s` per revolution.
- Computed CPU-side in `MetalWallpaperRenderer.draw(in:)`, so contrast/vivid corrections are applied first, then cycled.

### `beatGate: Bool`

- Location: `AudioReactorPreferences`. Default `false`.
- Effect: when on, pulse ring opacity is gated by a beat-detect signal rather than continuous bass.
- Implementation: lightweight in-renderer beat detector — maintain `bassEMA` (slow, τ ≈ 0.6 s) and `bassNow`. Beat fires when `bassNow > bassEMA * 1.45 && bassNow > 0.25`. On fire, set `gateLevel = 1`. Each frame `gateLevel *= 0.92`. Sent to overlay shader via an existing slot (replacing the continuous bass term in the ring path only; spectrum/wave keep raw audio).

### `motionTrail: Double` (0–1)

- Location: `AudioReactorStyle`. Default `0.0`.
- Effect: temporal smoothing of `overlaySpectrum` array. The renderer keeps a previous-spectrum buffer. When `motionTrail < 0.001`, behavior is bypassed: `prev[i] = new[i]; out[i] = new[i]`. Otherwise `decay = 0.55 + 0.4 * motionTrail` and `out[i] = max(new[i], prev[i] * decay)`, then `prev[i] = out[i]`.
- Cheap (~96 floats), no extra texture.

## UI changes

### `AudioReactorSectionView`

- Below the existing "Color source" `NSPopUpButton` (Manual / Album), add a new `NSSegmentedControl` ("Album mode": Match / Contrast / Vivid). Show only when `style.palette.source == .albumArtwork`; hide when `.manual`. Wired through the same target/action pattern as `paletteSourceChanged`.
- Add a `NSBox`-grouped "Advanced" section (or `NSDisclosureButton`-driven collapse) below the existing controls containing:
  - "Mirror spectrum" `NSSwitch` → `style.spectrum.mirrored`
  - "Color cycle" `NSSlider` 0–1 → `style.colorCycle`
  - "Beat gate" `NSSwitch` → `preferences.beatGate`
  - "Motion trail" `NSSlider` 0–1 → `style.motionTrail`
- Existing enabled/disabled enforcement (`usesManualColors`, master toggle gating) extended to cover the new controls consistently.

### No new wallpaper-side UI

Each new wallpaper exposes its parameters via existing `manifest.json → parameters` → already rendered by Library section parameter inspector.

## Data model & persistence

Backwards-compatible decoding:

- `AudioReactorPalette.init(from:)` adds `albumColorMode` with default `.contrast`.
- `AudioReactorSpectrumStyle.init(from:)` adds `mirrored` with default `false`.
- `AudioReactorStyle.init(from:)` adds `colorCycle` and `motionTrail` with defaults `0.0`.
- `AudioReactorPreferences.init(from:)` adds `beatGate` with default `false`.
- New preset IDs decode normally; presetID strings that the running build doesn't recognize fall back to `studio` (existing behavior — verify in test).
- Codable round-trip tests in `AudioReactorPreferencesTests` extended for each new field.

## File / module changes

```
Sources/LunoApp/Resources/SamplePackages/SynthwaveHorizon.luno/{manifest.json, Synthwave.metal, preview.png}
Sources/LunoApp/Resources/SamplePackages/GlitchDistrict.luno/{manifest.json, Glitch.metal, preview.png}
Sources/LunoApp/Resources/SamplePackages/IsoTower.luno/{manifest.json, IsoTower.metal, preview.png}
Sources/LunoApp/Resources/SamplePackages/QuietLattice.luno/{manifest.json, QuietLattice.metal, preview.png}
Sources/LunoApp/Resources/SamplePackages/InkPlume.luno/{manifest.json, InkPlume.metal, preview.png}
Sources/LunoApp/Resources/SamplePackages/VelvetTide.luno/{manifest.json, VelvetTide.metal, preview.png}
Sources/LunoApp/Resources/SamplePackages/VinylEcho.luno/{manifest.json, VinylEcho.metal, preview.png}
Sources/LunoApp/Resources/SamplePackages/CoverBloom.luno/{manifest.json, CoverBloom.metal, preview.png}

Sources/LunoEngineCore/AudioReactorPreferences.swift  // enum + fields + algorithms
Sources/LunoEngineCore/WallpaperRuntime.swift          // colorCycle / beatGate / motionTrail wiring + overlay shader updates for `mirrored`
Sources/LunoApp/Settings/AudioReactorSectionView.swift // album mode picker + Advanced disclosure
Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift // contrast/vivid/match cases, codable, beat gate state machine
```

Total Swift LOC delta target: ≤ 700 (preferences + algorithms + UI). Metal LOC: ~120 per shader × 8 ≈ 1000.

## Preview images

Each `preview.png` is `512×320`. Required by the Library grid thumbnail. Captured by running the shader at the target resolution against `AlbumPalette.fallback` with `audio = .silent` and reading back the drawable on the first frame. Implementation plan adds a small `scripts/render-preview.swift` that takes a package path and writes `preview.png`, so previews are reproducible from the shader sources.

## Testing

### Unit tests (extend `AudioReactorPreferencesTests`)

- Codable round-trip for each new field with both present and absent JSON.
- `albumColorMode = .match` returns existing behavior.
- `albumColorMode = .contrast`: low-contrast input → output luma `|Δ|` with album bg `> 0.32`.
- `albumColorMode = .vivid`: forced lightness/saturation matches table within tolerance.
- `mirrored` toggle round-trips.
- Beat gate state machine: stepping with synthetic bass values fires `gateLevel == 1` exactly when threshold crossed.

### Visual regression (manual checklist in `docs/superpowers/qa/`)

For each of 8 wallpapers and 8 presets, manually verify:
- Renders at 60fps on M1.
- Audio responds (use built-in test tone or actual music).
- Album-color modes produce visibly distinct results against the same wallpaper.

## Implementation plan decomposition

The scope is large enough to warrant splitting into ordered phases when writing the implementation plan:

1. **Reactor data model & UI** — add `AudioReactorAlbumColorMode`, the four new style/preference fields, HSL utilities, contrast/vivid algorithms, beat-gate state, mirrored shader branch, settings UI. Lands first because everything else either tests or uses these.
2. **8 new reactor presets** — preset definitions + displayNames + codable tests. Depends on (1).
3. **Preview render script** — `scripts/render-preview.swift`. Depends on nothing structural; lets later wallpaper PRs ship preview.png deterministically.
4. **4 new wallpapers (Cyberpunk + Geometric)** — Synthwave, Glitch, Iso Tower, Quiet Lattice.
5. **4 new wallpapers (Organic + Album-reactive)** — Ink Plume, Velvet Tide, Vinyl Echo, Cover Bloom.

Each phase is independently shippable.

## Risks & mitigations

- **Shader complexity**: 8 new shaders may slow up GPU on integrated graphics. Mitigation: keep each shader ≤ ~120 lines, avoid heavy noise loops (>4 iterations), test on minimum target.
- **Preset count growth**: 14 presets total may overwhelm the picker. Mitigation: preset picker already a list — fine; consider grouping by category in a follow-up if user signals overload.
- **Contrast algorithm edge cases**: monochrome album art may yield no usable hue. Mitigation: when album primary saturation `< 0.08`, fall back to manual palette colors regardless of mode (one explicit `if` early-exit).
- **Beat gate false positives**: silent passages can show spurious "beats." Mitigation: `bassNow > 0.25` absolute floor.
