# Settings UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Luno's flat library window with a production-quality sidebar+detail settings UI, and add a `NowPlayingAppearance` model with shape/typography/color customization, per-effect reaction weights, and 5 built-in appearance presets. All settings must persist across app restarts via the existing JSON preferences store.

**Architecture:** Add a new `NowPlayingAppearance` value type inside `LunoEngineCore`, embed it into `NowPlayingPreferences` so it inherits free JSON persistence. Rebuild `LibraryWindowController` as `SettingsWindowController` using `NSSplitView` with an `NSOutlineView` sidebar and one extracted `NSStackView`-based section view per detail surface. The Now Playing widget reads `appearance` directly from preferences passed through the existing `NowPlayingViewModel`.

**Tech Stack:** Swift 6, SwiftPM, AppKit (NSSplitView, NSOutlineView, NSColorWell, NSSlider, NSPopUpButton), SwiftUI (widget rendering), XCTest.

---

## File Structure

**Create:**
- `Sources/LunoEngineCore/NowPlaying/NowPlayingAppearance.swift` — appearance model + presets + hex helpers
- `Sources/LunoApp/Settings/SettingsSection.swift` — section enum
- `Sources/LunoApp/Settings/SettingsSidebar.swift` — `NSOutlineView` wrapper
- `Sources/LunoApp/Settings/LibrarySectionView.swift` — library/wallpaper/preset controls (extracted)
- `Sources/LunoApp/Settings/NowPlayingBasicSectionView.swift` — enable/style/keep-visible/react toggles
- `Sources/LunoApp/Settings/NowPlayingAppearanceSectionView.swift` — preset popup + shape sliders + color wells + weight popups
- `Sources/LunoApp/Settings/NowPlayingReactivitySectionView.swift` — master intensity + per-effect weights
- `Sources/LunoApp/Settings/AudioReactorSectionView.swift` — existing reactor controls (extracted)
- `Sources/LunoApp/Settings/HexColor.swift` — shared `NSColor`/`SwiftUI.Color` hex helpers
- `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingAppearanceTests.swift`
- `Tests/LunoEngineCoreTests/NowPlaying/HexColorTests.swift`

**Rename:**
- `Sources/LunoApp/LibraryWindowController.swift` → `Sources/LunoApp/Settings/SettingsWindowController.swift`

**Modify:**
- `Sources/LunoEngineCore/NowPlaying/NowPlayingPreferences.swift` — add `appearance` field, migration decoder
- `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingPreferencesStoreTests.swift` — migration assertions
- `Sources/LunoApp/NowPlayingWidget/NowPlayingWidgetView.swift` — accept and apply appearance
- `Sources/LunoApp/NowPlayingWidget/NowPlayingWindowController.swift` — forward `appearance` to widget view
- `Sources/LunoApp/NowPlayingWidget/Styles/AlbumDominantStyle.swift` — apply title/subtitle font weights
- `Sources/LunoApp/NowPlayingWidget/Styles/CompactBarStyle.swift` — apply title/subtitle font weights
- `Sources/LunoApp/NowPlayingWidget/Styles/MinimalStyle.swift` — apply title font weight
- `Sources/LunoApp/AppDelegate.swift` — reference `SettingsWindowController` instead of `LibraryWindowController`

---

## Task 1: `NowPlayingAppearance.FontWeight` enum + nested model skeleton

**Files:**
- Create: `Sources/LunoEngineCore/NowPlaying/NowPlayingAppearance.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingAppearanceTests.swift`

- [ ] **Step 1: Write the failing test for FontWeight Codable round-trip**

```swift
// Tests/LunoEngineCoreTests/NowPlaying/NowPlayingAppearanceTests.swift
import XCTest
@testable import LunoEngineCore

final class NowPlayingAppearanceTests: XCTestCase {
    func testFontWeightCases() {
        XCTAssertEqual(NowPlayingAppearance.FontWeight.allCases.count, 6)
        XCTAssertEqual(NowPlayingAppearance.FontWeight.regular.rawValue, "regular")
        XCTAssertEqual(NowPlayingAppearance.FontWeight.black.rawValue, "black")
    }

    func testFontWeightRoundTrip() throws {
        let original = NowPlayingAppearance.FontWeight.semibold
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NowPlayingAppearance.FontWeight.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter NowPlayingAppearanceTests`
Expected: FAIL with "cannot find 'NowPlayingAppearance' in scope"

- [ ] **Step 3: Create the file with the enum**

```swift
// Sources/LunoEngineCore/NowPlaying/NowPlayingAppearance.swift
import Foundation

public struct NowPlayingAppearance: Codable, Equatable, Sendable {
    public enum FontWeight: String, Codable, Sendable, CaseIterable {
        case regular
        case medium
        case semibold
        case bold
        case heavy
        case black
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter NowPlayingAppearanceTests`
Expected: 2 tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/NowPlayingAppearance.swift Tests/LunoEngineCoreTests/NowPlaying/NowPlayingAppearanceTests.swift
git -c commit.gpgsign=false commit -m "feat(now-playing): scaffold NowPlayingAppearance with FontWeight enum"
```

---

## Task 2: `NowPlayingAppearance` shape, typography, color, reaction fields

**Files:**
- Modify: `Sources/LunoEngineCore/NowPlaying/NowPlayingAppearance.swift`
- Modify: `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingAppearanceTests.swift`

- [ ] **Step 1: Add failing tests for `.default`, clamping, round-trip**

Append to `NowPlayingAppearanceTests.swift`:

```swift
    func testDefaultAppearanceMatchesExpectedValues() {
        let appearance = NowPlayingAppearance.default
        XCTAssertEqual(appearance.cornerRadius, 14)
        XCTAssertEqual(appearance.padding, 14)
        XCTAssertEqual(appearance.borderWidth, 1)
        XCTAssertEqual(appearance.borderOpacity, 0.08, accuracy: 0.0001)
        XCTAssertEqual(appearance.titleWeight, .semibold)
        XCTAssertEqual(appearance.subtitleWeight, .regular)
        XCTAssertEqual(appearance.textColor, "#FFFFFF")
        XCTAssertEqual(appearance.accentColor, "#FF6B9C")
        XCTAssertEqual(appearance.glowTint, "#FFFFFF")
        XCTAssertEqual(appearance.scaleReaction, 1.0)
        XCTAssertEqual(appearance.glowReaction, 1.0)
        XCTAssertEqual(appearance.borderReaction, 1.0)
    }

    func testAppearanceClampsOutOfRangeNumericValues() {
        let appearance = NowPlayingAppearance(
            cornerRadius: -5,
            padding: 999,
            borderWidth: -10,
            borderOpacity: 2.5,
            titleWeight: .regular,
            subtitleWeight: .regular,
            textColor: "#FFFFFF",
            accentColor: "#FFFFFF",
            glowTint: "#FFFFFF",
            scaleReaction: -1,
            glowReaction: 5,
            borderReaction: 0.4
        )
        XCTAssertEqual(appearance.cornerRadius, 0)
        XCTAssertEqual(appearance.padding, 24)
        XCTAssertEqual(appearance.borderWidth, 0)
        XCTAssertEqual(appearance.borderOpacity, 1)
        XCTAssertEqual(appearance.scaleReaction, 0)
        XCTAssertEqual(appearance.glowReaction, 1)
        XCTAssertEqual(appearance.borderReaction, 0.4)
    }

    func testAppearanceRoundTripsThroughJSON() throws {
        let original = NowPlayingAppearance.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NowPlayingAppearance.self, from: data)
        XCTAssertEqual(decoded, original)
    }
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter NowPlayingAppearanceTests`
Expected: FAIL (default and clamp tests fail to compile / not defined)

- [ ] **Step 3: Add fields, initializer with clamping, and `.default`**

Replace contents of `Sources/LunoEngineCore/NowPlaying/NowPlayingAppearance.swift`:

```swift
import Foundation

public struct NowPlayingAppearance: Codable, Equatable, Sendable {
    public enum FontWeight: String, Codable, Sendable, CaseIterable {
        case regular
        case medium
        case semibold
        case bold
        case heavy
        case black
    }

    public var cornerRadius: Double
    public var padding: Double
    public var borderWidth: Double
    public var borderOpacity: Double
    public var titleWeight: FontWeight
    public var subtitleWeight: FontWeight
    public var textColor: String
    public var accentColor: String
    public var glowTint: String
    public var scaleReaction: Double
    public var glowReaction: Double
    public var borderReaction: Double

    public init(
        cornerRadius: Double = 14,
        padding: Double = 14,
        borderWidth: Double = 1,
        borderOpacity: Double = 0.08,
        titleWeight: FontWeight = .semibold,
        subtitleWeight: FontWeight = .regular,
        textColor: String = "#FFFFFF",
        accentColor: String = "#FF6B9C",
        glowTint: String = "#FFFFFF",
        scaleReaction: Double = 1.0,
        glowReaction: Double = 1.0,
        borderReaction: Double = 1.0
    ) {
        self.cornerRadius = Self.clampShape(cornerRadius, max: 28)
        self.padding = Self.clampShape(padding, min: 8, max: 24)
        self.borderWidth = Self.clampShape(borderWidth, max: 6)
        self.borderOpacity = Self.clampUnit(borderOpacity)
        self.titleWeight = titleWeight
        self.subtitleWeight = subtitleWeight
        self.textColor = Self.normalizedHex(textColor, fallback: "#FFFFFF")
        self.accentColor = Self.normalizedHex(accentColor, fallback: "#FF6B9C")
        self.glowTint = Self.normalizedHex(glowTint, fallback: "#FFFFFF")
        self.scaleReaction = Self.clampUnit(scaleReaction)
        self.glowReaction = Self.clampUnit(glowReaction)
        self.borderReaction = Self.clampUnit(borderReaction)
    }

    public static let `default` = NowPlayingAppearance()

    private static func clampShape(_ value: Double, min minValue: Double = 0, max maxValue: Double) -> Double {
        guard value.isFinite else { return minValue }
        return Swift.min(Swift.max(value, minValue), maxValue)
    }

