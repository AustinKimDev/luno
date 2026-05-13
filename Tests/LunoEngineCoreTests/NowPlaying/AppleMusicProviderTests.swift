import XCTest
@testable import LunoEngineCore

actor MockAppleScriptRunner: AppleScriptRunner {
    private var queue: [Result<RawTrackInfo?, Error>] = []
    private var sentCommands: [NowPlayingControlCommand] = []

    func enqueue(_ result: Result<RawTrackInfo?, Error>) {
        queue.append(result)
    }

    func fetchTrack() async throws -> RawTrackInfo? {
        let next = queue.isEmpty ? .success(nil) : queue.removeFirst()
        return try next.get()
    }

    func sendControl(_ command: NowPlayingControlCommand) async throws {
        sentCommands.append(command)
    }

    func commands() -> [NowPlayingControlCommand] {
        sentCommands
    }
}

actor MockAppleMusicArtworkURLResolver: AppleMusicArtworkURLResolving {
    private let url: URL?

    init(url: URL?) {
        self.url = url
    }

    func artworkURL(title: String, artist: String?, album: String?) async -> URL? {
        url
    }
}

final class AppleMusicProviderTests: XCTestCase {
    func testEmitsTrackWhenRunnerReportsPlaying() async throws {
        let runner = MockAppleScriptRunner()
        let info = RawTrackInfo(
            title: "Clair de Lune",
            artist: "Lang Lang",
            album: "Suite bergamasque",
            composer: "Claude Debussy",
            artworkData: Data([0xAA]),
            artworkURL: nil,
            trackID: "1",
            isPlaying: true
        )
        await runner.enqueue(.success(info))

        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let provider = AppleMusicProvider(runner: runner, clock: clock, pollInterval: 0.01)

        var iterator = provider.tracks.makeAsyncIterator()
        await provider.start()
        let track = await iterator.next()
        await provider.stop()

        XCTAssertEqual(track??.title, "Clair de Lune")
        XCTAssertEqual(track??.composer, "Claude Debussy")
        XCTAssertEqual(track??.source, .appleMusic)
        XCTAssertEqual(track??.artwork, .data(Data([0xAA])))
    }

    func testEmitsNilWhenRunnerReportsNotPlaying() async throws {
        let runner = MockAppleScriptRunner()
        await runner.enqueue(.success(nil))

        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let provider = AppleMusicProvider(runner: runner, clock: clock, pollInterval: 0.01)

        var iterator = provider.tracks.makeAsyncIterator()
        await provider.start()
        let track = await iterator.next()
        await provider.stop()

        XCTAssertNil(track ?? nil)
    }

    func testForwardsControlCommands() async throws {
        let runner = MockAppleScriptRunner()
        let provider = AppleMusicProvider(runner: runner, clock: SystemNowPlayingClock(), pollInterval: 60)
        try await provider.send(.playPause)
        try await provider.send(.nextTrack)
        let commands = await runner.commands()
        XCTAssertEqual(commands, [.playPause, .nextTrack])
    }

    func testIgnoresAppNotInstalledError() async throws {
        let runner = MockAppleScriptRunner()
        await runner.enqueue(.failure(AppleScriptRunnerError.appNotInstalled))

        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let provider = AppleMusicProvider(runner: runner, clock: clock, pollInterval: 0.01)

        let info = RawTrackInfo(
            title: "Aja",
            artist: "Steely Dan",
            album: "Aja",
            composer: nil,
            artworkData: nil,
            artworkURL: nil,
            trackID: "2",
            isPlaying: true
        )
        await runner.enqueue(.success(info))

        var iterator = provider.tracks.makeAsyncIterator()
        await provider.start()
        let track = await iterator.next()
        await provider.stop()

        XCTAssertEqual(track??.title, "Aja")
    }

    func testUsesArtworkURLResolverWhenRunnerHasNoArtwork() async throws {
        let runner = MockAppleScriptRunner()
        let artworkURL = try XCTUnwrap(URL(string: "https://example.com/artwork.jpg"))
        let resolver = MockAppleMusicArtworkURLResolver(url: artworkURL)
        let info = RawTrackInfo(
            title: "Susususu Suki Daaisuki",
            artist: "Yamane Mah",
            album: "すすすす、すき、だあいすき - 今週のシングル",
            composer: nil,
            artworkData: nil,
            artworkURL: nil,
            trackID: "3",
            isPlaying: true
        )
        await runner.enqueue(.success(info))

        let clock = FakeNowPlayingClock(start: Date(timeIntervalSince1970: 1_000))
        let provider = AppleMusicProvider(
            runner: runner,
            clock: clock,
            pollInterval: 0.01,
            artworkURLResolver: resolver
        )

        var iterator = provider.tracks.makeAsyncIterator()
        await provider.start()
        let track = await iterator.next()
        await provider.stop()

        XCTAssertEqual(track??.artwork, .url(artworkURL))
    }
}
