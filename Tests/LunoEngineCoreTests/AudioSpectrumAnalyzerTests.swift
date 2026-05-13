import XCTest
@testable import LunoEngineCore

final class AudioSpectrumAnalyzerTests: XCTestCase {
    func testLowFrequencySineProducesBassDominantFeatures() {
        let analyzer = AudioSpectrumAnalyzer()
        let sampleRate = 4_800.0
        let samples = (0..<4_800).map { index in
            Float(sin(2.0 * Double.pi * 80.0 * Double(index) / sampleRate))
        }

        let features = analyzer.analyze(samples: samples, sampleRate: sampleRate)

        XCTAssertGreaterThan(features.rms, 0.65)
        XCTAssertGreaterThan(features.bass, features.mid)
        XCTAssertGreaterThan(features.bass, features.treble)
        XCTAssertEqual(features.spectrum.count, 64)
    }
}
