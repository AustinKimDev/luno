import Foundation

public enum AudioReactorResponse: String, Codable, Equatable, Sendable, CaseIterable {
    case soft
    case punchy
    case hard

    var gain: Float {
        switch self {
        case .soft: 0.7
        case .punchy: 1.0
        case .hard: 1.35
        }
    }

    var exponent: Float {
        switch self {
        case .soft: 1.25
        case .punchy: 0.85
        case .hard: 0.62
        }
    }
}

public struct AudioReactorPreferences: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var intensity: Double
    public var response: AudioReactorResponse
    public var bassPulseStrength: Double
    public var showsPulseRing: Bool
    public var showsSpectrumBars: Bool
    public var showsWaveLine: Bool
    public var overlayOpacity: Double

    public init(
        isEnabled: Bool,
        intensity: Double,
        response: AudioReactorResponse,
        bassPulseStrength: Double,
        showsPulseRing: Bool,
        showsSpectrumBars: Bool,
        showsWaveLine: Bool,
        overlayOpacity: Double
    ) {
        self.isEnabled = isEnabled
        self.intensity = intensity
        self.response = response
        self.bassPulseStrength = bassPulseStrength
        self.showsPulseRing = showsPulseRing
        self.showsSpectrumBars = showsSpectrumBars
        self.showsWaveLine = showsWaveLine
        self.overlayOpacity = overlayOpacity
    }

    public static let defaults = AudioReactorPreferences(
        isEnabled: true,
        intensity: 0.8,
        response: .punchy,
        bassPulseStrength: 0.75,
        showsPulseRing: true,
        showsSpectrumBars: true,
        showsWaveLine: false,
        overlayOpacity: 0.6
    )

    public func shaped(_ features: AudioFeatures) -> AudioFeatures {
        guard isEnabled else { return .silent }

        return AudioFeatures(
            rms: shaped(features.rms),
            bass: shaped(features.bass),
            mid: shaped(features.mid),
            treble: shaped(features.treble),
            spectrum: features.spectrum.map(shaped)
        )
    }

    public func shaped(_ value: Float) -> Float {
        let clamped = Self.clamp(value)
        let gain = Float(Self.clamp(intensity)) * response.gain
        let shaped = pow(clamped, response.exponent) * gain
        return Self.clamp(shaped)
    }

    public static func downsampleSpectrum(_ spectrum: [Float], count: Int) -> [Float] {
        guard count > 0 else { return [] }
        guard !spectrum.isEmpty else { return Array(repeating: 0, count: count) }

        return (0..<count).map { index in
            let start = index * spectrum.count / count
            let end = max(start + 1, (index + 1) * spectrum.count / count)
            let bucket = spectrum[start..<min(end, spectrum.count)]
            let total = bucket.reduce(Float(0)) { $0 + clamp($1) }
            return total / Float(bucket.count)
        }
    }

    public static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    public static func clamp(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}

public struct AudioReactorPreferencesStore: Sendable {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> AudioReactorPreferences {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .defaults
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(AudioReactorPreferences.self, from: data)
    }

    public func save(_ preferences: AudioReactorPreferences) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(preferences)
        try data.write(to: fileURL, options: .atomic)
    }
}
