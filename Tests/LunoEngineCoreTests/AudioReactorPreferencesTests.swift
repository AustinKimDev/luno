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
