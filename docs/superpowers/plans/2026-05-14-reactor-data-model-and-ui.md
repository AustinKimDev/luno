# Reactor Data Model and UI Implementation Plan (Phase 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the data model, algorithms, renderer wiring, and Settings UI for the album-color contrast modes (Match / Contrast / Vivid) and four new reactor options (`mirrored`, `colorCycle`, `beatGate`, `motionTrail`). After this phase the existing 6 presets keep working, and the new fields are all set up for the new presets and wallpapers in later phases.

**Architecture:** Pure-Swift color math and small state structs live in a new file `AudioReactorColorMath.swift`. They are called from `AudioReactorPalette.resolved(with:)` (color modes) and from `MetalWallpaperRenderer.draw(in:)` (beat gate, color cycle, motion trail). The overlay shader gains two small branches (mirrored spectrum, beat-gate ring). The Settings UI gains a conditional segmented control and an Advanced box.

**Tech Stack:** Swift Package Manager, XCTest, AppKit/Metal. Tests are pure Swift (no Metal needed). Build commands: `swift build`, `swift test`.

**Spec reference:** `docs/superpowers/specs/2026-05-14-wallpapers-and-reactors-expansion-design.md`

**Pre-flight:** the working tree currently has uncommitted "Scale" slider work on `AudioReactorSectionView`, `AudioReactorPreferences`, `WallpaperRuntime`, and `AudioReactorPreferencesTests`. Task 0 commits this first so the plan executes against a clean main.

---

## File map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `Sources/LunoEngineCore/AudioReactorColorMath.swift` | RGB↔HSL, contrast algorithm, vivid algorithm, `BeatGate`, `MotionTrailBuffer`, color-cycle palette transform |
| Modify | `Sources/LunoEngineCore/AudioReactorPreferences.swift` | Add `AudioReactorAlbumColorMode` enum, add field to `AudioReactorPalette`, add `mirrored` to `AudioReactorSpectrumStyle`, add `colorCycle`/`motionTrail` to `AudioReactorStyle`, add `beatGate` to `AudioReactorPreferences`, rewire `resolved(with:)` |
| Modify | `Sources/LunoEngineCore/WallpaperRuntime.swift` | Hold `BeatGate` + `MotionTrailBuffer` state; apply color cycle CPU-side; pass new uniform flags to overlay shader; add mirrored + beat-gate branches in the Metal shader source |
| Modify | `Sources/LunoApp/Settings/AudioReactorSectionView.swift` | New segmented control for album mode + Advanced box with four controls |
| Modify | `Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift` | Extend Codable tests for new fields |
| Create | `Tests/LunoEngineCoreTests/AudioReactorColorMathTests.swift` | Unit tests for all new pure logic |

Net Swift LOC: ~600 added, ~80 modified. Net Metal LOC: ~40 added inside the existing inline shader string.

---

## Task 0: Commit existing "Scale" WIP

**Files:**
- Modify: `Sources/LunoApp/Settings/AudioReactorSectionView.swift`
- Modify: `Sources/LunoEngineCore/AudioReactorPreferences.swift`
- Modify: `Sources/LunoEngineCore/WallpaperRuntime.swift`
- Modify: `Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift`

- [ ] **Step 1: Confirm existing diff is the scale-slider feature**

Run: `git diff --stat`
Expected: 4 files changed, ~174 insertions, ~30 deletions. All changes relate to the `scale` field, `AudioReactorOverlayLayoutMetrics`, and a Scale slider in the settings view.

- [ ] **Step 2: Run tests to verify current state**

Run: `swift test --filter AudioReactorPreferencesTests`
Expected: PASS — the diff already includes tests for `style.scale` defaults and clamping.

- [ ] **Step 3: Commit the WIP**

```bash
git add Sources/LunoApp/Settings/AudioReactorSectionView.swift \
        Sources/LunoEngineCore/AudioReactorPreferences.swift \
        Sources/LunoEngineCore/WallpaperRuntime.swift \
        Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift
git commit -m "$(cat <<'EOF'
feat(reactor): add overlay scale slider with portrait-aware layout

Adds a 0.5–1.5 scale on AudioReactorStyle, an AudioReactorOverlayLayoutMetrics
helper that computes scale + rail width + radial scale per-aspect-ratio, and a
Settings slider bound to style.scale. Overlay shader uses the metrics so the
reactor fits portrait and ultrawide displays.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Verify clean tree**

Run: `git status`
Expected: `nothing to commit, working tree clean`.

---

## Task 1: HSL conversion utility

**Files:**
- Create: `Sources/LunoEngineCore/AudioReactorColorMath.swift`
- Create: `Tests/LunoEngineCoreTests/AudioReactorColorMathTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/LunoEngineCoreTests/AudioReactorColorMathTests.swift`:

```swift
import XCTest
@testable import LunoEngineCore

final class AudioReactorColorMathTests: XCTestCase {
    func testRGBToHSLRoundTripPreservesColor() {
        let cases: [(Double, Double, Double)] = [
            (1.0, 0.0, 0.0),        // pure red
            (0.0, 1.0, 0.0),        // pure green
            (0.0, 0.0, 1.0),        // pure blue
            (0.5, 0.5, 0.5),        // mid gray
            (0.95, 0.2, 0.6),       // pink
            (0.0, 0.0, 0.0),        // black
            (1.0, 1.0, 1.0)         // white
        ]
        for (r, g, b) in cases {
            let hsl = AudioReactorColorMath.rgbToHSL(r: r, g: g, b: b)
            let back = AudioReactorColorMath.hslToRGB(h: hsl.h, s: hsl.s, l: hsl.l)
            XCTAssertEqual(back.r, r, accuracy: 0.001, "red mismatch for \(r),\(g),\(b)")
            XCTAssertEqual(back.g, g, accuracy: 0.001, "green mismatch")
            XCTAssertEqual(back.b, b, accuracy: 0.001, "blue mismatch")
        }
    }