    private static func clampUnit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return Swift.min(Swift.max(value, 0), 1)
    }

    static func normalizedHex(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard stripped.count == 6, Int(stripped, radix: 16) != nil else {
            return fallback
        }
        return "#" + stripped.uppercased()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter NowPlayingAppearanceTests`
Expected: 5 tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/NowPlayingAppearance.swift Tests/LunoEngineCoreTests/NowPlaying/NowPlayingAppearanceTests.swift
git -c commit.gpgsign=false commit -m "feat(now-playing): add appearance fields with clamping and defaults"
```

---

## Task 3: `NowPlayingAppearance.presets` — 5 built-in presets

**Files:**
- Modify: `Sources/LunoEngineCore/NowPlaying/NowPlayingAppearance.swift`
- Modify: `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingAppearanceTests.swift`

- [ ] **Step 1: Add failing tests for presets**

Append to `NowPlayingAppearanceTests.swift`:

```swift
    func testFivePresetsExistInExpectedOrder() {
        let ids = NowPlayingAppearance.presets.map(\.id)
        XCTAssertEqual(ids, ["default", "vivid", "minimal", "neon", "mono"])
    }

    func testPresetIDsAndNamesAreUnique() {
        let ids = Set(NowPlayingAppearance.presets.map(\.id))
        let names = Set(NowPlayingAppearance.presets.map(\.name))
        XCTAssertEqual(ids.count, NowPlayingAppearance.presets.count)
        XCTAssertEqual(names.count, NowPlayingAppearance.presets.count)
    }

    func testDefaultPresetMatchesDefaultAppearance() {
        let defaultPreset = NowPlayingAppearance.presets.first { $0.id == "default" }
        XCTAssertNotNil(defaultPreset)
        XCTAssertEqual(defaultPreset?.appearance, NowPlayingAppearance.default)
    }

    func testNeonPresetUsesCyanAccent() {
        let neon = NowPlayingAppearance.presets.first { $0.id == "neon" }?.appearance
        XCTAssertEqual(neon?.accentColor, "#00F0FF")
        XCTAssertEqual(neon?.glowTint, "#00F0FF")
        XCTAssertEqual(neon?.titleWeight, .bold)
    }
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter NowPlayingAppearanceTests`
Expected: FAIL ("presets" not found)

- [ ] **Step 3: Add `NamedPreset` and `presets` static**

Append to `Sources/LunoEngineCore/NowPlaying/NowPlayingAppearance.swift` (after the closing `}` of the struct):

```swift

public struct NowPlayingAppearancePreset: Equatable, Sendable {
    public let id: String
    public let name: String
    public let appearance: NowPlayingAppearance

    public init(id: String, name: String, appearance: NowPlayingAppearance) {
        self.id = id
        self.name = name
        self.appearance = appearance
    }
}

public extension NowPlayingAppearance {
    static let presets: [NowPlayingAppearancePreset] = [
        NowPlayingAppearancePreset(id: "default", name: "Default", appearance: .default),
        NowPlayingAppearancePreset(
            id: "vivid",
            name: "Vivid",
            appearance: NowPlayingAppearance(
                cornerRadius: 18,
                padding: 14,
                borderWidth: 2,
                borderOpacity: 0.20,
                titleWeight: .bold,
                subtitleWeight: .medium,
                textColor: "#FFFFFF",
                accentColor: "#FF3D81",
                glowTint: "#FF6B9C"
            )
        ),
        NowPlayingAppearancePreset(
            id: "minimal",
            name: "Minimal",
            appearance: NowPlayingAppearance(
                cornerRadius: 8,
                padding: 12,
                borderWidth: 0,
                borderOpacity: 0.00,
                titleWeight: .regular,
                subtitleWeight: .regular,
                textColor: "#FFFFFF",
                accentColor: "#FFFFFF",
                glowTint: "#FFFFFF"
            )
        ),
        NowPlayingAppearancePreset(
            id: "neon",
            name: "Neon",
            appearance: NowPlayingAppearance(
                cornerRadius: 22,
                padding: 14,
                borderWidth: 2,
                borderOpacity: 0.35,
                titleWeight: .bold,
                subtitleWeight: .medium,
                textColor: "#FFFFFF",
                accentColor: "#00F0FF",
                glowTint: "#00F0FF"
            )
        ),
        NowPlayingAppearancePreset(
            id: "mono",
            name: "Mono",
            appearance: NowPlayingAppearance(
                cornerRadius: 4,
                padding: 14,
                borderWidth: 1,
                borderOpacity: 0.15,
                titleWeight: .medium,
                subtitleWeight: .regular,
                textColor: "#FFFFFF",
                accentColor: "#FFFFFF",
                glowTint: "#FFFFFF"
            )
        )
    ]

    /// Returns the preset whose appearance equals this one, or nil if the value has diverged.
    func matchingPreset() -> NowPlayingAppearancePreset? {
        Self.presets.first { $0.appearance == self }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter NowPlayingAppearanceTests`
Expected: 9 tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/NowPlayingAppearance.swift Tests/LunoEngineCoreTests/NowPlaying/NowPlayingAppearanceTests.swift
git -c commit.gpgsign=false commit -m "feat(now-playing): add five built-in appearance presets"
```

---

## Task 4: Embed `appearance` in `NowPlayingPreferences` with legacy migration

**Files:**
- Modify: `Sources/LunoEngineCore/NowPlaying/NowPlayingPreferences.swift`
- Modify: `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingPreferencesStoreTests.swift`

- [ ] **Step 1: Add failing migration test**

Append to `Tests/LunoEngineCoreTests/NowPlaying/NowPlayingPreferencesStoreTests.swift`:

```swift
    func testLegacyJSONWithoutAppearanceLoadsWithDefaultAppearance() throws {
        let json = """
        {
          "isEnabled": true,
          "style": "albumDominant",
          "audioReactivityEnabled": true,
          "audioReactivityIntensity": 0.4,
          "keepVisibleWhilePaused": false,
          "isPinned": false,
          "positionsByDisplay": {}
        }
        """.data(using: .utf8)!

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("luno-now-playing-legacy-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try json.write(to: url)

        let store = NowPlayingPreferencesStore(fileURL: url)
        let loaded = try store.load()

        XCTAssertEqual(loaded.appearance, .default)
        XCTAssertEqual(loaded.audioReactivityIntensity, 0.4)
        XCTAssertTrue(loaded.isEnabled)
    }

    func testAppearancePersistsThroughSaveAndLoad() throws {
        let custom = NowPlayingAppearance(
            cornerRadius: 22,
            padding: 18,
            borderWidth: 2,
            borderOpacity: 0.35,
            titleWeight: .bold,
            subtitleWeight: .medium,
            textColor: "#FFFFFF",
            accentColor: "#00F0FF",
            glowTint: "#00F0FF",
            scaleReaction: 0.8,
            glowReaction: 1.0,
            borderReaction: 0.6
        )
        var preferences = NowPlayingPreferences.defaults
        preferences.appearance = custom

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("luno-now-playing-roundtrip-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = NowPlayingPreferencesStore(fileURL: url)
        try store.save(preferences)
        let reloaded = try store.load()

        XCTAssertEqual(reloaded.appearance, custom)
    }
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test --filter NowPlayingPreferencesStoreTests`
Expected: FAIL (`appearance` missing)

- [ ] **Step 3: Add `appearance` to preferences**

Modify `Sources/LunoEngineCore/NowPlaying/NowPlayingPreferences.swift`. Add `case appearance` to `CodingKeys`, add `public var appearance: NowPlayingAppearance` to the struct, update the memberwise init to accept `appearance: NowPlayingAppearance = .default`, add `self.appearance = appearance` to the init body, add `self.appearance = try container.decodeIfPresent(NowPlayingAppearance.self, forKey: .appearance) ?? .default` to the decoder, add `try container.encode(appearance, forKey: .appearance)` to the encoder, and add `appearance: .default,` to the `defaults` static.

Final file:

```swift
import Foundation

public struct NowPlayingPreferences: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case style
        case audioReactivityEnabled
        case audioReactivityIntensity
        case keepVisibleWhilePaused
        case isPinned
        case positionsByDisplay
        case appearance
    }

    public enum Style: String, Codable, Sendable, CaseIterable {
        case albumDominant
        case compactBar
        case minimal
    }

    public struct Position: Codable, Equatable, Sendable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public var isEnabled: Bool
    public var style: Style
    public var audioReactivityEnabled: Bool
    public var audioReactivityIntensity: Double
    public var keepVisibleWhilePaused: Bool
    public var isPinned: Bool
    public var positionsByDisplay: [String: Position]
    public var appearance: NowPlayingAppearance

    public init(
        isEnabled: Bool,
        style: Style,
        audioReactivityEnabled: Bool,
        audioReactivityIntensity: Double = 0.2,
        keepVisibleWhilePaused: Bool,
        isPinned: Bool = false,
        positionsByDisplay: [String: Position],
        appearance: NowPlayingAppearance = .default
    ) {
        self.isEnabled = isEnabled
        self.style = style
        self.audioReactivityEnabled = audioReactivityEnabled
        self.audioReactivityIntensity = min(max(audioReactivityIntensity, 0), 1)
        self.keepVisibleWhilePaused = keepVisibleWhilePaused
        self.isPinned = isPinned
        self.positionsByDisplay = positionsByDisplay
        self.appearance = appearance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        self.style = try container.decode(Style.self, forKey: .style)
        self.audioReactivityEnabled = try container.decode(Bool.self, forKey: .audioReactivityEnabled)
        let rawIntensity = try container.decodeIfPresent(Double.self, forKey: .audioReactivityIntensity) ?? 0.2
        self.audioReactivityIntensity = min(max(rawIntensity, 0), 1)
        self.keepVisibleWhilePaused = try container.decode(Bool.self, forKey: .keepVisibleWhilePaused)
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.positionsByDisplay = try container.decode([String: Position].self, forKey: .positionsByDisplay)
        self.appearance = try container.decodeIfPresent(NowPlayingAppearance.self, forKey: .appearance) ?? .default
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(style, forKey: .style)
        try container.encode(audioReactivityEnabled, forKey: .audioReactivityEnabled)
        try container.encode(audioReactivityIntensity, forKey: .audioReactivityIntensity)
        try container.encode(keepVisibleWhilePaused, forKey: .keepVisibleWhilePaused)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(positionsByDisplay, forKey: .positionsByDisplay)
        try container.encode(appearance, forKey: .appearance)
    }

    public static let defaults = NowPlayingPreferences(
        isEnabled: false,
        style: .compactBar,
        audioReactivityEnabled: true,
        audioReactivityIntensity: 0.2,
        keepVisibleWhilePaused: false,
        isPinned: false,
        positionsByDisplay: [:],
        appearance: .default
    )
}

public struct NowPlayingPreferencesStore: Sendable {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public func load() throws -> NowPlayingPreferences {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .defaults
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(NowPlayingPreferences.self, from: data)
    }

    public func save(_ preferences: NowPlayingPreferences) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(preferences)
        try data.write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter NowPlayingPreferencesStoreTests`
Expected: all tests pass including the two new ones

Then full suite:

Run: `swift test`
Expected: all tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/LunoEngineCore/NowPlaying/NowPlayingPreferences.swift Tests/LunoEngineCoreTests/NowPlaying/NowPlayingPreferencesStoreTests.swift
git -c commit.gpgsign=false commit -m "feat(now-playing): persist appearance in NowPlayingPreferences"
```

---

## Task 5: Shared `HexColor` helpers for `NSColor` and `SwiftUI.Color`

**Files:**
- Create: `Sources/LunoApp/Settings/HexColor.swift`
- Create: `Tests/LunoEngineCoreTests/NowPlaying/HexColorTests.swift` (engine-side coverage uses the normalization helper)
- Modify: `Sources/LunoApp/LibraryWindowController.swift` — remove inline `NSColor` hex extension once `HexColor.swift` provides the same surface

- [ ] **Step 1: Create directory and add the shared helper file**

```bash
mkdir -p Sources/LunoApp/Settings
```

Create `Sources/LunoApp/Settings/HexColor.swift`:

```swift
import AppKit
import SwiftUI

enum HexColor {
    /// Parses "#RRGGBB" (with or without leading "#"). Returns nil if invalid.
    static func parse(_ hex: String) -> (red: Double, green: Double, blue: Double)? {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#").union(.whitespacesAndNewlines))
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        return (red, green, blue)
    }
}

extension NSColor {
    convenience init?(hexString: String) {
        guard let rgb = HexColor.parse(hexString) else { return nil }
        self.init(
            calibratedRed: CGFloat(rgb.red),
            green: CGFloat(rgb.green),
            blue: CGFloat(rgb.blue),
            alpha: 1
        )
    }

    var hexString: String {
        let color = usingColorSpace(.deviceRGB) ?? self
        return String(
            format: "#%02X%02X%02X",
            Int(round(color.redComponent * 255)),
            Int(round(color.greenComponent * 255)),
            Int(round(color.blueComponent * 255))
        )
    }
}

extension Color {
    init(hexString: String, fallback: Color = .white) {
        if let rgb = HexColor.parse(hexString) {
            self = Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        } else {
            self = fallback
        }
    }
}
```

- [ ] **Step 2: Remove the duplicate `NSColor` extension from `LibraryWindowController.swift`**

Find the `private extension NSColor { ... }` block at the bottom of `Sources/LunoApp/LibraryWindowController.swift` and delete it entirely (the helper now lives in `HexColor.swift` and is exposed as `internal`).

- [ ] **Step 3: Build to verify**

Run: `swift build`
Expected: build succeeds

- [ ] **Step 4: Add a test that verifies the engine-side normalization helper**

Create `Tests/LunoEngineCoreTests/NowPlaying/HexColorTests.swift`:

```swift
import XCTest
@testable import LunoEngineCore

final class HexColorNormalizationTests: XCTestCase {
    func testNormalizedHexAcceptsValidValues() {
        XCTAssertEqual(NowPlayingAppearance.normalizedHex("#FF6B9C", fallback: "#000000"), "#FF6B9C")
        XCTAssertEqual(NowPlayingAppearance.normalizedHex("ff6b9c", fallback: "#000000"), "#FF6B9C")
    }

    func testNormalizedHexRejectsInvalidLengths() {
        XCTAssertEqual(NowPlayingAppearance.normalizedHex("#FFF", fallback: "#000000"), "#000000")
        XCTAssertEqual(NowPlayingAppearance.normalizedHex("#FF6B9C9C", fallback: "#000000"), "#000000")
    }

    func testNormalizedHexRejectsNonHexCharacters() {
        XCTAssertEqual(NowPlayingAppearance.normalizedHex("#GG6B9C", fallback: "#FF0000"), "#FF0000")
    }
}
```

- [ ] **Step 5: Run tests and full suite**

Run: `swift test --filter HexColorNormalizationTests`
Expected: 3 tests pass

Run: `swift test`
Expected: full suite passes

- [ ] **Step 6: Commit**

```bash
git add Sources/LunoApp/Settings/HexColor.swift Sources/LunoApp/LibraryWindowController.swift Tests/LunoEngineCoreTests/NowPlaying/HexColorTests.swift
git -c commit.gpgsign=false commit -m "refactor: extract HexColor helpers shared by AppKit and SwiftUI"
```

---

## Task 6: Widget reads appearance — shape, colors, per-effect reaction weights

**Files:**
- Modify: `Sources/LunoApp/NowPlayingWidget/NowPlayingWidgetView.swift`
- Modify: `Sources/LunoApp/NowPlayingWidget/NowPlayingWindowController.swift` — pass `appearance` to `NowPlayingWidgetView`

- [ ] **Step 1: Update `NowPlayingWidgetView` to accept and apply appearance**

Replace the body of `Sources/LunoApp/NowPlayingWidget/NowPlayingWidgetView.swift`:

```swift
import LunoEngineCore
import SwiftUI

struct NowPlayingWidgetView: View {
    let style: NowPlayingPreferences.Style
    let track: ResolvedNowPlayingTrack
    let pulseAmplitude: Double
    let appearance: NowPlayingAppearance
    let isHovering: Bool
    let canControl: Bool
    let onCommand: (NowPlayingControlIntent) -> Void

    @State private var animatedPulse: Double = 0

    private var glowPulse: Double { animatedPulse * appearance.glowReaction }
    private var scalePulse: Double { animatedPulse * appearance.scaleReaction }
    private var borderPulse: Double { animatedPulse * appearance.borderReaction }

    var body: some View {
        Group {
            switch style {
            case .albumDominant:
                AlbumDominantStyle(
                    title: displayTitle,
                    artist: track.artist,
                    album: track.album,
                    composer: track.composer,
                    artworkData: track.artworkData,
                    pulseAmplitude: pulseAmplitude,
                    appearance: appearance,
                    isHovering: isHovering,
                    canControl: canControl,
                    onCommand: onCommand
                )
            case .compactBar:
                CompactBarStyle(
                    title: displayTitle,
                    artist: track.artist,
                    album: track.album,
                    composer: track.composer,
                    artworkData: track.artworkData,
                    pulseAmplitude: pulseAmplitude,
                    appearance: appearance,
                    isHovering: isHovering,
                    canControl: canControl,
                    onCommand: onCommand
                )
            case .minimal:
                MinimalStyle(
                    title: displayTitle,
                    artist: track.artist,
                    artworkData: track.artworkData,
                    pulseAmplitude: pulseAmplitude,
                    appearance: appearance,
                    isHovering: isHovering,
                    canControl: canControl,
                    onCommand: onCommand
                )
            }
        }
        .background(GlassBackground(cornerRadius: appearance.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: appearance.cornerRadius)
                .stroke(
                    Color(hexString: appearance.textColor)
                        .opacity(min(appearance.borderOpacity + borderPulse * 1.75, 1.0)),
                    lineWidth: appearance.borderWidth + borderPulse * 7.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: appearance.cornerRadius))
        .scaleEffect(1.0 + scalePulse * 0.20)
        .shadow(
            color: Color(hexString: appearance.glowTint).opacity(min(glowPulse * 2.25, 1.0)),
            radius: glowPulse * 40
        )
        .onChange(of: pulseAmplitude) { _, newValue in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                animatedPulse = min(max(newValue, 0), 1)
            }
        }
    }

    private var displayTitle: String {
        track.isAdvertisement ? "Advertisement" : track.title
    }
}

extension NowPlayingPreferences.Style {
    static let glowMargin: CGFloat = 48

    var widgetSize: CGSize {
        switch self {
        case .albumDominant:
            return CGSize(width: 180, height: 216)
        case .compactBar:
            return CGSize(width: 280, height: 72)
        case .minimal:
            return CGSize(width: 240, height: 52)
        }
    }

    var windowSize: CGSize {
        let margin = Self.glowMargin * 2
        return CGSize(width: widgetSize.width + margin, height: widgetSize.height + margin)
    }
}
```

- [ ] **Step 2: Update `RootContainer` in `NowPlayingWindowController.swift` to forward appearance**

Find the existing `NowPlayingWidgetView(...)` call in `RootContainer.body` inside `Sources/LunoApp/NowPlayingWidget/NowPlayingWindowController.swift` and replace it with:

```swift
                NowPlayingWidgetView(
                    style: viewModel.preferences.style,
                    track: track,
                    pulseAmplitude: viewModel.pulseAmplitude,
                    appearance: viewModel.preferences.appearance,
                    isHovering: viewModel.isHovering,
                    canControl: track.source != .mediaRemote && !track.isAdvertisement,
                    onCommand: { intent in viewModel.send(intent) }
                )
```

- [ ] **Step 3: Build to catch missing parameters in style files**

Run: `swift build`
Expected: FAIL (Style component initializers don't accept `appearance:` yet) — these are fixed in Task 7.

If the build succeeds because the existing `Style` files already happen to accept extra params, that's fine — proceed.

- [ ] **Step 4: Commit (partial — Style components fixed in next task)**

Skip the commit if the build fails. Move directly to Task 7 to make this compile, then commit at the end of Task 7 with both changes.

---

## Task 7: Style components accept `appearance` and apply typography weights

**Files:**
- Modify: `Sources/LunoApp/NowPlayingWidget/Styles/AlbumDominantStyle.swift`
- Modify: `Sources/LunoApp/NowPlayingWidget/Styles/CompactBarStyle.swift`
- Modify: `Sources/LunoApp/NowPlayingWidget/Styles/MinimalStyle.swift`

- [ ] **Step 1: Add a `Font.Weight` mapping helper to `NowPlayingAppearance.FontWeight`**

This stays inside the SwiftUI-using target. Create a small file `Sources/LunoApp/NowPlayingWidget/Styles/AppearanceFontWeight.swift`:

```swift
import LunoEngineCore
import SwiftUI

extension NowPlayingAppearance.FontWeight {
    var swiftUIWeight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}
```

- [ ] **Step 2: Update `AlbumDominantStyle.swift`**

Read the existing file to determine the current signature. Then update it to add `appearance: NowPlayingAppearance` after `pulseAmplitude`, and apply `.fontWeight(appearance.titleWeight.swiftUIWeight)` to the title Text and `.fontWeight(appearance.subtitleWeight.swiftUIWeight)` to the artist Text. Apply `Color(hexString: appearance.textColor)` to the title's `foregroundStyle` and the artist's foregroundStyle (keep the existing opacity multiplier on the artist line).

Concretely, find the existing title/artist `Text(...)` definitions in `body` and modify so they look like:

```swift
                Text(title)
                    .font(.system(size: 13, weight: appearance.titleWeight.swiftUIWeight))
                    .foregroundStyle(Color(hexString: appearance.textColor))
                    .lineLimit(1)
                if let artist {
                    Text(artist)
                        .font(.system(size: 11, weight: appearance.subtitleWeight.swiftUIWeight))
                        .foregroundStyle(Color(hexString: appearance.textColor).opacity(0.7))
                        .lineLimit(1)
                }
```

(Keep the rest of the file's existing layout intact; only the title/subtitle Text usages and the property list change.)

- [ ] **Step 3: Update `CompactBarStyle.swift`**

Open `Sources/LunoApp/NowPlayingWidget/Styles/CompactBarStyle.swift`. Add `let appearance: NowPlayingAppearance` to the property list (right after `let pulseAmplitude: Double`). Then for each `Text(...)` in the body, replace the existing `.font(.system(size: ..., weight: .semibold))` / `.font(.system(size: ...))` calls and `.foregroundStyle(...)` calls so they look like:

```swift
                Text(title)
                    .font(.system(size: 13, weight: appearance.titleWeight.swiftUIWeight))
                    .foregroundStyle(Color(hexString: appearance.textColor))
                    .lineLimit(1)
                if let secondary = secondaryLine {
                    Text(secondary)
                        .font(.system(size: 11, weight: appearance.subtitleWeight.swiftUIWeight))
                        .foregroundStyle(Color(hexString: appearance.textColor).opacity(0.7))
                        .lineLimit(1)
                }
                if let composer, !composer.isEmpty {
                    Text(composer)
                        .font(.system(size: 10, weight: appearance.subtitleWeight.swiftUIWeight).italic())
                        .foregroundStyle(Color(hexString: appearance.textColor).opacity(0.45))
                        .lineLimit(1)
                }
```

Adapt the exact variable names (`secondaryLine`, `composer`) to whatever the existing file uses; the structural change is the same — replace the inline `.font(...)` weight and the hardcoded `.foregroundStyle(.white...)` with the appearance-derived values.

- [ ] **Step 4: Update `MinimalStyle.swift`**

Open `Sources/LunoApp/NowPlayingWidget/Styles/MinimalStyle.swift`. Add `let appearance: NowPlayingAppearance` to the property list (after `pulseAmplitude`). In the body, the title Text should become:

```swift
                Text(title)
                    .font(.system(size: 12, weight: appearance.titleWeight.swiftUIWeight))
                    .foregroundStyle(Color(hexString: appearance.textColor))
                    .lineLimit(1)
```

If the file also renders an artist line, apply `appearance.subtitleWeight.swiftUIWeight` and `Color(hexString: appearance.textColor).opacity(0.7)` the same way as in CompactBar.

- [ ] **Step 5: Run a full build**

Run: `swift build`
Expected: build succeeds

- [ ] **Step 6: Manually launch the app and verify defaults look identical**

Run:

```bash
./scripts/build-app.sh && ./.build/artifacts/Luno.app/Contents/MacOS/Luno
```

Enable the now playing widget if not already. Confirm the widget looks the same as before (defaults are unchanged) and bass still triggers the pulse animation. Quit.

- [ ] **Step 7: Commit the widget-side changes together**

```bash
git add Sources/LunoApp/NowPlayingWidget/
git -c commit.gpgsign=false commit -m "feat(now-playing): widget renders from appearance preferences"
```

---

## Task 8: `SettingsSection` enum + `SettingsSidebar` view

**Files:**
- Create: `Sources/LunoApp/Settings/SettingsSection.swift`
- Create: `Sources/LunoApp/Settings/SettingsSidebar.swift`

- [ ] **Step 1: Create the section enum**

```swift
// Sources/LunoApp/Settings/SettingsSection.swift
import Foundation

enum SettingsSection: Hashable, CaseIterable {
    case library
    case nowPlayingBasic
    case nowPlayingAppearance
    case nowPlayingReactivity
    case audioReactor

    var title: String {
        switch self {
        case .library: "Library"
        case .nowPlayingBasic: "Basic"
        case .nowPlayingAppearance: "Appearance"
        case .nowPlayingReactivity: "Reactivity"
        case .audioReactor: "Audio Reactor"
        }
    }
}

/// Outline nodes for the sidebar: top-level groups and their child sections.
enum SettingsOutlineNode: Hashable {
    case group(title: String, children: [SettingsSection])
    case leaf(SettingsSection)

    var title: String {
        switch self {
        case .group(let title, _): title
        case .leaf(let section): section.title
        }
    }
}

enum SettingsOutline {
    /// The tree shown in the sidebar.
    static let nodes: [SettingsOutlineNode] = [
        .leaf(.library),
        .group(title: "Now Playing", children: [
            .nowPlayingBasic,
            .nowPlayingAppearance,
            .nowPlayingReactivity
        ]),
        .leaf(.audioReactor)
    ]
}
```

- [ ] **Step 2: Create the sidebar view**

```swift
// Sources/LunoApp/Settings/SettingsSidebar.swift
import AppKit

@MainActor
protocol SettingsSidebarDelegate: AnyObject {
    func sidebar(_ sidebar: SettingsSidebar, didSelect section: SettingsSection)
}

@MainActor
final class SettingsSidebar: NSObject {
    let scrollView: NSScrollView
    let outlineView: NSOutlineView
    weak var delegate: SettingsSidebarDelegate?

    private let column: NSTableColumn

    override init() {
        scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false

        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.indentationPerLevel = 12
        outlineView.style = .sourceList
        outlineView.allowsMultipleSelection = false
        outlineView.focusRingType = .none
        outlineView.intercellSpacing = NSSize(width: 0, height: 4)

        column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        column.title = "Section"
        column.minWidth = 140
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView.documentView = outlineView
        super.init()

        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.expandItem(nil, expandChildren: true)
    }

    func selectInitialItem() {
        outlineView.expandItem(nil, expandChildren: true)
        if outlineView.numberOfRows > 0 {
            outlineView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
}

extension SettingsSidebar: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return SettingsOutline.nodes.count }
        if let node = item as? SettingsOutlineNode {
            switch node {
            case .group(_, let children): return children.count
            case .leaf: return 0
            }
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return SettingsOutline.nodes[index] }
        if let node = item as? SettingsOutlineNode, case .group(_, let children) = node {
            return SettingsOutlineNode.leaf(children[index])
        }
        return SettingsOutlineNode.leaf(.library)
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let node = item as? SettingsOutlineNode, case .group = node {
            return true
        }
        return false
    }
}

extension SettingsSidebar: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SettingsOutlineNode else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("Cell")
        let cell: NSTableCellView
        if let reused = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier
            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            cell.textField = label
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        cell.textField?.stringValue = node.title
        switch node {
        case .group:
            cell.textField?.font = .systemFont(ofSize: 11, weight: .semibold)
            cell.textField?.textColor = .secondaryLabelColor
        case .leaf(let section):
            cell.textField?.font = .systemFont(ofSize: 13)
            cell.textField?.textColor = .labelColor
            _ = section // reserved for future per-section glyph
        }
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        if let node = item as? SettingsOutlineNode, case .group = node {
            return false
        }
        return true
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard outlineView.selectedRow >= 0,
              let node = outlineView.item(atRow: outlineView.selectedRow) as? SettingsOutlineNode,
              case .leaf(let section) = node
        else { return }
        delegate?.sidebar(self, didSelect: section)
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `swift build`
Expected: build succeeds

- [ ] **Step 4: Commit**

```bash
git add Sources/LunoApp/Settings/SettingsSection.swift Sources/LunoApp/Settings/SettingsSidebar.swift
git -c commit.gpgsign=false commit -m "feat(settings): sidebar outline view + section enum"
```

---

## Task 9: Extract `LibrarySectionView` from existing controller

**Files:**
- Create: `Sources/LunoApp/Settings/LibrarySectionView.swift`

This task moves the existing wallpaper/preset/display UI into a self-contained view object without changing behavior. The current `LibraryWindowController` still owns lifecycle, but the view object owns layout.

- [ ] **Step 1: Create the view class**

```swift
// Sources/LunoApp/Settings/LibrarySectionView.swift
import AppKit
import CoreGraphics
import LunoEngineCore

@MainActor
protocol LibrarySectionViewDelegate: AnyObject {
    func librarySectionDidRequestApply(_ view: LibrarySectionView)
    func librarySectionDidRequestSavePreset(_ view: LibrarySectionView)
    func librarySectionDidRequestImport(_ view: LibrarySectionView)
    func librarySectionDidRequestExport(_ view: LibrarySectionView)
}

@MainActor
final class LibrarySectionView: NSView {
    weak var delegate: LibrarySectionViewDelegate?

    let packagePopup = NSPopUpButton()
    let displayPopup = NSPopUpButton()
    let presetNameField = NSTextField()
    let parameterStack = NSStackView()

    private(set) var controlsByParameterID: [String: NSControl] = [:]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func buildLayout() {
        translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20)
        ])

        packagePopup.widthAnchor.constraint(equalToConstant: 340).isActive = true
        packagePopup.target = self
        packagePopup.action = #selector(noop)
        stack.addArrangedSubview(labeledRow(label: "Wallpaper", view: packagePopup))

        displayPopup.widthAnchor.constraint(equalToConstant: 220).isActive = true
        stack.addArrangedSubview(labeledRow(label: "Display", view: displayPopup))

        presetNameField.placeholderString = "Preset name"
        presetNameField.stringValue = "Default"
        presetNameField.widthAnchor.constraint(equalToConstant: 220).isActive = true
        stack.addArrangedSubview(labeledRow(label: "Preset", view: presetNameField))

        parameterStack.orientation = .vertical
        parameterStack.alignment = .leading
        parameterStack.spacing = 10
        stack.addArrangedSubview(parameterStack)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.addArrangedSubview(NSButton(title: "Apply", target: self, action: #selector(applyTapped)))
        buttonRow.addArrangedSubview(NSButton(title: "Save Preset", target: self, action: #selector(saveTapped)))
        buttonRow.addArrangedSubview(NSButton(title: "Import", target: self, action: #selector(importTapped)))
        buttonRow.addArrangedSubview(NSButton(title: "Export", target: self, action: #selector(exportTapped)))
        stack.addArrangedSubview(buttonRow)
    }

    func setPackagePopupTarget(_ target: AnyObject, action: Selector) {
        packagePopup.target = target
        packagePopup.action = action
    }

    func rebuildParameterControls(
        with package: LunoPackageRecord?,
        presets: [WallpaperPreset]
    ) {
        controlsByParameterID.removeAll()
        parameterStack.arrangedSubviews.forEach {
            parameterStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard let package else {
            parameterStack.addArrangedSubview(NSTextField(labelWithString: "Import a .luno package to begin."))
            return
        }

        let matchingPreset = presets.first { $0.packageID == package.manifest.id }
        presetNameField.stringValue = matchingPreset?.name ?? "Default"

        for parameter in package.manifest.parameters {
            let currentValue = matchingPreset?.values[parameter.id] ?? parameter.defaultValue
            let control = makeControl(for: parameter, value: currentValue)
            controlsByParameterID[parameter.id] = control
            parameterStack.addArrangedSubview(labeledRow(label: parameter.name, view: control))
        }
    }

    @objc private func applyTapped() { delegate?.librarySectionDidRequestApply(self) }
    @objc private func saveTapped() { delegate?.librarySectionDidRequestSavePreset(self) }
    @objc private func importTapped() { delegate?.librarySectionDidRequestImport(self) }
    @objc private func exportTapped() { delegate?.librarySectionDidRequestExport(self) }
    @objc private func noop() {}

    private func labeledRow(label: String, view: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        let labelView = NSTextField(labelWithString: label)
        labelView.widthAnchor.constraint(equalToConstant: 90).isActive = true
        row.addArrangedSubview(labelView)
        row.addArrangedSubview(view)
        return row
    }

    private func makeControl(for parameter: WallpaperParameterDefinition, value: ParameterValue) -> NSControl {
        switch parameter.type {
        case .float:
            let slider = NSSlider(
                value: value.floatValue ?? 0,
                minValue: parameter.min ?? 0,
                maxValue: parameter.max ?? 1,
                target: nil,
                action: nil
            )
            slider.widthAnchor.constraint(equalToConstant: 220).isActive = true
            return slider
        case .bool:
            let button = NSButton(checkboxWithTitle: "", target: nil, action: nil)
            button.state = (value.boolValue ?? false) ? .on : .off
            return button
        case .color:
            let well = NSColorWell()
            well.color = NSColor(hexString: value.stringValue ?? "#FFFFFF") ?? .white
            return well
        case .enum:
            let popup = NSPopUpButton()
            popup.addItems(withTitles: parameter.options ?? [])
            if let selected = value.stringValue {
                popup.selectItem(withTitle: selected)
            }
            popup.widthAnchor.constraint(equalToConstant: 220).isActive = true
            return popup
        }
    }

    func currentParameterValues(for manifest: WallpaperPackageManifest) -> [String: ParameterValue] {
        var values: [String: ParameterValue] = [:]
        for parameter in manifest.parameters {
            guard let control = controlsByParameterID[parameter.id] else {
                values[parameter.id] = parameter.defaultValue
                continue
            }
            switch parameter.type {
            case .float:
                values[parameter.id] = .float((control as? NSSlider)?.doubleValue ?? parameter.defaultValue.floatValue ?? 0)
            case .bool:
                values[parameter.id] = .bool((control as? NSButton)?.state == .on)
            case .color:
                let color = (control as? NSColorWell)?.color.hexString ?? parameter.defaultValue.stringValue ?? "#FFFFFF"
                values[parameter.id] = .color(color)
            case .enum:
                let selected = (control as? NSPopUpButton)?.selectedItem?.title ?? parameter.defaultValue.stringValue ?? ""
                values[parameter.id] = .string(selected)
            }
        }
        return values
    }
}
```

- [ ] **Step 2: Build to verify (controller still builds independently)**

Run: `swift build`
Expected: build succeeds (this view is unused by the controller yet — wiring happens in Task 13).

- [ ] **Step 3: Commit**

```bash
git add Sources/LunoApp/Settings/LibrarySectionView.swift
git -c commit.gpgsign=false commit -m "refactor(settings): extract LibrarySectionView"
```

---

## Task 10: `NowPlayingBasicSectionView`

**Files:**
- Create: `Sources/LunoApp/Settings/NowPlayingBasicSectionView.swift`

- [ ] **Step 1: Create the view**

```swift
// Sources/LunoApp/Settings/NowPlayingBasicSectionView.swift
import AppKit
import LunoEngineCore

@MainActor
protocol NowPlayingBasicSectionViewDelegate: AnyObject {
    func nowPlayingBasicSection(_ view: NowPlayingBasicSectionView, didChange preferences: NowPlayingPreferences)
}

@MainActor
final class NowPlayingBasicSectionView: NSView {
    weak var delegate: NowPlayingBasicSectionViewDelegate?

    private let enableSwitch = NSSwitch()
    private let stylePopup = NSPopUpButton()
    private let reactivitySwitch = NSSwitch()
    private let keepVisibleSwitch = NSSwitch()

    private var preferences: NowPlayingPreferences = .defaults

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func configure(_ preferences: NowPlayingPreferences) {
        self.preferences = preferences
        enableSwitch.state = preferences.isEnabled ? .on : .off
        reactivitySwitch.state = preferences.audioReactivityEnabled ? .on : .off
        keepVisibleSwitch.state = preferences.keepVisibleWhilePaused ? .on : .off
        let index = NowPlayingPreferences.Style.allCases.firstIndex(of: preferences.style) ?? 0
        stylePopup.selectItem(at: index)
    }

    private func buildLayout() {
        translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20)
        ])

        let heading = NSTextField(labelWithString: "Now Playing widget")
        heading.font = .boldSystemFont(ofSize: 13)
        stack.addArrangedSubview(heading)

        enableSwitch.target = self
        enableSwitch.action = #selector(enableChanged)
        stack.addArrangedSubview(labeled("Enable widget", control: enableSwitch))

        stylePopup.removeAllItems()
        stylePopup.addItems(withTitles: ["A — Album-art dominant", "B — Compact bar", "C — Minimal"])
        stylePopup.target = self
        stylePopup.action = #selector(styleChanged)
        stack.addArrangedSubview(labeled("Style", control: stylePopup))

        reactivitySwitch.target = self
        reactivitySwitch.action = #selector(reactivityChanged)
        stack.addArrangedSubview(labeled("React to music", control: reactivitySwitch))

        keepVisibleSwitch.target = self
        keepVisibleSwitch.action = #selector(keepVisibleChanged)
        stack.addArrangedSubview(labeled("Keep visible while paused", control: keepVisibleSwitch))
    }

    private func labeled(_ title: String, control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 200).isActive = true
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    @objc private func enableChanged(_ sender: NSSwitch) {
        preferences.isEnabled = sender.state == .on
        delegate?.nowPlayingBasicSection(self, didChange: preferences)
    }

    @objc private func styleChanged(_ sender: NSPopUpButton) {
        let styles = NowPlayingPreferences.Style.allCases
        let index = sender.indexOfSelectedItem
        guard styles.indices.contains(index) else { return }
        preferences.style = styles[index]
        delegate?.nowPlayingBasicSection(self, didChange: preferences)
    }

    @objc private func reactivityChanged(_ sender: NSSwitch) {
        preferences.audioReactivityEnabled = sender.state == .on
        delegate?.nowPlayingBasicSection(self, didChange: preferences)
    }

    @objc private func keepVisibleChanged(_ sender: NSSwitch) {
        preferences.keepVisibleWhilePaused = sender.state == .on
        delegate?.nowPlayingBasicSection(self, didChange: preferences)
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build`
Expected: build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/LunoApp/Settings/NowPlayingBasicSectionView.swift
git -c commit.gpgsign=false commit -m "feat(settings): NowPlayingBasicSectionView"
```

---

## Task 11: `NowPlayingAppearanceSectionView` — preset + shape + colors + typography

**Files:**
- Create: `Sources/LunoApp/Settings/NowPlayingAppearanceSectionView.swift`

- [ ] **Step 1: Create the view**

```swift
// Sources/LunoApp/Settings/NowPlayingAppearanceSectionView.swift
import AppKit
import LunoEngineCore

@MainActor
protocol NowPlayingAppearanceSectionViewDelegate: AnyObject {
    func nowPlayingAppearanceSection(_ view: NowPlayingAppearanceSectionView, didChange appearance: NowPlayingAppearance)
}

@MainActor
final class NowPlayingAppearanceSectionView: NSView {
    weak var delegate: NowPlayingAppearanceSectionViewDelegate?

    private let presetPopup = NSPopUpButton()
    private let cornerSlider = LabeledValueSlider(minValue: 0, maxValue: 28)
    private let paddingSlider = LabeledValueSlider(minValue: 8, maxValue: 24)
    private let borderWidthSlider = LabeledValueSlider(minValue: 0, maxValue: 6)
    private let borderOpacitySlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let titleWeightPopup = NSPopUpButton()
    private let subtitleWeightPopup = NSPopUpButton()
    private let textColorWell = NSColorWell()
    private let accentColorWell = NSColorWell()
    private let glowColorWell = NSColorWell()

    private var appearance: NowPlayingAppearance = .default
    private var isInternallyUpdating = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func configure(_ appearance: NowPlayingAppearance) {
        self.appearance = appearance
        isInternallyUpdating = true
        defer { isInternallyUpdating = false }

        rebuildPresetMenu(selecting: appearance)
        cornerSlider.value = appearance.cornerRadius
        paddingSlider.value = appearance.padding
        borderWidthSlider.value = appearance.borderWidth
        borderOpacitySlider.value = appearance.borderOpacity
        selectWeight(titleWeightPopup, appearance.titleWeight)
        selectWeight(subtitleWeightPopup, appearance.subtitleWeight)
        textColorWell.color = NSColor(hexString: appearance.textColor) ?? .white
        accentColorWell.color = NSColor(hexString: appearance.accentColor) ?? .white
        glowColorWell.color = NSColor(hexString: appearance.glowTint) ?? .white
    }

    private func buildLayout() {
        translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20)
        ])

        let heading = NSTextField(labelWithString: "Appearance")
        heading.font = .boldSystemFont(ofSize: 13)
        stack.addArrangedSubview(heading)

        presetPopup.target = self
        presetPopup.action = #selector(presetChanged)
        stack.addArrangedSubview(labeled("Preset", control: presetPopup))

        cornerSlider.onChange = { [weak self] value in self?.appearanceField(\.cornerRadius, value) }
        paddingSlider.onChange = { [weak self] value in self?.appearanceField(\.padding, value) }
        borderWidthSlider.onChange = { [weak self] value in self?.appearanceField(\.borderWidth, value) }
        borderOpacitySlider.onChange = { [weak self] value in self?.appearanceField(\.borderOpacity, value) }
        stack.addArrangedSubview(labeled("Corner radius", control: cornerSlider))
        stack.addArrangedSubview(labeled("Padding", control: paddingSlider))
        stack.addArrangedSubview(labeled("Border width", control: borderWidthSlider))
        stack.addArrangedSubview(labeled("Border opacity", control: borderOpacitySlider))

        configureWeightPopup(titleWeightPopup, selector: #selector(titleWeightChanged))
        configureWeightPopup(subtitleWeightPopup, selector: #selector(subtitleWeightChanged))
        stack.addArrangedSubview(labeled("Title weight", control: titleWeightPopup))
        stack.addArrangedSubview(labeled("Subtitle weight", control: subtitleWeightPopup))

        configureColorWell(textColorWell, selector: #selector(textColorChanged))
        configureColorWell(accentColorWell, selector: #selector(accentColorChanged))
        configureColorWell(glowColorWell, selector: #selector(glowColorChanged))
        stack.addArrangedSubview(labeled("Text color", control: textColorWell))
        stack.addArrangedSubview(labeled("Accent color", control: accentColorWell))
        stack.addArrangedSubview(labeled("Glow tint", control: glowColorWell))

        rebuildPresetMenu(selecting: appearance)
    }

    private func labeled(_ title: String, control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 150).isActive = true
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func configureWeightPopup(_ popup: NSPopUpButton, selector: Selector) {
        popup.removeAllItems()
        for weight in NowPlayingAppearance.FontWeight.allCases {
            popup.addItem(withTitle: weight.displayName)
        }
        popup.target = self
        popup.action = selector
        popup.widthAnchor.constraint(equalToConstant: 160).isActive = true
    }

    private func configureColorWell(_ well: NSColorWell, selector: Selector) {
        well.target = self
        well.action = selector
        well.widthAnchor.constraint(equalToConstant: 60).isActive = true
        well.heightAnchor.constraint(equalToConstant: 24).isActive = true
    }

    private func selectWeight(_ popup: NSPopUpButton, _ weight: NowPlayingAppearance.FontWeight) {
        guard let index = NowPlayingAppearance.FontWeight.allCases.firstIndex(of: weight) else { return }
        popup.selectItem(at: index)
    }

    private func rebuildPresetMenu(selecting appearance: NowPlayingAppearance) {
        presetPopup.removeAllItems()
        for preset in NowPlayingAppearance.presets {
            presetPopup.addItem(withTitle: preset.name)
            presetPopup.lastItem?.representedObject = preset.id
        }
        presetPopup.menu?.addItem(.separator())
        let customItem = NSMenuItem(title: "Custom", action: nil, keyEquivalent: "")
        customItem.representedObject = "custom"
        customItem.isEnabled = false
        presetPopup.menu?.addItem(customItem)

        if let match = appearance.matchingPreset(),
           let index = NowPlayingAppearance.presets.firstIndex(where: { $0.id == match.id }) {
            presetPopup.selectItem(at: index)
        } else {
            // Select the Custom item (the very last entry)
            presetPopup.selectItem(at: presetPopup.numberOfItems - 1)
        }
    }

    private func appearanceField(_ keyPath: WritableKeyPath<NowPlayingAppearance, Double>, _ value: Double) {
        guard !isInternallyUpdating else { return }
        appearance[keyPath: keyPath] = value
        commit(reconciledFromColorWells: false)
    }

    private func commit(reconciledFromColorWells: Bool) {
        if reconciledFromColorWells {
            appearance.textColor = textColorWell.color.hexString
            appearance.accentColor = accentColorWell.color.hexString
            appearance.glowTint = glowColorWell.color.hexString
        }
        // Re-clamp through the initializer so out-of-range slider values are normalized.
        let clamped = NowPlayingAppearance(
            cornerRadius: appearance.cornerRadius,
            padding: appearance.padding,
            borderWidth: appearance.borderWidth,
            borderOpacity: appearance.borderOpacity,
            titleWeight: appearance.titleWeight,
            subtitleWeight: appearance.subtitleWeight,
            textColor: appearance.textColor,
            accentColor: appearance.accentColor,
            glowTint: appearance.glowTint,
            scaleReaction: appearance.scaleReaction,
            glowReaction: appearance.glowReaction,
            borderReaction: appearance.borderReaction
        )
        appearance = clamped
        rebuildPresetMenu(selecting: appearance)
        delegate?.nowPlayingAppearanceSection(self, didChange: appearance)
    }

    @objc private func presetChanged(_ sender: NSPopUpButton) {
        guard let id = sender.selectedItem?.representedObject as? String,
              let preset = NowPlayingAppearance.presets.first(where: { $0.id == id })
        else { return }
        configure(preset.appearance)
        delegate?.nowPlayingAppearanceSection(self, didChange: preset.appearance)
    }

    @objc private func titleWeightChanged(_ sender: NSPopUpButton) {
        guard !isInternallyUpdating else { return }
        let weights = NowPlayingAppearance.FontWeight.allCases
        guard weights.indices.contains(sender.indexOfSelectedItem) else { return }
        appearance.titleWeight = weights[sender.indexOfSelectedItem]
        commit(reconciledFromColorWells: false)
    }

    @objc private func subtitleWeightChanged(_ sender: NSPopUpButton) {
        guard !isInternallyUpdating else { return }
        let weights = NowPlayingAppearance.FontWeight.allCases
        guard weights.indices.contains(sender.indexOfSelectedItem) else { return }
        appearance.subtitleWeight = weights[sender.indexOfSelectedItem]
        commit(reconciledFromColorWells: false)
    }

    @objc private func textColorChanged(_ sender: NSColorWell) {
        guard !isInternallyUpdating else { return }
        commit(reconciledFromColorWells: true)
    }

    @objc private func accentColorChanged(_ sender: NSColorWell) {
        guard !isInternallyUpdating else { return }
        commit(reconciledFromColorWells: true)
    }

    @objc private func glowColorChanged(_ sender: NSColorWell) {
        guard !isInternallyUpdating else { return }
        commit(reconciledFromColorWells: true)
    }
}

private extension NowPlayingAppearance.FontWeight {
    var displayName: String {
        switch self {
        case .regular: "Regular"
        case .medium: "Medium"
        case .semibold: "Semibold"
        case .bold: "Bold"
        case .heavy: "Heavy"
        case .black: "Black"
        }
    }
}

@MainActor
final class LabeledValueSlider: NSStackView {
    private let slider = NSSlider()
    private let valueLabel = NSTextField(labelWithString: "")
    private let displayAsPercent: Bool

    var onChange: ((Double) -> Void)?

    var value: Double {
        get { slider.doubleValue }
        set {
            slider.doubleValue = newValue
            updateLabel()
        }
    }

    init(minValue: Double, maxValue: Double, displayAsPercent: Bool = false) {
        self.displayAsPercent = displayAsPercent
        super.init(frame: .zero)

        slider.minValue = minValue
        slider.maxValue = maxValue
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.widthAnchor.constraint(equalToConstant: 180).isActive = true

        valueLabel.alignment = .right
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true

        orientation = .horizontal
        alignment = .centerY
        spacing = 8
        setViews([slider, valueLabel], in: .leading)
        updateLabel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    @objc private func sliderChanged() {
        updateLabel()
        onChange?(slider.doubleValue)
    }

    private func updateLabel() {
        if displayAsPercent {
            valueLabel.stringValue = "\(Int(round(slider.doubleValue * 100)))%"
        } else {
            valueLabel.stringValue = String(format: "%.0f", slider.doubleValue)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build`
Expected: build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/LunoApp/Settings/NowPlayingAppearanceSectionView.swift
git -c commit.gpgsign=false commit -m "feat(settings): NowPlayingAppearanceSectionView with presets, shape, colors, typography"
```

---

## Task 12: `NowPlayingReactivitySectionView`

**Files:**
- Create: `Sources/LunoApp/Settings/NowPlayingReactivitySectionView.swift`

- [ ] **Step 1: Create the view**

```swift
// Sources/LunoApp/Settings/NowPlayingReactivitySectionView.swift
import AppKit
import LunoEngineCore

@MainActor
protocol NowPlayingReactivitySectionViewDelegate: AnyObject {
    func nowPlayingReactivitySection(_ view: NowPlayingReactivitySectionView, didChange preferences: NowPlayingPreferences)
}

@MainActor
final class NowPlayingReactivitySectionView: NSView {
    weak var delegate: NowPlayingReactivitySectionViewDelegate?

    private let masterSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let glowSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let scaleSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let borderSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)

    private var preferences: NowPlayingPreferences = .defaults
    private var isInternallyUpdating = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func configure(_ preferences: NowPlayingPreferences) {
        self.preferences = preferences
        isInternallyUpdating = true
        defer { isInternallyUpdating = false }
        masterSlider.value = preferences.audioReactivityIntensity
        glowSlider.value = preferences.appearance.glowReaction
        scaleSlider.value = preferences.appearance.scaleReaction
        borderSlider.value = preferences.appearance.borderReaction
        applyMasterEnabledState()
    }

    private func buildLayout() {
        translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20)
        ])

        let heading = NSTextField(labelWithString: "Reactivity")
        heading.font = .boldSystemFont(ofSize: 13)
        stack.addArrangedSubview(heading)

        masterSlider.onChange = { [weak self] value in
            guard let self, !isInternallyUpdating else { return }
            preferences.audioReactivityIntensity = value
            applyMasterEnabledState()
            delegate?.nowPlayingReactivitySection(self, didChange: preferences)
        }
        stack.addArrangedSubview(labeled("Master intensity", control: masterSlider))

        let divider = NSTextField(labelWithString: "Per-effect weights")
        divider.font = .systemFont(ofSize: 11)
        divider.textColor = .secondaryLabelColor
        stack.addArrangedSubview(divider)

        glowSlider.onChange = { [weak self] value in self?.setReactionField(\.glowReaction, value) }
        scaleSlider.onChange = { [weak self] value in self?.setReactionField(\.scaleReaction, value) }
        borderSlider.onChange = { [weak self] value in self?.setReactionField(\.borderReaction, value) }
        stack.addArrangedSubview(labeled("Glow", control: glowSlider))
        stack.addArrangedSubview(labeled("Scale", control: scaleSlider))
        stack.addArrangedSubview(labeled("Border", control: borderSlider))
    }

    private func labeled(_ title: String, control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 150).isActive = true
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func applyMasterEnabledState() {
        let masterActive = preferences.audioReactivityIntensity > 0 && preferences.audioReactivityEnabled
        glowSlider.isEnabled = masterActive
        scaleSlider.isEnabled = masterActive
        borderSlider.isEnabled = masterActive
    }

    private func setReactionField(_ keyPath: WritableKeyPath<NowPlayingAppearance, Double>, _ value: Double) {
        guard !isInternallyUpdating else { return }
        preferences.appearance[keyPath: keyPath] = value
        // Re-clamp through the initializer (writing the keypath bypasses clamping).
        preferences.appearance = NowPlayingAppearance(
            cornerRadius: preferences.appearance.cornerRadius,
            padding: preferences.appearance.padding,
            borderWidth: preferences.appearance.borderWidth,
            borderOpacity: preferences.appearance.borderOpacity,
            titleWeight: preferences.appearance.titleWeight,
            subtitleWeight: preferences.appearance.subtitleWeight,
            textColor: preferences.appearance.textColor,
            accentColor: preferences.appearance.accentColor,
            glowTint: preferences.appearance.glowTint,
            scaleReaction: preferences.appearance.scaleReaction,
            glowReaction: preferences.appearance.glowReaction,
            borderReaction: preferences.appearance.borderReaction
        )
        delegate?.nowPlayingReactivitySection(self, didChange: preferences)
    }
}

```

Also extend `LabeledValueSlider` so the wrapper can be disabled. Open `Sources/LunoApp/Settings/NowPlayingAppearanceSectionView.swift` and add this property to the `LabeledValueSlider` class (note: not `override` — `NSStackView` does not declare `isEnabled`):

```swift
    var isEnabled: Bool {
        get { slider.isEnabled }
        set {
            slider.isEnabled = newValue
            valueLabel.alphaValue = newValue ? 1 : 0.4
        }
    }
```

- [ ] **Step 2: Build to verify**

Run: `swift build`
Expected: build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/LunoApp/Settings/NowPlayingReactivitySectionView.swift Sources/LunoApp/Settings/NowPlayingAppearanceSectionView.swift
git -c commit.gpgsign=false commit -m "feat(settings): NowPlayingReactivitySectionView with master + per-effect"
```

---

## Task 13: `AudioReactorSectionView`

**Files:**
- Create: `Sources/LunoApp/Settings/AudioReactorSectionView.swift`

The audio reactor section moves from `LibraryWindowController` into a dedicated view object. Method bodies and behavior are preserved verbatim.

- [ ] **Step 1: Create the view**

```swift
// Sources/LunoApp/Settings/AudioReactorSectionView.swift
import AppKit
import LunoEngineCore

@MainActor
protocol AudioReactorSectionViewDelegate: AnyObject {
    func audioReactorSection(_ view: AudioReactorSectionView, didChange preferences: AudioReactorPreferences)
}

@MainActor
final class AudioReactorSectionView: NSView {
    weak var delegate: AudioReactorSectionViewDelegate?

    private let enableSwitch = NSSwitch()
    private let intensitySlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let responseControl = NSSegmentedControl(labels: ["Soft", "Punchy", "Hard"], trackingMode: .selectOne, target: nil, action: nil)
    private let bassPulseSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let pulseRingSwitch = NSSwitch()
    private let spectrumBarsSwitch = NSSwitch()
    private let waveLineSwitch = NSSwitch()
    private let overlayOpacitySlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)

    private var preferences: AudioReactorPreferences = .defaults
    private var isInternallyUpdating = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func configure(_ preferences: AudioReactorPreferences) {
        self.preferences = preferences
        isInternallyUpdating = true
        defer { isInternallyUpdating = false }
        enableSwitch.state = preferences.isEnabled ? .on : .off
        intensitySlider.value = preferences.intensity
        responseControl.selectedSegment = AudioReactorResponse.allCases.firstIndex(of: preferences.response) ?? 1
        bassPulseSlider.value = preferences.bassPulseStrength
        pulseRingSwitch.state = preferences.showsPulseRing ? .on : .off
        spectrumBarsSwitch.state = preferences.showsSpectrumBars ? .on : .off
        waveLineSwitch.state = preferences.showsWaveLine ? .on : .off
        overlayOpacitySlider.value = preferences.overlayOpacity
        applyEnabledState()
    }

    private func buildLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20)
        ])

        let heading = NSTextField(labelWithString: "Audio Reactor")
        heading.font = .boldSystemFont(ofSize: 13)
        stack.addArrangedSubview(heading)

        enableSwitch.target = self
        enableSwitch.action = #selector(enabledChanged)
        stack.addArrangedSubview(labeled("Enabled", control: enableSwitch))

        intensitySlider.onChange = { [weak self] value in self?.commitField { $0.intensity = value } }
        stack.addArrangedSubview(labeled("Intensity", control: intensitySlider))

        responseControl.target = self
        responseControl.action = #selector(responseChanged)
        stack.addArrangedSubview(labeled("Response", control: responseControl))

        bassPulseSlider.onChange = { [weak self] value in self?.commitField { $0.bassPulseStrength = value } }
        stack.addArrangedSubview(labeled("Bass pulse", control: bassPulseSlider))

        pulseRingSwitch.target = self
        pulseRingSwitch.action = #selector(pulseRingChanged)
        stack.addArrangedSubview(labeled("Pulse ring", control: pulseRingSwitch))

        spectrumBarsSwitch.target = self
        spectrumBarsSwitch.action = #selector(spectrumBarsChanged)
        stack.addArrangedSubview(labeled("Spectrum bars", control: spectrumBarsSwitch))

        waveLineSwitch.target = self
        waveLineSwitch.action = #selector(waveLineChanged)
        stack.addArrangedSubview(labeled("Wave line", control: waveLineSwitch))

        overlayOpacitySlider.onChange = { [weak self] value in self?.commitField { $0.overlayOpacity = value } }
        stack.addArrangedSubview(labeled("Overlay opacity", control: overlayOpacitySlider))
    }

    private func labeled(_ title: String, control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 150).isActive = true
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func applyEnabledState() {
        let active = preferences.isEnabled
        intensitySlider.isEnabled = active
        responseControl.isEnabled = active
        bassPulseSlider.isEnabled = active
        pulseRingSwitch.isEnabled = active
        spectrumBarsSwitch.isEnabled = active
        waveLineSwitch.isEnabled = active
        overlayOpacitySlider.isEnabled = active
    }

    private func commitField(_ mutate: (inout AudioReactorPreferences) -> Void) {
        guard !isInternallyUpdating else { return }
        mutate(&preferences)
        delegate?.audioReactorSection(self, didChange: preferences)
    }

    @objc private func enabledChanged(_ sender: NSSwitch) {
        commitField { $0.isEnabled = sender.state == .on }
        applyEnabledState()
    }

    @objc private func responseChanged(_ sender: NSSegmentedControl) {
        guard !isInternallyUpdating else { return }
        let cases = AudioReactorResponse.allCases
        guard cases.indices.contains(sender.selectedSegment) else { return }
        preferences.response = cases[sender.selectedSegment]
        delegate?.audioReactorSection(self, didChange: preferences)
    }

    @objc private func pulseRingChanged(_ sender: NSSwitch) {
        commitField { $0.showsPulseRing = sender.state == .on }
    }

    @objc private func spectrumBarsChanged(_ sender: NSSwitch) {
        commitField { $0.showsSpectrumBars = sender.state == .on }
    }

    @objc private func waveLineChanged(_ sender: NSSwitch) {
        commitField { $0.showsWaveLine = sender.state == .on }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build`
Expected: build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/LunoApp/Settings/AudioReactorSectionView.swift
git -c commit.gpgsign=false commit -m "feat(settings): AudioReactorSectionView"
```

---

## Task 14: `SettingsWindowController` — rename + assembly + delegate forwarding

**Files:**
- Rename: `Sources/LunoApp/LibraryWindowController.swift` → `Sources/LunoApp/Settings/SettingsWindowController.swift`
- Rewrite contents to use the new sidebar + section views
- Modify: `Sources/LunoApp/AppDelegate.swift` — references `SettingsWindowController` instead of `LibraryWindowController`

- [ ] **Step 1: Move and rewrite the controller**

Run:

```bash
git mv Sources/LunoApp/LibraryWindowController.swift Sources/LunoApp/Settings/SettingsWindowController.swift
```

Then replace the file's contents:

```swift
import AppKit
import CoreGraphics
import LunoEngineCore
import UniformTypeIdentifiers

@MainActor
protocol SettingsWindowControllerDelegate: AnyObject {
    func settingsWindowDidRequestImport(_ controller: SettingsWindowController)
    func settingsWindow(_ controller: SettingsWindowController, didRequestExport package: LunoPackageRecord)
    func settingsWindow(
        _ controller: SettingsWindowController,
        didRequestApply package: LunoPackageRecord,
        preset: WallpaperPreset?,
        displayID: CGDirectDisplayID?
    )
    func settingsWindow(_ controller: SettingsWindowController, didSave preset: WallpaperPreset)
    func settingsWindow(_ controller: SettingsWindowController, didChange nowPlayingPreferences: NowPlayingPreferences)
    func settingsWindow(_ controller: SettingsWindowController, didChange audioReactorPreferences: AudioReactorPreferences)
}

@MainActor
final class SettingsWindowController: NSWindowController {
    weak var delegate: SettingsWindowControllerDelegate?

    private var packages: [LunoPackageRecord] = []
    private var presets: [WallpaperPreset] = []
    private var nowPlayingPreferences: NowPlayingPreferences = .defaults
    private var audioReactorPreferences: AudioReactorPreferences = .defaults

    private let splitView = NSSplitView()
    private let sidebar = SettingsSidebar()
    private let detailContainer = NSView()

    private let librarySection = LibrarySectionView()
    private let basicSection = NowPlayingBasicSectionView()
    private let appearanceSection = NowPlayingAppearanceSectionView()
    private let reactivitySection = NowPlayingReactivitySectionView()
    private let audioReactorSection = AudioReactorSectionView()

    convenience init() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 540))
        let window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Luno"
        window.minSize = NSSize(width: 640, height: 460)
        window.contentView = contentView
        self.init(window: window)
        buildUI(in: contentView)
        wireSections()
        sidebar.selectInitialItem()
    }

    func configure(packages: [LunoPackageRecord], presets: [WallpaperPreset]) {
        self.packages = packages
        self.presets = presets
        reloadPackages()
        reloadDisplays()
        librarySection.rebuildParameterControls(with: selectedPackage, presets: presets)
    }

    func configureNowPlaying(_ preferences: NowPlayingPreferences) {
        nowPlayingPreferences = preferences
        basicSection.configure(preferences)
        appearanceSection.configure(preferences.appearance)
        reactivitySection.configure(preferences)
    }

    func configureAudioReactor(_ preferences: AudioReactorPreferences) {
        audioReactorPreferences = preferences
        audioReactorSection.configure(preferences)
    }

    func reloadDisplays() {
        let popup = librarySection.displayPopup
        popup.removeAllItems()
        popup.addItem(withTitle: "All Displays")
        popup.lastItem?.representedObject = nil
        for screen in NSScreen.screens {
            let displayID = screen.lunoDisplayID
            let title = displayID.map { "Display \($0)" } ?? "Unknown Display"
            popup.addItem(withTitle: title)
            popup.lastItem?.representedObject = displayID.map { NSNumber(value: $0) }
        }
    }

    private func buildUI(in root: NSView) {
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(splitView)
        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: root.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        let sidebarContainer = NSView()
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(sidebar.scrollView)
        NSLayoutConstraint.activate([
            sidebar.scrollView.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor),
            sidebar.scrollView.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            sidebar.scrollView.topAnchor.constraint(equalTo: sidebarContainer.topAnchor),
            sidebar.scrollView.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor)
        ])
        sidebarContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        sidebarContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 240).isActive = true

        detailContainer.translatesAutoresizingMaskIntoConstraints = false

        splitView.addArrangedSubview(sidebarContainer)
        splitView.addArrangedSubview(detailContainer)
        splitView.setHoldingPriority(NSLayoutConstraint.Priority(rawValue: 250), forSubviewAt: 0)
    }

    private func wireSections() {
        sidebar.delegate = self
        librarySection.delegate = self
        librarySection.setPackagePopupTarget(self, action: #selector(packageSelectionChanged))
        basicSection.delegate = self
        appearanceSection.delegate = self
        reactivitySection.delegate = self
        audioReactorSection.delegate = self
    }

    private func showSection(_ section: SettingsSection) {
        detailContainer.subviews.forEach { $0.removeFromSuperview() }
        let view: NSView
        switch section {
        case .library: view = librarySection
        case .nowPlayingBasic: view = basicSection
        case .nowPlayingAppearance: view = appearanceSection
        case .nowPlayingReactivity: view = reactivitySection
        case .audioReactor: view = audioReactorSection
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
            view.topAnchor.constraint(equalTo: detailContainer.topAnchor),
            view.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor)
        ])
    }

    private func reloadPackages() {
        let popup = librarySection.packagePopup
        popup.removeAllItems()
        for package in packages {
            popup.addItem(withTitle: package.manifest.name)
            popup.lastItem?.representedObject = package.manifest.id
        }
        librarySection.rebuildParameterControls(with: selectedPackage, presets: presets)
    }

    private var selectedPackage: LunoPackageRecord? {
        let index = librarySection.packagePopup.indexOfSelectedItem
        guard packages.indices.contains(index) else { return nil }
        return packages[index]
    }

    private var selectedDisplayID: CGDirectDisplayID? {
        guard let number = librarySection.displayPopup.selectedItem?.representedObject as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private func selectedPreset(for package: LunoPackageRecord) -> WallpaperPreset {
        let values = librarySection.currentParameterValues(for: package.manifest)
        let trimmed = librarySection.presetNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Default" : trimmed
        let id = name.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return WallpaperPreset(
            id: id.isEmpty ? "default" : id,
            packageID: package.manifest.id,
            name: name,
            values: values
        )
    }

    @objc private func packageSelectionChanged() {
        librarySection.rebuildParameterControls(with: selectedPackage, presets: presets)
    }
}

