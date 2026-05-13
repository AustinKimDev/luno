import Foundation
import LunoEngineCore
import SwiftUI

struct MinimalStyle: View {
    let title: String
    let artist: String?
    let artworkData: Data?
    let pulseAmplitude: Double
    let appearance: NowPlayingAppearance
    let isHovering: Bool
    let canControl: Bool
    let onCommand: (NowPlayingControlIntent) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(imageData: artworkData, pulseAmplitude: pulseAmplitude, cornerRadius: 4)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: appearance.titleWeight.swiftUIWeight))
                    .foregroundStyle(Color(hexString: appearance.textColor))
                    .lineLimit(1)
                if let artist {
                    Text(artist)
                        .font(.system(size: 11, weight: appearance.subtitleWeight.swiftUIWeight))
                        .foregroundStyle(Color(hexString: appearance.textColor).opacity(0.7))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isHovering {
                HoverControlsView(layout: .singleRight, canSkip: false, enabled: canControl, onCommand: onCommand)
            }
        }
        .padding(EdgeInsets(top: CGFloat(appearance.padding), leading: CGFloat(appearance.padding), bottom: CGFloat(appearance.padding), trailing: CGFloat(appearance.padding)))
    }
}
