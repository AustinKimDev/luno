import Accelerate
import Foundation

public struct AudioFeatures: Codable, Equatable, Sendable {
    public static let spectrumBinCount = 96

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
        spectrum: Array(repeating: 0, count: spectrumBinCount)
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

private final class FFTSetupCache: @unchecked Sendable {
    let size: Int
    let log2Size: vDSP_Length
    let setup: FFTSetup
    let window: [Float]
    let windowSum: Float

    init?(size: Int) {
        let log2Size = vDSP_Length(log2(Double(size)))
        guard let setup = vDSP_create_fftsetup(log2Size, FFTRadix(kFFTRadix2)) else {
            return nil
        }
        var window = Array<Float>(repeating: 0, count: size)
        vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))
        self.size = size
        self.log2Size = log2Size
        self.setup = setup
        self.window = window
        self.windowSum = max(window.reduce(Float(0), +), 0.000_001)
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
    }
}

public struct AudioSpectrumAnalyzer: Sendable {
    public static let analysisSampleCount = 8_192
    private static let cachedFFTSetup = FFTSetupCache(size: analysisSampleCount)

    public init() {}

    public func analyzeScalars(
        samples: UnsafeBufferPointer<Float>,
        sampleRate: Double
    ) -> AudioScalars {
        guard let base = samples.baseAddress, samples.count > 0, sampleRate > 0 else {
            return .silent
        }

        let count = min(samples.count, Self.analysisSampleCount)

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

    public func analyzeFeatures(
        samples: UnsafeBufferPointer<Float>,
        sampleRate: Double
    ) -> AudioFeatures {
        let scalars = analyzeScalars(samples: samples, sampleRate: sampleRate)
        let spectrum = makeSpectrum(
            samples: samples,
            sampleRate: sampleRate,
            rms: scalars.rms,
            binCount: AudioFeatures.spectrumBinCount
        )
        return AudioFeatures(
            rms: scalars.rms,
            bass: scalars.bass,
            mid: scalars.mid,
            treble: scalars.treble,
            spectrum: spectrum
        )
    }

    public func analyze(samples: [Float], sampleRate: Double) -> AudioFeatures {
        samples.withUnsafeBufferPointer { buffer in
            analyzeFeatures(samples: buffer, sampleRate: sampleRate)
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

        let fftSize = min(samples.count, Self.analysisSampleCount)
        let magnitudes = fftMagnitudes(base: base, count: fftSize)
        guard !magnitudes.isEmpty else {
            return Array(repeating: 0, count: binCount)
        }
        let nyquist = sampleRate / 2.0
        var spectrum = Array<Float>(repeating: 0, count: binCount)
        for band in 0..<binCount {
            let range = spectrumBandRange(
                band: band,
                binCount: binCount,
                nyquist: nyquist
            )
            let mag = spectrumBandMagnitude(
                magnitudes: magnitudes,
                sampleRate: sampleRate,
                lowerFrequency: range.lower,
                centerFrequency: range.center,
                upperFrequency: range.upper
            )
            let normalized = mag
            spectrum[band] = min(max(normalized, 0), 1)
        }
        return spectrum
    }

    private func fftMagnitudes(base: UnsafePointer<Float>, count: Int) -> [Float] {
        guard count >= 2 else { return [] }

        let fftSize = 1 << Int(floor(log2(Double(count))))
        let halfSize = fftSize / 2
        let setupCache = fftSize == Self.cachedFFTSetup?.size
            ? Self.cachedFFTSetup
            : FFTSetupCache(size: fftSize)
        guard let setupCache else { return [] }

        var windowed = Array<Float>(repeating: 0, count: fftSize)
        vDSP_vmul(base, 1, setupCache.window, 1, &windowed, 1, vDSP_Length(fftSize))

        var real = Array<Float>(repeating: 0, count: halfSize)
        var imaginary = Array<Float>(repeating: 0, count: halfSize)

        windowed.withUnsafeBufferPointer { inputBuffer in
            inputBuffer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexBuffer in
                real.withUnsafeMutableBufferPointer { realBuffer in
                    imaginary.withUnsafeMutableBufferPointer { imaginaryBuffer in
                        var split = DSPSplitComplex(
                            realp: realBuffer.baseAddress!,
                            imagp: imaginaryBuffer.baseAddress!
                        )
                        vDSP_ctoz(complexBuffer, 2, &split, 1, vDSP_Length(halfSize))
                        vDSP_fft_zrip(
                            setupCache.setup,
                            &split,
                            1,
                            setupCache.log2Size,
                            FFTDirection(FFT_FORWARD)
                        )
                    }
                }
            }
        }

        var magnitudes = Array<Float>(repeating: 0, count: halfSize)
        let amplitudeScale = 2.0 / setupCache.windowSum
        magnitudes[0] = abs(real[0]) * amplitudeScale
        if halfSize > 1 {
            for index in 1..<halfSize {
                magnitudes[index] = hypot(real[index], imaginary[index]) * amplitudeScale
            }
        }
        return magnitudes
    }

    private func spectrumBandRange(
        band: Int,
        binCount: Int,
        nyquist: Double
    ) -> (lower: Double, center: Double, upper: Double) {
        let minimumFrequency = 20.0
        let maximumFrequency = min(20_000.0, nyquist * 0.95)
        guard binCount > 1, maximumFrequency > minimumFrequency else {
            let frequency = min(maximumFrequency, nyquist)
            return (frequency, frequency, frequency)
        }

        let centerPosition = (Double(band) + 0.5) / Double(binCount)
        let lowerPosition = max(0, (Double(band) - 0.5) / Double(binCount))
        let upperPosition = min(1, (Double(band) + 1.5) / Double(binCount))
        let ratio = maximumFrequency / minimumFrequency
        return (
            minimumFrequency * pow(ratio, lowerPosition),
            minimumFrequency * pow(ratio, centerPosition),
            minimumFrequency * pow(ratio, upperPosition)
        )
    }

    private func spectrumBandMagnitude(
        magnitudes: [Float],
        sampleRate: Double,
        lowerFrequency: Double,
        centerFrequency: Double,
        upperFrequency: Double
    ) -> Float {
        guard !magnitudes.isEmpty, sampleRate > 0 else { return 0 }

        let binFrequency = sampleRate / Double(magnitudes.count * 2)
        let startIndex = max(1, Int(floor(lowerFrequency / binFrequency)))
        let endIndex = min(magnitudes.count - 1, Int(ceil(upperFrequency / binFrequency)))
        guard startIndex <= endIndex else { return 0 }

        let lowerLog = log2(max(lowerFrequency, 1))
        let centerLog = log2(max(centerFrequency, lowerFrequency + 0.001))
        let upperLog = log2(max(upperFrequency, centerFrequency + 0.001))
        var weightedPower: Float = 0
        var weightTotal: Float = 0
        for index in startIndex...endIndex {
            let frequency = Double(index) * binFrequency
            let frequencyLog = log2(max(frequency, 1))
            let weight: Double
            if frequencyLog <= centerLog {
                weight = (frequencyLog - lowerLog) / max(centerLog - lowerLog, 0.000_001)
            } else {
                weight = (upperLog - frequencyLog) / max(upperLog - centerLog, 0.000_001)
            }
            let clampedWeight = Float(min(max(weight, 0), 1))
            let magnitude = magnitudes[index]
            weightedPower += magnitude * magnitude * clampedWeight
            weightTotal += clampedWeight
        }
        guard weightTotal > 0 else { return 0 }
        return (weightedPower / max(weightTotal, 1)).squareRoot() * 3.0
    }
}
