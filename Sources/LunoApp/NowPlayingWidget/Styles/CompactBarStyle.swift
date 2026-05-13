import Foundation
import LunoEngineCore
import SwiftUI

struct CompactBarStyle: View {
    let title: String
    let artist: String?
    let album: String?
    let composer: String?
    let artworkData: Data?
    let pulseAmplitude: Double
    let appearance: NowPlayingAppearance
    let isHovering: Bool
    let canControl: Bool
    let onCommand: (NowPlayingControlIntent) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(imageData: artworkData, pulseAmplitude: pulseAmplitude, cornerRadius: 6)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: appearance.titleWeight.swiftUIWeight))
                    .foregroundStyle(Color(hexString: appearance.textColor))
                    .lineLimit(1)
                if let secondary = secondaryLine {
                    Text(secondary)
                        .font(.system(size: 11, weight: appearance.subtitleWeight.swiftUIWeight))
                        .foregroundStyle(Color(hexString: appearance.textColor).opacity(0.7))
                        .lineLimit(1)
                }
                if let composer, !composer.isEmpty {
                    Text(composer)
                        .font(.system(size: 10, weight: appearance.subtitleWeight.swiftUIWeight).italic())
                        .foregroundStyle(Color(hexString: appearance.textColor).opacity(0.45))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(isHovering ? 0.3 : 1.0)
            if isHovering {
                HoverControlsView(layout: .horizontalRight, canSkip: true, enabled: canControl, onCommand: onCommand)
            }
        }
        .padding(CGFloat(appearance.padding))
    }

    private var secondaryLine: String? {
        switch (artist, album) {
        case let (artist?, album?):
            return "\(artist) · \(album)"
        case let (artist?, nil):
            return artist
        case let (nil, album?):
            return album
        default:
            return nil
        }
    }
}
