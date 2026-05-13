import Foundation
@testable import LunoEngineCore

final class FakeNowPlayingClock: NowPlayingClock, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date

    init(start: Date = Date(timeIntervalSince1970: 0)) {
        self._now = start
    }

    func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return _now
    }

    func advance(by interval: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        _now.addTimeInterval(interval)
    }
}
