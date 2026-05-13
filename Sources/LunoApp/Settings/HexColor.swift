import AppKit
import SwiftUI

enum HexColor {
    /// Parses "#RRGGBB" (with or without leading "#"). Returns nil if invalid.
    static func parse(_ hex: String) -> (red: Double, green: Double, blue: Double)? {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#").union(.whitespacesAndNewlines))
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        return (red, green, blue)
    }
}

extension NSColor {
    convenience init?(hexString: String) {
        guard let rgb = HexColor.parse(hexString) else { return nil }
        self.init(
            calibratedRed: CGFloat(rgb.red),
            green: CGFloat(rgb.green),
            blue: CGFloat(rgb.blue),
            alpha: 1
        )
    }

    var hexString: String {
        let color = usingColorSpace(.deviceRGB) ?? self
        return String(
            format: "#%02X%02X%02X",
            Int(round(color.redComponent * 255)),
            Int(round(color.greenComponent * 255)),
            Int(round(color.blueComponent * 255))
        )
    }
}

extension Color {
    init(hexString: String, fallback: Color = .white) {
        if let rgb = HexColor.parse(hexString) {
            self = Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        } else {
            self = fallback
        }
    }
}
