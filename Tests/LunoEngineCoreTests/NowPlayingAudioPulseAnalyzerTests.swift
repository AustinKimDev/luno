import XCTest
@testable import LunoEngineCore

final class NowPlayingAudioPulseAnalyzerTests: XCTestCase {
    func testBassPulseStaysResponsiveForShortBassWindows() {
        let analyzer = NowPlayingAudioPulseAnalyzer()
        let sampleRate = 48_000.0
        let samples = sineWave(frequency: 80, sampleRate: sampleRate, duration: 0.08, amplitude: 0.08)

        let level = analyzer.bassLevel(samples: samples, sampleRate: sampleRate)

        XCTAssertGreaterThan(level, 0.45)
    }

    func testBassPulsePrefersBassOverTreble() {
        let analyzer = NowPlayingAudioPulseAnalyzer()
        let sampleRate = 48_000.0
        let bass = sineWave(frequency: 80, sampleRate: sampleRate, duration: 0.08, amplitude: 0.08)
        let treble = sineWave(frequency: 4_000, sampleRate: sampleRate, duration: 0.08, amplitude: 0.08)

        XCTAssertGreaterThan(
            analyzer.bassLevel(samples: bass, sampleRate: sampleRate),
            analyzer.bassLevel(samples: treble, sampleRate: sampleRate) * 1.8
        )
    }

    func testSilenceProducesNoBassPulse() {
        let analyzer = NowPlayingAudioPulseAnalyzer()
        let samples = Array<Float>(repeating: 0, count: 4_096)

        XCTAssertEqual(analyzer.bassLevel(samples: samples, sampleRate: 48_000), 0)
    }

    private func sineWave(
        frequency: Double,
        sampleRate: Double,
        duration: Double,
        amplitude: Double
    ) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        return (0..<sampleCount).map { index in
            Float(amplitude * sin(2.0 * Double.pi * frequency * Double(index) / sampleRate))
        }
    }
}