extension SettingsWindowController: SettingsSidebarDelegate {
    func sidebar(_ sidebar: SettingsSidebar, didSelect section: SettingsSection) {
        showSection(section)
    }
}

extension SettingsWindowController: LibrarySectionViewDelegate {
    func librarySectionDidRequestApply(_ view: LibrarySectionView) {
        guard let package = selectedPackage else { return }
        delegate?.settingsWindow(
            self,
            didRequestApply: package,
            preset: selectedPreset(for: package),
            displayID: selectedDisplayID
        )
    }

    func librarySectionDidRequestSavePreset(_ view: LibrarySectionView) {
        guard let package = selectedPackage else { return }
        delegate?.settingsWindow(self, didSave: selectedPreset(for: package))
    }

    func librarySectionDidRequestImport(_ view: LibrarySectionView) {
        delegate?.settingsWindowDidRequestImport(self)
    }

    func librarySectionDidRequestExport(_ view: LibrarySectionView) {
        guard let package = selectedPackage else { return }
        delegate?.settingsWindow(self, didRequestExport: package)
    }
}

extension SettingsWindowController: NowPlayingBasicSectionViewDelegate {
    func nowPlayingBasicSection(_ view: NowPlayingBasicSectionView, didChange preferences: NowPlayingPreferences) {
        nowPlayingPreferences = preferences
        delegate?.settingsWindow(self, didChange: nowPlayingPreferences)
    }
}

