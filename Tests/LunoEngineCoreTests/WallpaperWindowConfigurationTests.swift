import AppKit
import XCTest
@testable import LunoEngineCore

final class WallpaperWindowConfigurationTests: XCTestCase {
    func testWallpaperWindowsJoinSpacesAndStayStationaryDuringSpaceTransitions() {
        let configuration = WallpaperWindowConfiguration()

        XCTAssertTrue(configuration.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(configuration.collectionBehavior.contains(.stationary))
        XCTAssertTrue(configuration.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(configuration.collectionBehavior.contains(.ignoresCycle))
    }
}
