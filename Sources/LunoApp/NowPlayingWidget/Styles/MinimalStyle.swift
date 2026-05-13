import Foundation
import SwiftUI

struct MinimalStyle: View {
    let title: String
    let artist: String?
    let artworkData: Data?
    let pulseAmplitude: Double
    let isHovering: Bool
    let canControl: Bool
    let onCommand: (NowPlayingControlIntent) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(imageData: artworkData, pulseAmplitude: pulseAmplitude, cornerRadius: 4)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let artist {
                    Text(artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isHovering {
                HoverControlsView(layout: .singleRight, canSkip: false, enabled: canControl, onCommand: onCommand)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
    }
}