extension SettingsWindowController: NowPlayingAppearanceSectionViewDelegate {
    func nowPlayingAppearanceSection(_ view: NowPlayingAppearanceSectionView, didChange appearance: NowPlayingAppearance) {
        nowPlayingPreferences.appearance = appearance
        delegate?.settingsWindow(self, didChange: nowPlayingPreferences)
        reactivitySection.configure(nowPlayingPreferences)
    }
}

extension SettingsWindowController: NowPlayingReactivitySectionViewDelegate {
    func nowPlayingReactivitySection(_ view: NowPlayingReactivitySectionView, didChange preferences: NowPlayingPreferences) {
        nowPlayingPreferences = preferences
        delegate?.settingsWindow(self, didChange: nowPlayingPreferences)
        appearanceSection.configure(preferences.appearance)
    }
}

extension SettingsWindowController: AudioReactorSectionViewDelegate {
    func audioReactorSection(_ view: AudioReactorSectionView, didChange preferences: AudioReactorPreferences) {
        audioReactorPreferences = preferences
        delegate?.settingsWindow(self, didChange: audioReactorPreferences)
    }
}
```

- [ ] **Step 2: Update `AppDelegate.swift` to use the new types**

Search `Sources/LunoApp/AppDelegate.swift` for `LibraryWindowController` and `LibraryWindowControllerDelegate` and replace each with `SettingsWindowController` / `SettingsWindowControllerDelegate`. Update each protocol method signature:

- `libraryWindowDidRequestImport(_:)` → `settingsWindowDidRequestImport(_:)`
- `libraryWindow(_:didRequestExport:)` → `settingsWindow(_:didRequestExport:)`
- `libraryWindow(_:didRequestApply:preset:displayID:)` → `settingsWindow(_:didRequestApply:preset:displayID:)`
- `libraryWindow(_:didSave:)` → `settingsWindow(_:didSave:)`
- `libraryWindow(_:didChange nowPlayingPreferences:)` → `settingsWindow(_:didChange nowPlayingPreferences:)`
- `libraryWindow(_:didChange audioReactorPreferences:)` → `settingsWindow(_:didChange audioReactorPreferences:)`

The body of each delegate method stays the same. Rename the `private var libraryWindowController: LibraryWindowController?` property to `private var settingsWindowController: SettingsWindowController?` and update all references inside `AppDelegate`.

- [ ] **Step 3: Build to verify**

Run: `swift build`
Expected: build succeeds

- [ ] **Step 4: Run tests**

Run: `swift test`
Expected: all tests pass

- [ ] **Step 5: Manual QA — launch and check every section**

Run:

```bash
./scripts/build-app.sh && ./.build/artifacts/Luno.app/Contents/MacOS/Luno
```

Steps:

1. Open Luno. Window appears with sidebar showing `Library`, `Now Playing` (with three children), `Audio Reactor`.
2. Click each leaf section; the detail view swaps with no flicker.
3. Library section behaves as before (popups populated, Apply/Save/Import/Export buttons).
4. Now Playing › Basic toggles enable/style/react/keep-visible — widget responds.
5. Now Playing › Appearance — switch to `Vivid` preset; widget should render with the vivid pink accent and thicker border. Then drag `Corner radius` slider — widget's corners change live; preset popup flips to "Custom".
6. Now Playing › Reactivity — set master to 0; per-effect sliders disable. Set master to 50%; sliders enable. Drag `Scale` to 0 and confirm the widget no longer pulses in scale (but still glows/borders if those weights stay non-zero).
7. Audio Reactor — toggles match existing behavior.

Quit the app.

- [ ] **Step 6: Restart and verify persistence**

Run again:

```bash
./.build/artifacts/Luno.app/Contents/MacOS/Luno
```

Verify:
- Selected preset/custom appearance preserved.
- Master intensity preserved.
- Per-effect weights preserved.
- Now Playing basic toggles preserved.
- Audio Reactor preferences preserved.

Quit.

- [ ] **Step 7: Commit**

```bash
git add Sources/LunoApp/
git -c commit.gpgsign=false commit -m "feat(settings): rebuild library window as SettingsWindowController with sidebar"
```

---

## Task 15: Plan-level verification + QA doc

**Files:**
- Create: `docs/superpowers/qa/2026-05-13-settings-ui-redesign-qa.md`

- [ ] **Step 1: Run full test suite**

Run: `swift test`
Expected: all tests pass.

- [ ] **Step 2: Write the manual QA doc**

```markdown
# Settings UI Redesign — Manual QA Checklist

