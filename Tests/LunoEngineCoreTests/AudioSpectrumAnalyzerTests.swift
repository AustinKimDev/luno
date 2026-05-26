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
        XCTAssertEqual(features.spectrum.count, 96)
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
        XCTAssertEqual(features.spectrum.count, 96)
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

    func testSpectrumMatchesMaximumReactorBarCount() {
        let analyzer = AudioSpectrumAnalyzer()
        let sampleRate = 48_000.0
        let samples = sineWave(frequency: 440, sampleRate: sampleRate)

        let features = analyzer.analyze(samples: samples, sampleRate: sampleRate)

        XCTAssertEqual(features.spectrum.count, 96)
    }

    func testSpectrumUsesMusicalBandSpacingAtProductionSampleRate() {
        let analyzer = AudioSpectrumAnalyzer()
        let sampleRate = 48_000.0
        let lowSamples = sineWave(frequency: 80, sampleRate: sampleRate)
        let highSamples = sineWave(frequency: 8_000, sampleRate: sampleRate)

        let lowSpectrum = analyzer.analyze(samples: lowSamples, sampleRate: sampleRate).spectrum
        let highSpectrum = analyzer.analyze(samples: highSamples, sampleRate: sampleRate).spectrum

        XCTAssertLessThan(peakIndex(in: lowSpectrum), 24)
        XCTAssertGreaterThan(lowSpectrum[0..<24].max() ?? 0, 0.35)
        XCTAssertGreaterThan(peakIndex(in: highSpectrum), 60)
        XCTAssertGreaterThan(highSpectrum[60..<96].max() ?? 0, 0.35)
    }

    func testSpectrumCoversAudibleRangeAtProductionSampleRate() {
        let analyzer = AudioSpectrumAnalyzer()
        let sampleRate = 48_000.0
        let subBass = analyzer.analyze(samples: sineWave(frequency: 30, sampleRate: sampleRate), sampleRate: sampleRate).spectrum
        let air = analyzer.analyze(samples: sineWave(frequency: 18_000, sampleRate: sampleRate), sampleRate: sampleRate).spectrum

        XCTAssertLessThan(peakIndex(in: subBass), 8)
        XCTAssertGreaterThan(subBass[0..<8].max() ?? 0, 0.25)
        XCTAssertGreaterThan(peakIndex(in: air), 88)
        XCTAssertGreaterThan(air[88..<96].max() ?? 0, 0.20)
    }

    func testSpectrumPeakIndexesIncreaseWithFrequencyAcrossAudibleRange() {
        let analyzer = AudioSpectrumAnalyzer()
        let sampleRate = 48_000.0
        let indexes = [80.0, 440.0, 1_000.0, 8_000.0].map { frequency in
            peakIndex(in: analyzer.analyze(samples: sineWave(frequency: frequency, sampleRate: sampleRate), sampleRate: sampleRate).spectrum)
        }

        XCTAssertLessThan(indexes[0], indexes[1])
        XCTAssertLessThan(indexes[1], indexes[2])
        XCTAssertLessThan(indexes[2], indexes[3])
    }

    func testQuietSpectrumDoesNotNormalizeToFullScale() {
        let analyzer = AudioSpectrumAnalyzer()
        let sampleRate = 48_000.0
        let quietSamples = sineWave(frequency: 440, sampleRate: sampleRate, amplitude: 0.04)
        let loudSamples = sineWave(frequency: 440, sampleRate: sampleRate, amplitude: 1.0)

        let quietPeak = analyzer.analyze(samples: quietSamples, sampleRate: sampleRate).spectrum.max() ?? 0
        let loudPeak = analyzer.analyze(samples: loudSamples, sampleRate: sampleRate).spectrum.max() ?? 0

        XCTAssertLessThan(quietPeak, 0.2)
        XCTAssertLessThan(quietPeak, loudPeak * 0.3)
    }

    func testBassSpectrumDoesNotSmearAcrossManyAdjacentBars() {
        let analyzer = AudioSpectrumAnalyzer()
        let sampleRate = 48_000.0
        let samples = sineWave(frequency: 80, sampleRate: sampleRate)

        let spectrum = analyzer.analyze(samples: samples, sampleRate: sampleRate).spectrum
        let strongBassBars = spectrum[0..<24].filter { $0 > 0.35 }.count

        XCTAssertLessThanOrEqual(strongBassBars, 5)
    }

    private func sineWave(
        frequency: Double,
        sampleRate: Double,
        duration: Double = 1.0,
        amplitude: Double = 1.0
    ) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        return (0..<sampleCount).map { index in
            Float(amplitude * sin(2.0 * Double.pi * frequency * Double(index) / sampleRate))
        }
    }

    private func peakIndex(in spectrum: [Float]) -> Int {
        spectrum.indices.max { spectrum[$0] < spectrum[$1] } ?? 0
    }
}
