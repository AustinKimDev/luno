import Foundation

public enum NowPlayingColorSource: String, Codable, Equatable, Sendable, CaseIterable {
    case manual
    case albumArtwork
}

public struct NowPlayingAppearance: Codable, Equatable, Sendable {
    public enum FontWeight: String, Codable, Sendable, CaseIterable {
        case regular
        case medium
        case semibold
        case bold
        case heavy
        case black
    }

    public var cornerRadius: Double
    public var padding: Double
    public var borderWidth: Double
    public var borderOpacity: Double
    public var titleWeight: FontWeight
    public var subtitleWeight: FontWeight
    public var textColor: String
    public var accentColor: String
    public var glowTint: String
    public var colorSource: NowPlayingColorSource
    public var scaleReaction: Double
    public var glowReaction: Double
    public var borderReaction: Double

    public init(
        cornerRadius: Double = 14,
        padding: Double = 14,
        borderWidth: Double = 1,
        borderOpacity: Double = 0.08,
        titleWeight: FontWeight = .semibold,
        subtitleWeight: FontWeight = .regular,
        textColor: String = "#FFFFFF",
        accentColor: String = "#FF6B9C",
        glowTint: String = "#FFFFFF",
        colorSource: NowPlayingColorSource = .manual,
        scaleReaction: Double = 1.0,
        glowReaction: Double = 1.0,
        borderReaction: Double = 1.0
    ) {
        self.cornerRadius = Self.clampShape(cornerRadius, max: 28)
        self.padding = Self.clampShape(padding, min: 8, max: 24)
        self.borderWidth = Self.clampShape(borderWidth, max: 6)
        self.borderOpacity = Self.clampUnit(borderOpacity)
        self.titleWeight = titleWeight
        self.subtitleWeight = subtitleWeight
        self.textColor = Self.normalizedHex(textColor, fallback: "#FFFFFF")
        self.accentColor = Self.normalizedHex(accentColor, fallback: "#FF6B9C")
        self.glowTint = Self.normalizedHex(glowTint, fallback: "#FFFFFF")
        self.colorSource = colorSource
        self.scaleReaction = Self.clampUnit(scaleReaction)
        self.glowReaction = Self.clampUnit(glowReaction)
        self.borderReaction = Self.clampUnit(borderReaction)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            cornerRadius: try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 14,
            padding: try container.decodeIfPresent(Double.self, forKey: .padding) ?? 14,
            borderWidth: try container.decodeIfPresent(Double.self, forKey: .borderWidth) ?? 1,
            borderOpacity: try container.decodeIfPresent(Double.self, forKey: .borderOpacity) ?? 0.08,
            titleWeight: try container.decodeIfPresent(FontWeight.self, forKey: .titleWeight) ?? .semibold,
            subtitleWeight: try container.decodeIfPresent(FontWeight.self, forKey: .subtitleWeight) ?? .regular,
            textColor: try container.decodeIfPresent(String.self, forKey: .textColor) ?? "#FFFFFF",
            accentColor: try container.decodeIfPresent(String.self, forKey: .accentColor) ?? "#FF6B9C",
            glowTint: try container.decodeIfPresent(String.self, forKey: .glowTint) ?? "#FFFFFF",
            colorSource: try container.decodeIfPresent(NowPlayingColorSource.self, forKey: .colorSource) ?? .manual,
            scaleReaction: try container.decodeIfPresent(Double.self, forKey: .scaleReaction) ?? 1,
            glowReaction: try container.decodeIfPresent(Double.self, forKey: .glowReaction) ?? 1,
            borderReaction: try container.decodeIfPresent(Double.self, forKey: .borderReaction) ?? 1
        )
    }

    public static let `default` = NowPlayingAppearance()

    public func resolved(with albumPalette: AlbumPalette) -> NowPlayingAppearance {
        guard colorSource == .albumArtwork else { return self }
        return NowPlayingAppearance(
            cornerRadius: cornerRadius,
            padding: padding,
            borderWidth: borderWidth,
            borderOpacity: borderOpacity,
            titleWeight: titleWeight,
            subtitleWeight: subtitleWeight,
            textColor: "#FFFFFF",
            accentColor: Self.hexString(from: albumPalette.highlight),
            glowTint: Self.hexString(from: Self.mix(albumPalette.highlight, SIMD4<Float>(1, 1, 1, 1), amount: 0.5)),
            colorSource: colorSource,
            scaleReaction: scaleReaction,
            glowReaction: glowReaction,
            borderReaction: borderReaction
        )
    }

    private static func clampShape(_ value: Double, min minValue: Double = 0, max maxValue: Double) -> Double {
        guard value.isFinite else { return minValue }
        return Swift.min(Swift.max(value, minValue), maxValue)
    }

    private static func clampUnit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return Swift.min(Swift.max(value, 0), 1)
    }

    static func normalizedHex(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard stripped.count == 6, Int(stripped, radix: 16) != nil else {
            return fallback
        }
        return "#" + stripped.uppercased()
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

public struct NowPlayingAppearancePreset: Equatable, Sendable {
    public let id: String
    public let name: String
    public let appearance: NowPlayingAppearance

    public init(id: String, name: String, appearance: NowPlayingAppearance) {
        self.id = id
        self.name = name
        self.appearance = appearance
    }
}

public extension NowPlayingAppearance {
    static let presets: [NowPlayingAppearancePreset] = [
        NowPlayingAppearancePreset(id: "default", name: "Default", appearance: .default),
        NowPlayingAppearancePreset(
            id: "vivid",
            name: "Vivid",
            appearance: NowPlayingAppearance(
                cornerRadius: 18,
                padding: 14,
                borderWidth: 2,
                borderOpacity: 0.20,
                titleWeight: .bold,
                subtitleWeight: .medium,
                textColor: "#FFFFFF",
                accentColor: "#FF3D81",
                glowTint: "#FF6B9C"
            )
        ),
        NowPlayingAppearancePreset(
            id: "minimal",
            name: "Minimal",
            appearance: NowPlayingAppearance(
                cornerRadius: 8,
                padding: 12,
                borderWidth: 0,
                borderOpacity: 0.00,
                titleWeight: .regular,
                subtitleWeight: .regular,
                textColor: "#FFFFFF",
                accentColor: "#FFFFFF",
                glowTint: "#FFFFFF"
            )
        ),
        NowPlayingAppearancePreset(
            id: "neon",
            name: "Neon",
            appearance: NowPlayingAppearance(
                cornerRadius: 22,
                padding: 14,
                borderWidth: 2,
                borderOpacity: 0.35,
                titleWeight: .bold,
                subtitleWeight: .medium,
                textColor: "#FFFFFF",
                accentColor: "#00F0FF",
                glowTint: "#00F0FF"
            )
        ),
        NowPlayingAppearancePreset(
            id: "mono",
            name: "Mono",
            appearance: NowPlayingAppearance(
                cornerRadius: 4,
                padding: 14,
                borderWidth: 1,
                borderOpacity: 0.15,
                titleWeight: .medium,
                subtitleWeight: .regular,
                textColor: "#FFFFFF",
                accentColor: "#FFFFFF",
                glowTint: "#FFFFFF"
            )
        )
    ]

    /// Returns the preset whose appearance equals this one, or nil if the value has diverged.
    func matchingPreset() -> NowPlayingAppearancePreset? {
        Self.presets.first { $0.appearance == self }
    }
}
