import XCTest
@testable import LunoEngineCore

final class NowPlayingCoordinatorTests: XCTestCase {
    func testEmitsTrackFromOnlyPlayingProvider() async throws {
        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let spotify = MockNowPlayingProvider(source: .spotify)
        let coordinator = NowPlayingCoordinator(providers: [spotify], clock: clock)

        var iterator = coordinator.tracks.makeAsyncIterator()
        await coordinator.start()

        let track = NowPlayingTrack.fixture(source: .spotify, updatedAt: clock.now())
        spotify.emit(track)

        let received = await iterator.next() ?? nil
        XCTAssertEqual(received, track)

        await coordinator.stop()
        XCTAssertEqual(spotify.stopCount, 1)
    }

    func testAppleMusicWinsOverSpotifyWhenBothPlaying() async throws {
        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let am = MockNowPlayingProvider(source: .appleMusic)
        let sp = MockNowPlayingProvider(source: .spotify)
        let coordinator = NowPlayingCoordinator(providers: [am, sp], clock: clock)

        var iterator = coordinator.tracks.makeAsyncIterator()
        await coordinator.start()

        let spotifyTrack = NowPlayingTrack.fixture(title: "Spotify Song", source: .spotify, updatedAt: clock.now())
        sp.emit(spotifyTrack)
        let first = await iterator.next() ?? nil
        XCTAssertEqual(first?.title, "Spotify Song")

        let amTrack = NowPlayingTrack.fixture(title: "Apple Music Song", source: .appleMusic, updatedAt: clock.now())
        am.emit(amTrack)
        let second = await iterator.next() ?? nil
        XCTAssertEqual(second?.title, "Apple Music Song")

        await coordinator.stop()
    }

    func testEmitsNilWhenNoProviderIsPlaying() async throws {
        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let am = MockNowPlayingProvider(source: .appleMusic)
        let coordinator = NowPlayingCoordinator(providers: [am], clock: clock)

        var iterator = coordinator.tracks.makeAsyncIterator()
        await coordinator.start()

        let playing = NowPlayingTrack.fixture(source: .appleMusic, isPlaying: true, updatedAt: clock.now())
        am.emit(playing)
        _ = await iterator.next()

        let paused = NowPlayingTrack.fixture(source: .appleMusic, isPlaying: false, updatedAt: clock.now())
        am.emit(paused)
        let after = await iterator.next() ?? nil
        XCTAssertNil(after)

        await coordinator.stop()
    }
}
