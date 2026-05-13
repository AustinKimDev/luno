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

    func testUnsafeBufferFeatureAnalysisIncludesSpectrum() {
        let analyzer = AudioSpectrumAnalyzer()
        let sampleRate = 4_800.0
        let samples = (0..<4_800).map { index in
            Float(sin(2.0 * Double.pi * 80.0 * Double(index) / sampleRate))
        }

        let features = samples.withUnsafeBufferPointer {
            analyzer.analyzeFeatures(samples: $0, sampleRate: sampleRate)
        }

        XCTAssertGreaterThan(features.rms, 0.65)
        XCTAssertGreaterThan(features.bass, features.mid)
        XCTAssertEqual(features.spectrum.count, 64)
        XCTAssertGreaterThan(features.spectrum.max() ?? 0, 0)
    }

    func testArrayAnalysisMatchesUnsafeBufferFeatureAnalysis() {
        let analyzer = AudioSpectrumAnalyzer()
        let sampleRate = 4_800.0
        let samples = (0..<4_800).map { index in
            let time = Double(index) / sampleRate
            return Float(
                0.8 * sin(2.0 * Double.pi * 80.0 * time)
                    + 0.3 * sin(2.0 * Double.pi * 1_200.0 * time)
            )
        }

        let arrayFeatures = analyzer.analyze(samples: samples, sampleRate: sampleRate)
        let bufferFeatures = samples.withUnsafeBufferPointer {
            analyzer.analyzeFeatures(samples: $0, sampleRate: sampleRate)
        }

        XCTAssertEqual(arrayFeatures, bufferFeatures)
    }
}
