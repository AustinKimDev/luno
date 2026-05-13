import XCTest
@testable import LunoEngineCore

final class MediaRemoteSymbolsTests: XCTestCase {
    func testSymbolsAreAvailableOnHostMachine() {
        let symbols = MediaRemoteSymbols.load()
        XCTAssertEqual(
            symbols.registerForNotifications == nil,
            symbols.unregisterForNotifications == nil
        )
    }

    func testEmptySymbolsReportUnavailable() {
        let empty = MediaRemoteSymbols(
            getNowPlayingInfo: nil,
            registerForNotifications: nil,
            unregisterForNotifications: nil
        )
        XCTAssertFalse(empty.isAvailable)
    }
}
