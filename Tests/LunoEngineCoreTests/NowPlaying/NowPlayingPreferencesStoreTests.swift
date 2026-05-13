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
}
