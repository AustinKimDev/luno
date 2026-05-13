# Audio Reactor Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add live Audio Reactor controls plus visible bass pulse and spectrum/wave overlays for audio-reactive Luno wallpapers.

**Architecture:** Add a small persisted `AudioReactorPreferences` model in `LunoEngineCore`, shape `AudioFeatures` before shader uniforms, and draw a built-in Metal overlay pass after each package shader. `LunoApp` owns the AppKit controls and passes live preference/audio providers into `WallpaperRuntime`.

**Tech Stack:** Swift 6, SwiftPM, XCTest, AppKit, MetalKit, ScreenCaptureKit.

---

## File Map

- Create `Sources/LunoEngineCore/AudioReactorPreferences.swift`: Codable preferences, response shaping, spectrum downsampling, and store.
- Modify `Sources/LunoEngineCore/AudioSpectrumAnalyzer.swift`: expose `AudioFeatures` generation from an unsafe buffer so capture can keep spectrum data without an extra public array conversion.
- Modify `Sources/LunoEngineCore/SystemAudioCaptureService.swift`: store latest full `AudioFeatures`, not just `AudioScalars`.
- Modify `Sources/LunoEngineCore/WallpaperRuntime.swift`: change wallpaper audio provider to `AudioFeatures`, add preferences provider, shape scalar uniforms, and render pulse/spectrum/wave overlay.
- Modify `Sources/LunoApp/LibraryWindowController.swift`: add Audio Reactor controls and delegate callback.
- Modify `Sources/LunoApp/AppDelegate.swift`: load/save preferences, wire controls to runtime, update audio capture reconciliation.
- Create `Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift`: defaults, Codable, shaping, downsampling, and store tests.
- Modify `Tests/LunoEngineCoreTests/AudioSpectrumAnalyzerTests.swift`: verify unsafe-buffer feature analysis returns a real spectrum.

---

### Task 1: Audio Reactor Preferences and Pure Logic

**Files:**
- Create: `Sources/LunoEngineCore/AudioReactorPreferences.swift`
- Create: `Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift`

- [ ] **Step 1: Write failing tests for defaults, Codable, shaping, downsampling, and store**

