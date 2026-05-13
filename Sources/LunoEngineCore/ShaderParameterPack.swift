import Foundation

public struct ShaderParameterPack: Equatable, Sendable {
    public var numeric: SIMD4<Float>
    public var color0: SIMD4<Float>
    public var color1: SIMD4<Float>
    public var color2: SIMD4<Float>
    public var color3: SIMD4<Float>

    public init(
        numeric: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 0),
        color0: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 0),
        color1: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 0),
        color2: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 0),
        color3: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 0)
    ) {
        self.numeric = numeric
        self.color0 = color0
        self.color1 = color1
        self.color2 = color2
        self.color3 = color3
    }

    public static func make(
        manifest: WallpaperPackageManifest,
        preset: WallpaperPreset?
    ) -> ShaderParameterPack {
        var numeric = SIMD4<Float>(0, 0, 0, 0)
        var colors = [
            SIMD4<Float>(0, 0, 0, 0),
            SIMD4<Float>(0, 0, 0, 0),
            SIMD4<Float>(0, 0, 0, 0),
            SIMD4<Float>(0, 0, 0, 0)
        ]
        var numericIndex = 0
        var colorIndex = 0

        for parameter in manifest.parameters {
            let value = preset?.values[parameter.id] ?? parameter.defaultValue
            switch value {
            case .float(let double) where numericIndex < 4:
                numeric[numericIndex] = Float(double)
                numericIndex += 1
            case .bool(let bool) where numericIndex < 4:
                numeric[numericIndex] = bool ? 1 : 0
                numericIndex += 1
            case .string(let string) where parameter.type == .enum && numericIndex < 4:
                guard let optionIndex = parameter.options?.firstIndex(of: string) else { continue }
                numeric[numericIndex] = Float(optionIndex)
                numericIndex += 1
            case .color(let color) where colorIndex < 4:
                colors[colorIndex] = normalizedColor(from: color)
                colorIndex += 1
            case .string, .float, .bool, .color:
                continue
            }
        }

        return ShaderParameterPack(
            numeric: numeric,
            color0: colors[0],
            color1: colors[1],
            color2: colors[2],
            color3: colors[3]
        )
    }

    private static func normalizedColor(from hexString: String) -> SIMD4<Float> {
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard (hex.count == 6 || hex.count == 8), let value = UInt32(hex, radix: 16) else {
            return SIMD4<Float>(0, 0, 0, 0)
        }

        let red: UInt32
        let green: UInt32
        let blue: UInt32
        let alpha: UInt32
        if hex.count == 8 {
            red = (value >> 24) & 0xFF
            green = (value >> 16) & 0xFF
            blue = (value >> 8) & 0xFF
            alpha = value & 0xFF
        } else {
            red = (value >> 16) & 0xFF
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
            alpha = 0xFF
        }

        return SIMD4<Float>(
            Float(red) / 255.0,
            Float(green) / 255.0,
            Float(blue) / 255.0,
            Float(alpha) / 255.0
        )
    }
}
