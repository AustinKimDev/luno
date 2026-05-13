import XCTest
@testable import LunoEngineCore

final class RawTrackInfoTests: XCTestCase {
    func testEquatable() {
        let a = RawTrackInfo(
            title: "T",
            artist: "A",
            album: "L",
            composer: "C",
            artworkData: Data([0x01]),
            artworkURL: nil,
            trackID: "1",
            isPlaying: true
        )
        let b = a
        XCTAssertEqual(a, b)
    }
}
