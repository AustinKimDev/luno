import Foundation

public struct AudioFeatures: Codable, Equatable, Sendable {
    public var rms: Float
    public var bass: Float
    public var mid: Float
    public var treble: Float
    public var spectrum: [Float]

    public static let silent = AudioFeatures(
        rms: 0,
        bass: 0,
        mid: 0,
        treble: 0,
        spectrum: Array(repeating: 0, count: 64)
    )

    public init(
        rms: Float,
        bass: Float,
        mid: Float,
        treble: Float,
        spectrum: [Float]
    ) {
        self.rms = rms
        self.bass = bass
        self.mid = mid
        self.treble = treble
        self.spectrum = spectrum
    }

    public var scalars: AudioScalars {
        AudioScalars(rms: rms, bass: bass, mid: mid, treble: treble)
    }
}

public struct AudioScalars: Equatable, Sendable {
    public var rms: Float
    public var bass: Float
    public var mid: Float
    public var treble: Float

    public static let silent = AudioScalars(rms: 0, bass: 0, mid: 0, treble: 0)

    public init(rms: Float, bass: Float, mid: Float, treble: Float) {
        self.rms = rms
        self.bass = bass
        self.mid = mid
        self.treble = treble
    }
}

public struct AudioSpectrumAnalyzer: Sendable {
    public init() {}

    public func analyzeScalars(
        samples: UnsafeBufferPointer<Float>,
        sampleRate: Double
    ) -> AudioScalars {
        guard let base = samples.baseAddress, samples.count > 0, sampleRate > 0 else {
            return .silent
        }

        let count = min(samples.count, 4_096)

        var sumSquares: Float = 0
        for index in 0..<count {
            let sample = base[index]
            sumSquares += sample * sample
        }
        let rms = (sumSquares / Float(count)).squareRoot()
        guard rms > 0.000_001 else {
            return AudioScalars(rms: rms, bass: 0, mid: 0, treble: 0)
        }

        let bass = bandEnergy(base: base, count: count, sampleRate: sampleRate, targets: Self.bassTargets, rms: rms)
        let mid = bandEnergy(base: base, count: count, sampleRate: sampleRate, targets: Self.midTargets, rms: rms)
        let treble = bandEnergy(base: base, count: count, sampleRate: sampleRate, targets: Self.trebleTargets, rms: rms)

        return AudioScalars(rms: rms, bass: bass, mid: mid, treble: treble)
    }

    private static let bassTargets: [Double] = [60, 100, 180]
    private static let midTargets: [Double] = [500, 1_200, 2_500]
    private static let trebleTargets: [Double] = [5_000, 8_000, 12_000]

    private func bandEnergy(
        base: UnsafePointer<Float>,
        count: Int,
        sampleRate: Double,
        targets: [Double],
        rms: Float
    ) -> Float {
        var total: Float = 0
        var validTargets: Int = 0
        let nyquist = sampleRate / 2.0
        for target in targets where target < nyquist {
            total += goertzelMagnitude(
                base: base,
                count: count,
                sampleRate: sampleRate,
                targetFrequency: target
            )
            validTargets += 1
        }
        guard validTargets > 0 else { return 0 }
        let avg = total / Float(validTargets)
        let normalized = avg / max(rms, 0.000_001)
        return min(max(normalized, 0), 1)
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

    public func analyze(samples: [Float], sampleRate: Double) -> AudioFeatures {
        samples.withUnsafeBufferPointer { buffer in
            let scalars = analyzeScalars(samples: buffer, sampleRate: sampleRate)
            let spectrum = makeSpectrum(samples: buffer, sampleRate: sampleRate, rms: scalars.rms, binCount: 64)
            return AudioFeatures(
                rms: scalars.rms,
                bass: scalars.bass,
                mid: scalars.mid,
                treble: scalars.treble,
                spectrum: spectrum
            )
        }
    }

    private func makeSpectrum(
        samples: UnsafeBufferPointer<Float>,
        sampleRate: Double,
        rms: Float,
        binCount: Int
    ) -> [Float] {
        guard let base = samples.baseAddress, samples.count > 0, sampleRate > 0, rms > 0.000_001 else {
            return Array(repeating: 0, count: binCount)
        }

        let count = min(samples.count, 4_096)
        let nyquist = sampleRate / 2.0
        var spectrum = Array<Float>(repeating: 0, count: binCount)
        for band in 0..<binCount {
            let target = nyquist * Double(band + 1) / Double(binCount)
            let mag = goertzelMagnitude(
                base: base,
                count: count,
                sampleRate: sampleRate,
                targetFrequency: target
            )
            let normalized = mag / max(rms, 0.000_001)
            spectrum[band] = min(max(normalized, 0), 1)
        }
        return spectrum
    }
}
