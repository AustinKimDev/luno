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

    func testShapingMapsNonFiniteValuesToSafeZeros() {
        let features = AudioFeatures(
            rms: .nan,
            bass: .infinity,
            mid: -.infinity,
            treble: 0.5,
            spectrum: [.nan, .infinity, -.infinity, 0.25]
        )
        let shaped = AudioReactorPreferences.defaults.shaped(features)

        XCTAssertEqual(shaped.rms, 0)
        XCTAssertEqual(shaped.bass, 0)
        XCTAssertEqual(shaped.mid, 0)
        XCTAssertTrue(shaped.treble.isFinite)
        XCTAssertEqual(shaped.spectrum[0], 0)
        XCTAssertEqual(shaped.spectrum[1], 0)
        XCTAssertEqual(shaped.spectrum[2], 0)
        XCTAssertTrue(shaped.spectrum[3].isFinite)
        XCTAssertTrue(shaped.spectrum.allSatisfy(\.isFinite))
    }

    func testDownsamplesSpectrumByAveragingBuckets() {
        let preferences = AudioReactorPreferences.defaults.with(intensity: 1, response: .punchy)
        let spectrum: [Float] = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 0.5, 0.25]

        let bars = preferences.downsampleSpectrum(spectrum, count: 4)

        XCTAssertEqual(bars.count, 4)
        XCTAssertEqual(bars[0], (preferences.shaped(0.0) + preferences.shaped(0.2)) / 2, accuracy: 0.001)
        XCTAssertEqual(bars[1], (preferences.shaped(0.4) + preferences.shaped(0.6)) / 2, accuracy: 0.001)
        XCTAssertEqual(bars[2], (preferences.shaped(0.8) + preferences.shaped(1.0)) / 2, accuracy: 0.001)
        XCTAssertEqual(bars[3], (preferences.shaped(0.5) + preferences.shaped(0.25)) / 2, accuracy: 0.001)
    }

    func testWritesDownsampledSpectrumIntoExistingBuffer() {
        let preferences = AudioReactorPreferences.defaults.with(intensity: 1, response: .punchy)
        let spectrum: [Float] = [0.0, 0.5, 1.0, 0.25]
        var bars: [Float] = [9, 9]

        preferences.writeDownsampledSpectrum(spectrum, into: &bars)

        XCTAssertEqual(bars[0], (preferences.shaped(0.0) + preferences.shaped(0.5)) / 2, accuracy: 0.001)
        XCTAssertEqual(bars[1], (preferences.shaped(1.0) + preferences.shaped(0.25)) / 2, accuracy: 0.001)
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
