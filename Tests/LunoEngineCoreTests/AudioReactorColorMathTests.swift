import XCTest
@testable import LunoEngineCore

final class AudioReactorColorMathTests: XCTestCase {
    func testRGBToHSLRoundTripPreservesColor() {
        let cases: [(Double, Double, Double)] = [
            (1.0, 0.0, 0.0),        // pure red
            (0.0, 1.0, 0.0),        // pure green
            (0.0, 0.0, 1.0),        // pure blue
            (0.5, 0.5, 0.5),        // mid gray
            (0.95, 0.2, 0.6),       // pink
            (0.0, 0.0, 0.0),        // black
            (1.0, 1.0, 1.0)         // white
        ]
        for (r, g, b) in cases {
            let hsl = AudioReactorColorMath.rgbToHSL(r: r, g: g, b: b)
            let back = AudioReactorColorMath.hslToRGB(h: hsl.h, s: hsl.s, l: hsl.l)
            XCTAssertEqual(back.r, r, accuracy: 0.001, "red mismatch for \(r),\(g),\(b)")
            XCTAssertEqual(back.g, g, accuracy: 0.001, "green mismatch")
            XCTAssertEqual(back.b, b, accuracy: 0.001, "blue mismatch")
        }
    }

    func testHSLKnownValues() {
        // Pure red: h=0, s=1, l=0.5
        let red = AudioReactorColorMath.rgbToHSL(r: 1, g: 0, b: 0)
        XCTAssertEqual(red.h, 0, accuracy: 0.001)
        XCTAssertEqual(red.s, 1, accuracy: 0.001)
        XCTAssertEqual(red.l, 0.5, accuracy: 0.001)

        // Pure green: h=120, s=1, l=0.5
        let green = AudioReactorColorMath.rgbToHSL(r: 0, g: 1, b: 0)
        XCTAssertEqual(green.h, 120, accuracy: 0.001)
        XCTAssertEqual(green.s, 1, accuracy: 0.001)
        XCTAssertEqual(green.l, 0.5, accuracy: 0.001)

        // Gray: s=0
        let gray = AudioReactorColorMath.rgbToHSL(r: 0.5, g: 0.5, b: 0.5)
        XCTAssertEqual(gray.s, 0, accuracy: 0.001)
        XCTAssertEqual(gray.l, 0.5, accuracy: 0.001)
    }

    func testHSLToRGBNormalizesOutOfRangeHue() {
        // 480° is 360° + 120° → should produce the same result as 120° (green).
        let cycled = AudioReactorColorMath.hslToRGB(h: 480, s: 1, l: 0.5)
        let direct = AudioReactorColorMath.hslToRGB(h: 120, s: 1, l: 0.5)
        XCTAssertEqual(cycled.r, direct.r, accuracy: 0.001)
        XCTAssertEqual(cycled.g, direct.g, accuracy: 0.001)
        XCTAssertEqual(cycled.b, direct.b, accuracy: 0.001)

        // Negative hue: -60° should equal +300° (magenta).
        let negative = AudioReactorColorMath.hslToRGB(h: -60, s: 1, l: 0.5)
        let positive = AudioReactorColorMath.hslToRGB(h: 300, s: 1, l: 0.5)
        XCTAssertEqual(negative.r, positive.r, accuracy: 0.001)
        XCTAssertEqual(negative.g, positive.g, accuracy: 0.001)
        XCTAssertEqual(negative.b, positive.b, accuracy: 0.001)
    }

    func testContrastLumaCorrectionShiftsAwayFromDarkBackground() {
        // Album bg: very dark navy. Reactor primary: also dark navy.
        let albumBg = AudioReactorColorMath.RGB(r: 0.05, g: 0.06, b: 0.18)
        let albumPrimary = AudioReactorColorMath.RGB(r: 0.92, g: 0.32, b: 0.42)
        let albumSecondary = AudioReactorColorMath.RGB(r: 0.12, g: 0.55, b: 0.94)
        let reactor = AudioReactorColorMath.RGB(r: 0.07, g: 0.08, b: 0.22)

        let corrected = AudioReactorColorMath.applyContrast(
            channel: reactor,
            role: .primary,
            albumBackground: albumBg,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary
        )

        let reactorLuma = AudioReactorColorMath.luma(r: reactor.r, g: reactor.g, b: reactor.b)
        let correctedLuma = AudioReactorColorMath.luma(r: corrected.r, g: corrected.g, b: corrected.b)
        XCTAssertGreaterThan(correctedLuma - reactorLuma, 0.25, "expected luma boost away from dark bg")
    }