```swift
import XCTest
@testable import LunoEngineCore

final class AudioReactorPreferencesTests: XCTestCase {
    func testDefaultsAreVisibleButControlled() {
        let preferences = AudioReactorPreferences.defaults

        XCTAssertTrue(preferences.isEnabled)
        XCTAssertEqual(preferences.intensity, 0.8, accuracy: 0.001)
        XCTAssertEqual(preferences.response, .punchy)
        XCTAssertEqual(preferences.bassPulseStrength, 0.75, accuracy: 0.001)
        XCTAssertTrue(preferences.showsPulseRing)
        XCTAssertTrue(preferences.showsSpectrumBars)
        XCTAssertFalse(preferences.showsWaveLine)
        XCTAssertEqual(preferences.overlayOpacity, 0.6, accuracy: 0.001)
    }

    func testCodableRoundTripPreservesFields() throws {
        let preferences = AudioReactorPreferences(
            isEnabled: false,
            intensity: 0.35,
            response: .hard,
            bassPulseStrength: 0.9,
            showsPulseRing: false,
            showsSpectrumBars: true,
            showsWaveLine: true,
            overlayOpacity: 0.42
        )

        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(AudioReactorPreferences.self, from: data)

        XCTAssertEqual(decoded, preferences)
    }

    func testDisabledPreferencesSilenceFeatures() {
        let preferences = AudioReactorPreferences.defaults.with(isEnabled: false)
        let features = AudioFeatures(rms: 0.4, bass: 0.7, mid: 0.5, treble: 0.3, spectrum: [0.2, 0.8])

        XCTAssertEqual(preferences.shaped(features), .silent)
    }

    func testHardResponseAmplifiesMoreThanSoftResponse() {
        let features = AudioFeatures(rms: 0.2, bass: 0.35, mid: 0.25, treble: 0.1, spectrum: [0.1, 0.5, 0.9])
        let soft = AudioReactorPreferences.defaults.with(response: .soft).shaped(features)
        let hard = AudioReactorPreferences.defaults.with(response: .hard).shaped(features)

        XCTAssertGreaterThan(hard.bass, soft.bass)
        XCTAssertGreaterThan(hard.rms, soft.rms)
        XCTAssertEqual(hard.spectrum.count, features.spectrum.count)
    }

    func testShapingClampsUnsafeValues() {
        let preferences = AudioReactorPreferences.defaults.with(intensity: 3.0)
        let features = AudioFeatures(rms: 2.0, bass: 1.5, mid: -0.5, treble: 0.5, spectrum: [-1, 0.4, 4])
        let shaped = preferences.shaped(features)

        XCTAssertEqual(shaped.rms, 1)
        XCTAssertEqual(shaped.bass, 1)
        XCTAssertEqual(shaped.mid, 0)
        XCTAssertGreaterThan(shaped.treble, 0)
        XCTAssertEqual(shaped.spectrum, [0, shaped.spectrum[1], 1])
    }

    func testDownsamplesSpectrumByAveragingBuckets() {
        let spectrum: [Float] = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 0.5, 0.25]

        let bars = AudioReactorPreferences.downsampleSpectrum(spectrum, count: 4)

        XCTAssertEqual(bars.count, 4)
        XCTAssertEqual(bars[0], 0.1, accuracy: 0.001)
        XCTAssertEqual(bars[1], 0.5, accuracy: 0.001)
        XCTAssertEqual(bars[2], 0.9, accuracy: 0.001)
        XCTAssertEqual(bars[3], 0.375, accuracy: 0.001)
    }

    func testStoreReturnsDefaultsWhenMissingAndRoundTrips() throws {
        let directory = try temporaryDirectory()
        let store = AudioReactorPreferencesStore(fileURL: directory.appending(path: "audio-reactor.json"))

        XCTAssertEqual(try store.load(), .defaults)

        let preferences = AudioReactorPreferences.defaults.with(response: .hard, overlayOpacity: 0.25)
        try store.save(preferences)

        XCTAssertEqual(try store.load(), preferences)
    }
}

private extension AudioReactorPreferences {
    func with(
        isEnabled: Bool? = nil,
        intensity: Double? = nil,
        response: AudioReactorResponse? = nil,
        bassPulseStrength: Double? = nil,
        showsPulseRing: Bool? = nil,
        showsSpectrumBars: Bool? = nil,
        showsWaveLine: Bool? = nil,
        overlayOpacity: Double? = nil
    ) -> AudioReactorPreferences {
        AudioReactorPreferences(
            isEnabled: isEnabled ?? self.isEnabled,
            intensity: intensity ?? self.intensity,
            response: response ?? self.response,
            bassPulseStrength: bassPulseStrength ?? self.bassPulseStrength,
            showsPulseRing: showsPulseRing ?? self.showsPulseRing,
            showsSpectrumBars: showsSpectrumBars ?? self.showsSpectrumBars,
            showsWaveLine: showsWaveLine ?? self.showsWaveLine,
            overlayOpacity: overlayOpacity ?? self.overlayOpacity
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AudioReactorPreferencesTests`

Expected: compile failure because `AudioReactorPreferences`, `AudioReactorResponse`, and `AudioReactorPreferencesStore` do not exist.

- [ ] **Step 3: Implement the preferences model and store**

