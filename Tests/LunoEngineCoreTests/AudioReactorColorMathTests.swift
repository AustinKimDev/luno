import XCTest
@testable import LunoEngineCore

final class AudioReactorColorMathTests: XCTestCase {
    func testRGBToHSLRoundTripPreservesColor() {
        let cases: [(Double, Double, Double)] = [
            (1.0, 0.0, 0.0),        // pure red
            (0.0, 1.0, 0.0),        // pure green
            (0.0, 0.0, 1.0),        // pure blue
            (0.5, 0.5, 0.5),        // mid gray
            (0.95, 0.2, 0.6),       // pink
            (0.0, 0.0, 0.0),        // black
            (1.0, 1.0, 1.0)         // white
        ]
        for (r, g, b) in cases {
            let hsl = AudioReactorColorMath.rgbToHSL(r: r, g: g, b: b)
            let back = AudioReactorColorMath.hslToRGB(h: hsl.h, s: hsl.s, l: hsl.l)
            XCTAssertEqual(back.r, r, accuracy: 0.001, "red mismatch for \(r),\(g),\(b)")
            XCTAssertEqual(back.g, g, accuracy: 0.001, "green mismatch")
            XCTAssertEqual(back.b, b, accuracy: 0.001, "blue mismatch")
        }
    }

    func testHSLKnownValues() {
        // Pure red: h=0, s=1, l=0.5
        let red = AudioReactorColorMath.rgbToHSL(r: 1, g: 0, b: 0)
        XCTAssertEqual(red.h, 0, accuracy: 0.001)
        XCTAssertEqual(red.s, 1, accuracy: 0.001)
        XCTAssertEqual(red.l, 0.5, accuracy: 0.001)

        // Pure green: h=120, s=1, l=0.5
        let green = AudioReactorColorMath.rgbToHSL(r: 0, g: 1, b: 0)
        XCTAssertEqual(green.h, 120, accuracy: 0.001)
        XCTAssertEqual(green.s, 1, accuracy: 0.001)
        XCTAssertEqual(green.l, 0.5, accuracy: 0.001)

        // Gray: s=0
        let gray = AudioReactorColorMath.rgbToHSL(r: 0.5, g: 0.5, b: 0.5)
        XCTAssertEqual(gray.s, 0, accuracy: 0.001)
        XCTAssertEqual(gray.l, 0.5, accuracy: 0.001)
    }

    func testHSLToRGBNormalizesOutOfRangeHue() {
        // 480° is 360° + 120° → should produce the same result as 120° (green).
        let cycled = AudioReactorColorMath.hslToRGB(h: 480, s: 1, l: 0.5)
        let direct = AudioReactorColorMath.hslToRGB(h: 120, s: 1, l: 0.5)
        XCTAssertEqual(cycled.r, direct.r, accuracy: 0.001)
        XCTAssertEqual(cycled.g, direct.g, accuracy: 0.001)
        XCTAssertEqual(cycled.b, direct.b, accuracy: 0.001)

        // Negative hue: -60° should equal +300° (magenta).
        let negative = AudioReactorColorMath.hslToRGB(h: -60, s: 1, l: 0.5)
        let positive = AudioReactorColorMath.hslToRGB(h: 300, s: 1, l: 0.5)
        XCTAssertEqual(negative.r, positive.r, accuracy: 0.001)
        XCTAssertEqual(negative.g, positive.g, accuracy: 0.001)
        XCTAssertEqual(negative.b, positive.b, accuracy: 0.001)
    }
}
