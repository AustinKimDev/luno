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

public enum AudioReactorVisualizerLayout: String, Codable, Equatable, Sendable, CaseIterable {
    case bottom
    case circle
    case arc
}

public enum AudioReactorStylePresetID: String, Codable, Equatable, Sendable, CaseIterable {
    case studio
    case orbit
    case club
    case minimal
    case ambient
    case mono
}

public struct AudioReactorStylePreset: Equatable, Sendable {
    public let id: String
    public let name: String
    public let style: AudioReactorStyle
}

public enum AudioReactorPaletteSource: String, Codable, Equatable, Sendable, CaseIterable {
    case manual
    case albumArtwork
}

public enum AudioReactorAlbumColorMode: String, Codable, Equatable, Sendable, CaseIterable {
    case match
    case contrast
    case vivid
}

public struct AudioReactorPalette: Codable, Equatable, Sendable {
    public var source: AudioReactorPaletteSource
    public var albumColorMode: AudioReactorAlbumColorMode
    public var primaryColor: String
    public var secondaryColor: String
    public var accentColor: String
    public var glowColor: String

    public init(
        source: AudioReactorPaletteSource = .manual,
        albumColorMode: AudioReactorAlbumColorMode = .contrast,
        primaryColor: String,
        secondaryColor: String,
        accentColor: String,
        glowColor: String
    ) {
        self.source = source
        self.albumColorMode = albumColorMode
        self.primaryColor = Self.normalizedHex(primaryColor) ?? Self.default.primaryColor
        self.secondaryColor = Self.normalizedHex(secondaryColor) ?? Self.default.secondaryColor
        self.accentColor = Self.normalizedHex(accentColor) ?? Self.default.accentColor
        self.glowColor = Self.normalizedHex(glowColor) ?? Self.default.glowColor
    }

    public static let `default` = AudioReactorPalette(
        uncheckedPrimaryColor: "#24C7FF",
        secondaryColor: "#FF6B9C",
        accentColor: "#7A5CFF",
        glowColor: "#FFFFFF"
    )

