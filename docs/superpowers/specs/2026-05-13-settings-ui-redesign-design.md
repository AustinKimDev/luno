# Settings UI Redesign Design

Status: spec
Date: 2026-05-13
Target platform: macOS 15+
Owner: jidong

## Summary

Rebuild Luno's library window into a production-quality settings window with a sidebar navigation, replacing the single long vertical stack. Add a customization model for the Now Playing widget covering shape, typography, color tinting, and per-effect reactivity, with built-in appearance presets so users can switch looks in one click and then tweak.

## Goals

- Replace `LibraryWindowController`'s flat layout with an `NSSplitView` sidebar + detail UI that scales to the existing Wallpapers, Now Playing, and Audio Reactor surfaces.
- Allow users to customize the widget's shape (corner radius, padding, border), text colors, accent/glow tint, and font weights.
- Split the single `audioReactivityIntensity` into a global intensity plus three per-effect weights (glow, scale, border) so each effect can be dialed independently.
- Ship 5 built-in appearance presets (Default, Vivid, Minimal, Neon, Mono) that users select from a popup, then customize freely.
- Preserve all existing preferences and storage formats: legacy `now-playing.json` files must continue to load with sensible defaults for new fields.

## Non-Goals

- Per-display widget appearance (single global look).
- Custom typography beyond a curated set of weights (no font family picker, no custom point sizes beyond presets).
- Custom appearance presets that users save by name (one set of built-in presets, plus the live "Custom" state).
- Migrating Library functionality to SwiftUI — the rebuild stays AppKit-native to match the surrounding code.
- Animated theme transitions when switching presets.

## User Experience

```
┌──────────────┬─────────────────────────────────────────┐
│  Luno        │  Now Playing › Appearance               │
│ ┌──────────┐ │                                         │
│ │Library   │ │  Preset    [Custom              ▼]      │
│ │NowPlaying│ │                                         │
│ │  · Basic │ │  Corner radius    14   ●━━━━━━     28   │
│ │  · Look  │ │  Padding          14   ●━━           28 │
│ │  · React │ │  Border width      1   ●━━           6  │
│ │AudioReact│ │  Border opacity   8%   ●━            100│
│ │          │ │                                         │
│ │          │ │  Title weight     [Semibold      ▼]    │
│ │          │ │  Subtitle weight  [Regular       ▼]    │
│ │          │ │  Text color       [#FFFFFF ⬛]          │
│ │          │ │  Accent color     [#FF6B9C ⬛]          │
│ │          │ │  Glow tint        [#FFFFFF ⬛]          │
│ └──────────┘ │                                         │
└──────────────┴─────────────────────────────────────────┘
```

Sidebar (single-column `NSOutlineView`) holds three top-level rows. `Now Playing` is the only expandable row and contains three children: `Basic`, `Appearance`, `Reactivity`. Selecting a row swaps the detail view on the right.

Detail sections:

- **Library**: existing wallpaper popup, display popup, preset name field, parameter controls, Apply/Save/Import/Export buttons. No behavioral change.
- **Now Playing › Basic**: enable switch, style popup, keep-visible-while-paused switch, react-to-music master switch.
- **Now Playing › Appearance**: preset popup, shape sliders (corner radius, padding, border width, border opacity), weight popups (title, subtitle), color wells (text, accent, glow tint). Changing any slider/popup/color flips the preset popup to "Custom".
- **Now Playing › Reactivity**: master intensity slider (0–100%, default 20%), three sub-sliders for `Glow`, `Scale`, `Border` (each 0–100%, default 100%, multiplied into the master). Sub-sliders disabled when master = 0.
- **Audio Reactor**: existing reactor controls (intensity, response, bass pulse, visualizer toggles, overlay opacity). No behavioral change.

Hovering any slider shows a tooltip with the numeric value. Color wells use `NSColorWell` with the standard system color picker.

## Data Model

New `NowPlayingAppearance` struct in `Sources/LunoEngineCore/NowPlaying/NowPlayingAppearance.swift`:

