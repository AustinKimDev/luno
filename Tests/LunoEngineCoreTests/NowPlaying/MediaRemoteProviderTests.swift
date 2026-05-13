import XCTest
@testable import LunoEngineCore

final class MediaRemoteProviderTests: XCTestCase {
    func testStaysSilentWhenSymbolsUnavailable() async throws {
        let symbols = MediaRemoteSymbols(
            getNowPlayingInfo: nil,
            registerForNotifications: nil,
            unregisterForNotifications: nil
        )
        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let provider = MediaRemoteProvider(symbols: symbols, clock: clock, pollInterval: 0.01)

        await provider.start()
        await provider.stop()

        do {
            try await provider.send(.playPause)
            XCTFail("Expected unavailable error")
        } catch MediaRemoteProvider.UnavailableError.frameworkUnavailable {
        }
    }

    func testParsesInfoDictionaryIntoTrack() {
        let info: [String: Any] = [
            "kMRMediaRemoteNowPlayingInfoTitle": "Clair de Lune",
            "kMRMediaRemoteNowPlayingInfoArtist": "Lang Lang",
            "kMRMediaRemoteNowPlayingInfoAlbum": "Suite bergamasque",
            "kMRMediaRemoteNowPlayingInfoComposer": "Claude Debussy",
            "kMRMediaRemoteNowPlayingInfoArtworkData": Data([0xCC, 0xDD]),
            "kMRMediaRemoteNowPlayingInfoPlaybackRate": Double(1.0)
        ]
        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 2_000))
        let track = MediaRemoteProvider.makeTrack(from: info, now: clock.now())
        XCTAssertEqual(track?.title, "Clair de Lune")
        XCTAssertEqual(track?.composer, "Claude Debussy")
        XCTAssertEqual(track?.source, .mediaRemote)
        XCTAssertTrue(track?.isPlaying ?? false)
        XCTAssertEqual(track?.artwork, .data(Data([0xCC, 0xDD])))
    }

    func testReturnsNilWhenInfoHasNoTitle() {
        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 2_000))
        XCTAssertNil(MediaRemoteProvider.makeTrack(from: [:], now: clock.now()))
    }
}
