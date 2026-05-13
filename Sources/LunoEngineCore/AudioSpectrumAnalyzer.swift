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
}

public struct AudioSpectrumAnalyzer: Sendable {
    public init() {}

    public func analyze(samples: [Float], sampleRate: Double) -> AudioFeatures {
        guard !samples.isEmpty, sampleRate > 0 else {
            return .silent
        }

        let maxSampleCount = min(samples.count, 4_096)
        let window = Array(samples.prefix(maxSampleCount))
        let rms = rootMeanSquare(window)
        let nyquist = sampleRate / 2.0
        let binCount = 64

        var spectrum: [Float] = []
        spectrum.reserveCapacity(binCount)

        for band in 0..<binCount {
            let targetFrequency = nyquist * Double(band + 1) / Double(binCount)
            spectrum.append(normalizedMagnitude(
                samples: window,
                sampleRate: sampleRate,
                targetFrequency: targetFrequency,
                rms: rms
            ))
        }

        return AudioFeatures(
            rms: rms,
            bass: averageSpectrum(spectrum, sampleRate: sampleRate, range: 20...250),
            mid: averageSpectrum(spectrum, sampleRate: sampleRate, range: 250...4_000),
            treble: averageSpectrum(spectrum, sampleRate: sampleRate, range: 4_000...20_000),
            spectrum: spectrum
        )
    }

    private func rootMeanSquare(_ samples: [Float]) -> Float {
        let sum = samples.reduce(Float(0)) { partial, sample in
            partial + sample * sample
        }
        return sqrt(sum / Float(samples.count))
    }

    private func normalizedMagnitude(
        samples: [Float],
        sampleRate: Double,
        targetFrequency: Double,
        rms: Float
    ) -> Float {
        let n = samples.count
        guard n > 0 else { return 0 }

        var real = 0.0
        var imaginary = 0.0
        let angularStep = 2.0 * Double.pi * targetFrequency / sampleRate

        for (index, sample) in samples.enumerated() {
            let phase = angularStep * Double(index)
            let value = Double(sample)
            real += value * cos(phase)
            imaginary -= value * sin(phase)
        }

        let magnitude = sqrt(real * real + imaginary * imaginary) * 2.0 / Double(n)
        let normalized = magnitude / max(Double(rms), 0.000_001)
        return Float(min(max(normalized, 0), 1))
    }

    private func averageSpectrum(_ spectrum: [Float], sampleRate: Double, range: ClosedRange<Double>) -> Float {
        guard !spectrum.isEmpty else { return 0 }

        let nyquist = sampleRate / 2.0
        var values: [Float] = []

        for (index, value) in spectrum.enumerated() {
            let frequency = nyquist * Double(index + 1) / Double(spectrum.count)
            if range.contains(frequency) {
                values.append(value)
            }
        }

        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Float(values.count)
    }
}