```swift
public struct NowPlayingAppearance: Codable, Equatable, Sendable {
    public enum FontWeight: String, Codable, Sendable, CaseIterable {
        case regular, medium, semibold, bold, heavy, black
    }

    // Shape
    public var cornerRadius: Double       // 0...28, default 14
    public var padding: Double            // 8...24, default 14
    public var borderWidth: Double        // 0...6, default 1
    public var borderOpacity: Double      // 0...1, default 0.08

    // Typography
    public var titleWeight: FontWeight    // default .semibold
    public var subtitleWeight: FontWeight // default .regular

    // Colors (hex strings like #RRGGBB; empty/nil = use default)
    public var textColor: String          // default "#FFFFFF"
    public var accentColor: String        // default "#FF6B9C"
    public var glowTint: String           // default "#FFFFFF"

    // Per-effect reaction weights (0...1, multiplied into master intensity)
    public var scaleReaction: Double      // default 1.0
    public var glowReaction: Double       // default 1.0
    public var borderReaction: Double     // default 1.0

    public static let `default`: NowPlayingAppearance
    public static let presets: [NamedPreset]
}

public struct NamedPreset: Equatable, Sendable {
    public let id: String       // "default", "vivid", "minimal", "neon", "mono"
    public let name: String     // "Default", "Vivid", "Minimal", "Neon", "Mono"
    public let appearance: NowPlayingAppearance
}
```

Preset values:

| Preset  | corner | padding | border | borderOp | titleW   | accent    | glow      |
|---------|--------|---------|--------|----------|----------|-----------|-----------|
| Default | 14     | 14      | 1      | 0.08     | semibold | #FF6B9C   | #FFFFFF   |
| Vivid   | 18     | 14      | 2      | 0.20     | bold     | #FF3D81   | #FF6B9C   |
| Minimal | 8      | 12      | 0      | 0.00     | regular  | #FFFFFF   | #FFFFFF   |
| Neon    | 22     | 14      | 2      | 0.35     | bold     | #00F0FF   | #00F0FF   |
| Mono    | 4      | 14      | 1      | 0.15     | medium   | #FFFFFF   | #FFFFFF   |

`NowPlayingPreferences` gets a new optional field:

```swift
public var appearance: NowPlayingAppearance
```

Decoder reads `appearance` with `decodeIfPresent`, falling back to `.default`. Existing keys (`audioReactivityIntensity`, etc.) stay where they are.

`NowPlayingPreferences` also gains a helper `func matchesPreset() -> NamedPreset?` that returns the preset whose `appearance` equals the current one, used by the UI to show the preset popup's current selection (or "Custom" when nothing matches).

## Widget Application

`NowPlayingWidgetView` consumes the appearance to drive:

- `clipShape(RoundedRectangle(cornerRadius: appearance.cornerRadius))`
- Border stroke: `Color(hex: textColor).opacity(borderOpacity + animatedPulse * borderReactionMax * borderReaction)`
- Border line width: `borderWidth + animatedPulse * borderReactionMaxWidth * borderReaction`
- `scaleEffect(1.0 + animatedPulse * scaleReactionMax * scaleReaction)`
- Glow shadow color: `Color(hex: glowTint).opacity(min(animatedPulse * glowReactionMax * glowReaction, 1))`

Title/subtitle weights map to `Font.Weight` and drive each style component's `Text(...).fontWeight(...)`. The Color hex utility (already used by `WallpaperPreset` color values) gets reused.

The existing global `audioReactivityIntensity` becomes the master multiplier passed through `pulseAmplitude`. Per-effect weights are read directly inside the widget view (no need to push them through the ViewModel).

## Window Architecture

Rename `LibraryWindowController` to `SettingsWindowController`. Top-level layout:

```
NSSplitView (horizontal)
├── Sidebar (NSScrollView wrapping NSOutlineView)   width 180
└── Detail container (NSView)                       fills remainder
```

`Section` enum drives the sidebar and detail swap:

```swift
enum SettingsSection: Hashable {
    case library
    case nowPlayingBasic
    case nowPlayingAppearance
    case nowPlayingReactivity
    case audioReactor
}
```

When the outline view selection changes, the controller calls `setDetailView(for: section)`, which removes the current detail subview and adds the appropriate `SectionView`.

