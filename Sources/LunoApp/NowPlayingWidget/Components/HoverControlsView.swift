import SwiftUI

struct HoverControlsView: View {
    enum Layout {
        case overlayCenter
        case horizontalRight
        case singleRight
    }

    let layout: Layout
    let canSkip: Bool
    let enabled: Bool
    let onCommand: (NowPlayingControlIntent) -> Void

    var body: some View {
        HStack(spacing: layout == .overlayCenter ? 14 : 10) {
            if canSkip {
                button("backward.fill") { onCommand(.previous) }
            }
            button("playpause.fill") { onCommand(.playPause) }
            if canSkip {
                button("forward.fill") { onCommand(.next) }
            }
        }
        .opacity(enabled ? 1.0 : 0.3)
        .allowsHitTesting(enabled)
    }

    private func button(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.white.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }
}

enum NowPlayingControlIntent {
    case playPause
    case next
    case previous
}
