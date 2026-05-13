import Foundation
import LunoEngineCore
import Observation
import SwiftUI

@MainActor
@Observable
final class NowPlayingViewModel {
    enum PermissionState {
        case unknown
        case granted
        case deniedAppleMusic
        case deniedSpotify
        case deniedBoth
    }

    var track: ResolvedNowPlayingTrack?
    var visible = false
    var isHovering = false
    var pulseAmplitude: Double = 0
    var preferences: NowPlayingPreferences
    var permissionState: PermissionState = .unknown
    var controlSender: ((NowPlayingControlCommand, NowPlayingSource) async throws -> Void)?

    var activeSource: NowPlayingSource? {
        track?.source
    }

    private let coordinator: NowPlayingCoordinator
    private let pipeline: NowPlayingPipeline
    private let preferencesStore: NowPlayingPreferencesStore
    private let audioFeaturesProvider: @MainActor () -> AudioFeatures
    private var consumerTask: Task<Void, Never>?
    private var animationTimer: Timer?
    private var fadeOutTask: Task<Void, Never>?

    private let fadeOutGrace: TimeInterval = 5.0

    init(
        coordinator: NowPlayingCoordinator,
        pipeline: NowPlayingPipeline,
        preferencesStore: NowPlayingPreferencesStore,
        preferences: NowPlayingPreferences,
        audioFeaturesProvider: @escaping @MainActor () -> AudioFeatures
    ) {
        self.coordinator = coordinator
        self.pipeline = pipeline
        self.preferencesStore = preferencesStore
        self.preferences = preferences
        self.audioFeaturesProvider = audioFeaturesProvider
    }

    func start() {
        consumerTask?.cancel()
        consumerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await resolved in pipeline.output {
                handle(resolved: resolved)
            }
        }

        startAnimationTimer()
        Task {
            await coordinator.start()
        }
    }

    func stop() {
        consumerTask?.cancel()
        consumerTask = nil

        animationTimer?.invalidate()
        animationTimer = nil

        fadeOutTask?.cancel()
        fadeOutTask = nil

        Task {
            await coordinator.stop()
        }
    }

    func send(_ intent: NowPlayingControlIntent) {
        let command: NowPlayingControlCommand
        switch intent {
        case .playPause:
            command = .playPause
        case .next:
            command = .nextTrack
        case .previous:
            command = .previousTrack
        }

        guard let activeSource else { return }
        Task {
            do {
                try await sendCommand(command, to: activeSource)
            } catch {
                // Controls are best-effort; providers may disappear between render and click.
            }
        }
    }

    func update(preferences: NowPlayingPreferences) {
        self.preferences = preferences
        try? preferencesStore.save(preferences)
    }

    private func sendCommand(_ command: NowPlayingControlCommand, to source: NowPlayingSource) async throws {
        guard let controlSender else { return }
        try await controlSender(command, source)
    }

    private func handle(resolved: ResolvedNowPlayingTrack?) {
        fadeOutTask?.cancel()
        fadeOutTask = nil

        if let resolved, resolved.isPlaying {
            track = resolved
            withAnimation(.easeOut(duration: 0.3)) {
                visible = true
            }
            return
        }

        if let resolved {
            track = resolved
            scheduleFadeOut()
            return
        }

        scheduleFadeOut()
    }

    private func scheduleFadeOut() {
        if preferences.keepVisibleWhilePaused {
            return
        }

        fadeOutTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(fadeOutGrace * 1_000_000_000))
            } catch {
                return
            }
            if !isHovering {
                withAnimation(.easeIn(duration: 0.4)) {
                    visible = false
                }
            }
        }
    }

    private func startAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let features = audioFeaturesProvider()
                let hoverScale = isHovering ? 0.3 : 1.0
                let strength = preferences.audioReactivityEnabled ? 0.5 : 0
                pulseAmplitude = Double(features.bass) * strength * hoverScale
            }
        }
    }
}
