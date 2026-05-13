import AppKit
import CoreGraphics
import LunoEngineCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, LibraryWindowControllerDelegate {
    private let runtime = WallpaperRuntime()
    private let archiveService = PackageArchiveService()
    private var statusItem: NSStatusItem?
    private var library: LocalPackageLibrary?
    private var presetStore: PresetStore?
    private var assignmentStore: DisplayAssignmentStore?
    private var libraryWindowController: LibraryWindowController?
    private var packages: [LunoPackageRecord] = []
    private var presets: [WallpaperPreset] = []
    private var performancePolicy = PerformancePolicy.balanced
    @available(macOS 15.0, *)
    private var audioCapture: SystemAudioCaptureService?
    private var nowPlayingPreferencesStore: NowPlayingPreferencesStore?
    private var nowPlayingPreferences: NowPlayingPreferences = .defaults
    private var appleMusicRunner = MusicAppScriptRunner()
    private var spotifyRunner = SpotifyAppScriptRunner()
    private var nowPlayingCoordinator: NowPlayingCoordinator?
    private var nowPlayingPipeline: NowPlayingPipeline?
    private var nowPlayingViewModel: NowPlayingViewModel?
    private var nowPlayingWindowController: NowPlayingWindowController?
    private var appleMusicProvider: AppleMusicProvider?
    private var spotifyProvider: SpotifyProvider?
    private var mediaRemoteProvider: MediaRemoteProvider?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let paths = try LunoAppPaths.default()
            try FileManager.default.createDirectory(at: paths.packages, withIntermediateDirectories: true)

            library = LocalPackageLibrary(libraryURL: paths.packages, archiveService: archiveService)
            presetStore = PresetStore(fileURL: paths.presets)
            assignmentStore = DisplayAssignmentStore(fileURL: paths.assignments)
            let nowPlayingStore = NowPlayingPreferencesStore(fileURL: paths.nowPlayingPreferences)
            nowPlayingPreferencesStore = nowPlayingStore
            nowPlayingPreferences = (try? nowPlayingStore.load()) ?? .defaults

            try installBundledSamplesIfNeeded()
            try reloadLibraryState()
            setupStatusItem()
            showLibrary()
            try restoreAssignments()
            reconcileAudioCaptureState()
            if nowPlayingPreferences.isEnabled {
                startNowPlaying()
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
        runtime.stop()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Luno"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Library", action: #selector(openLibraryFromMenu), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Stop Wallpapers", action: #selector(stopWallpapersFromMenu), keyEquivalent: "s"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Luno", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func installBundledSamplesIfNeeded() throws {
        guard let library else { return }

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

    private func reloadLibraryState() throws {
        packages = try library?.packages() ?? []
        presets = try presetStore?.load() ?? []
        libraryWindowController?.configure(packages: packages, presets: presets)
    }

    private func showLibrary() {
        if libraryWindowController == nil {
            let controller = LibraryWindowController()
            controller.delegate = self
            libraryWindowController = controller
        }

        libraryWindowController?.configure(packages: packages, presets: presets)
        libraryWindowController?.configureNowPlaying(nowPlayingPreferences)
        libraryWindowController?.showWindow(nil)
        libraryWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func restoreAssignments() throws {
        let assignments = try assignmentStore?.load() ?? []
        for assignment in assignments {
            guard let package = packages.first(where: { $0.manifest.id == assignment.packageID }) else {
                continue
            }
            let preset = presets.first(where: { $0.id == assignment.presetID && $0.packageID == assignment.packageID })
            try apply(package: package, preset: preset, displayID: CGDirectDisplayID(UInt32(assignment.displayID) ?? 0))
        }
    }

    private func apply(package: LunoPackageRecord, preset: WallpaperPreset?, displayID: CGDirectDisplayID?) throws {
        let decision = performancePolicy.decision(
            powerSource: .powerAdapter,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            isFullscreenAppActive: false
        )

        if decision.shouldPause {
            runtime.stop(displayID: displayID)
            return
        }

        try runtime.show(
            package: package,
            preset: preset,
            displayID: displayID,
            frameRate: decision.frameRate,
            audioProvider: { [weak self] in
                self?.audioScalars ?? .silent
            }
        )

        try persistAssignment(package: package, preset: preset, displayID: displayID)
        reconcileAudioCaptureState()
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
                presetID: preset?.id ?? "default"
            ))
        }
        try assignmentStore.save(assignments)
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }

    private var audioScalars: AudioScalars {
        if #available(macOS 15.0, *) {
            return audioCapture?.scalars ?? .silent
        }
        return .silent
    }

    private var audioFeatures: AudioFeatures {
        if #available(macOS 15.0, *) {
            return audioCapture?.features ?? .silent
        }
        return .silent
    }

    private func startAudioCaptureIfAvailable() {
        guard #available(macOS 15.0, *) else { return }
        guard audioCapture == nil else { return }
        let capture = SystemAudioCaptureService()
        audioCapture = capture

        Task { @MainActor in
            do {
                try await capture.start()
            } catch {
                await MainActor.run {
                    self.statusItem?.button?.toolTip = "Luno is running without system audio access."
                }
            }
        }
    }

    private func stopAudioCaptureIfRunning() {
        guard #available(macOS 15.0, *) else { return }
        guard let capture = audioCapture else { return }
        audioCapture = nil
        Task { @MainActor in
            await capture.stop()
        }
    }

    private func anyActivePackageNeedsAudio() -> Bool {
        guard let assignmentStore else { return false }
        let assignments = (try? assignmentStore.load()) ?? []
        let activeDisplayIDs = Set(runtime.activeDisplayIDs.map(String.init))
        for assignment in assignments where activeDisplayIDs.contains(assignment.displayID) {
            guard let package = packages.first(where: { $0.manifest.id == assignment.packageID }) else { continue }
            if !package.manifest.audioBindings.isEmpty { return true }
        }
        return false
    }

    private func reconcileAudioCaptureState() {
        if anyActivePackageNeedsAudio() {
            startAudioCaptureIfAvailable()
        } else {
            stopAudioCaptureIfRunning()
        }
    }

    @objc private func openLibraryFromMenu() {
        showLibrary()
    }

    @objc private func stopWallpapersFromMenu() {
        runtime.stop()
        reconcileAudioCaptureState()
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
        runtime.refreshDisplayLayout()
        libraryWindowController?.reloadDisplays()
    }

    @objc private func systemWillSleep() {
        guard nowPlayingPreferences.isEnabled else { return }
        stopNowPlaying()
    }

    @objc private func systemDidWake() {
        guard nowPlayingPreferences.isEnabled else { return }
        startNowPlaying()
    }

    func libraryWindowDidRequestImport(_ controller: LibraryWindowController) {
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

    func libraryWindow(_ controller: LibraryWindowController, didRequestExport package: LunoPackageRecord) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(package.manifest.name).luno"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try archiveService.exportPackage(from: package.packageURL, to: url)
        } catch {
            presentError(error)
        }
    }

    func libraryWindow(
        _ controller: LibraryWindowController,
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

    func libraryWindow(_ controller: LibraryWindowController, didSave preset: WallpaperPreset) {
        do {
            presets.removeAll { $0.id == preset.id && $0.packageID == preset.packageID }
            presets.append(preset)
            try presetStore?.save(presets)
            try reloadLibraryState()
        } catch {
            presentError(error)
        }
    }

    func libraryWindow(_ controller: LibraryWindowController, didChange nowPlayingPreferences: NowPlayingPreferences) {
        updateNowPlaying(preferences: nowPlayingPreferences)
    }

    private func startNowPlaying() {
        guard nowPlayingCoordinator == nil else { return }
        guard let nowPlayingPreferencesStore else { return }

        let appleMusicProvider = AppleMusicProvider(runner: appleMusicRunner)
        let spotifyProvider = SpotifyProvider(runner: spotifyRunner)
        let mediaRemoteProvider = MediaRemoteProvider()
        self.appleMusicProvider = appleMusicProvider
        self.spotifyProvider = spotifyProvider
        self.mediaRemoteProvider = mediaRemoteProvider

        let coordinator = NowPlayingCoordinator(providers: [appleMusicProvider, spotifyProvider, mediaRemoteProvider])
        nowPlayingCoordinator = coordinator

        let pipeline = NowPlayingPipeline(upstream: coordinator.tracks, fetcher: ArtworkFetcher())
        nowPlayingPipeline = pipeline

        let viewModel = NowPlayingViewModel(
            coordinator: coordinator,
            pipeline: pipeline,
            preferencesStore: nowPlayingPreferencesStore,
            preferences: nowPlayingPreferences,
            audioFeaturesProvider: { [weak self] in
                self?.audioFeatures ?? .silent
            }
        )
        viewModel.controlSender = { [weak self] command, source in
            guard let self else { return }
            switch source {
            case .appleMusic:
                try await self.appleMusicProvider?.send(command)
            case .spotify:
                try await self.spotifyProvider?.send(command)
            case .mediaRemote:
                return
            }
        }
        nowPlayingViewModel = viewModel

        let windowController = NowPlayingWindowController(viewModel: viewModel)
        nowPlayingWindowController = windowController
        viewModel.start()
        windowController.show()
    }

    private func stopNowPlaying() {
        nowPlayingWindowController?.hide()
        nowPlayingViewModel?.stop()
        nowPlayingWindowController = nil
        nowPlayingViewModel = nil
        nowPlayingPipeline = nil
        nowPlayingCoordinator = nil
        appleMusicProvider = nil
        spotifyProvider = nil
        mediaRemoteProvider = nil
    }

    private func updateNowPlaying(preferences: NowPlayingPreferences) {
        let wasEnabled = nowPlayingPreferences.isEnabled
        nowPlayingPreferences = preferences
        try? nowPlayingPreferencesStore?.save(preferences)
        nowPlayingViewModel?.update(preferences: preferences)
        nowPlayingWindowController?.applySizeForCurrentStyle()

        if preferences.isEnabled && !wasEnabled {
            startNowPlaying()
        } else if !preferences.isEnabled && wasEnabled {
            stopNowPlaying()
        }
    }
}

private struct LunoAppPaths {
    var root: URL
    var packages: URL
    var presets: URL
    var assignments: URL
    var nowPlayingPreferences: URL

    static func `default`() throws -> LunoAppPaths {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appending(path: "Luno", directoryHint: .isDirectory)

        return LunoAppPaths(
            root: root,
            packages: root.appending(path: "Packages", directoryHint: .isDirectory),
            presets: root.appending(path: "presets.json"),
            assignments: root.appending(path: "assignments.json"),
            nowPlayingPreferences: root.appending(path: "now-playing.json")
        )
    }
}
