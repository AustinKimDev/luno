import Foundation

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
        self.scaleReaction = Self.clampUnit(scaleReaction)
        self.glowReaction = Self.clampUnit(glowReaction)
        self.borderReaction = Self.clampUnit(borderReaction)
    }

    public static let `default` = NowPlayingAppearance()

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
}
