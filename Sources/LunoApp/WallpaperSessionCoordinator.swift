import AppKit
import CoreGraphics
import LunoEngineCore

@MainActor
final class WallpaperSessionCoordinator {
    var packages: [LunoPackageRecord] = []
    var presets: [WallpaperPreset] = []
    var performancePolicy = PerformancePolicy.balanced
    var audioFeaturesProvider: () -> AudioFeatures = { .silent }
    var audioReactorPreferencesProvider: () -> AudioReactorPreferences = { .defaults }
    var albumPaletteProvider: () -> AlbumPalette = { .fallback }
    var assignmentsDidChange: (([DisplayAssignment]) -> Void)?
    var renderingStateDidChange: (() -> Void)?

    private let runtime: WallpaperRuntime
    private let assignmentStore: DisplayAssignmentStore?

    init(runtime: WallpaperRuntime, assignmentStore: DisplayAssignmentStore?) {
        self.runtime = runtime
        self.assignmentStore = assignmentStore
        runtime.renderingStateDidChange = { [weak self] in
            self?.renderingStateDidChange?()
        }
    }

    var renderingDisplayIDs: [CGDirectDisplayID] {
        runtime.renderingDisplayIDs
    }

    func stopAll() {
        runtime.stop()
    }

    func refreshDisplayLayout() {
        runtime.refreshDisplayLayout()
    }

    func restoreAssignments() throws {
        let assignments = try assignmentStore?.load() ?? []
        for assignment in assignments {
            guard let package = packages.first(where: { $0.manifest.id == assignment.packageID }) else {
                continue
            }
            let preset = preset(for: assignment)
            try apply(package: package, preset: preset, displayID: CGDirectDisplayID(UInt32(assignment.displayID) ?? 0))
        }
    }

    func apply(package: LunoPackageRecord, preset: WallpaperPreset?, displayID: CGDirectDisplayID?) throws {
        let decision = performancePolicy.decision(
            powerSource: .powerAdapter,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            isFullscreenAppActive: false
        )

        if decision.shouldPause {
            runtime.stop(displayID: displayID)
            renderingStateDidChange?()
            return
        }

        try runtime.show(
            package: package,
            preset: preset,
            displayID: displayID,
            frameRate: decision.frameRate,
            pauseWhenOccluded: performancePolicy.pausesWhenNotVisible,
            audioProvider: { [weak self] in
                self?.audioFeaturesProvider() ?? .silent
            },
            audioReactorPreferencesProvider: { [weak self] in
                guard let self else { return Self.disabledAudioReactorPreferences }
                guard !package.manifest.audioBindings.isEmpty else {
                    return Self.disabledAudioReactorPreferences
                }
                return self.audioReactorPreferencesProvider()
            },
            albumPaletteProvider: { [weak self] in
                self?.albumPaletteProvider() ?? .fallback
            },
            backgroundAudioReactiveProvider: {
                Self.isAudioReactiveEnabled(for: preset)
            }
        )

        try persistAssignment(package: package, preset: preset, displayID: displayID)
        renderingStateDidChange?()
    }

    func anyRenderingPackageNeedsAudio(audioReactorPreferences: AudioReactorPreferences) -> Bool {
        guard let assignmentStore else { return false }
        let assignments = (try? assignmentStore.load()) ?? []
        let renderingDisplayIDs = Set(runtime.renderingDisplayIDs.map(String.init))
        for assignment in assignments where renderingDisplayIDs.contains(assignment.displayID) {
            guard let package = packages.first(where: { $0.manifest.id == assignment.packageID }) else { continue }
            let preset = preset(for: assignment)
            if !package.manifest.audioBindings.isEmpty,
               (Self.isAudioReactiveEnabled(for: preset) || audioReactorPreferences.isEnabled) {
                return true
            }
        }
        return false
    }

    func preset(for assignment: DisplayAssignment) -> WallpaperPreset? {
        if let values = assignment.values {
            return WallpaperPreset(
                id: assignment.presetID,
                packageID: assignment.packageID,
                name: presets.first { $0.id == assignment.presetID && $0.packageID == assignment.packageID }?.name ?? "Default",
                values: values
            )
        }
        return presets.first { $0.id == assignment.presetID && $0.packageID == assignment.packageID }
    }

    private func persistAssignment(package: LunoPackageRecord, preset: WallpaperPreset?, displayID: CGDirectDisplayID?) throws {
        guard let assignmentStore else { return }

        let targetDisplayIDs: [CGDirectDisplayID]
        if let displayID {
            targetDisplayIDs = [displayID]
        } else {
            targetDisplayIDs = NSScreen.screens.compactMap(\.lunoDisplayID)
        }

        var assignments = try assignmentStore.load()
        for targetDisplayID in targetDisplayIDs {
            assignments.removeAll { $0.displayID == String(targetDisplayID) }
            assignments.append(DisplayAssignment(
                displayID: String(targetDisplayID),
                packageID: package.manifest.id,
                presetID: preset?.id ?? "default",
                values: preset?.values
            ))
        }
        try assignmentStore.save(assignments)
        assignmentsDidChange?(assignments)
    }

    private static let disabledAudioReactorPreferences = AudioReactorPreferences(
        isEnabled: false,
        intensity: AudioReactorPreferences.defaults.intensity,
        response: AudioReactorPreferences.defaults.response,
        bassPulseStrength: AudioReactorPreferences.defaults.bassPulseStrength,
        showsPulseRing: AudioReactorPreferences.defaults.showsPulseRing,
        showsSpectrumBars: AudioReactorPreferences.defaults.showsSpectrumBars,
        showsWaveLine: AudioReactorPreferences.defaults.showsWaveLine,
        overlayOpacity: AudioReactorPreferences.defaults.overlayOpacity
    )

    private static func isAudioReactiveEnabled(for preset: WallpaperPreset?) -> Bool {
        guard case .bool(let isEnabled)? = preset?.values[LibrarySectionView.audioReactiveParameterID] else {
            return true
        }
        return isEnabled
    }
}