Date: 2026-05-13

## Sections

- [ ] Sidebar shows three top-level rows: `Library`, `Now Playing`, `Audio Reactor`.
- [ ] `Now Playing` is expandable and shows three children: `Basic`, `Appearance`, `Reactivity`.
- [ ] Clicking the group header (`Now Playing`) does NOT change the detail view.
- [ ] Clicking each leaf swaps the detail view to the correct section.
- [ ] Initial selection on app launch is `Library`.

## Library

- [ ] Package popup lists all installed `.luno` packages.
- [ ] Display popup lists `All Displays` plus each attached screen.
- [ ] Preset name field defaults to `Default` for a new package, or the saved preset name.
- [ ] Apply / Save / Import / Export buttons work as before.

## Now Playing › Basic

- [ ] Enable widget toggle persists across restart.
- [ ] Style popup shows Album-art dominant, Compact bar, Minimal.
- [ ] React to music toggle persists across restart.
- [ ] Keep visible while paused toggle persists across restart.

## Now Playing › Appearance

- [ ] Preset popup lists Default / Vivid / Minimal / Neon / Mono, plus a disabled "Custom" item.
- [ ] Selecting a preset updates all sliders/colors/popups to match.
- [ ] Modifying any slider/popup/color flips the popup selection to "Custom".
- [ ] Corner radius slider range 0..28 — verify lower and upper bounds applied to widget.
- [ ] Padding slider range 8..24 — visible inside the widget body.
- [ ] Border width slider range 0..6.
- [ ] Border opacity slider shows percent label.
- [ ] Title weight and Subtitle weight popups list 6 weights.
- [ ] Text / Accent / Glow color wells open the system color picker.
- [ ] All shape/typography/color changes persist across restart.

