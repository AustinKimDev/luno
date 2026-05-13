import LunoEngineCore
import SwiftUI

struct NowPlayingWidgetView: View {
    let style: NowPlayingPreferences.Style
    let track: ResolvedNowPlayingTrack
    let pulseAmplitude: Double
    let appearance: NowPlayingAppearance
    let isHovering: Bool
    let canControl: Bool
    let onCommand: (NowPlayingControlIntent) -> Void

    @State private var animatedPulse: Double = 0

    private var glowPulse: Double { animatedPulse * appearance.glowReaction }
    private var scalePulse: Double { animatedPulse * appearance.scaleReaction }
    private var borderPulse: Double { animatedPulse * appearance.borderReaction }

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
                    appearance: appearance,
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
                    appearance: appearance,
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
                    appearance: appearance,
                    isHovering: isHovering,
                    canControl: canControl,
                    onCommand: onCommand
                )
            }
        }
        .background(GlassBackground(cornerRadius: CGFloat(appearance.cornerRadius)))
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(appearance.cornerRadius))
                .stroke(
                    Color(hexString: appearance.textColor)
                        .opacity(min(appearance.borderOpacity + borderPulse * 1.75, 1.0)),
                    lineWidth: appearance.borderWidth + borderPulse * 7.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(appearance.cornerRadius)))
        .scaleEffect(1.0 + scalePulse * 0.20)
        .shadow(
            color: Color(hexString: appearance.glowTint).opacity(min(glowPulse * 2.25, 1.0)),
            radius: glowPulse * 40
        )
        .onChange(of: pulseAmplitude) { _, newValue in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                animatedPulse = min(max(newValue, 0), 1)
            }
        }
    }

    private var displayTitle: String {
        track.isAdvertisement ? "Advertisement" : track.title
    }
}

extension NowPlayingPreferences.Style {
    static let glowMargin: CGFloat = 48

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

    var windowSize: CGSize {
        let margin = Self.glowMargin * 2
        return CGSize(width: widgetSize.width + margin, height: widgetSize.height + margin)
    }
}
