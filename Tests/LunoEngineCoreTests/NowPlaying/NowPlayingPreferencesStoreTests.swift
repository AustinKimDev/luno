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
            isPinned: true,
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

    func testLoadDefaultsPinnedWhenFieldIsMissing() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appending(path: "now-playing.json")
        let store = NowPlayingPreferencesStore(fileURL: fileURL)
        let legacyJSON = """
        {
          "audioReactivityEnabled": true,
          "isEnabled": true,
          "keepVisibleWhilePaused": false,
          "positionsByDisplay": {},
          "style": "compactBar"
        }
        """
        try XCTUnwrap(legacyJSON.data(using: .utf8)).write(to: fileURL)

        let loaded = try store.load()
        XCTAssertTrue(loaded.isEnabled)
        XCTAssertFalse(loaded.isPinned)
    }
}
