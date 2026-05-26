import Foundation

public struct ResolvedNowPlayingTrack: Equatable, Sendable {
    public var title: String
    public var artist: String?
    public var album: String?
    public var composer: String?
    public var artworkData: Data?
    public var source: NowPlayingSource
    public var isPlaying: Bool
    public var isAdvertisement: Bool
    public var updatedAt: Date

    public init(track: NowPlayingTrack, artworkData: Data?) {
        self.title = track.title
        self.artist = track.artist
        self.album = track.album
        self.composer = track.composer
        self.artworkData = artworkData
        self.source = track.source
        self.isPlaying = track.isPlaying
        self.isAdvertisement = track.isAdvertisement
        self.updatedAt = track.updatedAt
    }
}

public final class NowPlayingPipeline: @unchecked Sendable {
    public let output: AsyncStream<ResolvedNowPlayingTrack?>
    private var pumpTask: Task<Void, Never>?

    public init(upstream: AsyncStream<NowPlayingTrack?>, fetcher: ArtworkFetcher) {
        let (stream, continuation) = AsyncStream<ResolvedNowPlayingTrack?>.makeStream()
        self.output = stream
        self.pumpTask = Task {
            var lastEmittedKey: String?
            for await track in upstream {
                guard let track else {
                    if lastEmittedKey != nil {
                        lastEmittedKey = nil
                        continuation.yield(nil)
                    }
                    continue
                }

                let key = Self.key(for: track)
                guard key != lastEmittedKey else {
                    continue
                }

                let resolved = await Self.resolve(track: track, fetcher: fetcher)
                lastEmittedKey = key
                continuation.yield(resolved)
            }
            continuation.finish()
        }
    }

    deinit {
        pumpTask?.cancel()
    }

    private static func resolve(track: NowPlayingTrack, fetcher: ArtworkFetcher) async -> ResolvedNowPlayingTrack {
        let artworkData: Data?
        switch track.artwork {
        case .data(let data):
            artworkData = data
        case .url(let url):
            artworkData = try? await fetcher.data(for: url)
        case .none:
            artworkData = nil
        }
        return ResolvedNowPlayingTrack(track: track, artworkData: artworkData)
    }

    private static func key(for track: NowPlayingTrack) -> String {
        "\(track.title)|\(track.artist ?? "")|\(track.album ?? "")|\(track.isPlaying)"
    }
}
