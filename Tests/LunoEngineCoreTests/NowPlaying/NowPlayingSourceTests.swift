import XCTest
@testable import LunoEngineCore

final class NowPlayingSourceTests: XCTestCase {
    func testRawValuesAreStableForPersistence() {
        XCTAssertEqual(NowPlayingSource.appleMusic.rawValue, "appleMusic")
        XCTAssertEqual(NowPlayingSource.spotify.rawValue, "spotify")
        XCTAssertEqual(NowPlayingSource.mediaRemote.rawValue, "mediaRemote")
    }

    func testCaseIterableOrderMatchesPriority() {
        XCTAssertEqual(NowPlayingSource.allCases, [.appleMusic, .spotify, .mediaRemote])
    }
}
