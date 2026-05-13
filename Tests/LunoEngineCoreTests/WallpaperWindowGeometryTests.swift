import CoreGraphics
import XCTest
@testable import LunoEngineCore

final class WallpaperWindowGeometryTests: XCTestCase {
    func testCreatesLocalContentRectForTargetScreen() {
        let screenFrame = CGRect(x: -1440, y: -1117, width: 1440, height: 2560)

        let geometry = WallpaperWindowGeometry(screenFrame: screenFrame)

        XCTAssertEqual(geometry.windowFrame, screenFrame)
        XCTAssertEqual(geometry.contentFrame, CGRect(x: 0, y: 0, width: 1440, height: 2560))
    }
}
