import XCTest
@testable import LunoEngineCore

final class SpotifyProviderTests: XCTestCase {
    func testEmitsTrackWithArtworkURL() async throws {
        let runner = MockAppleScriptRunner()
        let info = RawTrackInfo(
            title: "Aja",
            artist: "Steely Dan",
            album: "Aja",
            composer: nil,
            artworkData: nil,
            artworkURL: URL(string: "https://i.scdn.co/image/abc.jpg")!,
            trackID: "spotify:track:abc",
            isPlaying: true
        )
        await runner.enqueue(.success(info))

        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let provider = SpotifyProvider(runner: runner, clock: clock, pollInterval: 0.01)

        var iterator = provider.tracks.makeAsyncIterator()
        await provider.start()
        let track = await iterator.next()
        await provider.stop()

        XCTAssertEqual(track??.source, .spotify)
        XCTAssertEqual(track??.artwork, .url(URL(string: "https://i.scdn.co/image/abc.jpg")!))
        XCTAssertFalse(track??.isAdvertisement ?? true)
    }

    func testMarksAdvertisementWhenTrackIDHasAdPrefix() async throws {
        let runner = MockAppleScriptRunner()
        let info = RawTrackInfo(
            title: "Ad",
            artist: nil,
            album: nil,
            composer: nil,
            artworkData: nil,
            artworkURL: nil,
            trackID: "spotify:ad:12345",
            isPlaying: true
        )
        await runner.enqueue(.success(info))

        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let provider = SpotifyProvider(runner: runner, clock: clock, pollInterval: 0.01)

        var iterator = provider.tracks.makeAsyncIterator()
        await provider.start()
        let track = await iterator.next()
        await provider.stop()

        XCTAssertTrue(track??.isAdvertisement ?? false)
    }
}
