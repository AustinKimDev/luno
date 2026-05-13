import Foundation

public protocol NowPlayingProvider: Sendable {
    var source: NowPlayingSource { get }
    var tracks: AsyncStream<NowPlayingTrack?> { get }
    func start() async
    func stop() async
}
