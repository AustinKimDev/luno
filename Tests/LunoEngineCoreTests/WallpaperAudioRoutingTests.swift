import XCTest
@testable import LunoEngineCore

final class WallpaperAudioRoutingTests: XCTestCase {
    func testBackgroundAudioReactiveToggleDoesNotMuteReactorOverlayAudio() {
        let rawAudio = AudioFeatures(
            rms: 0.5,
            bass: 0.6,
            mid: 0.4,
            treble: 0.3,
            spectrum: [0.1, 0.2, 0.3]
        )
        let routing = WallpaperAudioRouting(
            usesAudioReactor: true,
            backgroundAudioReactiveEnabled: false
        )

        XCTAssertEqual(
            routing.backgroundScalars(rawAudio: rawAudio, preferences: .defaults),
            .silent
        )
        XCTAssertNotEqual(
            routing.reactorScalars(rawAudio: rawAudio, preferences: .defaults),
            .silent
        )
    }

    func testDisabledAudioReactorStillAllowsBackgroundAudioWhenBackgroundIsEnabled() {
        let rawAudio = AudioFeatures(
            rms: 0.5,
            bass: 0.6,
            mid: 0.4,
            treble: 0.3,
            spectrum: [0.1, 0.2, 0.3]
        )
        let routing = WallpaperAudioRouting(
            usesAudioReactor: true,
            backgroundAudioReactiveEnabled: true
        )
        var disabledPreferences = AudioReactorPreferences.defaults
        disabledPreferences.isEnabled = false

        XCTAssertNotEqual(
            routing.backgroundScalars(rawAudio: rawAudio, preferences: disabledPreferences),
            .silent
        )
        XCTAssertEqual(routing.reactorScalars(rawAudio: rawAudio, preferences: disabledPreferences), .silent)
    }
}