## Now Playing › Reactivity

- [ ] Master intensity slider shows percent label.
- [ ] When master is 0, per-effect sliders are disabled (and visibly dimmed).
- [ ] When master is non-zero, per-effect sliders are enabled.
- [ ] Each per-effect slider (Glow / Scale / Border) affects only its corresponding effect on the widget.
- [ ] All four sliders persist across restart.

## Audio Reactor

- [ ] All controls behave as before (no behavioral regression).

## Widget Behavior

- [ ] Default appearance matches the pre-redesign look.
- [ ] Vivid preset renders with thicker border and pink accent.
- [ ] Neon preset renders with cyan glow on bass.
- [ ] Bass pulse animates only the effects whose per-effect weights are non-zero.
- [ ] Glow does not clip into the window edge at high intensities (window margin 48 should suffice).
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/qa/2026-05-13-settings-ui-redesign-qa.md
git -c commit.gpgsign=false commit -m "docs(qa): manual QA checklist for settings UI redesign"
```

---

## Final Checklist (run after all tasks above complete)

- [ ] `swift build` succeeds with no warnings introduced by this work.
- [ ] `swift test` passes for all targets.
- [ ] Manual QA walkthrough from Task 15 completes without findings.
- [ ] `git log --oneline -20` shows commits in the order above, all conventional commit subjects, no follow-up rework commits inline.
- [ ] No orphan files in `Sources/LunoApp/Settings/` from the rename.
- [ ] `LibraryWindowController` no longer exists in the codebase (`grep -r LibraryWindowController Sources Tests` returns no hits).
