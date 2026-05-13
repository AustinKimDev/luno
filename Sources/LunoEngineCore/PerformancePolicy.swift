import Foundation

public enum PowerSource: Equatable, Sendable {
    case battery
    case powerAdapter
}

public struct PerformanceDecision: Equatable, Sendable {
    public var frameRate: Int
    public var shouldPause: Bool

    public init(frameRate: Int, shouldPause: Bool) {
        self.frameRate = frameRate
        self.shouldPause = shouldPause
    }
}

public struct PerformancePolicy: Equatable, Sendable {
    public var batteryFrameRate: Int
    public var powerAdapterFrameRate: Int
    public var pausesForFullscreenApps: Bool
    public var pausesForLowPowerMode: Bool
    public var pausesWhenNotVisible: Bool

    public static let balanced = PerformancePolicy(
        batteryFrameRate: 30,
        powerAdapterFrameRate: 30,
        pausesForFullscreenApps: true,
        pausesForLowPowerMode: true,
        pausesWhenNotVisible: true
    )

    public var highQuality: PerformancePolicy {
        var copy = self
        copy.powerAdapterFrameRate = 60
        return copy
    }

    public init(
        batteryFrameRate: Int,
        powerAdapterFrameRate: Int,
        pausesForFullscreenApps: Bool,
        pausesForLowPowerMode: Bool,
        pausesWhenNotVisible: Bool = true
    ) {
        self.batteryFrameRate = batteryFrameRate
        self.powerAdapterFrameRate = powerAdapterFrameRate
        self.pausesForFullscreenApps = pausesForFullscreenApps
        self.pausesForLowPowerMode = pausesForLowPowerMode
        self.pausesWhenNotVisible = pausesWhenNotVisible
    }

    public func decision(
        powerSource: PowerSource,
        isLowPowerModeEnabled: Bool,
        isFullscreenAppActive: Bool,
        isWallpaperVisible: Bool = true
    ) -> PerformanceDecision {
        let frameRate = switch powerSource {
        case .battery:
            batteryFrameRate
        case .powerAdapter:
            powerAdapterFrameRate
        }
        let shouldPause = (pausesWhenNotVisible && !isWallpaperVisible)
            || (pausesForFullscreenApps && isFullscreenAppActive)
            || (pausesForLowPowerMode && isLowPowerModeEnabled)

        return PerformanceDecision(frameRate: frameRate, shouldPause: shouldPause)
    }
}
