import Foundation
import SwiftUI

struct AlbumDominantStyle: View {
    let title: String
    let artist: String?
    let album: String?
    let composer: String?
    let artworkData: Data?
    let pulseAmplitude: Double
    let isHovering: Bool
    let canControl: Bool
    let onCommand: (NowPlayingControlIntent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                ArtworkView(imageData: artworkData, pulseAmplitude: pulseAmplitude, cornerRadius: 8)
                    .frame(width: 152, height: 152)
                if isHovering {
                    Color.black.opacity(0.45)
                        .frame(width: 152, height: 152)
                        .cornerRadius(8)
                    HoverControlsView(layout: .overlayCenter, canSkip: true, enabled: canControl, onCommand: onCommand)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let secondary = secondaryLine {
                    Text(secondary)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                if let composer, !composer.isEmpty {
                    Text(composer)
                        .font(.system(size: 10).italic())
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }
            .frame(width: 152, alignment: .leading)
        }
        .padding(14)
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
