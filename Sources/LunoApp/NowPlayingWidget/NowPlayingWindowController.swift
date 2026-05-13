import AppKit
import LunoEngineCore
import SwiftUI

@MainActor
final class NowPlayingWindowController: NSWindowController {
    private let viewModel: NowPlayingViewModel
    private var hostingView: NSHostingView<RootContainer>?

    init(viewModel: NowPlayingViewModel) {
        self.viewModel = viewModel

        let window = NowPlayingFloatingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 72),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = false

        super.init(window: window)

        let root = RootContainer(viewModel: viewModel, windowController: self)
        let host = NSHostingView(rootView: root)
        window.contentView = host
        hostingView = host
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func show() {
        applySavedPosition()
        applySizeForCurrentStyle()
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func applySizeForCurrentStyle() {
        guard let window else { return }
        let size = viewModel.preferences.style.widgetSize
        var frame = window.frame
        frame.size = size
        window.setFrame(frame, display: true, animate: false)
    }

    func saveCurrentPosition() {
        guard let window, let screen = window.screen else { return }
        let displayID = screen.lunoDisplayID.map { String($0) } ?? "main"
        var preferences = viewModel.preferences
        preferences.positionsByDisplay[displayID] = NowPlayingPreferences.Position(
            x: Double(window.frame.origin.x),
            y: Double(window.frame.origin.y)
        )
        viewModel.update(preferences: preferences)
    }

    private func applySavedPosition() {
        guard let window else { return }

        let visibleFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let displayIDs = NSScreen.screens.compactMap(\.lunoDisplayID).map(String.init)
        let preferredDisplayID = displayIDs.first { viewModel.preferences.positionsByDisplay[$0] != nil }
        let size = viewModel.preferences.style.widgetSize

        let position: NSPoint
        if let preferredDisplayID, let saved = viewModel.preferences.positionsByDisplay[preferredDisplayID] {
            position = NSPoint(x: saved.x, y: saved.y)
        } else {
            position = NSPoint(
                x: visibleFrame.maxX - size.width - 24,
                y: visibleFrame.minY + 24
            )
        }

        let clamped = clamp(point: position, size: size, into: visibleFrame)
        window.setFrame(NSRect(origin: clamped, size: size), display: true)
    }

    private func clamp(point: NSPoint, size: CGSize, into frame: NSRect) -> NSPoint {
        let x = min(max(point.x, frame.minX), frame.maxX - size.width)
        let y = min(max(point.y, frame.minY), frame.maxY - size.height)
        return NSPoint(x: x, y: y)
    }
}

@MainActor
private final class NowPlayingFloatingWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct RootContainer: View {
    @Bindable var viewModel: NowPlayingViewModel
    weak var windowController: NowPlayingWindowController?

    @State private var dragOrigin: NSPoint?

    var body: some View {
        Group {
            if let track = viewModel.track {
                NowPlayingWidgetView(
                    style: viewModel.preferences.style,
                    track: track,
                    pulseAmplitude: viewModel.pulseAmplitude,
                    isHovering: viewModel.isHovering,
                    canControl: track.source != .mediaRemote && !track.isAdvertisement,
                    onCommand: { intent in viewModel.send(intent) }
                )
                .onHover { hovering in
                    viewModel.isHovering = hovering
                }
                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { value in
                            guard let window = windowController?.window else { return }
                            let origin = dragOrigin ?? window.frame.origin
                            dragOrigin = origin
                            window.setFrameOrigin(NSPoint(
                                x: origin.x + value.translation.width,
                                y: origin.y - value.translation.height
                            ))
                        }
                        .onEnded { _ in
                            dragOrigin = nil
                            windowController?.saveCurrentPosition()
                        }
                )
                .opacity(viewModel.visible ? 1 : 0)
            } else {
                WaitingForMusicView()
                    .gesture(dragGesture)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                guard let window = windowController?.window else { return }
                let origin = dragOrigin ?? window.frame.origin
                dragOrigin = origin
                window.setFrameOrigin(NSPoint(
                    x: origin.x + value.translation.width,
                    y: origin.y - value.translation.height
                ))
            }
            .onEnded { _ in
                dragOrigin = nil
                windowController?.saveCurrentPosition()
            }
    }
}

private struct WaitingForMusicView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text("Waiting for music")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Apple Music or Spotify")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GlassBackground())
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
    }
}
