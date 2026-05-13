import Foundation

public actor MediaRemoteProvider: NowPlayingProvider, NowPlayingControls {
    public enum UnavailableError: Error, Equatable {
        case frameworkUnavailable
    }

    public nonisolated let source: NowPlayingSource = .mediaRemote
    public nonisolated let tracks: AsyncStream<NowPlayingTrack?>

    private let symbols: MediaRemoteSymbols
    private let clock: NowPlayingClock
    private let pollInterval: TimeInterval
    private let continuation: AsyncStream<NowPlayingTrack?>.Continuation
    private let queue = DispatchQueue(label: "com.luno.mediaremote.poll")

    private var pollTask: Task<Void, Never>?
    private var hasEmitted = false
    private var lastEmitted: NowPlayingTrack?

    public init(
        symbols: MediaRemoteSymbols = MediaRemoteSymbols.load(),
        clock: NowPlayingClock = SystemNowPlayingClock(),
        pollInterval: TimeInterval = 5.0
    ) {
        self.symbols = symbols
        self.clock = clock
        self.pollInterval = pollInterval
        let (stream, continuation) = AsyncStream<NowPlayingTrack?>.makeStream()
        self.tracks = stream
        self.continuation = continuation
    }

    public func start() async {
        guard symbols.isAvailable else { return }

        let interval = pollInterval
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshOnce()
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
        throw UnavailableError.frameworkUnavailable
    }

    private func refreshOnce() {
        guard let getInfo = symbols.getNowPlayingInfo else { return }
        let now = clock.now()
        getInfo(queue) { [weak self] info in
            let payload = MediaRemoteInfoPayload(info: info)
            Task { await self?.handle(payload: payload, now: now) }
        }
    }

    private func handle(payload: MediaRemoteInfoPayload, now: Date) {
        let track = Self.makeTrack(from: payload.info, now: now)
        if !hasEmitted || track != lastEmitted {
            hasEmitted = true
            lastEmitted = track
            continuation.yield(track)
        }
    }

    static func makeTrack(from info: [String: Any], now: Date) -> NowPlayingTrack? {
        guard let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String, !title.isEmpty else {
            return nil
        }
        let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String
        let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String
        let composer = info["kMRMediaRemoteNowPlayingInfoComposer"] as? String
        let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
        let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0

        return NowPlayingTrack(
            title: title,
            artist: artist,
            album: album,
            composer: composer,
            artwork: artworkData.map { .data($0) },
            source: .mediaRemote,
            isPlaying: rate > 0,
            isAdvertisement: false,
            updatedAt: now
        )
    }
}

private struct MediaRemoteInfoPayload: @unchecked Sendable {
    let info: [String: Any]
}
