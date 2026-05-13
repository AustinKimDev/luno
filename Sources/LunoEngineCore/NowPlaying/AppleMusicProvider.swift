import Foundation

public actor AppleMusicProvider: NowPlayingProvider, NowPlayingControls {
    public nonisolated let source: NowPlayingSource = .appleMusic
    public nonisolated let tracks: AsyncStream<NowPlayingTrack?>

    private let runner: AppleScriptRunner
    private let clock: NowPlayingClock
    private let pollInterval: TimeInterval
    private let artworkURLResolver: AppleMusicArtworkURLResolving
    private let continuation: AsyncStream<NowPlayingTrack?>.Continuation

    private var pollTask: Task<Void, Never>?
    private var hasEmitted = false
    private var lastEmitted: NowPlayingTrack?

    public init(
        runner: AppleScriptRunner,
        clock: NowPlayingClock = SystemNowPlayingClock(),
        pollInterval: TimeInterval = 1.0,
        artworkURLResolver: AppleMusicArtworkURLResolving = NoopAppleMusicArtworkURLResolver()
    ) {
        self.runner = runner
        self.clock = clock
        self.pollInterval = pollInterval
        self.artworkURLResolver = artworkURLResolver
        let (stream, continuation) = AsyncStream<NowPlayingTrack?>.makeStream()
        self.tracks = stream
        self.continuation = continuation
    }

    public func start() async {
        pollTask?.cancel()
        let runner = runner
        let clock = clock
        let interval = pollInterval
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                let result: Result<RawTrackInfo?, Error>
                do {
                    result = .success(try await runner.fetchTrack())
                } catch {
                    result = .failure(error)
                }

                await self?.handle(result: result, now: clock.now())
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    public func stop() async {
        pollTask?.cancel()
        pollTask = nil
        continuation.finish()
    }

    public func send(_ command: NowPlayingControlCommand) async throws {
        try await runner.sendControl(command)
    }

    private func handle(result: Result<RawTrackInfo?, Error>, now: Date) async {
        switch result {
        case .failure:
            return
        case .success(let raw):
            let track: NowPlayingTrack?
            if let raw {
                track = await mapToTrack(raw, now: now)
            } else {
                track = nil
            }
            if !hasEmitted || track != lastEmitted {
                hasEmitted = true
                lastEmitted = track
                continuation.yield(track)
            }
        }
    }

    private func mapToTrack(_ raw: RawTrackInfo, now: Date) async -> NowPlayingTrack {
        let artwork: NowPlayingTrack.Artwork?
        if let data = raw.artworkData {
            artwork = .data(data)
        } else if let url = raw.artworkURL {
            artwork = .url(url)
        } else if let url = await artworkURLResolver.artworkURL(title: raw.title, artist: raw.artist, album: raw.album) {
            artwork = .url(url)
        } else {
            artwork = nil
        }

        return NowPlayingTrack(
            title: raw.title,
            artist: raw.artist,
            album: raw.album,
            composer: raw.composer,
            artwork: artwork,
            source: source,
            isPlaying: raw.isPlaying,
            isAdvertisement: false,
            updatedAt: now
        )
    }
}
