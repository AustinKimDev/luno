import XCTest
@testable import LunoEngineCore

final class AlbumPaletteExtractorTests: XCTestCase {
    func testExtractsDominantAlbumPaletteFromSampleColors() throws {
        let samples =
            Array(repeating: AlbumPaletteExtractor.Sample(red: 12, green: 15, blue: 22), count: 60) +
            Array(repeating: AlbumPaletteExtractor.Sample(red: 230, green: 64, blue: 72), count: 45) +
            Array(repeating: AlbumPaletteExtractor.Sample(red: 37, green: 125, blue: 228), count: 25) +
            Array(repeating: AlbumPaletteExtractor.Sample(red: 255, green: 240, blue: 188), count: 12) +
            Array(repeating: AlbumPaletteExtractor.Sample(red: 250, green: 250, blue: 250), count: 30)

        let palette = AlbumPaletteExtractor.extract(from: samples)

        XCTAssertLessThan(palette.background.x, 0.12)
        XCTAssertLessThan(palette.background.y, 0.12)
        XCTAssertLessThan(palette.background.z, 0.14)
        XCTAssertGreaterThan(palette.primary.x, 0.75)
        XCTAssertLessThan(palette.primary.y, 0.35)
        XCTAssertLessThan(palette.primary.z, 0.40)
        XCTAssertLessThan(palette.secondary.x, 0.35)
        XCTAssertGreaterThan(palette.secondary.y, 0.35)
        XCTAssertGreaterThan(palette.secondary.z, 0.65)
        XCTAssertGreaterThan(palette.highlight.x, 0.75)
        XCTAssertGreaterThan(palette.highlight.y, 0.65)
    }

    func testFallsBackWhenNoVisibleSamplesExist() throws {
        let samples = [
            AlbumPaletteExtractor.Sample(red: 255, green: 0, blue: 0, alpha: 0),
            AlbumPaletteExtractor.Sample(red: 0, green: 255, blue: 0, alpha: 1)
        ]

        XCTAssertEqual(AlbumPaletteExtractor.extract(from: samples), .fallback)
    }

    func testInterpolatesPaletteColors() throws {
        let start = AlbumPalette(
            background: SIMD4<Float>(0, 0, 0, 1),
            primary: SIMD4<Float>(1, 0, 0, 1),
            secondary: SIMD4<Float>(0, 1, 0, 1),
            highlight: SIMD4<Float>(0, 0, 1, 1)
        )
        let end = AlbumPalette(
            background: SIMD4<Float>(1, 1, 1, 1),
            primary: SIMD4<Float>(0, 1, 0, 1),
            secondary: SIMD4<Float>(0, 0, 1, 1),
            highlight: SIMD4<Float>(1, 0, 0, 1)
        )

        let palette = start.interpolated(toward: end, amount: 0.25)

        XCTAssertEqual(palette.background, SIMD4<Float>(0.25, 0.25, 0.25, 1))
        XCTAssertEqual(palette.primary, SIMD4<Float>(0.75, 0.25, 0, 1))
        XCTAssertEqual(palette.secondary, SIMD4<Float>(0, 0.75, 0.25, 1))
        XCTAssertEqual(palette.highlight, SIMD4<Float>(0.25, 0, 0.75, 1))
    }
}