    func testHSLKnownValues() {
        // Pure red: h=0, s=1, l=0.5
        let red = AudioReactorColorMath.rgbToHSL(r: 1, g: 0, b: 0)
        XCTAssertEqual(red.h, 0, accuracy: 0.001)
        XCTAssertEqual(red.s, 1, accuracy: 0.001)
        XCTAssertEqual(red.l, 0.5, accuracy: 0.001)

        // Pure green: h=120, s=1, l=0.5
        let green = AudioReactorColorMath.rgbToHSL(r: 0, g: 1, b: 0)
        XCTAssertEqual(green.h, 120, accuracy: 0.001)

        // Gray: s=0
        let gray = AudioReactorColorMath.rgbToHSL(r: 0.5, g: 0.5, b: 0.5)
        XCTAssertEqual(gray.s, 0, accuracy: 0.001)
        XCTAssertEqual(gray.l, 0.5, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AudioReactorColorMathTests`
Expected: FAIL — `AudioReactorColorMath` not found.

- [ ] **Step 3: Implement HSL conversion**

Create `Sources/LunoEngineCore/AudioReactorColorMath.swift`:

```swift
import Foundation

public enum AudioReactorColorMath {
    public struct HSL: Equatable, Sendable {
        public var h: Double  // 0..360
        public var s: Double  // 0..1
        public var l: Double  // 0..1
    }

    public struct RGB: Equatable, Sendable {
        public var r: Double
        public var g: Double
        public var b: Double
    }

    public static func rgbToHSL(r: Double, g: Double, b: Double) -> HSL {
        let cr = clamp01(r)
        let cg = clamp01(g)
        let cb = clamp01(b)
        let maxC = max(cr, max(cg, cb))
        let minC = min(cr, min(cg, cb))
        let delta = maxC - minC
        let l = (maxC + minC) / 2

        guard delta > 0.00001 else {
            return HSL(h: 0, s: 0, l: l)
        }

        let s = l > 0.5 ? delta / (2 - maxC - minC) : delta / (maxC + minC)
        var h: Double
        if maxC == cr {
            h = ((cg - cb) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxC == cg {
            h = (cb - cr) / delta + 2
        } else {
            h = (cr - cg) / delta + 4
        }
        h *= 60
        if h < 0 { h += 360 }
        return HSL(h: h, s: s, l: l)
    }

    public static func hslToRGB(h: Double, s: Double, l: Double) -> RGB {
        let cs = clamp01(s)
        let cl = clamp01(l)
        guard cs > 0.00001 else {
            return RGB(r: cl, g: cl, b: cl)
        }

        let c = (1 - abs(2 * cl - 1)) * cs
        let hp = h.truncatingRemainder(dividingBy: 360) / 60
        let normalized = hp < 0 ? hp + 6 : hp
        let x = c * (1 - abs(normalized.truncatingRemainder(dividingBy: 2) - 1))
        let m = cl - c / 2

        let (r1, g1, b1): (Double, Double, Double)
        switch Int(floor(normalized)) {
        case 0: (r1, g1, b1) = (c, x, 0)
        case 1: (r1, g1, b1) = (x, c, 0)
        case 2: (r1, g1, b1) = (0, c, x)
        case 3: (r1, g1, b1) = (0, x, c)
        case 4: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        return RGB(r: r1 + m, g: g1 + m, b: b1 + m)
    }

    static func clamp01(_ v: Double) -> Double {
        guard v.isFinite else { return 0 }
        return min(max(v, 0), 1)
    }

    static func luma(r: Double, g: Double, b: Double) -> Double {
        r * 0.2126 + g * 0.7152 + b * 0.0722
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AudioReactorColorMathTests`
Expected: PASS — both tests green.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/AudioReactorColorMath.swift \
        Tests/LunoEngineCoreTests/AudioReactorColorMathTests.swift
git commit -m "$(cat <<'EOF'
feat(reactor): add RGB↔HSL color math utilities

New AudioReactorColorMath module with rgbToHSL/hslToRGB and a luma helper,
needed by the upcoming album-color contrast and vivid modes. Pure Swift,
no Metal.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: AudioReactorAlbumColorMode enum + field

**Files:**
- Modify: `Sources/LunoEngineCore/AudioReactorPreferences.swift:46-49` (add enum near `AudioReactorPaletteSource`)
- Modify: `Sources/LunoEngineCore/AudioReactorPreferences.swift:51-102` (`AudioReactorPalette` struct)
- Modify: `Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift`

- [ ] **Step 1: Write failing tests**

Append to `AudioReactorPreferencesTests.swift`:

```swift
    func testAlbumColorModeDecodesDefaultWhenAbsent() throws {
        let json = """
        {
          "source": "albumArtwork",
          "primaryColor": "#24C7FF",
          "secondaryColor": "#FF6B9C",
          "accentColor": "#7A5CFF",
          "glowColor": "#FFFFFF"
        }
        """.data(using: .utf8)!
        let palette = try JSONDecoder().decode(AudioReactorPalette.self, from: json)
        XCTAssertEqual(palette.albumColorMode, .contrast)
    }

    func testAlbumColorModeRoundTrips() throws {
        let palette = AudioReactorPalette(
            source: .albumArtwork,
            albumColorMode: .vivid,
            primaryColor: "#24C7FF",
            secondaryColor: "#FF6B9C",
            accentColor: "#7A5CFF",
            glowColor: "#FFFFFF"
        )
        let data = try JSONEncoder().encode(palette)
        let decoded = try JSONDecoder().decode(AudioReactorPalette.self, from: data)
        XCTAssertEqual(decoded.albumColorMode, .vivid)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AudioReactorPreferencesTests`
Expected: FAIL — `albumColorMode` does not exist; `AudioReactorPalette.init` does not accept it.

- [ ] **Step 3: Add enum and field**

In `AudioReactorPreferences.swift`, immediately below the `AudioReactorPaletteSource` enum (line ~49), insert:

```swift
public enum AudioReactorAlbumColorMode: String, Codable, Equatable, Sendable, CaseIterable {
    case match
    case contrast
    case vivid
}
```

In `AudioReactorPalette`, add the new field after `source`:

```swift
public var source: AudioReactorPaletteSource
public var albumColorMode: AudioReactorAlbumColorMode
public var primaryColor: String
public var secondaryColor: String
public var accentColor: String
public var glowColor: String
```

Update both initializers — the public init and the private `uncheckedPrimaryColor` init — to accept `albumColorMode` with default `.contrast`:

```swift
public init(
    source: AudioReactorPaletteSource = .manual,
    albumColorMode: AudioReactorAlbumColorMode = .contrast,
    primaryColor: String,
    secondaryColor: String,
    accentColor: String,
    glowColor: String
) {
    self.source = source
    self.albumColorMode = albumColorMode
    self.primaryColor = Self.normalizedHex(primaryColor) ?? Self.default.primaryColor
    self.secondaryColor = Self.normalizedHex(secondaryColor) ?? Self.default.secondaryColor
    self.accentColor = Self.normalizedHex(accentColor) ?? Self.default.accentColor
    self.glowColor = Self.normalizedHex(glowColor) ?? Self.default.glowColor
}

private init(
    source: AudioReactorPaletteSource = .manual,
    albumColorMode: AudioReactorAlbumColorMode = .contrast,
    uncheckedPrimaryColor primaryColor: String,
    secondaryColor: String,
    accentColor: String,
    glowColor: String
) {
    self.source = source
    self.albumColorMode = albumColorMode
    self.primaryColor = primaryColor
    self.secondaryColor = secondaryColor
    self.accentColor = accentColor
    self.glowColor = glowColor
}
```

Update `init(from:)` to read with default:

```swift
public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
        source: try container.decodeIfPresent(AudioReactorPaletteSource.self, forKey: .source) ?? .manual,
        albumColorMode: try container.decodeIfPresent(AudioReactorAlbumColorMode.self, forKey: .albumColorMode) ?? .contrast,
        primaryColor: try container.decodeIfPresent(String.self, forKey: .primaryColor) ?? Self.default.primaryColor,
        secondaryColor: try container.decodeIfPresent(String.self, forKey: .secondaryColor) ?? Self.default.secondaryColor,
        accentColor: try container.decodeIfPresent(String.self, forKey: .accentColor) ?? Self.default.accentColor,
        glowColor: try container.decodeIfPresent(String.self, forKey: .glowColor) ?? Self.default.glowColor
    )
}
```

Note: Swift will auto-synthesize the `CodingKeys` to include `albumColorMode`. No explicit `CodingKeys` enum exists today, so no change needed.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AudioReactorPreferencesTests`
Expected: PASS — including all prior tests, since the new field has a default.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/AudioReactorPreferences.swift \
        Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift
git commit -m "$(cat <<'EOF'
feat(reactor): add AudioReactorAlbumColorMode (match/contrast/vivid)

New enum and field on AudioReactorPalette controlling how album-derived
reactor colors are corrected for visibility against album-reactive
wallpapers. Default contrast preserves user safety; backwards-compatible
decoding leaves existing prefs files untouched.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Contrast algorithm

**Files:**
- Modify: `Sources/LunoEngineCore/AudioReactorColorMath.swift`
- Modify: `Tests/LunoEngineCoreTests/AudioReactorColorMathTests.swift`

- [ ] **Step 1: Write failing tests**

Append to `AudioReactorColorMathTests.swift`:

```swift
    func testContrastLumaCorrectionShiftsAwayFromDarkBackground() {
        // Album bg: very dark navy. Reactor primary: also dark navy.
        let albumBg = AudioReactorColorMath.RGB(r: 0.05, g: 0.06, b: 0.18)
        let albumPrimary = AudioReactorColorMath.RGB(r: 0.92, g: 0.32, b: 0.42)
        let albumSecondary = AudioReactorColorMath.RGB(r: 0.12, g: 0.55, b: 0.94)
        let reactor = AudioReactorColorMath.RGB(r: 0.07, g: 0.08, b: 0.22)

        let corrected = AudioReactorColorMath.applyContrast(
            channel: reactor,
            role: .primary,
            albumBackground: albumBg,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary
        )

        let reactorLuma = AudioReactorColorMath.luma(r: reactor.r, g: reactor.g, b: reactor.b)
        let correctedLuma = AudioReactorColorMath.luma(r: corrected.r, g: corrected.g, b: corrected.b)
        XCTAssertGreaterThan(correctedLuma - reactorLuma, 0.25, "expected luma boost away from dark bg")
    }

    func testContrastHueRotationOnPrimaryClashWithAlbumPrimary() {
        let albumBg = AudioReactorColorMath.RGB(r: 0.1, g: 0.1, b: 0.1)
        let albumPrimary = AudioReactorColorMath.RGB(r: 0.95, g: 0.2, b: 0.2)  // red
        let albumSecondary = AudioReactorColorMath.RGB(r: 0.2, g: 0.95, b: 0.2)  // green
        let reactor = AudioReactorColorMath.RGB(r: 0.9, g: 0.18, b: 0.22)  // also red

        let corrected = AudioReactorColorMath.applyContrast(
            channel: reactor,
            role: .primary,
            albumBackground: albumBg,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary
        )

        let albumHue = AudioReactorColorMath.rgbToHSL(r: albumPrimary.r, g: albumPrimary.g, b: albumPrimary.b).h
        let correctedHue = AudioReactorColorMath.rgbToHSL(r: corrected.r, g: corrected.g, b: corrected.b).h
        let hueDelta = min(abs(correctedHue - albumHue), 360 - abs(correctedHue - albumHue))
        XCTAssertGreaterThan(hueDelta, 60, "expected hue rotation away from album primary")
    }

    func testContrastGlowLockedNearWhite() {
        let albumBg = AudioReactorColorMath.RGB(r: 0.05, g: 0.05, b: 0.05)
        let albumPrimary = AudioReactorColorMath.RGB(r: 0.9, g: 0.3, b: 0.4)
        let albumSecondary = AudioReactorColorMath.RGB(r: 0.2, g: 0.7, b: 0.9)
        let reactor = AudioReactorColorMath.RGB(r: 0.2, g: 0.2, b: 0.2)  // dark

        let corrected = AudioReactorColorMath.applyContrast(
            channel: reactor,
            role: .glow,
            albumBackground: albumBg,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary
        )

        let luma = AudioReactorColorMath.luma(r: corrected.r, g: corrected.g, b: corrected.b)
        XCTAssertGreaterThanOrEqual(luma, 0.85, "glow must lock to luma >= 0.85")
    }

    func testContrastSaturationFloor() {
        // After luma boost, an originally low-sat reactor channel should be pushed to >= 0.55 sat.
        let albumBg = AudioReactorColorMath.RGB(r: 0.05, g: 0.05, b: 0.05)
        let albumPrimary = AudioReactorColorMath.RGB(r: 0.9, g: 0.3, b: 0.4)
        let albumSecondary = AudioReactorColorMath.RGB(r: 0.2, g: 0.7, b: 0.9)
        let reactor = AudioReactorColorMath.RGB(r: 0.5, g: 0.52, b: 0.55)  // near gray

        let corrected = AudioReactorColorMath.applyContrast(
            channel: reactor,
            role: .secondary,
            albumBackground: albumBg,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary
        )

        let sat = AudioReactorColorMath.rgbToHSL(r: corrected.r, g: corrected.g, b: corrected.b).s
        XCTAssertGreaterThanOrEqual(sat, 0.54)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AudioReactorColorMathTests`
Expected: FAIL — `applyContrast` and `ChannelRole` do not exist.

- [ ] **Step 3: Implement contrast algorithm**

Append to `AudioReactorColorMath.swift` (still inside the `enum AudioReactorColorMath`):

```swift
public enum ChannelRole: Equatable, Sendable {
    case primary
    case secondary
    case accent
    case glow
}

public static func applyContrast(
    channel: RGB,
    role: ChannelRole,
    albumBackground: RGB,
    albumPrimary: RGB,
    albumSecondary: RGB
) -> RGB {
    // Monochrome album fallback: if album primary is essentially gray, skip correction.
    let albumPrimaryHSL = rgbToHSL(r: albumPrimary.r, g: albumPrimary.g, b: albumPrimary.b)
    if albumPrimaryHSL.s < 0.08 {
        return clampedFinish(channel: channel, role: role)
    }

    var hsl = rgbToHSL(r: channel.r, g: channel.g, b: channel.b)
    let channelLuma = luma(r: channel.r, g: channel.g, b: channel.b)
    let bgLuma = luma(r: albumBackground.r, g: albumBackground.g, b: albumBackground.b)

    // 1. Luma collision
    if abs(channelLuma - bgLuma) < 0.18 {
        let direction: Double = bgLuma < 0.5 ? 1 : -1
        hsl.l = clamp01(hsl.l + direction * 0.35)
    }

    // 2. Hue collision (primary only)
    if role == .primary {
        let albumPrimaryHue = albumPrimaryHSL.h
        let albumSecondaryHue = rgbToHSL(r: albumSecondary.r, g: albumSecondary.g, b: albumSecondary.b).h
        let hueDelta = hueDistance(hsl.h, albumPrimaryHue)
        let satDelta = abs(hsl.s - albumPrimaryHSL.s)
        if hueDelta < 30 && satDelta < 0.2 {
            let plus = (hsl.h + 120).truncatingRemainder(dividingBy: 360)
            let minus = (hsl.h - 120 + 360).truncatingRemainder(dividingBy: 360)
            let plusDistance = hueDistance(plus, albumSecondaryHue)
            let minusDistance = hueDistance(minus, albumSecondaryHue)
            hsl.h = plusDistance > minusDistance ? plus : minus
        }
    }

    // 3. Saturation floor
    if hsl.s < 0.35 {
        hsl.s = 0.55
    }

    let rotated = hslToRGB(h: hsl.h, s: hsl.s, l: hsl.l)
    return clampedFinish(channel: rotated, role: role)
}

private static func clampedFinish(channel: RGB, role: ChannelRole) -> RGB {
    // 4. Glow lock
    guard role == .glow else { return channel }
    let lum = luma(r: channel.r, g: channel.g, b: channel.b)
    guard lum < 0.85 else { return channel }
    let hsl = rgbToHSL(r: channel.r, g: channel.g, b: channel.b)
    return hslToRGB(h: hsl.h, s: hsl.s, l: max(hsl.l, 0.9))
}

static func hueDistance(_ a: Double, _ b: Double) -> Double {
    let raw = abs(a - b).truncatingRemainder(dividingBy: 360)
    return min(raw, 360 - raw)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AudioReactorColorMathTests`
Expected: PASS — all four contrast tests green.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/AudioReactorColorMath.swift \
        Tests/LunoEngineCoreTests/AudioReactorColorMathTests.swift
git commit -m "$(cat <<'EOF'
feat(reactor): contrast algorithm for album-derived reactor colors

Adds AudioReactorColorMath.applyContrast with luma/hue/saturation
correction and a glow lock. Falls back to no correction on monochrome
album art (saturation < 0.08).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Vivid algorithm

**Files:**
- Modify: `Sources/LunoEngineCore/AudioReactorColorMath.swift`
- Modify: `Tests/LunoEngineCoreTests/AudioReactorColorMathTests.swift`

- [ ] **Step 1: Write failing tests**

Append to `AudioReactorColorMathTests.swift`:

```swift
    func testVividProducesExpectedLightnessPerChannel() {
        let albumPrimary = AudioReactorColorMath.RGB(r: 0.95, g: 0.2, b: 0.6)
        let albumSecondary = AudioReactorColorMath.RGB(r: 0.2, g: 0.7, b: 0.9)
        let albumHighlight = AudioReactorColorMath.RGB(r: 0.95, g: 0.9, b: 0.55)

        let primary = AudioReactorColorMath.applyVivid(
            role: .primary,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary,
            albumHighlight: albumHighlight
        )
        let primaryHSL = AudioReactorColorMath.rgbToHSL(r: primary.r, g: primary.g, b: primary.b)
        XCTAssertEqual(primaryHSL.l, 0.78, accuracy: 0.01)
        XCTAssertEqual(primaryHSL.s, 1.0, accuracy: 0.01)

        let secondary = AudioReactorColorMath.applyVivid(
            role: .secondary,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary,
            albumHighlight: albumHighlight
        )
        let secondaryHSL = AudioReactorColorMath.rgbToHSL(r: secondary.r, g: secondary.g, b: secondary.b)
        XCTAssertEqual(secondaryHSL.l, 0.65, accuracy: 0.01)

        let glow = AudioReactorColorMath.applyVivid(
            role: .glow,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary,
            albumHighlight: albumHighlight
        )
        let glowHSL = AudioReactorColorMath.rgbToHSL(r: glow.r, g: glow.g, b: glow.b)
        XCTAssertEqual(glowHSL.l, 0.95, accuracy: 0.01)
        XCTAssertEqual(glowHSL.s, 0.5, accuracy: 0.01)
    }

    func testVividPullsHueFromCorrectAlbumChannel() {
        let albumPrimary = AudioReactorColorMath.RGB(r: 0.95, g: 0.2, b: 0.2)   // red
        let albumSecondary = AudioReactorColorMath.RGB(r: 0.2, g: 0.95, b: 0.2) // green
        let albumHighlight = AudioReactorColorMath.RGB(r: 0.2, g: 0.2, b: 0.95) // blue

        let primary = AudioReactorColorMath.applyVivid(
            role: .primary,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary,
            albumHighlight: albumHighlight
        )
        let primaryHue = AudioReactorColorMath.rgbToHSL(r: primary.r, g: primary.g, b: primary.b).h
        let albumPrimaryHue = AudioReactorColorMath.rgbToHSL(r: albumPrimary.r, g: albumPrimary.g, b: albumPrimary.b).h
        XCTAssertEqual(primaryHue, albumPrimaryHue, accuracy: 1.0)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AudioReactorColorMathTests`
Expected: FAIL — `applyVivid` does not exist.

- [ ] **Step 3: Implement vivid algorithm**

Append to `AudioReactorColorMath.swift`:

```swift
public static func applyVivid(
    role: ChannelRole,
    albumPrimary: RGB,
    albumSecondary: RGB,
    albumHighlight: RGB
) -> RGB {
    let (source, sat, lightness): (RGB, Double, Double)
    switch role {
    case .primary:
        source = albumPrimary
        sat = 1.0
        lightness = 0.78
    case .secondary:
        source = albumSecondary
        sat = 1.0
        lightness = 0.65
    case .accent:
        source = albumHighlight
        sat = 0.95
        lightness = 0.55
    case .glow:
        source = albumHighlight
        sat = 0.5
        lightness = 0.95
    }
    let hue = rgbToHSL(r: source.r, g: source.g, b: source.b).h
    return hslToRGB(h: hue, s: sat, l: lightness)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AudioReactorColorMathTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/AudioReactorColorMath.swift \
        Tests/LunoEngineCoreTests/AudioReactorColorMathTests.swift
git commit -m "$(cat <<'EOF'
feat(reactor): vivid algorithm forces lightness/saturation per channel

Vivid mode borrows hue from the album palette but locks lightness and
saturation per role (primary 0.78/1.0, secondary 0.65/1.0,
accent 0.55/0.95, glow 0.95/0.5).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Wire `resolved(with:)` to branch on mode

**Files:**
- Modify: `Sources/LunoEngineCore/AudioReactorPreferences.swift:104-113` (`resolved(with:)`)
- Modify: `Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift`

- [ ] **Step 1: Write failing tests**

Append to `AudioReactorPreferencesTests.swift`:

```swift
    func testResolvedManualSourceIgnoresAlbumMode() {
        let palette = AudioReactorPalette(
            source: .manual,
            albumColorMode: .vivid,
            primaryColor: "#24C7FF",
            secondaryColor: "#FF6B9C",
            accentColor: "#7A5CFF",
            glowColor: "#FFFFFF"
        )
        let resolved = palette.resolved(with: .fallback)
        XCTAssertEqual(resolved.primaryColor, "#24C7FF")
    }

    func testResolvedMatchModePreservesAlbumColors() {
        let palette = AudioReactorPalette(
            source: .albumArtwork,
            albumColorMode: .match,
            primaryColor: "#000000",
            secondaryColor: "#000000",
            accentColor: "#000000",
            glowColor: "#000000"
        )
        let album = AlbumPalette(
            background: SIMD4<Float>(0.1, 0.1, 0.1, 1),
            primary: SIMD4<Float>(0.9, 0.2, 0.5, 1),
            secondary: SIMD4<Float>(0.2, 0.6, 0.9, 1),
            highlight: SIMD4<Float>(0.95, 0.85, 0.5, 1)
        )
        let resolved = palette.resolved(with: album)
        XCTAssertEqual(resolved.primaryColor, "#E63380")
    }

    func testResolvedContrastModeBoostsAgainstDarkBackground() {
        let palette = AudioReactorPalette(
            source: .albumArtwork,
            albumColorMode: .contrast,
            primaryColor: "#000000",
            secondaryColor: "#000000",
            accentColor: "#000000",
            glowColor: "#000000"
        )
        let album = AlbumPalette(
            background: SIMD4<Float>(0.05, 0.05, 0.1, 1),
            primary: SIMD4<Float>(0.10, 0.12, 0.20, 1),     // dark navy primary, low luma
            secondary: SIMD4<Float>(0.20, 0.70, 0.95, 1),
            highlight: SIMD4<Float>(0.95, 0.85, 0.5, 1)
        )
        let resolved = palette.resolved(with: album)
        let hexDigits = resolved.primaryColor.dropFirst()  // strip "#"
        XCTAssertEqual(hexDigits.count, 6)
        let r = Int(hexDigits.prefix(2), radix: 16) ?? 0
        let g = Int(hexDigits.dropFirst(2).prefix(2), radix: 16) ?? 0
        let b = Int(hexDigits.dropFirst(4).prefix(2), radix: 16) ?? 0
        let luma = Double(r) * 0.2126 / 255 + Double(g) * 0.7152 / 255 + Double(b) * 0.0722 / 255
        XCTAssertGreaterThan(luma, 0.30, "contrast must lift away from dark navy background")
    }

    func testResolvedVividModeProducesHighLightnessPrimary() {
        let palette = AudioReactorPalette(
            source: .albumArtwork,
            albumColorMode: .vivid,
            primaryColor: "#000000",
            secondaryColor: "#000000",
            accentColor: "#000000",
            glowColor: "#000000"
        )
        let album = AlbumPalette(
            background: SIMD4<Float>(0.05, 0.05, 0.05, 1),
            primary: SIMD4<Float>(0.95, 0.2, 0.4, 1),
            secondary: SIMD4<Float>(0.2, 0.6, 0.9, 1),
            highlight: SIMD4<Float>(0.95, 0.85, 0.5, 1)
        )
        let resolved = palette.resolved(with: album)
        let hex = resolved.primaryColor.dropFirst()
        let r = Int(hex.prefix(2), radix: 16) ?? 0
        let g = Int(hex.dropFirst(2).prefix(2), radix: 16) ?? 0
        let b = Int(hex.dropFirst(4).prefix(2), radix: 16) ?? 0
        let avg = (Double(r) + Double(g) + Double(b)) / (3 * 255)
        XCTAssertGreaterThan(avg, 0.55, "vivid primary should be high lightness")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AudioReactorPreferencesTests`
Expected: FAIL — `resolved(with:)` does not yet branch on mode.

- [ ] **Step 3: Rewrite `resolved(with:)`**

Replace the existing `resolved(with:)` in `AudioReactorPreferences.swift` (around line 104):

```swift
public func resolved(with albumPalette: AlbumPalette) -> AudioReactorPalette {
    guard source == .albumArtwork else { return self }

    let bg = Self.rgb(from: albumPalette.background)
    let albumP = Self.rgb(from: albumPalette.primary)
    let albumS = Self.rgb(from: albumPalette.secondary)
    let albumH = Self.rgb(from: albumPalette.highlight)

    switch albumColorMode {
    case .match:
        return AudioReactorPalette(
            source: source,
            albumColorMode: albumColorMode,
            primaryColor: Self.hexString(from: albumPalette.primary),
            secondaryColor: Self.hexString(from: albumPalette.secondary),
            accentColor: Self.hexString(from: albumPalette.highlight),
            glowColor: Self.hexString(from: Self.mix(albumPalette.highlight, SIMD4<Float>(1, 1, 1, 1), amount: 0.5))
        )
    case .contrast:
        let primary = AudioReactorColorMath.applyContrast(channel: albumP, role: .primary, albumBackground: bg, albumPrimary: albumP, albumSecondary: albumS)
        let secondary = AudioReactorColorMath.applyContrast(channel: albumS, role: .secondary, albumBackground: bg, albumPrimary: albumP, albumSecondary: albumS)
        let accent = AudioReactorColorMath.applyContrast(channel: albumH, role: .accent, albumBackground: bg, albumPrimary: albumP, albumSecondary: albumS)
        let glowSource = AudioReactorColorMath.RGB(
            r: (albumH.r + 1) * 0.5,
            g: (albumH.g + 1) * 0.5,
            b: (albumH.b + 1) * 0.5
        )
        let glow = AudioReactorColorMath.applyContrast(channel: glowSource, role: .glow, albumBackground: bg, albumPrimary: albumP, albumSecondary: albumS)
        return AudioReactorPalette(
            source: source,
            albumColorMode: albumColorMode,
            primaryColor: Self.hex(from: primary),
            secondaryColor: Self.hex(from: secondary),
            accentColor: Self.hex(from: accent),
            glowColor: Self.hex(from: glow)
        )
    case .vivid:
        let primary = AudioReactorColorMath.applyVivid(role: .primary, albumPrimary: albumP, albumSecondary: albumS, albumHighlight: albumH)
        let secondary = AudioReactorColorMath.applyVivid(role: .secondary, albumPrimary: albumP, albumSecondary: albumS, albumHighlight: albumH)
        let accent = AudioReactorColorMath.applyVivid(role: .accent, albumPrimary: albumP, albumSecondary: albumS, albumHighlight: albumH)
        let glow = AudioReactorColorMath.applyVivid(role: .glow, albumPrimary: albumP, albumSecondary: albumS, albumHighlight: albumH)
        return AudioReactorPalette(
            source: source,
            albumColorMode: albumColorMode,
            primaryColor: Self.hex(from: primary),
            secondaryColor: Self.hex(from: secondary),
            accentColor: Self.hex(from: accent),
            glowColor: Self.hex(from: glow)
        )
    }
}

private static func rgb(from vector: SIMD4<Float>) -> AudioReactorColorMath.RGB {
    AudioReactorColorMath.RGB(
        r: Double(min(max(vector.x, 0), 1)),
        g: Double(min(max(vector.y, 0), 1)),
        b: Double(min(max(vector.z, 0), 1))
    )
}

private static func hex(from rgb: AudioReactorColorMath.RGB) -> String {
    let r = UInt8(round(min(max(rgb.r, 0), 1) * 255))
    let g = UInt8(round(min(max(rgb.g, 0), 1) * 255))
    let b = UInt8(round(min(max(rgb.b, 0), 1) * 255))
    return String(format: "#%02X%02X%02X", r, g, b)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AudioReactorPreferencesTests`
Expected: PASS — all four new mode tests plus all prior tests.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/AudioReactorPreferences.swift \
        Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift
git commit -m "$(cat <<'EOF'
feat(reactor): resolve album palette through match/contrast/vivid

AudioReactorPalette.resolved(with:) now branches on albumColorMode.
Match preserves existing behavior, contrast applies the auto correction,
vivid forces lightness/saturation per channel.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Add `mirrored` field to `AudioReactorSpectrumStyle`

**Files:**
- Modify: `Sources/LunoEngineCore/AudioReactorPreferences.swift:139-209` (`AudioReactorSpectrumStyle`)
- Modify: `Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift`

- [ ] **Step 1: Write failing test**

Append to `AudioReactorPreferencesTests.swift`:

```swift
    func testSpectrumMirroredDefaultsFalseAndRoundTrips() throws {
        XCTAssertFalse(AudioReactorSpectrumStyle.default.mirrored)

        let style = AudioReactorSpectrumStyle(
            layout: .bottom,
            barCount: 48,
            barWidth: 0.5,
            barHeight: 0.7,
            spacing: 0.3,
            radius: 0.5,
            roundness: 0.8,
            smoothing: 0.5,
            glow: 0.5,
            arcStartDegrees: -150,
            arcEndDegrees: 150,
            mirrored: true
        )
        let data = try JSONEncoder().encode(style)
        let decoded = try JSONDecoder().decode(AudioReactorSpectrumStyle.self, from: data)
        XCTAssertTrue(decoded.mirrored)
    }

    func testSpectrumMirroredDecodesDefaultWhenAbsent() throws {
        let json = """
        {"layout":"bottom","barCount":48,"barWidth":0.5,"barHeight":0.7,"spacing":0.3,"radius":0.5,"roundness":0.8,"smoothing":0.5,"glow":0.5,"arcStartDegrees":-150,"arcEndDegrees":150}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AudioReactorSpectrumStyle.self, from: json)
        XCTAssertFalse(decoded.mirrored)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AudioReactorPreferencesTests`
Expected: FAIL — `mirrored` does not exist.

- [ ] **Step 3: Add the field**

In `AudioReactorSpectrumStyle`:

Add property:

```swift
public var mirrored: Bool
```

Update designated initializer to accept it with default `false`:

```swift
public init(
    layout: AudioReactorVisualizerLayout,
    barCount: Int,
    barWidth: Double,
    barHeight: Double,
    spacing: Double,
    radius: Double,
    roundness: Double,
    smoothing: Double,
    glow: Double,
    arcStartDegrees: Double,
    arcEndDegrees: Double,
    mirrored: Bool = false
) {
    self.layout = layout
    self.barCount = Self.clamp(barCount, min: 8, max: 96)
    self.barWidth = Self.clamp01(barWidth)
    self.barHeight = Self.clamp01(barHeight)
    self.spacing = Self.clamp01(spacing)
    self.radius = Self.clamp01(radius)
    self.roundness = Self.clamp01(roundness)
    self.smoothing = Self.clamp01(smoothing)
    self.glow = Self.clamp01(glow)
    self.arcStartDegrees = Self.clampAngle(arcStartDegrees)
    self.arcEndDegrees = Self.clampAngle(arcEndDegrees)
    self.mirrored = mirrored
}
```

Update `init(from:)`:

```swift
public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
        layout: try container.decodeIfPresent(AudioReactorVisualizerLayout.self, forKey: .layout) ?? .bottom,
        barCount: try container.decodeIfPresent(Int.self, forKey: .barCount) ?? 48,
        barWidth: try container.decodeIfPresent(Double.self, forKey: .barWidth) ?? 0.48,
        barHeight: try container.decodeIfPresent(Double.self, forKey: .barHeight) ?? 0.74,
        spacing: try container.decodeIfPresent(Double.self, forKey: .spacing) ?? 0.35,
        radius: try container.decodeIfPresent(Double.self, forKey: .radius) ?? 0.56,
        roundness: try container.decodeIfPresent(Double.self, forKey: .roundness) ?? 0.82,
        smoothing: try container.decodeIfPresent(Double.self, forKey: .smoothing) ?? 0.45,
        glow: try container.decodeIfPresent(Double.self, forKey: .glow) ?? 0.48,
        arcStartDegrees: try container.decodeIfPresent(Double.self, forKey: .arcStartDegrees) ?? -150,
        arcEndDegrees: try container.decodeIfPresent(Double.self, forKey: .arcEndDegrees) ?? 150,
        mirrored: try container.decodeIfPresent(Bool.self, forKey: .mirrored) ?? false
    )
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AudioReactorPreferencesTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/AudioReactorPreferences.swift \
        Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift
git commit -m "$(cat <<'EOF'
feat(reactor): add mirrored field to AudioReactorSpectrumStyle

Enables left/right symmetric spectrum rendering. Defaults to false;
shader wiring lands in a later task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Add `colorCycle` and `motionTrail` to `AudioReactorStyle`

**Files:**
- Modify: `Sources/LunoEngineCore/AudioReactorPreferences.swift` (`AudioReactorStyle`)
- Modify: `Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift`

- [ ] **Step 1: Write failing test**

Append to `AudioReactorPreferencesTests.swift`:

```swift
    func testStyleColorCycleAndMotionTrailDefaultAndClamp() throws {
        XCTAssertEqual(AudioReactorStyle.default.colorCycle, 0, accuracy: 0.001)
        XCTAssertEqual(AudioReactorStyle.default.motionTrail, 0, accuracy: 0.001)

        let style = AudioReactorStyle(
            presetID: nil,
            palette: .default,
            spectrum: .default,
            ring: .default,
            wave: .default,
            scale: 1.0,
            colorCycle: 2.0,
            motionTrail: -1
        )
        XCTAssertEqual(style.colorCycle, 1, accuracy: 0.001)
        XCTAssertEqual(style.motionTrail, 0, accuracy: 0.001)
    }

    func testStyleColorCycleMotionTrailDecodeDefaults() throws {
        let json = """
        {"presetID":"studio","palette":{"source":"manual","primaryColor":"#24C7FF","secondaryColor":"#FF6B9C","accentColor":"#7A5CFF","glowColor":"#FFFFFF"},"spectrum":{},"ring":{},"wave":{}}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AudioReactorStyle.self, from: json)
        XCTAssertEqual(decoded.colorCycle, 0, accuracy: 0.001)
        XCTAssertEqual(decoded.motionTrail, 0, accuracy: 0.001)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AudioReactorPreferencesTests`
Expected: FAIL.

- [ ] **Step 3: Add the fields**

In `AudioReactorStyle`, add properties (alongside `scale`):

```swift
public var colorCycle: Double {
    didSet { colorCycle = Self.clamp01(colorCycle) }
}
public var motionTrail: Double {
    didSet { motionTrail = Self.clamp01(motionTrail) }
}

public static func clamp01(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(max(value, 0), 1)
}
```

Update designated init signature to accept both with default 0 and clamp on assignment:

```swift
public init(
    presetID: String?,
    palette: AudioReactorPalette,
    spectrum: AudioReactorSpectrumStyle,
    ring: AudioReactorRingStyle,
    wave: AudioReactorWaveStyle,
    scale: Double = 1.0,
    colorCycle: Double = 0,
    motionTrail: Double = 0
) {
    self.presetID = presetID
    self.palette = palette
    self.spectrum = spectrum
    self.ring = ring
    self.wave = wave
    self.scale = Self.clampScale(scale)
    self.colorCycle = Self.clamp01(colorCycle)
    self.motionTrail = Self.clamp01(motionTrail)
}
```

Update `init(from:)`:

```swift
public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
        presetID: try container.decodeIfPresent(String.self, forKey: .presetID),
        palette: try container.decodeIfPresent(AudioReactorPalette.self, forKey: .palette) ?? .default,
        spectrum: try container.decodeIfPresent(AudioReactorSpectrumStyle.self, forKey: .spectrum) ?? Self.default.spectrum,
        ring: try container.decodeIfPresent(AudioReactorRingStyle.self, forKey: .ring) ?? Self.default.ring,
        wave: try container.decodeIfPresent(AudioReactorWaveStyle.self, forKey: .wave) ?? Self.default.wave,
        scale: try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1.0,
        colorCycle: try container.decodeIfPresent(Double.self, forKey: .colorCycle) ?? 0,
        motionTrail: try container.decodeIfPresent(Double.self, forKey: .motionTrail) ?? 0
    )
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AudioReactorPreferencesTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/AudioReactorPreferences.swift \
        Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift
git commit -m "$(cat <<'EOF'
feat(reactor): add colorCycle and motionTrail to AudioReactorStyle

Both clamp to 0..1 with default 0 (no-op). Wiring into the renderer
lands in a later task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Add `beatGate` to `AudioReactorPreferences`

**Files:**
- Modify: `Sources/LunoEngineCore/AudioReactorPreferences.swift:447-505` (`AudioReactorPreferences`)
- Modify: `Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift`

- [ ] **Step 1: Write failing test**

Append to `AudioReactorPreferencesTests.swift`:

```swift
    func testBeatGateDefaultsFalseAndRoundTrips() throws {
        XCTAssertFalse(AudioReactorPreferences.defaults.beatGate)

        var prefs = AudioReactorPreferences.defaults
        prefs.beatGate = true
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(AudioReactorPreferences.self, from: data)
        XCTAssertTrue(decoded.beatGate)
    }

    func testBeatGateDecodesDefaultWhenAbsent() throws {
        let json = """
        {"isEnabled":true,"intensity":0.8,"response":"punchy","bassPulseStrength":0.75,"showsPulseRing":true,"showsSpectrumBars":true,"showsWaveLine":false,"overlayOpacity":0.6}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AudioReactorPreferences.self, from: json)
        XCTAssertFalse(decoded.beatGate)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AudioReactorPreferencesTests`
Expected: FAIL.

- [ ] **Step 3: Add the field**

In `AudioReactorPreferences`:

Add property after `overlayOpacity`:

```swift
public var beatGate: Bool
```

Update designated init to accept it with default false:

```swift
public init(
    isEnabled: Bool,
    intensity: Double,
    response: AudioReactorResponse,
    bassPulseStrength: Double,
    showsPulseRing: Bool,
    showsSpectrumBars: Bool,
    showsWaveLine: Bool,
    overlayOpacity: Double,
    beatGate: Bool = false,
    style: AudioReactorStyle = .default
) {
    self.isEnabled = isEnabled
    self.intensity = intensity
    self.response = response
    self.bassPulseStrength = bassPulseStrength
    self.showsPulseRing = showsPulseRing
    self.showsSpectrumBars = showsSpectrumBars
    self.showsWaveLine = showsWaveLine
    self.overlayOpacity = overlayOpacity
    self.beatGate = beatGate
    self.style = style
}
```

Update `init(from:)`:

```swift
public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
        isEnabled: try container.decode(Bool.self, forKey: .isEnabled),
        intensity: try container.decode(Double.self, forKey: .intensity),
        response: try container.decode(AudioReactorResponse.self, forKey: .response),
        bassPulseStrength: try container.decode(Double.self, forKey: .bassPulseStrength),
        showsPulseRing: try container.decode(Bool.self, forKey: .showsPulseRing),
        showsSpectrumBars: try container.decode(Bool.self, forKey: .showsSpectrumBars),
        showsWaveLine: try container.decode(Bool.self, forKey: .showsWaveLine),
        overlayOpacity: try container.decode(Double.self, forKey: .overlayOpacity),
        beatGate: try container.decodeIfPresent(Bool.self, forKey: .beatGate) ?? false,
        style: try container.decodeIfPresent(AudioReactorStyle.self, forKey: .style) ?? .default
    )
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AudioReactorPreferencesTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/AudioReactorPreferences.swift \
        Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift
git commit -m "$(cat <<'EOF'
feat(reactor): add beatGate preference flag

When on, the pulse ring fires on detected beats rather than continuous
bass. State machine and renderer wiring land in a later task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: `BeatGate` state machine

**Files:**
- Modify: `Sources/LunoEngineCore/AudioReactorColorMath.swift`
- Modify: `Tests/LunoEngineCoreTests/AudioReactorColorMathTests.swift`

We host it in `AudioReactorColorMath.swift` because that file already serves as the home for pure reactor math/state primitives. We could split into its own file later if it grows.

- [ ] **Step 1: Write failing tests**

Append to `AudioReactorColorMathTests.swift`:

```swift
    func testBeatGateFiresWhenBassSpikesAboveEMA() {
        var gate = AudioReactorColorMath.BeatGate()

        // 30 frames of low bass to settle EMA near 0.10.
        for _ in 0..<30 {
            _ = gate.step(bass: 0.10, deltaTime: 1.0 / 60)
        }

        // Sudden spike: 0.10 -> 0.6 should clearly exceed EMA * 1.45 and > 0.25.
        let level = gate.step(bass: 0.6, deltaTime: 1.0 / 60)
        XCTAssertGreaterThan(level, 0.9, "beat should fire and produce ~1 gateLevel")
    }

    func testBeatGateDecaysOverFrames() {
        var gate = AudioReactorColorMath.BeatGate()
        for _ in 0..<30 {
            _ = gate.step(bass: 0.10, deltaTime: 1.0 / 60)
        }
        _ = gate.step(bass: 0.6, deltaTime: 1.0 / 60)

        // Five more frames at low bass: gateLevel should decay (0.92^5 ≈ 0.66).
        var level: Float = 1
        for _ in 0..<5 {
            level = gate.step(bass: 0.10, deltaTime: 1.0 / 60)
        }
        XCTAssertLessThan(level, 0.70, "expected decay below 0.70 after 5 frames")
        XCTAssertGreaterThan(level, 0.55)
    }

    func testBeatGateDoesNotFireBelowAbsoluteFloor() {
        var gate = AudioReactorColorMath.BeatGate()
        // Bass spike of 0.20 (>1.45 * EMA but < 0.25 absolute floor) must not fire.
        for _ in 0..<30 {
            _ = gate.step(bass: 0.05, deltaTime: 1.0 / 60)
        }
        let level = gate.step(bass: 0.20, deltaTime: 1.0 / 60)
        XCTAssertLessThan(level, 0.10, "bass below 0.25 floor must not fire")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AudioReactorColorMathTests`
Expected: FAIL — `BeatGate` does not exist.

- [ ] **Step 3: Implement `BeatGate`**

Append to `AudioReactorColorMath.swift`:

```swift
public struct BeatGate: Equatable, Sendable {
    public var emaBass: Float
    public var gateLevel: Float

    public init() {
        emaBass = 0
        gateLevel = 0
    }

    public mutating func step(bass: Float, deltaTime: Float) -> Float {
        let tau: Float = 0.6
        let alpha = max(0, min(1, deltaTime / max(tau, 0.0001)))
        emaBass = emaBass + (bass - emaBass) * alpha

        let fires = bass > emaBass * 1.45 && bass > 0.25
        if fires {
            gateLevel = 1
        } else {
            gateLevel *= 0.92
        }
        return gateLevel
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AudioReactorColorMathTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/AudioReactorColorMath.swift \
        Tests/LunoEngineCoreTests/AudioReactorColorMathTests.swift
git commit -m "$(cat <<'EOF'
feat(reactor): add BeatGate state machine

Maintains an EMA of bass with a 0.6 s tau and fires gateLevel = 1 when
bass > EMA * 1.45 AND > 0.25 absolute. Decays at 0.92 per frame.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: `MotionTrailBuffer` and `applyColorCycle`

**Files:**
- Modify: `Sources/LunoEngineCore/AudioReactorColorMath.swift`
- Modify: `Tests/LunoEngineCoreTests/AudioReactorColorMathTests.swift`

- [ ] **Step 1: Write failing tests**

Append to `AudioReactorColorMathTests.swift`:

```swift
    func testMotionTrailZeroBypassesSmoothing() {
        var buffer = AudioReactorColorMath.MotionTrailBuffer()
        let input: [Float] = [0.8, 0.6, 0.4]
        var output: [Float] = [0, 0, 0]
        buffer.apply(input: input, trail: 0, into: &output)
        XCTAssertEqual(output, input)
    }

    func testMotionTrailKeepsDescendingTail() {
        var buffer = AudioReactorColorMath.MotionTrailBuffer()
        var output: [Float] = [0, 0, 0]
        buffer.apply(input: [1.0, 1.0, 1.0], trail: 0.8, into: &output)
        buffer.apply(input: [0.0, 0.0, 0.0], trail: 0.8, into: &output)
        // decay = 0.55 + 0.4 * 0.8 = 0.87
        XCTAssertEqual(output[0], 0.87, accuracy: 0.001)
    }

    func testApplyColorCycleNoCycleReturnsInputHex() {
        let cycled = AudioReactorColorMath.applyColorCycle(hex: "#24C7FF", cycleRate: 0, time: 5)
        XCTAssertEqual(cycled, "#24C7FF")
    }

    func testApplyColorCycleFullPeriodReturnsToOriginal() {
        let original = "#24C7FF"
        let cycled = AudioReactorColorMath.applyColorCycle(hex: original, cycleRate: 1, time: 10.0)
        XCTAssertEqual(cycled, original)
    }

    func testApplyColorCycleHalfPeriodShiftsHue180() {
        let original = "#FF0000"  // hue 0
        let cycled = AudioReactorColorMath.applyColorCycle(hex: original, cycleRate: 1, time: 5.0)
        // 180° hue shift from red is cyan (#00FFFF)
        XCTAssertEqual(cycled, "#00FFFF")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AudioReactorColorMathTests`
Expected: FAIL.

- [ ] **Step 3: Implement `MotionTrailBuffer` and `applyColorCycle`**

Append to `AudioReactorColorMath.swift`:

```swift
public struct MotionTrailBuffer: Sendable {
    public var prev: [Float] = []

    public init() {}

    public mutating func apply(input: [Float], trail: Double, into output: inout [Float]) {
        guard output.count == input.count else {
            output = input
            prev = input
            return
        }
        if trail < 0.001 {
            for i in input.indices { output[i] = input[i] }
            prev = input
            return
        }
        if prev.count != input.count {
            prev = Array(repeating: 0, count: input.count)
        }
        let decay = Float(0.55 + 0.4 * min(max(trail, 0), 1))
        for i in input.indices {
            let value = max(input[i], prev[i] * decay)
            output[i] = value
            prev[i] = value
        }
    }
}

public static func applyColorCycle(hex: String, cycleRate: Double, time: Double) -> String {
    guard cycleRate > 0 else { return hex }
    let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#").union(.whitespacesAndNewlines))
    guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else { return hex }
    let r = Double((value >> 16) & 0xFF) / 255
    let g = Double((value >> 8) & 0xFF) / 255
    let b = Double(value & 0xFF) / 255
    var hsl = rgbToHSL(r: r, g: g, b: b)
    let degreesPerSecond = cycleRate * 36.0  // 1.0 -> 360°/10 s
    hsl.h = (hsl.h + time * degreesPerSecond).truncatingRemainder(dividingBy: 360)
    if hsl.h < 0 { hsl.h += 360 }
    let rgb = hslToRGB(h: hsl.h, s: hsl.s, l: hsl.l)
    let ri = UInt8(round(clamp01(rgb.r) * 255))
    let gi = UInt8(round(clamp01(rgb.g) * 255))
    let bi = UInt8(round(clamp01(rgb.b) * 255))
    return String(format: "#%02X%02X%02X", ri, gi, bi)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AudioReactorColorMathTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/AudioReactorColorMath.swift \
        Tests/LunoEngineCoreTests/AudioReactorColorMathTests.swift
git commit -m "$(cat <<'EOF'
feat(reactor): add MotionTrailBuffer and applyColorCycle

MotionTrailBuffer keeps a previous-frame array and outputs max(new,
prev * decay) where decay = 0.55 + 0.4 * trail; bypassed at trail < 0.001.

applyColorCycle rotates a hex color's hue at cycleRate * 36°/s, returning
hex back. cycleRate = 0 short-circuits.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Wire BeatGate, ColorCycle, MotionTrail into renderer

**Files:**
- Modify: `Sources/LunoEngineCore/WallpaperRuntime.swift` — the `MetalWallpaperRenderer` class

- [ ] **Step 1: Add renderer state**

In `MetalWallpaperRenderer` (around line 343, where `overlaySpectrum` is declared), add:

```swift
private var beatGate = AudioReactorColorMath.BeatGate()
private var motionTrailBuffer = AudioReactorColorMath.MotionTrailBuffer()
```

- [ ] **Step 2: Apply colorCycle inside `draw(in:)`**

Find the block where `overlayPalette` is built (around line 501):

```swift
let overlayPalette = style.palette.resolved(with: albumPalette)
```

Replace with:

```swift
let resolvedPalette = style.palette.resolved(with: albumPalette)
let overlayPalette: AudioReactorPalette
if style.colorCycle > 0 {
    let elapsed = now - startTime  // both are CFTimeInterval (Double) per line 460 + 349
    overlayPalette = AudioReactorPalette(
        source: resolvedPalette.source,
        albumColorMode: resolvedPalette.albumColorMode,
        primaryColor: AudioReactorColorMath.applyColorCycle(hex: resolvedPalette.primaryColor, cycleRate: style.colorCycle, time: elapsed),
        secondaryColor: AudioReactorColorMath.applyColorCycle(hex: resolvedPalette.secondaryColor, cycleRate: style.colorCycle, time: elapsed),
        accentColor: AudioReactorColorMath.applyColorCycle(hex: resolvedPalette.accentColor, cycleRate: style.colorCycle, time: elapsed),
        glowColor: AudioReactorColorMath.applyColorCycle(hex: resolvedPalette.glowColor, cycleRate: style.colorCycle, time: elapsed)
    )
} else {
    overlayPalette = resolvedPalette
}
```

- [ ] **Step 3: Apply motion trail to overlaySpectrum**

Find `downsampleShapedSpectrum(rawAudio.spectrum, preferences: audioReactorPreferences)` (around line 510). Replace with:

```swift
if overlaySpectrum.count != barCount {
    overlaySpectrum = Array(repeating: 0, count: barCount)
}
var fresh = Array(repeating: Float(0), count: barCount)
audioReactorPreferences.writeDownsampledSpectrum(rawAudio.spectrum, into: &fresh)
motionTrailBuffer.apply(input: fresh, trail: style.motionTrail, into: &overlaySpectrum)
```

Remove the prior `if overlaySpectrum.count != barCount { ... }` and `downsampleShapedSpectrum(...)` lines just before it (they are now merged into the block above).

- [ ] **Step 4: Apply beat gate — Swift side**

Before constructing `overlayUniforms`, add:

```swift
let gateLevel: Float = audioReactorPreferences.beatGate
    ? beatGate.step(bass: audio.bass, deltaTime: deltaTime)
    : audio.bass
```

Extend the `LunoOverlayUniforms` struct (at the bottom of `WallpaperRuntime.swift` around line 969) with a `gateLevel: Float` field at the end:

```swift
private struct LunoOverlayUniforms {
    var resolution: SIMD2<Float>
    var rms: Float
    var bass: Float
    var mid: Float
    var treble: Float
    var time: Float
    var overlayOpacity: Float
    var bassPulseStrength: Float
    var flags: UInt32
    var barCount: UInt32
    var palettePrimary: SIMD4<Float>
    var paletteSecondary: SIMD4<Float>
    var paletteAccent: SIMD4<Float>
    var paletteGlow: SIMD4<Float>
    var ringStyle: SIMD4<Float>
    var ringStyle2: SIMD4<Float>
    var spectrumStyle0: SIMD4<Float>
    var spectrumStyle1: SIMD4<Float>
    var spectrumStyle2: SIMD4<Float>
    var waveStyle0: SIMD4<Float>
    var waveStyle1: SIMD4<Float>
    var layoutStyle0: SIMD4<Float>
    var layoutStyle1: SIMD4<Float>
    var gateLevel: Float
}
```

In the `overlayUniforms` literal construction, add `gateLevel: gateLevel` as the final argument (after `layoutStyle1: SIMD4<Float>(...)`).

The shader change to consume this uniform lives in Task 12 alongside the mirrored branch.

- [ ] **Step 5: Build and run all tests**

Run: `swift build && swift test`
Expected: PASS — existing tests untouched, new behavior compiles.

- [ ] **Step 6: Commit**

```bash
git add Sources/LunoEngineCore/WallpaperRuntime.swift
git commit -m "$(cat <<'EOF'
feat(reactor): wire BeatGate/ColorCycle/MotionTrail into Metal renderer

Renderer applies color cycling CPU-side before sending uniforms,
runs the motion-trail EMA over the spectrum buffer, and rescales
bassPulseStrength via the BeatGate when the preference is enabled.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Shader updates — mirrored spectrum + beat-gate ring

**Files:**
- Modify: `Sources/LunoEngineCore/WallpaperRuntime.swift` — `LunoOverlayShaderSource.source` string + flag encoding

- [ ] **Step 1: Add flag bits (Swift side)**

Find the `overlayFlags` extension (around line 1014):

```swift
var overlayFlags: UInt32 {
    var flags: UInt32 = 0
    if showsPulseRing { flags |= 1 << 0 }
    if showsSpectrumBars { flags |= 1 << 1 }
    if showsWaveLine { flags |= 1 << 2 }
    return flags
}
```

Replace with:

```swift
func overlayFlags(mirrored: Bool) -> UInt32 {
    var flags: UInt32 = 0
    if showsPulseRing { flags |= 1 << 0 }
    if showsSpectrumBars { flags |= 1 << 1 }
    if showsWaveLine { flags |= 1 << 2 }
    if mirrored { flags |= 1 << 3 }
    if beatGate { flags |= 1 << 4 }
    return flags
}
```

Update the call site in `draw(in:)` (around line 520) — change `flags: audioReactorPreferences.overlayFlags` to:

```swift
flags: audioReactorPreferences.overlayFlags(mirrored: style.spectrum.mirrored),
```

- [ ] **Step 2: Add mirrored branch to shader**

Inside `LunoOverlayShaderSource.source`, find the bottom-spectrum block (the `if (isBottomLayout(layout))` clause inside the `if (((uniforms.flags & 2u) != 0u) && count > 0)` section, around line 835). The current code computes:

```c
float cell = railX * float(count);
uint index = min(uint(floor(cell)), count - 1);
```

Insert mirroring before the cell calc:

```c
float mirroredRailX = railX;
if ((uniforms.flags & 8u) != 0u) {
    // Fold right half onto left half: x ∈ [0.5, 1.0] -> [0.5, 0.0]
    if (mirroredRailX > 0.5) {
        mirroredRailX = 1.0 - mirroredRailX;
    }
    mirroredRailX *= 2.0;  // now [0, 1]
}
float cell = mirroredRailX * float(count);
```

For the arc layout (the `else` branch around line 869), insert similarly after `progress` is computed:

```c
float effectiveProgress = progress;
if ((uniforms.flags & 8u) != 0u && !circle) {
    if (effectiveProgress > 0.5) {
        effectiveProgress = 1.0 - effectiveProgress;
    }
    effectiveProgress *= 2.0;
}
float cell = effectiveProgress * float(count);
```

(Circle layout ignores the mirror flag per the spec.)

- [ ] **Step 3: Update the OverlayUniforms struct in the shader string**

Inside the `LunoOverlayShaderSource.source` string, find the `OverlayUniforms` struct at the top (around line 686). Add `float gateLevel;` at the bottom (after `layoutStyle1`):

```c
struct OverlayUniforms {
    float2 resolution;
    float rms;
    float bass;
    float mid;
    float treble;
    float time;
    float overlayOpacity;
    float bassPulseStrength;
    uint flags;
    uint barCount;
    float4 palettePrimary;
    float4 paletteSecondary;
    float4 paletteAccent;
    float4 paletteGlow;
    float4 ringStyle;
    float4 ringStyle2;
    float4 spectrumStyle0;
    float4 spectrumStyle1;
    float4 spectrumStyle2;
    float4 waveStyle0;
    float4 waveStyle1;
    float4 layoutStyle0;
    float4 layoutStyle1;
    float gateLevel;
};
```

- [ ] **Step 4: Wire gated bass into the ring path**

In `lunoOverlayFragment`, inside the `if ((uniforms.flags & 1u) != 0u)` ring block (around line 803), at the top of the block, add:

```c
float ringBass = (uniforms.flags & 16u) != 0u ? uniforms.gateLevel : uniforms.bass;
```

Then replace every occurrence of `uniforms.bass` WITHIN THE RING BLOCK ONLY (between `if ((uniforms.flags & 1u) != 0u) {` and its closing `}`) with `ringBass`. The spectrum and wave blocks below the ring block keep using `uniforms.bass`.

- [ ] **Step 5: Build and run smoke test**

Run: `swift build`
Expected: PASS — Swift parses + Metal compiles at runtime.

Run: `swift test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/LunoEngineCore/WallpaperRuntime.swift
git commit -m "$(cat <<'EOF'
feat(reactor): mirror spectrum + beat-gate ring in overlay shader

Flag bit 3 mirrors the spectrum about the rail/arc midpoint for bottom
and arc layouts. Flag bit 4 swaps the ring path's bass term for the
CPU-computed gateLevel uniform. Circle layout ignores the mirror flag
(already symmetric).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: UI — Album mode segmented control

**Files:**
- Modify: `Sources/LunoApp/Settings/AudioReactorSectionView.swift`

- [ ] **Step 1: Add control declaration**

Near the top of `AudioReactorSectionView` (alongside `paletteSourcePopup`), add:

```swift
private let albumModeControl = NSSegmentedControl(
    labels: ["Match", "Contrast", "Vivid"],
    trackingMode: .selectOne,
    target: nil,
    action: nil
)
private let albumModeLabel = NSTextField(labelWithString: "Album mode")
private lazy var albumModeRow: NSStackView = {
    let stack = NSStackView(views: [albumModeLabel, albumModeControl])
    stack.orientation = .horizontal
    stack.spacing = 8
    return stack
}()
```

- [ ] **Step 2: Add configuration in `apply(preferences:)`**

Inside `apply(preferences:)` (around line 95 where `selectPaletteSource` is called), add after that call:

```swift
let modeIndex = AudioReactorAlbumColorMode.allCases.firstIndex(of: preferences.style.palette.albumColorMode) ?? 1
albumModeControl.selectedSegment = modeIndex
albumModeRow.isHidden = preferences.style.palette.source != .albumArtwork
```

- [ ] **Step 3: Add to layout**

Find the labeled-controls list (around line 184). Add immediately after `labeled("Color source", control: paletteSourcePopup),`:

```swift
albumModeRow,
```

- [ ] **Step 4: Wire target/action**

Inside `configureColorWell`-area wiring (around line 251), add:

```swift
albumModeControl.target = self
albumModeControl.action = #selector(albumModeChanged)
```

Add the action method (alongside `paletteSourceChanged` around line 479):

```swift
@objc private func albumModeChanged(_ sender: NSSegmentedControl) {
    guard let mode = AudioReactorAlbumColorMode.allCases[safe: sender.selectedSegment] else { return }
    commitField { $0.style.palette.albumColorMode = mode }
}
```

If `Array.subscript(safe:)` doesn't exist yet in the project (grep for `subscript(safe`), add it as a private extension at the bottom of the file:

```swift
private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
```

- [ ] **Step 5: Show/hide tied to palette source**

Find `paletteSourceChanged(_:)` (around line 479). After applying the source change, also update visibility:

```swift
@objc private func paletteSourceChanged(_ sender: NSPopUpButton) {
    guard let rawValue = sender.selectedItem?.representedObject as? String,
          let source = AudioReactorPaletteSource(rawValue: rawValue) else { return }
    commitField { $0.style.palette.source = source }
    albumModeRow.isHidden = source != .albumArtwork
}
```

- [ ] **Step 6: Build and smoke-test**

Run: `swift build`
Expected: PASS.

Manually verify: open Library → Audio Reactor → switch color source between Manual and Album, the "Album mode" row should appear/disappear; segment changes persist.

- [ ] **Step 7: Commit**

```bash
git add Sources/LunoApp/Settings/AudioReactorSectionView.swift
git commit -m "$(cat <<'EOF'
feat(reactor-ui): album mode segmented control under color source

Shows Match/Contrast/Vivid only when palette source is Album. Wires to
style.palette.albumColorMode with the existing commit pattern.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: UI — Advanced section (mirror / cycle / gate / trail)

**Files:**
- Modify: `Sources/LunoApp/Settings/AudioReactorSectionView.swift`

- [ ] **Step 1: Add control declarations**

In the property block at the top of `AudioReactorSectionView`:

```swift
private let mirrorSpectrumSwitch = NSSwitch()
private let colorCycleSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
private let beatGateSwitch = NSSwitch()
private let motionTrailSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
private let advancedBox = NSBox()
```

- [ ] **Step 2: Configure Advanced box**

Add a helper inside the view (near the other layout helpers):

```swift
private func makeAdvancedBox() -> NSBox {
    let box = advancedBox
    box.title = "Advanced"
    box.titlePosition = .atTop
    box.boxType = .primary
    let content = NSStackView(views: [
        labeled("Mirror spectrum", control: mirrorSpectrumSwitch),
        labeled("Color cycle", control: colorCycleSlider),
        labeled("Beat gate", control: beatGateSwitch),
        labeled("Motion trail", control: motionTrailSlider)
    ])
    content.orientation = .vertical
    content.alignment = .leading
    content.spacing = 6
    content.translatesAutoresizingMaskIntoConstraints = false
    box.contentView = content
    NSLayoutConstraint.activate([
        content.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor, constant: 12),
        content.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor, constant: -12),
        content.topAnchor.constraint(equalTo: box.contentView!.topAnchor, constant: 8),
        content.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor, constant: -8)
    ])
    return box
}
```

- [ ] **Step 3: Add box to outer layout**

In the layout function where the existing labeled controls are listed (around line 174), after the existing labeled rows, append:

```swift
makeAdvancedBox(),
```

- [ ] **Step 4: Hydrate from preferences in `apply(preferences:)`**

Append at the end of `apply(preferences:)`:

```swift
mirrorSpectrumSwitch.state = preferences.style.spectrum.mirrored ? .on : .off
colorCycleSlider.value = preferences.style.colorCycle
beatGateSwitch.state = preferences.beatGate ? .on : .off
motionTrailSlider.value = preferences.style.motionTrail
```

- [ ] **Step 5: Wire actions**

Inside the wiring section (where `scaleSlider.onChange = ...` lives):

```swift
mirrorSpectrumSwitch.target = self
mirrorSpectrumSwitch.action = #selector(mirrorSpectrumChanged)
colorCycleSlider.onChange = { [weak self] value in self?.styleField { $0.colorCycle = value } }
beatGateSwitch.target = self
beatGateSwitch.action = #selector(beatGateChanged)
motionTrailSlider.onChange = { [weak self] value in self?.styleField { $0.motionTrail = value } }
```

Add the action methods alongside the other `@objc` actions:

```swift
@objc private func mirrorSpectrumChanged(_ sender: NSSwitch) {
    commitField { $0.style.spectrum.mirrored = sender.state == .on }
}

@objc private func beatGateChanged(_ sender: NSSwitch) {
    commitField { $0.beatGate = sender.state == .on }
}
```

- [ ] **Step 6: Disable handling**

Existing code at `AudioReactorSectionView.swift:394-406` toggles `isEnabled = active` on a small array of inline-literal controls. Append the new controls to that second array. The block currently reads:

```swift
[
    responseControl,
    pulseRingSwitch,
    spectrumBarsSwitch,
    waveLineSwitch,
    primaryColorWell,
    secondaryColorWell,
    accentColorWell,
    glowColorWell,
    paletteSourcePopup,
    spectrumLayoutPopup,
    waveLayoutPopup
].forEach { $0.isEnabled = active }
```

Change to:

```swift
[
    responseControl,
    pulseRingSwitch,
    spectrumBarsSwitch,
    waveLineSwitch,
    primaryColorWell,
    secondaryColorWell,
    accentColorWell,
    glowColorWell,
    paletteSourcePopup,
    spectrumLayoutPopup,
    waveLayoutPopup,
    albumModeControl,
    mirrorSpectrumSwitch,
    beatGateSwitch
].forEach { $0.isEnabled = active }
```

(`colorCycleSlider` and `motionTrailSlider` are `LabeledValueSlider` instances — slider enabling is handled by the first array at line 362–392. Append them there alongside `scaleSlider`.)

- [ ] **Step 7: Build and smoke-test**

Run: `swift build`
Expected: PASS.

Manually verify the four new controls appear in the Advanced box, toggle/slide them, confirm `~/Library/Application Support/.../audio-reactor.json` reflects changes.

- [ ] **Step 8: Commit**

```bash
git add Sources/LunoApp/Settings/AudioReactorSectionView.swift
git commit -m "$(cat <<'EOF'
feat(reactor-ui): Advanced section with mirror / cycle / gate / trail

Adds an Advanced NSBox below the existing controls exposing the new
mirrored spectrum toggle, color cycle slider, beat gate toggle, and
motion trail slider. All four bind to existing commit patterns.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: Full verification

**Files:** none modified — verification only

- [ ] **Step 1: Run full test suite**

Run: `swift test`
Expected: ALL PASS. Note any new failures; fix root causes inline (do NOT skip or comment out tests).

- [ ] **Step 2: Type-check build**

Run: `swift build -c release`
Expected: PASS without warnings introduced by this phase.

- [ ] **Step 3: Manual smoke test**

1. Launch the app: `swift run` (or use Xcode product target).
2. Open Library → Audio Reactor section.
3. Verify:
   - Existing 6 presets still load and look correct.
   - Color source = Manual: Album mode row hidden.
   - Color source = Album: Album mode row visible. Match/Contrast/Vivid changes affect the live wallpaper.
   - Advanced box: each control toggles/slides; changes persist after app restart.
4. Play music (or use a test tone), set Color source = Album with Contrast mode, switch to AlbumPalette wallpaper, verify reactor stays visible against the album-derived background.

- [ ] **Step 4: Commit (if no fixes needed)**

If Steps 1–3 surfaced no fixes, no commit needed.

If fixes were made:

```bash
git add -p   # stage selectively
git commit -m "fix(reactor): <specific fix description>"
```

---

## Self-review checklist

After all tasks complete:

- [ ] All four new fields decode with defaults when JSON omits them.
- [ ] All four new fields round-trip through encode → decode.
- [ ] `albumColorMode = .match` exact-matches the old `resolved(with:)` output.
- [ ] Vivid mode produces lightness within ±0.01 of the spec table.
- [ ] Contrast mode's primary luma is ≥ 0.32 different from the album background when the original was within 0.18.
- [ ] BeatGate fires only when bass > EMA × 1.45 AND > 0.25.
- [ ] MotionTrail at 0 produces identical output to the input each frame.
- [ ] applyColorCycle at cycleRate = 0 returns input unchanged.
- [ ] Mirrored shader branch is gated on `flags & 8u`; bottom + arc only.
- [ ] UI: Album mode row hidden when source is manual.
- [ ] UI: All new controls respect the master enabled state.
