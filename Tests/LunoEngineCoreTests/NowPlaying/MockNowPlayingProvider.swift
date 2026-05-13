import Foundation
@testable import LunoEngineCore

final class MockNowPlayingProvider: NowPlayingProvider, @unchecked Sendable {
    let source: NowPlayingSource
    let tracks: AsyncStream<NowPlayingTrack?>
    private let continuation: AsyncStream<NowPlayingTrack?>.Continuation

    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(source: NowPlayingSource) {
        self.source = source
        var captured: AsyncStream<NowPlayingTrack?>.Continuation!
        self.tracks = AsyncStream { captured = $0 }
        self.continuation = captured
    }

    func start() async { startCount += 1 }
    func stop() async {
        stopCount += 1
        continuation.finish()
    }

    func emit(_ track: NowPlayingTrack?) {
        continuation.yield(track)
    }

    func finish() {
        continuation.finish()
    }
}

extension NowPlayingTrack {
    static func fixture(
        title: String = "Title",
        source: NowPlayingSource,
        isPlaying: Bool = true,
        updatedAt: Date
    ) -> NowPlayingTrack {
        NowPlayingTrack(
            title: title,
            artist: "Artist",
            album: "Album",
            composer: nil,
            artwork: nil,
            source: source,
            isPlaying: isPlaying,
            isAdvertisement: false,
            updatedAt: updatedAt
        )
    }
}
