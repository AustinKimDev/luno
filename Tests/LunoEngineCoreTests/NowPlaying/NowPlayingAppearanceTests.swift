import XCTest
@testable import LunoEngineCore

final class NowPlayingAppearanceTests: XCTestCase {
    func testFontWeightCases() {
        XCTAssertEqual(NowPlayingAppearance.FontWeight.allCases.count, 6)
        XCTAssertEqual(NowPlayingAppearance.FontWeight.regular.rawValue, "regular")
        XCTAssertEqual(NowPlayingAppearance.FontWeight.black.rawValue, "black")
    }

    func testFontWeightRoundTrip() throws {
        let original = NowPlayingAppearance.FontWeight.semibold
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NowPlayingAppearance.FontWeight.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
