import Foundation

public struct AlbumPalette: Equatable, Sendable {
    public var background: SIMD4<Float>
    public var primary: SIMD4<Float>
    public var secondary: SIMD4<Float>
    public var highlight: SIMD4<Float>

    public init(
        background: SIMD4<Float>,
        primary: SIMD4<Float>,
        secondary: SIMD4<Float>,
        highlight: SIMD4<Float>
    ) {
        self.background = background
        self.primary = primary
        self.secondary = secondary
        self.highlight = highlight
    }

    public static let fallback = AlbumPalette(
        background: SIMD4<Float>(0.025, 0.032, 0.055, 1),
        primary: SIMD4<Float>(0.92, 0.32, 0.42, 1),
        secondary: SIMD4<Float>(0.12, 0.55, 0.94, 1),
        highlight: SIMD4<Float>(1.0, 0.78, 0.42, 1)
    )

    public func interpolated(toward target: AlbumPalette, amount: Float) -> AlbumPalette {
        let t = max(0, min(1, amount))
        return AlbumPalette(
            background: background + (target.background - background) * t,
            primary: primary + (target.primary - primary) * t,
            secondary: secondary + (target.secondary - secondary) * t,
            highlight: highlight + (target.highlight - highlight) * t
        )
    }
}

public enum AlbumPaletteExtractor {
    public struct Sample: Equatable, Sendable {
        public var red: UInt8
        public var green: UInt8
        public var blue: UInt8
        public var alpha: UInt8

        public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }
    }

    public static func extract(from samples: [Sample]) -> AlbumPalette {
        var buckets: [Int: Bucket] = [:]

        for sample in samples where sample.alpha > 8 {
            let color = Color(sample)
            guard color.luma < 0.96 else { continue }

            let key = (Int(sample.red) / 24) << 16
                | (Int(sample.green) / 24) << 8
                | (Int(sample.blue) / 24)
            buckets[key, default: Bucket()].add(color)
        }

        let candidates = buckets.values
            .map(\.representative)
            .filter { $0.alpha > 0.03 }

        guard !candidates.isEmpty else { return .fallback }

        let background = candidates.max { lhs, rhs in
            lhs.backgroundScore < rhs.backgroundScore
        } ?? Color(AlbumPalette.fallback.background)

        let accents = candidates
            .filter { $0.saturation > 0.18 && $0.luma > 0.06 && $0.luma < 0.92 }
            .sorted { lhs, rhs in
                lhs.accentScore > rhs.accentScore
            }

        let primary = accents.first ?? candidates.max { $0.accentScore < $1.accentScore } ?? Color(AlbumPalette.fallback.primary)
        let secondary = accents.first { primary.distance(to: $0) > 0.28 } ?? primary.rotatedFallback
        let highlight = candidates
            .filter { $0.luma > 0.45 && $0.saturation > 0.12 }
            .sorted { lhs, rhs in
                lhs.highlightScore > rhs.highlightScore
            }
            .first { primary.distance(to: $0) > 0.18 && secondary.distance(to: $0) > 0.18 }
            ?? primary.lightened

        return AlbumPalette(
            background: background.vector,
            primary: primary.vector,
            secondary: secondary.vector,
            highlight: highlight.vector
        )
    }

    private struct Bucket {
        var red: Float = 0
        var green: Float = 0
        var blue: Float = 0
        var count: Float = 0

        mutating func add(_ color: Color) {
            red += color.red
            green += color.green
            blue += color.blue
            count += 1
        }

        var representative: Color {
            guard count > 0 else { return Color(AlbumPalette.fallback.primary) }
            return Color(red: red / count, green: green / count, blue: blue / count, alpha: count)
        }
    }

    private struct Color {
        var red: Float
        var green: Float
        var blue: Float
        var alpha: Float

        init(red: Float, green: Float, blue: Float, alpha: Float) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        init(_ sample: Sample) {
            red = Float(sample.red) / 255
            green = Float(sample.green) / 255
            blue = Float(sample.blue) / 255
            alpha = Float(sample.alpha) / 255
        }

        init(_ vector: SIMD4<Float>) {
            red = vector.x
            green = vector.y
            blue = vector.z
            alpha = vector.w
        }

        var vector: SIMD4<Float> {
            SIMD4<Float>(
                max(0, min(1, red)),
                max(0, min(1, green)),
                max(0, min(1, blue)),
                1
            )
        }

        var brightness: Float {
            max(red, max(green, blue))
        }

        var luma: Float {
            red * 0.2126 + green * 0.7152 + blue * 0.0722
        }

        var saturation: Float {
            let maximum = brightness
            guard maximum > 0 else { return 0 }
            let minimum = min(red, min(green, blue))
            return (maximum - minimum) / maximum
        }

        var backgroundScore: Float {
            alpha * (1.08 - luma) * (0.55 + saturation * 0.45)
        }

        var accentScore: Float {
            alpha * (0.35 + saturation) * (0.35 + brightness)
        }

        var highlightScore: Float {
            alpha * (0.55 + luma) * (0.35 + saturation)
        }

        var lightened: Color {
            Color(
                red: red + (1 - red) * 0.42,
                green: green + (1 - green) * 0.42,
                blue: blue + (1 - blue) * 0.42,
                alpha: alpha
            )
        }

        var rotatedFallback: Color {
            Color(
                red: green * 0.55 + blue * 0.45,
                green: blue * 0.62 + red * 0.22,
                blue: red * 0.72 + green * 0.18,
                alpha: alpha
            )
        }

        func distance(to other: Color) -> Float {
            let dr = red - other.red
            let dg = green - other.green
            let db = blue - other.blue
            return sqrt(dr * dr + dg * dg + db * db)
        }
    }
}
