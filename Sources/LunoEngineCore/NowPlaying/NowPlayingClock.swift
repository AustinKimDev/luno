import Foundation

public protocol NowPlayingClock: Sendable {
    func now() -> Date
}

public struct SystemNowPlayingClock: NowPlayingClock {
    public init() {}
    public func now() -> Date { Date() }
}