    func testContrastHueRotationOnPrimaryClashWithAlbumPrimary() {
        let albumBg = AudioReactorColorMath.RGB(r: 0.1, g: 0.1, b: 0.1)
        let albumPrimary = AudioReactorColorMath.RGB(r: 0.95, g: 0.2, b: 0.2)  // red
        let albumSecondary = AudioReactorColorMath.RGB(r: 0.2, g: 0.95, b: 0.2)  // green
        let reactor = AudioReactorColorMath.RGB(r: 0.9, g: 0.18, b: 0.22)  // also red

        let corrected = AudioReactorColorMath.applyContrast(
            channel: reactor,
            role: .primary,
            albumBackground: albumBg,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary
        )

        let albumHue = AudioReactorColorMath.rgbToHSL(r: albumPrimary.r, g: albumPrimary.g, b: albumPrimary.b).h
        let correctedHue = AudioReactorColorMath.rgbToHSL(r: corrected.r, g: corrected.g, b: corrected.b).h
        let hueDelta = min(abs(correctedHue - albumHue), 360 - abs(correctedHue - albumHue))
        XCTAssertGreaterThan(hueDelta, 60, "expected hue rotation away from album primary")
    }

    func testContrastGlowLockedNearWhite() {
        let albumBg = AudioReactorColorMath.RGB(r: 0.05, g: 0.05, b: 0.05)
        let albumPrimary = AudioReactorColorMath.RGB(r: 0.9, g: 0.3, b: 0.4)
        let albumSecondary = AudioReactorColorMath.RGB(r: 0.2, g: 0.7, b: 0.9)
        let reactor = AudioReactorColorMath.RGB(r: 0.2, g: 0.2, b: 0.2)  // dark

        let corrected = AudioReactorColorMath.applyContrast(
            channel: reactor,
            role: .glow,
            albumBackground: albumBg,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary
        )

        let luma = AudioReactorColorMath.luma(r: corrected.r, g: corrected.g, b: corrected.b)
        XCTAssertGreaterThanOrEqual(luma, 0.85, "glow must lock to luma >= 0.85")
    }

    func testContrastSaturationFloor() {
        // After luma boost, an originally low-sat reactor channel should be pushed to >= 0.55 sat.
        let albumBg = AudioReactorColorMath.RGB(r: 0.05, g: 0.05, b: 0.05)
        let albumPrimary = AudioReactorColorMath.RGB(r: 0.9, g: 0.3, b: 0.4)
        let albumSecondary = AudioReactorColorMath.RGB(r: 0.2, g: 0.7, b: 0.9)
        let reactor = AudioReactorColorMath.RGB(r: 0.5, g: 0.52, b: 0.55)  // near gray

        let corrected = AudioReactorColorMath.applyContrast(
            channel: reactor,
            role: .secondary,
            albumBackground: albumBg,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary
        )

        let sat = AudioReactorColorMath.rgbToHSL(r: corrected.r, g: corrected.g, b: corrected.b).s
        XCTAssertGreaterThanOrEqual(sat, 0.54)
    }

    func testVividProducesExpectedLightnessPerChannel() {
        let albumPrimary = AudioReactorColorMath.RGB(r: 0.95, g: 0.2, b: 0.6)
        let albumSecondary = AudioReactorColorMath.RGB(r: 0.2, g: 0.7, b: 0.9)
        let albumHighlight = AudioReactorColorMath.RGB(r: 0.95, g: 0.9, b: 0.55)

        let primary = AudioReactorColorMath.applyVivid(
            role: .primary,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary,
            albumHighlight: albumHighlight
        )
        let primaryHSL = AudioReactorColorMath.rgbToHSL(r: primary.r, g: primary.g, b: primary.b)
        XCTAssertEqual(primaryHSL.l, 0.78, accuracy: 0.01)
        XCTAssertEqual(primaryHSL.s, 1.0, accuracy: 0.01)

        let secondary = AudioReactorColorMath.applyVivid(
            role: .secondary,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary,
            albumHighlight: albumHighlight
        )
        let secondaryHSL = AudioReactorColorMath.rgbToHSL(r: secondary.r, g: secondary.g, b: secondary.b)
        XCTAssertEqual(secondaryHSL.l, 0.65, accuracy: 0.01)

        let glow = AudioReactorColorMath.applyVivid(
            role: .glow,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary,
            albumHighlight: albumHighlight
        )
        let glowHSL = AudioReactorColorMath.rgbToHSL(r: glow.r, g: glow.g, b: glow.b)
        XCTAssertEqual(glowHSL.l, 0.95, accuracy: 0.01)
        XCTAssertEqual(glowHSL.s, 0.5, accuracy: 0.01)
    }

