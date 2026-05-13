import XCTest
@testable import LunoEngineCore

final class NowPlayingClockTests: XCTestCase {
    func testFakeClockReturnsConfiguredTime() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let clock = FakeNowPlayingClock(start: start)
        XCTAssertEqual(clock.now(), start)
    }

    func testFakeClockAdvancesByInterval() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let clock = FakeNowPlayingClock(start: start)
        clock.advance(by: 5)
        XCTAssertEqual(clock.now(), start.addingTimeInterval(5))
    }
}