    private init(
        source: AudioReactorPaletteSource = .manual,
        albumColorMode: AudioReactorAlbumColorMode = .contrast,
        uncheckedPrimaryColor primaryColor: String,
        secondaryColor: String,
        accentColor: String,
        glowColor: String
    ) {
        self.source = source
        self.albumColorMode = albumColorMode
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
        self.glowColor = glowColor
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            source: try container.decodeIfPresent(AudioReactorPaletteSource.self, forKey: .source) ?? .manual,
            albumColorMode: try container.decodeIfPresent(AudioReactorAlbumColorMode.self, forKey: .albumColorMode) ?? .contrast,
            primaryColor: try container.decodeIfPresent(String.self, forKey: .primaryColor) ?? Self.default.primaryColor,
            secondaryColor: try container.decodeIfPresent(String.self, forKey: .secondaryColor) ?? Self.default.secondaryColor,
            accentColor: try container.decodeIfPresent(String.self, forKey: .accentColor) ?? Self.default.accentColor,
            glowColor: try container.decodeIfPresent(String.self, forKey: .glowColor) ?? Self.default.glowColor
        )
    }

    public func resolved(with albumPalette: AlbumPalette) -> AudioReactorPalette {
        guard source == .albumArtwork else { return self }

        let bg = Self.rgb(from: albumPalette.background)
        let albumP = Self.rgb(from: albumPalette.primary)
        let albumS = Self.rgb(from: albumPalette.secondary)
        let albumH = Self.rgb(from: albumPalette.highlight)

        switch albumColorMode {
        case .match:
            return AudioReactorPalette(
                source: source,
                albumColorMode: albumColorMode,
                primaryColor: Self.hexString(from: albumPalette.primary),
                secondaryColor: Self.hexString(from: albumPalette.secondary),
                accentColor: Self.hexString(from: albumPalette.highlight),
                glowColor: Self.hexString(from: Self.mix(albumPalette.highlight, SIMD4<Float>(1, 1, 1, 1), amount: 0.5))
            )
        case .contrast:
            let primary = AudioReactorColorMath.applyContrast(channel: albumP, role: .primary, albumBackground: bg, albumPrimary: albumP, albumSecondary: albumS)
            let secondary = AudioReactorColorMath.applyContrast(channel: albumS, role: .secondary, albumBackground: bg, albumPrimary: albumP, albumSecondary: albumS)
            let accent = AudioReactorColorMath.applyContrast(channel: albumH, role: .accent, albumBackground: bg, albumPrimary: albumP, albumSecondary: albumS)
            let glowSource = AudioReactorColorMath.RGB(
                r: (albumH.r + 1) * 0.5,
                g: (albumH.g + 1) * 0.5,
                b: (albumH.b + 1) * 0.5
            )
            let glow = AudioReactorColorMath.applyContrast(channel: glowSource, role: .glow, albumBackground: bg, albumPrimary: albumP, albumSecondary: albumS)
            return AudioReactorPalette(
                source: source,
                albumColorMode: albumColorMode,
                primaryColor: Self.hex(from: primary),
                secondaryColor: Self.hex(from: secondary),
                accentColor: Self.hex(from: accent),
                glowColor: Self.hex(from: glow)
            )
        case .vivid:
            let primary = AudioReactorColorMath.applyVivid(role: .primary, albumPrimary: albumP, albumSecondary: albumS, albumHighlight: albumH)
            let secondary = AudioReactorColorMath.applyVivid(role: .secondary, albumPrimary: albumP, albumSecondary: albumS, albumHighlight: albumH)
            let accent = AudioReactorColorMath.applyVivid(role: .accent, albumPrimary: albumP, albumSecondary: albumS, albumHighlight: albumH)
            let glow = AudioReactorColorMath.applyVivid(role: .glow, albumPrimary: albumP, albumSecondary: albumS, albumHighlight: albumH)
            return AudioReactorPalette(
                source: source,
                albumColorMode: albumColorMode,
                primaryColor: Self.hex(from: primary),
                secondaryColor: Self.hex(from: secondary),
                accentColor: Self.hex(from: accent),
                glowColor: Self.hex(from: glow)
            )
        }
    }

    private static func rgb(from vector: SIMD4<Float>) -> AudioReactorColorMath.RGB {
        AudioReactorColorMath.RGB(
            r: Double(min(max(vector.x, 0), 1)),
            g: Double(min(max(vector.y, 0), 1)),
            b: Double(min(max(vector.z, 0), 1))
        )
    }

    private static func hex(from rgb: AudioReactorColorMath.RGB) -> String {
        let r = UInt8(round(min(max(rgb.r, 0), 1) * 255))
        let g = UInt8(round(min(max(rgb.g, 0), 1) * 255))
        let b = UInt8(round(min(max(rgb.b, 0), 1) * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private static func normalizedHex(_ hex: String) -> String? {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#").union(.whitespacesAndNewlines))
        guard trimmed.count == 6, Int(trimmed, radix: 16) != nil else { return nil }
        return "#\(trimmed.uppercased())"
    }

    private static func hexString(from color: SIMD4<Float>) -> String {
        let red = UInt8(round(Self.clamped(color.x) * 255))
        let green = UInt8(round(Self.clamped(color.y) * 255))
        let blue = UInt8(round(Self.clamped(color.z) * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private static func clamped(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    private static func mix(_ start: SIMD4<Float>, _ end: SIMD4<Float>, amount: Float) -> SIMD4<Float> {
        let t = clamped(amount)
        return start + (end - start) * t
    }
}

public struct AudioReactorSpectrumStyle: Codable, Equatable, Sendable {
    public var layout: AudioReactorVisualizerLayout
    public var barCount: Int
    public var barWidth: Double
    public var barHeight: Double
    public var spacing: Double
    public var radius: Double
    public var roundness: Double
    public var smoothing: Double
    public var glow: Double
    public var arcStartDegrees: Double
    public var arcEndDegrees: Double

    public init(
        layout: AudioReactorVisualizerLayout,
        barCount: Int,
        barWidth: Double,
        barHeight: Double,
        spacing: Double,
        radius: Double,
        roundness: Double,
        smoothing: Double,
        glow: Double,
        arcStartDegrees: Double,
        arcEndDegrees: Double
    ) {
        self.layout = layout
        self.barCount = Self.clamp(barCount, min: 8, max: 96)
        self.barWidth = Self.clamp01(barWidth)
        self.barHeight = Self.clamp01(barHeight)
        self.spacing = Self.clamp01(spacing)
        self.radius = Self.clamp01(radius)
        self.roundness = Self.clamp01(roundness)
        self.smoothing = Self.clamp01(smoothing)
        self.glow = Self.clamp01(glow)
        self.arcStartDegrees = Self.clampAngle(arcStartDegrees)
        self.arcEndDegrees = Self.clampAngle(arcEndDegrees)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            layout: try container.decodeIfPresent(AudioReactorVisualizerLayout.self, forKey: .layout) ?? .bottom,
            barCount: try container.decodeIfPresent(Int.self, forKey: .barCount) ?? 48,
            barWidth: try container.decodeIfPresent(Double.self, forKey: .barWidth) ?? 0.48,
            barHeight: try container.decodeIfPresent(Double.self, forKey: .barHeight) ?? 0.74,
            spacing: try container.decodeIfPresent(Double.self, forKey: .spacing) ?? 0.35,
            radius: try container.decodeIfPresent(Double.self, forKey: .radius) ?? 0.56,
            roundness: try container.decodeIfPresent(Double.self, forKey: .roundness) ?? 0.82,
            smoothing: try container.decodeIfPresent(Double.self, forKey: .smoothing) ?? 0.45,
            glow: try container.decodeIfPresent(Double.self, forKey: .glow) ?? 0.48,
            arcStartDegrees: try container.decodeIfPresent(Double.self, forKey: .arcStartDegrees) ?? -150,
            arcEndDegrees: try container.decodeIfPresent(Double.self, forKey: .arcEndDegrees) ?? 150
        )
    }

    public static let `default` = AudioReactorStyle.default.spectrum

    fileprivate static func clamp01(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    fileprivate static func clamp(_ value: Int, min minimum: Int, max maximum: Int) -> Int {
        Swift.min(Swift.max(value, minimum), maximum)
    }

    fileprivate static func clampAngle(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, -180), 180)
    }
}

public struct AudioReactorRingStyle: Codable, Equatable, Sendable {
    public var radius: Double
    public var thickness: Double
    public var softness: Double
    public var glow: Double
    public var roundness: Double

    public init(radius: Double, thickness: Double, softness: Double, glow: Double, roundness: Double) {
        self.radius = AudioReactorSpectrumStyle.clamp01(radius)
        self.thickness = min(max(AudioReactorSpectrumStyle.clamp01(thickness), 0), 0.08)
        self.softness = AudioReactorSpectrumStyle.clamp01(softness)
        self.glow = AudioReactorSpectrumStyle.clamp01(glow)
        self.roundness = AudioReactorSpectrumStyle.clamp01(roundness)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            radius: try container.decodeIfPresent(Double.self, forKey: .radius) ?? 0.36,
            thickness: try container.decodeIfPresent(Double.self, forKey: .thickness) ?? 0.018,
            softness: try container.decodeIfPresent(Double.self, forKey: .softness) ?? 0.55,
            glow: try container.decodeIfPresent(Double.self, forKey: .glow) ?? 0.62,
            roundness: try container.decodeIfPresent(Double.self, forKey: .roundness) ?? 0.9
        )
    }

    public static let `default` = AudioReactorStyle.default.ring
}

public struct AudioReactorWaveStyle: Codable, Equatable, Sendable {
    public var layout: AudioReactorVisualizerLayout
    public var thickness: Double
    public var amplitude: Double
    public var smoothing: Double
    public var glow: Double
    public var radius: Double
    public var arcStartDegrees: Double
    public var arcEndDegrees: Double

    public init(
        layout: AudioReactorVisualizerLayout,
        thickness: Double,
        amplitude: Double,
        smoothing: Double,
        glow: Double,
        radius: Double,
        arcStartDegrees: Double,
        arcEndDegrees: Double
    ) {
        self.layout = layout
        self.thickness = min(max(AudioReactorSpectrumStyle.clamp01(thickness), 0), 0.08)
        self.amplitude = AudioReactorSpectrumStyle.clamp01(amplitude)
        self.smoothing = AudioReactorSpectrumStyle.clamp01(smoothing)
        self.glow = AudioReactorSpectrumStyle.clamp01(glow)
        self.radius = AudioReactorSpectrumStyle.clamp01(radius)
        self.arcStartDegrees = AudioReactorSpectrumStyle.clampAngle(arcStartDegrees)
        self.arcEndDegrees = AudioReactorSpectrumStyle.clampAngle(arcEndDegrees)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            layout: try container.decodeIfPresent(AudioReactorVisualizerLayout.self, forKey: .layout) ?? .bottom,
            thickness: try container.decodeIfPresent(Double.self, forKey: .thickness) ?? 0.012,
            amplitude: try container.decodeIfPresent(Double.self, forKey: .amplitude) ?? 0.55,
            smoothing: try container.decodeIfPresent(Double.self, forKey: .smoothing) ?? 0.6,
            glow: try container.decodeIfPresent(Double.self, forKey: .glow) ?? 0.42,
            radius: try container.decodeIfPresent(Double.self, forKey: .radius) ?? 0.58,
            arcStartDegrees: try container.decodeIfPresent(Double.self, forKey: .arcStartDegrees) ?? -150,
            arcEndDegrees: try container.decodeIfPresent(Double.self, forKey: .arcEndDegrees) ?? 150
        )
    }

    public static let `default` = AudioReactorStyle.default.wave
}

public struct AudioReactorStyle: Codable, Equatable, Sendable {
    public var presetID: String?
    public var palette: AudioReactorPalette
    public var spectrum: AudioReactorSpectrumStyle
    public var ring: AudioReactorRingStyle
    public var wave: AudioReactorWaveStyle
    public var scale: Double {
        didSet {
            scale = Self.clampScale(scale)
        }
    }

    public init(
        presetID: String?,
        palette: AudioReactorPalette,
        spectrum: AudioReactorSpectrumStyle,
        ring: AudioReactorRingStyle,
        wave: AudioReactorWaveStyle,
        scale: Double = 1.0
    ) {
        self.presetID = presetID
        self.palette = palette
        self.spectrum = spectrum
        self.ring = ring
        self.wave = wave
        self.scale = Self.clampScale(scale)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            presetID: try container.decodeIfPresent(String.self, forKey: .presetID),
            palette: try container.decodeIfPresent(AudioReactorPalette.self, forKey: .palette) ?? .default,
            spectrum: try container.decodeIfPresent(AudioReactorSpectrumStyle.self, forKey: .spectrum) ?? Self.default.spectrum,
            ring: try container.decodeIfPresent(AudioReactorRingStyle.self, forKey: .ring) ?? Self.default.ring,
            wave: try container.decodeIfPresent(AudioReactorWaveStyle.self, forKey: .wave) ?? Self.default.wave,
            scale: try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1.0
        )
    }

    public static func clampScale(_ value: Double) -> Double {
        guard value.isFinite else { return 1 }
        return min(max(value, 0.5), 1.5)
    }

    public static let `default` = preset(.studio)

    public static func preset(_ id: AudioReactorStylePresetID) -> AudioReactorStyle {
        switch id {
        case .studio:
            return AudioReactorStyle(
                presetID: id.rawValue,
                palette: .default,
                spectrum: AudioReactorSpectrumStyle(
                    layout: .bottom,
                    barCount: 48,
                    barWidth: 0.48,
                    barHeight: 0.74,
                    spacing: 0.35,
                    radius: 0.56,
                    roundness: 0.82,
                    smoothing: 0.45,
                    glow: 0.48,
                    arcStartDegrees: -150,
                    arcEndDegrees: 150
                ),
                ring: AudioReactorRingStyle(radius: 0.36, thickness: 0.018, softness: 0.55, glow: 0.62, roundness: 0.9),
                wave: AudioReactorWaveStyle(layout: .bottom, thickness: 0.012, amplitude: 0.55, smoothing: 0.6, glow: 0.42, radius: 0.58, arcStartDegrees: -150, arcEndDegrees: 150)
            )
        case .orbit:
            return AudioReactorStyle(
                presetID: id.rawValue,
                palette: AudioReactorPalette(primaryColor: "#7BE7FF", secondaryColor: "#A78BFA", accentColor: "#FF8BD1", glowColor: "#DFFBFF"),
                spectrum: AudioReactorSpectrumStyle(layout: .arc, barCount: 64, barWidth: 0.44, barHeight: 0.62, spacing: 0.42, radius: 0.58, roundness: 0.88, smoothing: 0.55, glow: 0.62, arcStartDegrees: -155, arcEndDegrees: 155),
                ring: AudioReactorRingStyle(radius: 0.4, thickness: 0.014, softness: 0.72, glow: 0.72, roundness: 1),
                wave: AudioReactorWaveStyle(layout: .arc, thickness: 0.01, amplitude: 0.5, smoothing: 0.72, glow: 0.5, radius: 0.5, arcStartDegrees: -150, arcEndDegrees: 150)
            )
        case .club:
            return AudioReactorStyle(
                presetID: id.rawValue,
                palette: AudioReactorPalette(primaryColor: "#00F0FF", secondaryColor: "#FF2D95", accentColor: "#FFE66D", glowColor: "#FFFFFF"),
                spectrum: AudioReactorSpectrumStyle(layout: .circle, barCount: 72, barWidth: 0.55, barHeight: 0.86, spacing: 0.28, radius: 0.5, roundness: 0.62, smoothing: 0.25, glow: 0.9, arcStartDegrees: -180, arcEndDegrees: 180),
                ring: AudioReactorRingStyle(radius: 0.34, thickness: 0.026, softness: 0.42, glow: 0.92, roundness: 0.72),
                wave: AudioReactorWaveStyle(layout: .circle, thickness: 0.015, amplitude: 0.75, smoothing: 0.35, glow: 0.75, radius: 0.46, arcStartDegrees: -180, arcEndDegrees: 180)
            )
        case .minimal:
            return AudioReactorStyle(
                presetID: id.rawValue,
                palette: AudioReactorPalette(primaryColor: "#FFFFFF", secondaryColor: "#B8C1CC", accentColor: "#7A8491", glowColor: "#FFFFFF"),
                spectrum: AudioReactorSpectrumStyle(layout: .bottom, barCount: 40, barWidth: 0.32, barHeight: 0.42, spacing: 0.55, radius: 0.46, roundness: 1, smoothing: 0.72, glow: 0.18, arcStartDegrees: -120, arcEndDegrees: 120),
                ring: AudioReactorRingStyle(radius: 0.3, thickness: 0.01, softness: 0.78, glow: 0.25, roundness: 1),
                wave: AudioReactorWaveStyle(layout: .bottom, thickness: 0.006, amplitude: 0.32, smoothing: 0.78, glow: 0.12, radius: 0.52, arcStartDegrees: -120, arcEndDegrees: 120)
            )
        case .ambient:
            return AudioReactorStyle(
                presetID: id.rawValue,
                palette: AudioReactorPalette(primaryColor: "#8EE6A8", secondaryColor: "#6BD8FF", accentColor: "#E6D7A8", glowColor: "#EFFFF3"),
                spectrum: AudioReactorSpectrumStyle(layout: .arc, barCount: 56, barWidth: 0.38, barHeight: 0.48, spacing: 0.5, radius: 0.62, roundness: 1, smoothing: 0.82, glow: 0.36, arcStartDegrees: -130, arcEndDegrees: 130),
                ring: AudioReactorRingStyle(radius: 0.42, thickness: 0.012, softness: 0.86, glow: 0.5, roundness: 1),
                wave: AudioReactorWaveStyle(layout: .arc, thickness: 0.007, amplitude: 0.38, smoothing: 0.9, glow: 0.34, radius: 0.6, arcStartDegrees: -135, arcEndDegrees: 135)
            )
        case .mono:
            return AudioReactorStyle(
                presetID: id.rawValue,
                palette: AudioReactorPalette(primaryColor: "#F5F7FA", secondaryColor: "#AEB7C2", accentColor: "#6F7782", glowColor: "#FFFFFF"),
                spectrum: AudioReactorSpectrumStyle(layout: .bottom, barCount: 52, barWidth: 0.42, barHeight: 0.56, spacing: 0.44, radius: 0.5, roundness: 0.7, smoothing: 0.62, glow: 0.28, arcStartDegrees: -145, arcEndDegrees: 145),
                ring: AudioReactorRingStyle(radius: 0.36, thickness: 0.012, softness: 0.7, glow: 0.34, roundness: 0.86),
                wave: AudioReactorWaveStyle(layout: .bottom, thickness: 0.008, amplitude: 0.42, smoothing: 0.7, glow: 0.25, radius: 0.56, arcStartDegrees: -145, arcEndDegrees: 145)
            )
        }
    }

    public static let presets: [AudioReactorStylePreset] = AudioReactorStylePresetID.allCases.map { id in
        AudioReactorStylePreset(id: id.rawValue, name: id.displayName, style: preset(id))
    }
}

public struct AudioReactorOverlayLayoutMetrics: Equatable, Sendable {
    public var scale: Float
    public var bottomRailStart: Float
    public var bottomRailWidth: Float
    public var bottomBaseY: Float
    public var radialScale: Float
    public var centerY: Float

    public static func make(resolution: SIMD2<Float>, scale: Double) -> AudioReactorOverlayLayoutMetrics {
        let width = max(resolution.x, 1)
        let height = max(resolution.y, 1)
        let aspect = min(max(width / height, 0.1), 4)
        let portraitAmount = min(max((1 - aspect) / 0.45, 0), 1)
        let safeScale = Float(AudioReactorStyle.clampScale(scale))
        let portraitWidthCompression = 1 - portraitAmount * 0.18
        let railWidth = min(max(0.85 * portraitWidthCompression * safeScale, 0.52), 0.9)
        let radialScale = min(max((1 - portraitAmount * 0.24) * safeScale, 0.45), 1.35)

        return AudioReactorOverlayLayoutMetrics(
            scale: safeScale,
            bottomRailStart: (1 - railWidth) * 0.5,
            bottomRailWidth: railWidth,
            bottomBaseY: 0.058 + portraitAmount * 0.045 + max(safeScale - 1, 0) * 0.012,
            radialScale: radialScale,
            centerY: 0.53 + portraitAmount * 0.035
        )
    }
}

private extension AudioReactorStylePresetID {
    var displayName: String {
        switch self {
        case .studio: "Studio"
        case .orbit: "Orbit"
        case .club: "Club"
        case .minimal: "Minimal"
        case .ambient: "Ambient"
        case .mono: "Mono"
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
    public var style: AudioReactorStyle

    public init(
        isEnabled: Bool,
        intensity: Double,
        response: AudioReactorResponse,
        bassPulseStrength: Double,
        showsPulseRing: Bool,
        showsSpectrumBars: Bool,
        showsWaveLine: Bool,
        overlayOpacity: Double,
        style: AudioReactorStyle = .default
    ) {
        self.isEnabled = isEnabled
        self.intensity = intensity
        self.response = response
        self.bassPulseStrength = bassPulseStrength
        self.showsPulseRing = showsPulseRing
        self.showsSpectrumBars = showsSpectrumBars
        self.showsWaveLine = showsWaveLine
        self.overlayOpacity = overlayOpacity
        self.style = style
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isEnabled: try container.decode(Bool.self, forKey: .isEnabled),
            intensity: try container.decode(Double.self, forKey: .intensity),
            response: try container.decode(AudioReactorResponse.self, forKey: .response),
            bassPulseStrength: try container.decode(Double.self, forKey: .bassPulseStrength),
            showsPulseRing: try container.decode(Bool.self, forKey: .showsPulseRing),
            showsSpectrumBars: try container.decode(Bool.self, forKey: .showsSpectrumBars),
            showsWaveLine: try container.decode(Bool.self, forKey: .showsWaveLine),
            overlayOpacity: try container.decode(Double.self, forKey: .overlayOpacity),
            style: try container.decodeIfPresent(AudioReactorStyle.self, forKey: .style) ?? .default
        )
    }

    public static let defaults = AudioReactorPreferences(
        isEnabled: true,
        intensity: 0.8,
        response: .punchy,
        bassPulseStrength: 0.75,
        showsPulseRing: true,
        showsSpectrumBars: true,
        showsWaveLine: false,
        overlayOpacity: 0.6,
        style: .default
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

    func downsampleSpectrum(_ spectrum: [Float], count: Int) -> [Float] {
        guard count > 0 else { return [] }
        var output = Array(repeating: Float(0), count: count)
        writeDownsampledSpectrum(spectrum, into: &output)
        return output
    }

    func writeDownsampledSpectrum(_ spectrum: [Float], into output: inout [Float]) {
        Self.writeDownsampledSpectrum(spectrum, into: &output, transform: shaped)
    }

    private static func writeDownsampledSpectrum(
        _ spectrum: [Float],
        into output: inout [Float],
        transform: (Float) -> Float
    ) {
        guard !output.isEmpty else { return }
        guard !spectrum.isEmpty else {
            for index in output.indices {
                output[index] = 0
            }
            return
        }

        for index in output.indices {
            let start = index * spectrum.count / output.count
            let end = max(start + 1, (index + 1) * spectrum.count / output.count)
            let clampedEnd = min(end, spectrum.count)
            var total: Float = 0
            for spectrumIndex in start..<clampedEnd {
                total += transform(spectrum[spectrumIndex])
            }
            output[index] = total / Float(clampedEnd - start)
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