    func testVividPullsHueFromCorrectAlbumChannel() {
        let albumPrimary = AudioReactorColorMath.RGB(r: 0.95, g: 0.2, b: 0.2)   // red
        let albumSecondary = AudioReactorColorMath.RGB(r: 0.2, g: 0.95, b: 0.2) // green
        let albumHighlight = AudioReactorColorMath.RGB(r: 0.2, g: 0.2, b: 0.95) // blue

        let primary = AudioReactorColorMath.applyVivid(
            role: .primary,
            albumPrimary: albumPrimary,
            albumSecondary: albumSecondary,
            albumHighlight: albumHighlight
        )
        let primaryHue = AudioReactorColorMath.rgbToHSL(r: primary.r, g: primary.g, b: primary.b).h
        let albumPrimaryHue = AudioReactorColorMath.rgbToHSL(r: albumPrimary.r, g: albumPrimary.g, b: albumPrimary.b).h
        XCTAssertEqual(primaryHue, albumPrimaryHue, accuracy: 1.0)
    }

    func testBeatGateFiresWhenBassSpikesAboveEMA() {
        var gate = AudioReactorColorMath.BeatGate()

        // 30 frames of low bass to settle EMA near 0.10.
        for _ in 0..<30 {
            _ = gate.step(bass: 0.10, deltaTime: 1.0 / 60)
        }

        // Sudden spike: 0.10 -> 0.6 should clearly exceed EMA * 1.45 and > 0.25.
        let level = gate.step(bass: 0.6, deltaTime: 1.0 / 60)
        XCTAssertGreaterThan(level, 0.9, "beat should fire and produce ~1 gateLevel")
    }

    func testBeatGateDecaysOverFrames() {
        var gate = AudioReactorColorMath.BeatGate()
        for _ in 0..<30 {
            _ = gate.step(bass: 0.10, deltaTime: 1.0 / 60)
        }
        _ = gate.step(bass: 0.6, deltaTime: 1.0 / 60)

        // Five more frames at low bass: gateLevel should decay (0.92^5 ≈ 0.66).
        var level: Float = 1
        for _ in 0..<5 {
            level = gate.step(bass: 0.10, deltaTime: 1.0 / 60)
        }
        XCTAssertLessThan(level, 0.70, "expected decay below 0.70 after 5 frames")
        XCTAssertGreaterThan(level, 0.55)
    }

    func testBeatGateDoesNotFireBelowAbsoluteFloor() {
        var gate = AudioReactorColorMath.BeatGate()
        // Bass spike of 0.20 (>1.45 * EMA but < 0.25 absolute floor) must not fire.
        for _ in 0..<30 {
            _ = gate.step(bass: 0.05, deltaTime: 1.0 / 60)
        }
        let level = gate.step(bass: 0.20, deltaTime: 1.0 / 60)
        XCTAssertLessThan(level, 0.10, "bass below 0.25 floor must not fire")
    }

    func testMotionTrailZeroBypassesSmoothing() {
        var buffer = AudioReactorColorMath.MotionTrailBuffer()
        let input: [Float] = [0.8, 0.6, 0.4]
        var output: [Float] = [0, 0, 0]
        buffer.apply(input: input, trail: 0, into: &output)
        XCTAssertEqual(output, input)
    }

    func testMotionTrailKeepsDescendingTail() {
        var buffer = AudioReactorColorMath.MotionTrailBuffer()
        var output: [Float] = [0, 0, 0]
        buffer.apply(input: [1.0, 1.0, 1.0], trail: 0.8, into: &output)
        buffer.apply(input: [0.0, 0.0, 0.0], trail: 0.8, into: &output)
        // decay = 0.55 + 0.4 * 0.8 = 0.87
        XCTAssertEqual(output[0], 0.87, accuracy: 0.001)
    }

    func testSpectrumEnvelopeUsesFastAttackAndSlowerRelease() {
        var buffer = AudioReactorColorMath.SpectrumEnvelopeBuffer()
        var output: [Float] = []

        buffer.apply(input: [1.0], smoothing: 0.25, deltaTime: 1.0 / 60.0, into: &output)
        let attacked = output[0]
        buffer.apply(input: [0.0], smoothing: 0.25, deltaTime: 1.0 / 60.0, into: &output)
        let released = output[0]

        XCTAssertGreaterThan(attacked, 0.45)
        XCTAssertGreaterThan(released, 0.25)
        XCTAssertLessThan(released, attacked)
    }

    func testApplyColorCycleNoCycleReturnsInputHex() {
        let cycled = AudioReactorColorMath.applyColorCycle(hex: "#24C7FF", cycleRate: 0, time: 5)
        XCTAssertEqual(cycled, "#24C7FF")
    }

    func testApplyColorCycleFullPeriodReturnsToOriginal() {
        let original = "#24C7FF"
        let cycled = AudioReactorColorMath.applyColorCycle(hex: original, cycleRate: 1, time: 10.0)
        XCTAssertEqual(cycled, original)
    }

    func testApplyColorCycleHalfPeriodShiftsHue180() {
        let original = "#FF0000"  // hue 0
        let cycled = AudioReactorColorMath.applyColorCycle(hex: original, cycleRate: 1, time: 5.0)
        // 180° hue shift from red is cyan (#00FFFF)
        XCTAssertEqual(cycled, "#00FFFF")
    }
}
