import AppKit
import SwiftUI

struct ArtworkView: View {
    let imageData: Data?
    let pulseAmplitude: Double
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            if let imageData, let image = NSImage(data: imageData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.42, blue: 0.61),
                        Color(red: 0.36, green: 0.17, blue: 0.37)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
