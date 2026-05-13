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

    func testDefaultAppearanceMatchesExpectedValues() {
        let appearance = NowPlayingAppearance.default
        XCTAssertEqual(appearance.cornerRadius, 14)
        XCTAssertEqual(appearance.padding, 14)
        XCTAssertEqual(appearance.borderWidth, 1)
        XCTAssertEqual(appearance.borderOpacity, 0.08, accuracy: 0.0001)
        XCTAssertEqual(appearance.titleWeight, .semibold)
        XCTAssertEqual(appearance.subtitleWeight, .regular)
        XCTAssertEqual(appearance.textColor, "#FFFFFF")
        XCTAssertEqual(appearance.accentColor, "#FF6B9C")
        XCTAssertEqual(appearance.glowTint, "#FFFFFF")
        XCTAssertEqual(appearance.scaleReaction, 1.0)
        XCTAssertEqual(appearance.glowReaction, 1.0)
        XCTAssertEqual(appearance.borderReaction, 1.0)
    }

    func testAppearanceClampsOutOfRangeNumericValues() {
        let appearance = NowPlayingAppearance(
            cornerRadius: -5,
            padding: 999,
            borderWidth: -10,
            borderOpacity: 2.5,
            titleWeight: .regular,
            subtitleWeight: .regular,
            textColor: "#FFFFFF",
            accentColor: "#FFFFFF",
            glowTint: "#FFFFFF",
            scaleReaction: -1,
            glowReaction: 5,
            borderReaction: 0.4
        )
        XCTAssertEqual(appearance.cornerRadius, 0)
        XCTAssertEqual(appearance.padding, 24)
        XCTAssertEqual(appearance.borderWidth, 0)
        XCTAssertEqual(appearance.borderOpacity, 1)
        XCTAssertEqual(appearance.scaleReaction, 0)
        XCTAssertEqual(appearance.glowReaction, 1)
        XCTAssertEqual(appearance.borderReaction, 0.4)
    }

    func testAppearanceRoundTripsThroughJSON() throws {
        let original = NowPlayingAppearance.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NowPlayingAppearance.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
