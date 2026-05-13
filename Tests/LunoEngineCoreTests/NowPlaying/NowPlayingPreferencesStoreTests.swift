import XCTest
@testable import LunoEngineCore

final class NowPlayingPreferencesStoreTests: XCTestCase {
    func testRoundTripsAllFields() throws {
        let directory = try temporaryDirectory()
        let store = NowPlayingPreferencesStore(fileURL: directory.appending(path: "now-playing.json"))

        let prefs = NowPlayingPreferences(
            isEnabled: true,
            style: .compactBar,
            audioReactivityEnabled: true,
            keepVisibleWhilePaused: false,
            positionsByDisplay: ["1": NowPlayingPreferences.Position(x: 1200, y: 80)]
        )
        try store.save(prefs)

        let loaded = try store.load()
        XCTAssertEqual(loaded, prefs)
    }

    func testLoadReturnsDefaultsWhenFileMissing() throws {
        let directory = try temporaryDirectory()
        let store = NowPlayingPreferencesStore(fileURL: directory.appending(path: "now-playing.json"))
        XCTAssertEqual(try store.load(), .defaults)
    }
}
