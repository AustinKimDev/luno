import XCTest
@testable import LunoEngineCore

final class PerformancePolicyTests: XCTestCase {
    func testBalancedPolicyDefaultsToThirtyFPS() {
        let decision = PerformancePolicy.balanced.decision(
            powerSource: .powerAdapter,
            isLowPowerModeEnabled: false,
            isFullscreenAppActive: false
        )

        XCTAssertEqual(decision.frameRate, 30)
        XCTAssertFalse(decision.shouldPause)
    }

    func testBalancedPolicyPausesForFullscreenOrLowPowerMode() {
        let fullscreen = PerformancePolicy.balanced.decision(
            powerSource: .powerAdapter,
            isLowPowerModeEnabled: false,
            isFullscreenAppActive: true
        )
        let lowPower = PerformancePolicy.balanced.decision(
            powerSource: .battery,
            isLowPowerModeEnabled: true,
            isFullscreenAppActive: false
        )

        XCTAssertTrue(fullscreen.shouldPause)
        XCTAssertTrue(lowPower.shouldPause)
    }

    func testBalancedPolicyAllowsSixtyFPSOnPowerAdapterWhenRequested() {
        let decision = PerformancePolicy.balanced.highQuality.decision(
            powerSource: .powerAdapter,
            isLowPowerModeEnabled: false,
            isFullscreenAppActive: false
        )

        XCTAssertEqual(decision.frameRate, 60)
        XCTAssertFalse(decision.shouldPause)
    }
}
