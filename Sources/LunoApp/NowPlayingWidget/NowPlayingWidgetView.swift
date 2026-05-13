import LunoEngineCore
import SwiftUI

struct NowPlayingWidgetView: View {
    let style: NowPlayingPreferences.Style
    let track: ResolvedNowPlayingTrack
    let pulseAmplitude: Double
    let isHovering: Bool
    let canControl: Bool
    let onCommand: (NowPlayingControlIntent) -> Void

    var body: some View {
        Group {
            switch style {
            case .albumDominant:
                AlbumDominantStyle(
                    title: displayTitle,
                    artist: track.artist,
                    album: track.album,
                    composer: track.composer,
                    artworkData: track.artworkData,
                    pulseAmplitude: pulseAmplitude,
                    isHovering: isHovering,
                    canControl: canControl,
                    onCommand: onCommand
                )
            case .compactBar:
                CompactBarStyle(
                    title: displayTitle,
                    artist: track.artist,
                    album: track.album,
                    composer: track.composer,
                    artworkData: track.artworkData,
                    pulseAmplitude: pulseAmplitude,
                    isHovering: isHovering,
                    canControl: canControl,
                    onCommand: onCommand
                )
            case .minimal:
                MinimalStyle(
                    title: displayTitle,
                    artist: track.artist,
                    artworkData: track.artworkData,
                    pulseAmplitude: pulseAmplitude,
                    isHovering: isHovering,
                    canControl: canControl,
                    onCommand: onCommand
                )
            }
        }
        .background(GlassBackground(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
    }

    private var displayTitle: String {
        track.isAdvertisement ? "Advertisement" : track.title
    }
}

extension NowPlayingPreferences.Style {
    var widgetSize: CGSize {
        switch self {
        case .albumDominant:
            return CGSize(width: 180, height: 216)
        case .compactBar:
            return CGSize(width: 280, height: 72)
        case .minimal:
            return CGSize(width: 240, height: 52)
        }
    }
}
