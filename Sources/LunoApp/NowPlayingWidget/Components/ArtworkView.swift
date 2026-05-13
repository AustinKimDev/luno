import AppKit
import SwiftUI

struct ArtworkView: View {
    let imageData: Data?
    let pulseAmplitude: Double
    let cornerRadius: CGFloat

    @State private var animatedScale: CGFloat = 1.0

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
        .scaleEffect(animatedScale)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(
            color: .white.opacity(min(max(pulseAmplitude, 0), 1) * 0.18),
            radius: min(max(pulseAmplitude, 0), 1) * 10
        )
        .onChange(of: pulseAmplitude) { _, newValue in
            let target = 1.0 + min(max(newValue, 0), 1) * 0.08
            withAnimation(.spring(response: 0.18, dampingFraction: 0.6)) {
                animatedScale = target
            }
        }
    }
}