Each detail surface is its own `NSStackView`-based view object:

- `LibrarySectionView`
- `NowPlayingBasicSectionView`
- `NowPlayingAppearanceSectionView`
- `NowPlayingReactivitySectionView`
- `AudioReactorSectionView`

Each section view owns its controls, exposes a `configure(...)` to load preferences, and reports changes via a delegate callback to the controller. The controller is the single source of truth for preferences and routes changes to the existing `LibraryWindowControllerDelegate`.

The delegate protocol stays largely the same (`didChange nowPlayingPreferences`, `didChange audioReactorPreferences`, etc.). One new delegate method is required: `didChange nowPlayingAppearance` — actually folded into the existing `didChange nowPlayingPreferences` since appearance lives inside that struct, so no protocol change.

## Default Behavior and Migration

- Existing on-disk `now-playing.json` files have no `appearance` key. Loading produces `NowPlayingAppearance.default` (matches the current widget look), so users see no visible change until they touch the new controls.
- Existing widget code paths that don't yet read `appearance` keep working during the rollout (e.g. `AlbumDominantStyle` reads its own constants for the first pass, then is migrated to read from appearance in the same plan).
- Color hex strings outside valid `#RRGGBB` format fall back to the preset default for that field. Validation lives in the appearance struct's decoder.

## Components

| Component | File | Responsibility |
|-----------|------|----------------|
| `NowPlayingAppearance` | `Sources/LunoEngineCore/NowPlaying/NowPlayingAppearance.swift` | Model, presets, hex color helpers |
| `NowPlayingPreferences` | existing | New optional `appearance` field + decoder fallback |
| `SettingsWindowController` | `Sources/LunoApp/Settings/SettingsWindowController.swift` (rename from `LibraryWindowController.swift`) | NSSplitView, sidebar, detail swap, preference persistence |
| `SettingsSidebar` | `Sources/LunoApp/Settings/SettingsSidebar.swift` | NSOutlineView data source/delegate |
| `LibrarySectionView` | `Sources/LunoApp/Settings/LibrarySectionView.swift` | Current wallpaper/preset/display UI |
| `NowPlayingBasicSectionView` | `Sources/LunoApp/Settings/NowPlayingBasicSectionView.swift` | Enable / Style / Pin / KeepVisible |
| `NowPlayingAppearanceSectionView` | `Sources/LunoApp/Settings/NowPlayingAppearanceSectionView.swift` | Preset, shape, colors, typography |
| `NowPlayingReactivitySectionView` | `Sources/LunoApp/Settings/NowPlayingReactivitySectionView.swift` | Master intensity + per-effect weights |
| `AudioReactorSectionView` | `Sources/LunoApp/Settings/AudioReactorSectionView.swift` | Existing reactor controls |
| `NowPlayingWidgetView` | existing | Read appearance, apply shape/colors/per-effect weights |

The existing `AppDelegate` and `LibraryWindowControllerDelegate` keep their public surface; only the type/file names change inside `LunoApp`. `AppDelegate` updates its references accordingly.

## Testing

Unit tests in `Tests/LunoEngineCoreTests/`:

- `NowPlayingAppearanceTests` — preset count, default values, equality, decoder fallback for legacy JSON without `appearance` key, decoder reading a saved appearance round-trips equal.
- `NowPlayingPreferencesTests` — extend existing tests to assert migration default and equality with new field.

No tests in `LunoApp` target (existing pattern — UI is AppKit and not unit tested). Manual QA matrix added to `docs/superpowers/qa/` covering each section, preset switching, and slider-flip-to-Custom behavior.

## Open Questions

None requiring a decision before implementation.

## Risks

- The window currently has a fixed content size (560×460). The new layout needs a flexible content size and a sensible minimum (~640×460) so the detail view doesn't crush parameter controls. Address by setting `window.minSize` on the redesigned controller.
- `NSColorWell` opens a system-wide color panel; multiple wells on the same panel share state in macOS, which is expected behavior but could surprise users mid-edit. Accept the standard system behavior.
- Renaming `LibraryWindowController` changes the type name visible from `AppDelegate`. Mechanical fix-up; no API leaks outside `LunoApp`.
