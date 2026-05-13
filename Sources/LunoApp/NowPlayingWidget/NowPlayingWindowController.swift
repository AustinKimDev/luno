import AppKit
import LunoEngineCore
import SwiftUI

@MainActor
final class NowPlayingWindowController: NSWindowController {
    private static let widgetLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)

    private let viewModel: NowPlayingViewModel
    private var hostingView: NowPlayingHostingView<RootContainer>?
    private var savePositionTimer: Timer?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var currentlyIgnoresMouse = false

    init(viewModel: NowPlayingViewModel) {
        self.viewModel = viewModel

        let window = NowPlayingFloatingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 72),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = Self.widgetLevel
        window.collectionBehavior = [.stationary]
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false

        super.init(window: window)
        window.delegate = self

        let root = RootContainer(viewModel: viewModel, windowController: self)
        let host = NowPlayingHostingView(rootView: root)
        host.widgetSize = viewModel.preferences.style.widgetSize
        window.contentView = host
        hostingView = host
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func show() {
        applySavedPosition()
        applySizeForCurrentStyle()
        applyPresentationMode()
        window?.orderFrontRegardless()
        startClickThroughTracking()
        updateClickThroughForCursor(NSEvent.mouseLocation)
    }

    func hide() {
        stopClickThroughTracking()
        window?.orderOut(nil)
    }

    private func startClickThroughTracking() {
        stopClickThroughTracking()
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateClickThroughForCursor(NSEvent.mouseLocation)
            }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            guard let self else { return event }
            Task { @MainActor in
                self.updateClickThroughForCursor(NSEvent.mouseLocation)
            }
            return event
        }
    }

    private func stopClickThroughTracking() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
    }

    private func updateClickThroughForCursor(_ screenPoint: NSPoint) {
        guard let window, window.isVisible else { return }
        let windowFrame = window.frame
        let margin = NowPlayingPreferences.Style.glowMargin
        let widgetSize = viewModel.preferences.style.widgetSize
        let widgetRect = CGRect(
            x: windowFrame.origin.x + margin,
            y: windowFrame.origin.y + margin,
            width: widgetSize.width,
            height: widgetSize.height
        )
        let shouldIgnore = !widgetRect.contains(screenPoint)
        guard shouldIgnore != currentlyIgnoresMouse else { return }
        currentlyIgnoresMouse = shouldIgnore
        window.ignoresMouseEvents = shouldIgnore
    }

    func applySizeForCurrentStyle() {
        guard let window else { return }
        let size = viewModel.preferences.style.windowSize
        var frame = window.frame
        frame.size = size
        window.setFrame(frame, display: true, animate: false)
        hostingView?.widgetSize = viewModel.preferences.style.widgetSize
    }

    func togglePinned() {
        var preferences = viewModel.preferences
        preferences.isPinned.toggle()
        viewModel.update(preferences: preferences)
        applyPresentationMode()
        if preferences.isPinned {
            window?.orderFrontRegardless()
        }
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

    private func applyPresentationMode() {
        guard let window else { return }
        if viewModel.preferences.isPinned {
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        } else {
            window.level = Self.widgetLevel
            window.collectionBehavior = [.stationary]
        }
    }

    private func applySavedPosition() {
        guard let window else { return }

        let visibleFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let displayIDs = NSScreen.screens.compactMap(\.lunoDisplayID).map(String.init)
        let preferredDisplayID = displayIDs.first { viewModel.preferences.positionsByDisplay[$0] != nil }
        let size = viewModel.preferences.style.windowSize

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
private final class NowPlayingFloatingWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class NowPlayingHostingView<Content: View>: NSHostingView<Content> {
    var widgetSize: CGSize = .zero

    override func hitTest(_ point: NSPoint) -> NSView? {
        // point is in the superview's coordinate space. For a window's contentView this
        // matches the contentView's local coordinates (origin at bottom-left).
        let margin = NowPlayingPreferences.Style.glowMargin
        let widgetRect = CGRect(
            x: margin,
            y: margin,
            width: widgetSize.width,
            height: widgetSize.height
        )
        guard widgetRect.contains(point) else { return nil }
        return super.hitTest(point)
    }
}

extension NowPlayingWindowController: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        savePositionTimer?.invalidate()
        savePositionTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveCurrentPosition()
            }
        }
    }
}

private struct RootContainer: View {
    @Bindable var viewModel: NowPlayingViewModel
    weak var windowController: NowPlayingWindowController?

    var body: some View {
        let widgetSize = viewModel.preferences.style.widgetSize
        return Group {
            if let track = viewModel.track {
                NowPlayingWidgetView(
                    style: viewModel.preferences.style,
                    track: track,
                    pulseAmplitude: viewModel.pulseAmplitude,
                    appearance: viewModel.preferences.appearance,
                    isHovering: viewModel.isHovering,
                    canControl: track.source != .mediaRemote && !track.isAdvertisement,
                    onCommand: { intent in viewModel.send(intent) }
                )
                .onHover { hovering in
                    viewModel.isHovering = hovering
                }
                .opacity(viewModel.visible ? 1 : 0)
            } else {
                WaitingForMusicView()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                windowController?.togglePinned()
            } label: {
                Image(systemName: viewModel.preferences.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(viewModel.preferences.isPinned ? 0.95 : 0.65))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.black.opacity(0.26)))
            }
            .buttonStyle(.plain)
            .help(viewModel.preferences.isPinned ? "Unpin widget" : "Pin above apps and full screen spaces")
            .padding(6)
        }
        .frame(width: widgetSize.width, height: widgetSize.height)
        .padding(NowPlayingPreferences.Style.glowMargin)
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
        .background(GlassBackground(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
