import Foundation

public actor NowPlayingCoordinator {
    public nonisolated let tracks: AsyncStream<NowPlayingTrack?>

    private nonisolated let outputContinuation: AsyncStream<NowPlayingTrack?>.Continuation
    private let providers: [any NowPlayingProvider]
    private let clock: NowPlayingClock
    private let priorityOrder: [NowPlayingSource]
    private let priorityHoldSeconds: TimeInterval

    private var lastByProvider: [NowPlayingSource: NowPlayingTrack] = [:]
    private var lastEmitted: NowPlayingTrack?
    private var pumpTask: Task<Void, Never>?

    public init(
        providers: [any NowPlayingProvider],
        clock: NowPlayingClock = SystemNowPlayingClock(),
        priorityOrder: [NowPlayingSource] = [.appleMusic, .spotify, .mediaRemote],
        priorityHoldSeconds: TimeInterval = 2.0
    ) {
        self.providers = providers
        self.clock = clock
        self.priorityOrder = priorityOrder
        self.priorityHoldSeconds = priorityHoldSeconds
        var captured: AsyncStream<NowPlayingTrack?>.Continuation!
        self.tracks = AsyncStream { captured = $0 }
        self.outputContinuation = captured
    }

    public func start() async {
        for provider in providers { await provider.start() }

        pumpTask = Task { [weak self] in
            guard let self else { return }
            await self.pumpAll()
        }
    }

    public func stop() async {
        pumpTask?.cancel()
        pumpTask = nil
        for provider in providers { await provider.stop() }
        outputContinuation.finish()
    }

    private func pumpAll() async {
        await withTaskGroup(of: Void.self) { group in
            for provider in providers {
                let source = provider.source
                let stream = provider.tracks
                group.addTask { [weak self] in
                    for await track in stream {
                        await self?.handle(source: source, track: track)
                    }
                }
            }
        }
    }

    private func handle(source: NowPlayingSource, track: NowPlayingTrack?) {
        if let track {
            lastByProvider[source] = track
        } else {
            lastByProvider.removeValue(forKey: source)
        }
        let resolved = resolve()
        if resolved != lastEmitted {
            lastEmitted = resolved
            outputContinuation.yield(resolved)
        }
    }

    private func resolve() -> NowPlayingTrack? {
        let now = clock.now()

        for source in priorityOrder {
            if let track = lastByProvider[source],
               track.isPlaying,
               now.timeIntervalSince(track.updatedAt) <= priorityHoldSeconds {
                return track
            }
        }

        let playing = priorityOrder.compactMap { lastByProvider[$0] }.filter { $0.isPlaying }
        return playing.max(by: { $0.updatedAt < $1.updatedAt })
    }
}
