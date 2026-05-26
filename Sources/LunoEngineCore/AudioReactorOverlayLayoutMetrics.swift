import Foundation

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
