import Foundation

public enum AudioReactorColorMath {
    public struct HSL: Equatable, Sendable {
        public var h: Double  // 0..360
        public var s: Double  // 0..1
        public var l: Double  // 0..1
    }

    public struct RGB: Equatable, Sendable {
        public var r: Double
        public var g: Double
        public var b: Double
    }

    public static func rgbToHSL(r: Double, g: Double, b: Double) -> HSL {
        let cr = clamp01(r)
        let cg = clamp01(g)
        let cb = clamp01(b)
        let maxC = max(cr, max(cg, cb))
        let minC = min(cr, min(cg, cb))
        let delta = maxC - minC
        let l = (maxC + minC) / 2

        guard delta > 0.00001 else {
            return HSL(h: 0, s: 0, l: l)
        }

        let s = l > 0.5 ? delta / (2 - maxC - minC) : delta / (maxC + minC)
        var h: Double
        // maxC was assigned from one of cr/cg/cb via max(), so exact equality is correct.
        if maxC == cr {
            h = ((cg - cb) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxC == cg {
            h = (cb - cr) / delta + 2
        } else {
            h = (cr - cg) / delta + 4
        }
        h *= 60
        if h < 0 { h += 360 }
        return HSL(h: h, s: s, l: l)
    }

    public static func hslToRGB(h: Double, s: Double, l: Double) -> RGB {
        let cs = clamp01(s)
        let cl = clamp01(l)
        guard cs > 0.00001 else {
            return RGB(r: cl, g: cl, b: cl)
        }

        let c = (1 - abs(2 * cl - 1)) * cs
        let hp = h.truncatingRemainder(dividingBy: 360) / 60
        let normalized = hp < 0 ? hp + 6 : hp
        let x = c * (1 - abs(normalized.truncatingRemainder(dividingBy: 2) - 1))
        let m = cl - c / 2

        let (r1, g1, b1): (Double, Double, Double)
        switch Int(floor(normalized)) {
        case 0: (r1, g1, b1) = (c, x, 0)
        case 1: (r1, g1, b1) = (x, c, 0)
        case 2: (r1, g1, b1) = (0, c, x)
        case 3: (r1, g1, b1) = (0, x, c)
        case 4: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        return RGB(r: r1 + m, g: g1 + m, b: b1 + m)
    }

    static func clamp01(_ v: Double) -> Double {
        guard v.isFinite else { return 0 }
        return min(max(v, 0), 1)
    }

    static func luma(r: Double, g: Double, b: Double) -> Double {
        r * 0.2126 + g * 0.7152 + b * 0.0722
    }
}
