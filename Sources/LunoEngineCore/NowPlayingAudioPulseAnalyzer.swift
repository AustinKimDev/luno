import Foundation

public struct NowPlayingAudioPulseAnalyzer: Sendable {
    public static let maxSampleCount = 4_096
    private static let bassTargets = [55.0, 80.0, 120.0, 170.0]

    public init() {}

    public func bassLevel(samples: [Float], sampleRate: Double) -> Float {
        samples.withUnsafeBufferPointer { buffer in
            bassLevel(samples: buffer, sampleRate: sampleRate)
        }
    }

    public func bassLevel(samples: UnsafeBufferPointer<Float>, sampleRate: Double) -> Float {
        guard let base = samples.baseAddress, samples.count > 0, sampleRate > 0 else {
            return 0
        }

        let count = min(samples.count, Self.maxSampleCount)
        var sumSquares: Float = 0
        for index in 0..<count {
            let sample = base[index]
            sumSquares += sample * sample
        }

        let rms = (sumSquares / Float(count)).squareRoot()
        guard rms > 0.002 else { return 0 }

        var bassTotal: Float = 0
        var targetCount = 0
        let nyquist = sampleRate / 2
        for target in Self.bassTargets where target < nyquist {
            bassTotal += goertzelMagnitude(
                base: base,
                count: count,
                sampleRate: sampleRate,
                targetFrequency: target
            )
            targetCount += 1
        }

        guard targetCount > 0 else { return 0 }
        let relativeBass = min(max((bassTotal / Float(targetCount)) / max(rms, 0.000_001), 0), 1)
        let loudness = min(max((rms - 0.004) / 0.08, 0), 1)
        let level = pow(relativeBass, 0.65) * 0.75 + loudness * 0.35
        return min(max(level, 0), 1)
    }

    private func goertzelMagnitude(
        base: UnsafePointer<Float>,
        count: Int,
        sampleRate: Double,
        targetFrequency: Double
    ) -> Float {
        let omega = 2.0 * Double.pi * targetFrequency / sampleRate
        let coeff = Float(2.0 * cos(omega))
        var s1: Float = 0
        var s2: Float = 0
        for index in 0..<count {
            let s0 = base[index] + coeff * s1 - s2
            s2 = s1
            s1 = s0
        }
        let magSquared = s1 * s1 + s2 * s2 - coeff * s1 * s2
        let mag = magSquared > 0 ? magSquared.squareRoot() : 0
        return 2.0 * mag / Float(count)
    }
}