```swift
import Foundation

public enum AudioReactorResponse: String, Codable, Equatable, Sendable, CaseIterable {
    case soft
    case punchy
    case hard

    var gain: Float {
        switch self {
        case .soft: 0.7
        case .punchy: 1.0
        case .hard: 1.35
        }
    }

    var exponent: Float {
        switch self {
        case .soft: 1.25
        case .punchy: 0.85
        case .hard: 0.62
        }
    }
}

public struct AudioReactorPreferences: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var intensity: Double
    public var response: AudioReactorResponse
    public var bassPulseStrength: Double
    public var showsPulseRing: Bool
    public var showsSpectrumBars: Bool
    public var showsWaveLine: Bool
    public var overlayOpacity: Double

    public init(
        isEnabled: Bool,
        intensity: Double,
        response: AudioReactorResponse,
        bassPulseStrength: Double,
        showsPulseRing: Bool,
        showsSpectrumBars: Bool,
        showsWaveLine: Bool,
        overlayOpacity: Double
    ) {
        self.isEnabled = isEnabled
        self.intensity = intensity
        self.response = response
        self.bassPulseStrength = bassPulseStrength
        self.showsPulseRing = showsPulseRing
        self.showsSpectrumBars = showsSpectrumBars
        self.showsWaveLine = showsWaveLine
        self.overlayOpacity = overlayOpacity
    }

    public static let defaults = AudioReactorPreferences(
        isEnabled: true,
        intensity: 0.8,
        response: .punchy,
        bassPulseStrength: 0.75,
        showsPulseRing: true,
        showsSpectrumBars: true,
        showsWaveLine: false,
        overlayOpacity: 0.6
    )

    public func shaped(_ features: AudioFeatures) -> AudioFeatures {
        guard isEnabled else { return .silent }
        return AudioFeatures(
            rms: shaped(features.rms),
            bass: shaped(features.bass),
            mid: shaped(features.mid),
            treble: shaped(features.treble),
            spectrum: features.spectrum.map(shaped)
        )
    }

    public func shaped(_ value: Float) -> Float {
        let clamped = Self.clamp(value)
        let gain = Float(Self.clamp(intensity)) * response.gain
        let shaped = pow(clamped, response.exponent) * gain
        return Self.clamp(shaped)
    }

    public static func downsampleSpectrum(_ spectrum: [Float], count: Int) -> [Float] {
        guard count > 0 else { return [] }
        guard !spectrum.isEmpty else { return Array(repeating: 0, count: count) }

        return (0..<count).map { index in
            let start = index * spectrum.count / count
            let end = max(start + 1, (index + 1) * spectrum.count / count)
            let bucket = spectrum[start..<min(end, spectrum.count)]
            let total = bucket.reduce(Float(0)) { $0 + clamp($1) }
            return total / Float(bucket.count)
        }
    }

    public static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    public static func clamp(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

public struct AudioReactorPreferencesStore: Sendable {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public func load() throws -> AudioReactorPreferences {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .defaults
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(AudioReactorPreferences.self, from: data)
    }

    public func save(_ preferences: AudioReactorPreferences) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(preferences)
        try data.write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 4: Run tests to verify Task 1 passes**

Run: `swift test --filter AudioReactorPreferencesTests`

Expected: all `AudioReactorPreferencesTests` pass.

- [ ] **Step 5: Commit Task 1**

```bash
git add Sources/LunoEngineCore/AudioReactorPreferences.swift Tests/LunoEngineCoreTests/AudioReactorPreferencesTests.swift
git commit -m "Add audio reactor preferences"
```

---

### Task 2: Full AudioFeatures Capture

**Files:**
- Modify: `Sources/LunoEngineCore/AudioSpectrumAnalyzer.swift`
- Modify: `Sources/LunoEngineCore/SystemAudioCaptureService.swift`
- Modify: `Tests/LunoEngineCoreTests/AudioSpectrumAnalyzerTests.swift`

- [ ] **Step 1: Write failing analyzer test for unsafe-buffer feature analysis**

Append this test:

```swift
func testUnsafeBufferFeatureAnalysisIncludesSpectrum() {
    let analyzer = AudioSpectrumAnalyzer()
    let sampleRate = 4_800.0
    let samples = (0..<4_800).map { index in
        Float(sin(2.0 * Double.pi * 80.0 * Double(index) / sampleRate))
    }

    let features = samples.withUnsafeBufferPointer {
        analyzer.analyzeFeatures(samples: $0, sampleRate: sampleRate)
    }

    XCTAssertGreaterThan(features.rms, 0.65)
    XCTAssertGreaterThan(features.bass, features.mid)
    XCTAssertEqual(features.spectrum.count, 64)
    XCTAssertGreaterThan(features.spectrum.max() ?? 0, 0)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AudioSpectrumAnalyzerTests/testUnsafeBufferFeatureAnalysisIncludesSpectrum`

Expected: compile failure because `analyzeFeatures(samples:sampleRate:)` does not exist.

- [ ] **Step 3: Implement unsafe-buffer feature analysis**

Change `AudioSpectrumAnalyzer` so `analyze(samples:sampleRate:)` delegates to:

```swift
public func analyzeFeatures(
    samples: UnsafeBufferPointer<Float>,
    sampleRate: Double
) -> AudioFeatures {
    let scalars = analyzeScalars(samples: samples, sampleRate: sampleRate)
    let spectrum = makeSpectrum(samples: samples, sampleRate: sampleRate, rms: scalars.rms, binCount: 64)
    return AudioFeatures(
        rms: scalars.rms,
        bass: scalars.bass,
        mid: scalars.mid,
        treble: scalars.treble,
        spectrum: spectrum
    )
}

public func analyze(samples: [Float], sampleRate: Double) -> AudioFeatures {
    samples.withUnsafeBufferPointer { buffer in
        analyzeFeatures(samples: buffer, sampleRate: sampleRate)
    }
}
```

- [ ] **Step 4: Store latest full features in ScreenCaptureKit service**

In `SystemAudioCaptureService`, replace `latestScalars` with `latestFeatures`, make `scalars` return `features.scalars`, make `features` return the locked snapshot, and call `analyzer.analyzeFeatures(samples:sampleRate:)` inside `withFloatSamples`.

- [ ] **Step 5: Run tests**

Run: `swift test --filter AudioSpectrumAnalyzerTests`

Expected: `AudioSpectrumAnalyzerTests` pass.

- [ ] **Step 6: Commit Task 2**

```bash
git add Sources/LunoEngineCore/AudioSpectrumAnalyzer.swift Sources/LunoEngineCore/SystemAudioCaptureService.swift Tests/LunoEngineCoreTests/AudioSpectrumAnalyzerTests.swift
git commit -m "Capture audio spectrum features"
```

---

### Task 3: Runtime Audio Reactor Shaping and Metal Overlay

**Files:**
- Modify: `Sources/LunoEngineCore/WallpaperRuntime.swift`

- [ ] **Step 1: Update runtime API types**

Change `WallpaperRuntime.show`, `WallpaperWindowController.init`, `MetalWallpaperView.init`, and `MetalWallpaperRenderer.init` from:

```swift
audioProvider: @escaping @MainActor () -> AudioScalars
```

to:

```swift
audioProvider: @escaping @MainActor () -> AudioFeatures,
audioReactorPreferencesProvider: @escaping @MainActor () -> AudioReactorPreferences
```

- [ ] **Step 2: Add overlay pipeline state**

Add fields to `MetalWallpaperRenderer`:

```swift
private let overlayPipelineState: any MTLRenderPipelineState
private let audioProvider: @MainActor () -> AudioFeatures
private let audioReactorPreferencesProvider: @MainActor () -> AudioReactorPreferences
```

Compile a built-in Metal overlay library with a full-screen triangle vertex and fragment function. The fragment should read an overlay uniform containing `resolution`, shaped audio values, overlay opacity, bass pulse strength, and three boolean flags. It should blend a centered pulse ring, bottom spectrum bars, and wave line over the package shader output.

- [ ] **Step 3: Enable alpha blending for overlay pipeline**

Use a second `MTLRenderPipelineDescriptor` with:

```swift
let attachment = overlayDescriptor.colorAttachments[0]!
attachment.pixelFormat = view.colorPixelFormat
attachment.isBlendingEnabled = true
attachment.rgbBlendOperation = .add
attachment.alphaBlendOperation = .add
attachment.sourceRGBBlendFactor = .sourceAlpha
attachment.sourceAlphaBlendFactor = .sourceAlpha
attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
```

- [ ] **Step 4: Shape audio and draw overlay after base shader**

In `draw(in:)`:

```swift
let rawAudio = audioProvider()
let audioReactorPreferences = audioReactorPreferencesProvider()
let audio = audioReactorPreferences.shaped(rawAudio)
```

Use `audio` for existing shader uniforms. After the base shader draw, if preferences enable at least one overlay and opacity is above zero, set the overlay pipeline and draw another full-screen triangle.

- [ ] **Step 5: Build to catch Metal and API errors**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 6: Commit Task 3**

```bash
git add Sources/LunoEngineCore/WallpaperRuntime.swift
git commit -m "Render audio reactor overlays"
```

---

### Task 4: Library UI, Persistence, and Wiring

**Files:**
- Modify: `Sources/LunoApp/LibraryWindowController.swift`
- Modify: `Sources/LunoApp/AppDelegate.swift`

- [ ] **Step 1: Add delegate method and controls**

Extend `LibraryWindowControllerDelegate`:

```swift
func libraryWindow(_ controller: LibraryWindowController, didChange audioReactorPreferences: AudioReactorPreferences)
```

Add private controls:

```swift
private var audioReactorPreferences: AudioReactorPreferences = .defaults
private let audioReactorStack = NSStackView()
private let audioReactorEnableSwitch = NSSwitch()
private let audioReactorIntensitySlider = NSSlider()
private let audioReactorResponseControl = NSSegmentedControl(labels: ["Soft", "Punchy", "Hard"], trackingMode: .selectOne, target: nil, action: nil)
private let bassPulseSlider = NSSlider()
private let pulseRingSwitch = NSSwitch()
private let spectrumBarsSwitch = NSSwitch()
private let waveLineSwitch = NSSwitch()
private let overlayOpacitySlider = NSSlider()
```

- [ ] **Step 2: Add configuration and rebuild logic**

Add:

```swift
func configureAudioReactor(_ preferences: AudioReactorPreferences) {
    audioReactorPreferences = preferences
    syncAudioReactorControls()
}
```

Call `rebuildAudioReactorControls()` from `rebuildParameterControls()`. Show controls only when `selectedPackage?.manifest.audioBindings.isEmpty == false`; otherwise show one disabled row saying no audio bindings.

- [ ] **Step 3: Wire control actions**

Each switch/slider/segmented control updates `audioReactorPreferences`, clamps slider values, syncs dependent enabled state, and calls:

```swift
delegate?.libraryWindow(self, didChange: audioReactorPreferences)
```

- [ ] **Step 4: Persist and pass preferences from AppDelegate**

Add `audioReactorPreferencesStore` and `audioReactorPreferences` to `AppDelegate`. Extend `LunoAppPaths` with:

```swift
var audioReactorPreferences: URL
```

Set it to `root.appending(path: "audio-reactor.json")`. Load on launch, configure the library window, save on delegate changes, and pass the provider into `runtime.show`.

- [ ] **Step 5: Update audio capture reconciliation**

Rename or update `anyActivePackageNeedsAudio()` so it returns true when either:

```swift
(audioReactorPreferences.isEnabled && an active assigned package declares audio bindings)
|| (nowPlayingPreferences.isEnabled && nowPlayingPreferences.audioReactivityEnabled)
```

Call reconciliation when Audio Reactor preferences or Now Playing preferences change.

- [ ] **Step 6: Build**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 7: Commit Task 4**

```bash
git add Sources/LunoApp/LibraryWindowController.swift Sources/LunoApp/AppDelegate.swift
git commit -m "Add audio reactor controls"
```

---

### Task 5: Final Verification

**Files:**
- All modified files.

- [ ] **Step 1: Run full unit suite**

Run: `swift test`

Expected: all tests pass.

- [ ] **Step 2: Build the app**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 3: Inspect final diff**

Run: `git status --short` and `git log --oneline --max-count=6`

Expected: worktree is clean after commits, with the Audio Reactor commits on branch `audio-reactor-controls`.
