import XCTest
@testable import LunoEngineCore

final class HexColorNormalizationTests: XCTestCase {
    func testNormalizedHexAcceptsValidValues() {
        XCTAssertEqual(NowPlayingAppearance.normalizedHex("#FF6B9C", fallback: "#000000"), "#FF6B9C")
        XCTAssertEqual(NowPlayingAppearance.normalizedHex("ff6b9c", fallback: "#000000"), "#FF6B9C")
    }

    func testNormalizedHexRejectsInvalidLengths() {
        XCTAssertEqual(NowPlayingAppearance.normalizedHex("#FFF", fallback: "#000000"), "#000000")
        XCTAssertEqual(NowPlayingAppearance.normalizedHex("#FF6B9C9C", fallback: "#000000"), "#000000")
    }

    func testNormalizedHexRejectsNonHexCharacters() {
        XCTAssertEqual(NowPlayingAppearance.normalizedHex("#GG6B9C", fallback: "#FF0000"), "#FF0000")
    }
}
