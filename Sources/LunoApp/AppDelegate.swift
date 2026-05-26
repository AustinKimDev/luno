import AppKit
import CoreGraphics
import LunoEngineCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, SettingsWindowControllerDelegate {
    private static let albumPaletteSampleID = "com.luno.samples.album-palette"
    private static let retiredBundledSampleIDs: Set<String> = [
        "com.luno.samples.aurora",
        "com.luno.samples.cloud-lantern-flow",
        "com.luno.samples.cover-bloom",
        "com.luno.samples.glitch-district",
        "com.luno.samples.ink-plume",
        "com.luno.samples.iso-tower",
        "com.luno.samples.koi-light-drift",
        "com.luno.samples.liquid-chrome",
        "com.luno.samples.midnight-grid",
        "com.luno.samples.neon-rain-window",
        "com.luno.samples.quiet-lattice",
        "com.luno.samples.solar-drift",
        "com.luno.samples.synthwave-horizon",
        "com.luno.samples.velvet-tide",
        "com.luno.samples.vinyl-echo"
    ]

    private let runtime = WallpaperRuntime()
    private let archiveService = PackageArchiveService()
    private var statusItem: NSStatusItem?
    private var library: LocalPackageLibrary?
    private var presetStore: PresetStore?
    private var assignmentStore: DisplayAssignmentStore?
    private var wallpaperSession: WallpaperSessionCoordinator?
    private var settingsWindowController: SettingsWindowController?
    private var packages: [LunoPackageRecord] = []
    private var presets: [WallpaperPreset] = []
    private let audioCaptureCoordinator = AudioCaptureCoordinator()
    private var audioReactorPreferencesStore: AudioReactorPreferencesStore?
    private var audioReactorPreferences: AudioReactorPreferences = .defaults
    private var nowPlayingSession: NowPlayingSessionCoordinator?
    private var albumPalette: AlbumPalette = .fallback
    private var albumPaletteGeneration = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let paths = try LunoAppPaths.default()
            try FileManager.default.createDirectory(at: paths.packages, withIntermediateDirectories: true)

            library = LocalPackageLibrary(libraryURL: paths.packages, archiveService: archiveService)
            presetStore = PresetStore(fileURL: paths.presets)
            assignmentStore = DisplayAssignmentStore(fileURL: paths.assignments)
            let audioReactorStore = AudioReactorPreferencesStore(fileURL: paths.audioReactorPreferences)
            audioReactorPreferencesStore = audioReactorStore
            audioReactorPreferences = (try? audioReactorStore.load()) ?? .defaults
            let nowPlayingStore = NowPlayingPreferencesStore(fileURL: paths.nowPlayingPreferences)
            let nowPlayingPreferences = (try? nowPlayingStore.load()) ?? .defaults
            nowPlayingSession = NowPlayingSessionCoordinator(
                preferencesStore: nowPlayingStore,
                preferences: nowPlayingPreferences
            )
            configureCoordinators()

            try installBundledSamplesIfNeeded()
            try migrateRetiredBundledSampleAssignments()
            try reloadLibraryState()
            setupStatusItem()
            try restoreAssignments()
            reconcileAudioCaptureState()
            if nowPlayingSession?.preferences.isEnabled == true {
                nowPlayingSession?.start()
            }
        } catch {
            presentError(error)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        wallpaperSession?.stopAll()
    }

    private func configureCoordinators() {
        let wallpaperSession = WallpaperSessionCoordinator(runtime: runtime, assignmentStore: assignmentStore)
        wallpaperSession.audioFeaturesProvider = { [weak self] in
            self?.audioCaptureCoordinator.features ?? .silent
        }
        wallpaperSession.audioReactorPreferencesProvider = { [weak self] in
            self?.audioReactorPreferences ?? Self.disabledAudioReactorPreferences
        }
        wallpaperSession.albumPaletteProvider = { [weak self] in
            self?.albumPalette ?? .fallback
        }
        wallpaperSession.assignmentsDidChange = { [weak self] assignments in
            self?.settingsWindowController?.configureAssignments(assignments)
        }
        wallpaperSession.renderingStateDidChange = { [weak self] in
            self?.reconcileAudioCaptureState()
        }
        self.wallpaperSession = wallpaperSession

        audioCaptureCoordinator.needsAudioProvider = { [weak self] in
            self?.needsAudioCapture ?? false
        }
        audioCaptureCoordinator.accessFailureHandler = { [weak self] message in
            self?.statusItem?.button?.toolTip = message
        }

        nowPlayingSession?.bassLevelProvider = { [weak self] in
            self?.nowPlayingBassLevel ?? 0
        }
        nowPlayingSession?.preferencesDidChange = { [weak self] preferences in
            self?.settingsWindowController?.configureNowPlaying(preferences)
        }
        nowPlayingSession?.artworkDidChange = { [weak self] artworkData in
            self?.updateAlbumPalette(from: artworkData)
        }
        nowPlayingSession?.audioNeedsDidChange = { [weak self] in
            self?.reconcileAudioCaptureState()
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Luno"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Library", action: #selector(openLibraryFromMenu), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Stop Wallpapers", action: #selector(stopWallpapersFromMenu), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Reconnect Audio Share", action: #selector(reconnectAudioShareFromMenu), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Luno", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func installBundledSamplesIfNeeded() throws {
        guard let library else { return }

        for packageID in Self.retiredBundledSampleIDs {
            try library.removePackage(id: packageID)
        }

        var installedVersions = Dictionary(
            uniqueKeysWithValues: try library.packages().map { ($0.manifest.id, $0.manifest.version) }
        )
        for sampleURL in try bundledSamplePackageURLs() {
            let manifest = try archiveService.loadManifest(at: sampleURL)
            guard installedVersions[manifest.id] != manifest.version else { continue }

            _ = try library.importPackage(from: sampleURL)
            installedVersions[manifest.id] = manifest.version
        }
    }

    private func bundledSamplePackageURLs() throws -> [URL] {
        let candidates = [
            Bundle.main.resourceURL?
                .appending(path: "Luno_LunoApp.bundle/SamplePackages", directoryHint: .isDirectory),
            Bundle.main.bundleURL
                .appending(path: "Luno_LunoApp.bundle/SamplePackages", directoryHint: .isDirectory),
            Bundle.module.resourceURL?
                .appending(path: "SamplePackages", directoryHint: .isDirectory)
        ].compactMap(\.self)

        for samplesURL in candidates where FileManager.default.fileExists(atPath: samplesURL.path) {
            return try FileManager.default.contentsOfDirectory(
                at: samplesURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension.lowercased() == "luno" }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        }

        return []
    }

    private func migrateRetiredBundledSampleAssignments() throws {
        guard let assignmentStore else { return }
        var assignments = try assignmentStore.load()
        var changed = false
        for index in assignments.indices where Self.retiredBundledSampleIDs.contains(assignments[index].packageID) {
            assignments[index].packageID = Self.albumPaletteSampleID
            assignments[index].presetID = "default"
            assignments[index].values = nil
            changed = true
        }
        if changed {
            try assignmentStore.save(assignments)
        }
    }

    private func reloadLibraryState() throws {
        packages = try library?.packages() ?? []
        presets = try presetStore?.load() ?? []
        wallpaperSession?.packages = packages
        wallpaperSession?.presets = presets
        settingsWindowController?.configure(
            packages: packages,
            presets: presets,
            assignments: (try? assignmentStore?.load()) ?? []
        )
    }

    private func showLibrary() {
        if settingsWindowController == nil {
            let controller = SettingsWindowController()
            controller.delegate = self
            settingsWindowController = controller
        }

        settingsWindowController?.configure(
            packages: packages,
            presets: presets,
            assignments: (try? assignmentStore?.load()) ?? []
        )
        settingsWindowController?.configureAudioReactor(audioReactorPreferences)
        settingsWindowController?.configureNowPlaying(nowPlayingSession?.preferences ?? .defaults)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func restoreAssignments() throws {
        try wallpaperSession?.restoreAssignments()
    }

    private func apply(package: LunoPackageRecord, preset: WallpaperPreset?, displayID: CGDirectDisplayID?) throws {
        try wallpaperSession?.apply(package: package, preset: preset, displayID: displayID)
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }

    private var nowPlayingBassLevel: Double {
        audioCaptureCoordinator.nowPlayingBassLevel
    }

    private var needsAudioCapture: Bool {
        let wallpaperNeedsAudio = wallpaperSession?.anyRenderingPackageNeedsAudio(
            audioReactorPreferences: audioReactorPreferences
        ) ?? false
        let nowPlayingNeedsAudio = nowPlayingSession?.needsAudio ?? false
        return wallpaperNeedsAudio || nowPlayingNeedsAudio
    }

    private func reconcileAudioCaptureState() {
        audioCaptureCoordinator.reconcile()
    }

    @objc private func openLibraryFromMenu() {
        showLibrary()
    }

    @objc private func stopWallpapersFromMenu() {
        wallpaperSession?.stopAll()
        reconcileAudioCaptureState()
    }

    @objc private func reconnectAudioShareFromMenu() {
        audioCaptureCoordinator.reconnect()
    }

    @objc private func toggleStartAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                sender.state = .off
            } else {
                try SMAppService.mainApp.register()
                sender.state = .on
            }
        } catch {
            presentError(error)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func screenParametersDidChange() {
        wallpaperSession?.refreshDisplayLayout()
        settingsWindowController?.reloadDisplays()
    }

    @objc private func systemWillSleep() {
        if nowPlayingSession?.preferences.isEnabled == true {
            nowPlayingSession?.stop()
        }
    }

    @objc private func systemDidWake() {
        if nowPlayingSession?.preferences.isEnabled == true {
            nowPlayingSession?.start()
        }
        reconcileAudioCaptureState()
    }

    func settingsWindowDidRequestImport(_ controller: SettingsWindowController) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.zip, .folder]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            _ = try library?.importPackage(from: url)
            try reloadLibraryState()
        } catch {
            presentError(error)
        }
    }

    func settingsWindow(_ controller: SettingsWindowController, didRequestExport package: LunoPackageRecord) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(package.manifest.name).luno"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try archiveService.exportPackage(from: package.packageURL, to: url)
        } catch {
            presentError(error)
        }
    }

    func settingsWindow(
        _ controller: SettingsWindowController,
        didRequestApply package: LunoPackageRecord,
        preset: WallpaperPreset?,
        displayID: CGDirectDisplayID?
    ) {
        do {
            try apply(package: package, preset: preset, displayID: displayID)
        } catch {
            presentError(error)
        }
    }

    func settingsWindow(_ controller: SettingsWindowController, didSave preset: WallpaperPreset) {
        do {
            presets.removeAll { $0.id == preset.id && $0.packageID == preset.packageID }
            presets.append(preset)
            try presetStore?.save(presets)
            try reloadLibraryState()
        } catch {
            presentError(error)
        }
    }

    func settingsWindow(_ controller: SettingsWindowController, didChange nowPlayingPreferences: NowPlayingPreferences) {
        updateNowPlaying(preferences: nowPlayingPreferences)
    }

    func settingsWindow(
        _ controller: SettingsWindowController,
        didChange audioReactorPreferences: AudioReactorPreferences,
        shouldPersist: Bool
    ) {
        updateAudioReactor(preferences: audioReactorPreferences, shouldPersist: shouldPersist)
    }

    private func updateAlbumPalette(from artworkData: Data?) {
        albumPaletteGeneration += 1
        let generation = albumPaletteGeneration
        guard let artworkData else {
            return
        }

        Task.detached(priority: .utility) {
            let palette = AlbumArtworkPaletteExtractor.extract(from: artworkData)
            await MainActor.run {
                guard generation == self.albumPaletteGeneration,
                      let palette
                else {
                    return
                }
                self.albumPalette = palette
                self.nowPlayingSession?.albumPalette = palette
            }
        }
    }

    private func updateNowPlaying(preferences: NowPlayingPreferences) {
        nowPlayingSession?.update(preferences: preferences)
    }

    private func updateAudioReactor(preferences: AudioReactorPreferences, shouldPersist: Bool) {
        let wasEnabled = audioReactorPreferences.isEnabled
        audioReactorPreferences = preferences

        if shouldPersist {
            try? audioReactorPreferencesStore?.save(preferences)
        }
        if wasEnabled != preferences.isEnabled {
            reconcileAudioCaptureState()
        }
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
}
