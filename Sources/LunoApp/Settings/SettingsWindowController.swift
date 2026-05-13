import AppKit
import CoreGraphics
import LunoEngineCore
import UniformTypeIdentifiers

@MainActor
protocol SettingsWindowControllerDelegate: AnyObject {
    func settingsWindowDidRequestImport(_ controller: SettingsWindowController)
    func settingsWindow(_ controller: SettingsWindowController, didRequestExport package: LunoPackageRecord)
    func settingsWindow(
        _ controller: SettingsWindowController,
        didRequestApply package: LunoPackageRecord,
        preset: WallpaperPreset?,
        displayID: CGDirectDisplayID?
    )
    func settingsWindow(_ controller: SettingsWindowController, didSave preset: WallpaperPreset)
    func settingsWindow(_ controller: SettingsWindowController, didChange nowPlayingPreferences: NowPlayingPreferences)
    func settingsWindow(
        _ controller: SettingsWindowController,
        didChange audioReactorPreferences: AudioReactorPreferences,
        shouldPersist: Bool
    )
}

@MainActor
final class SettingsWindowController: NSWindowController {
    weak var delegate: SettingsWindowControllerDelegate?

    private var packages: [LunoPackageRecord] = []
    private var presets: [WallpaperPreset] = []
    private var nowPlayingPreferences: NowPlayingPreferences = .defaults
    private var audioReactorPreferences: AudioReactorPreferences = .defaults

    private let splitView = NSSplitView()
    private let sidebar = SettingsSidebar()
    private let detailContainer = NSView()

    private let librarySection = LibrarySectionView()
    private let basicSection = NowPlayingBasicSectionView()
    private let appearanceSection = NowPlayingAppearanceSectionView()
    private let reactivitySection = NowPlayingReactivitySectionView()
    private let audioReactorSection = AudioReactorSectionView()

    convenience init() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 540))
        let window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Luno"
        window.minSize = NSSize(width: 640, height: 460)
        window.contentView = contentView
        self.init(window: window)
        buildUI(in: contentView)
        wireSections()
        sidebar.selectInitialItem()
    }

    func configure(packages: [LunoPackageRecord], presets: [WallpaperPreset]) {
        self.packages = packages
        self.presets = presets
        reloadPackages()
        reloadDisplays()
        librarySection.rebuildParameterControls(with: selectedPackage, presets: presets)
    }

    func configureNowPlaying(_ preferences: NowPlayingPreferences) {
        nowPlayingPreferences = preferences
        basicSection.configure(preferences)
        appearanceSection.configure(preferences.appearance)
        reactivitySection.configure(preferences)
    }

    func configureAudioReactor(_ preferences: AudioReactorPreferences) {
        audioReactorPreferences = preferences
        audioReactorSection.configure(preferences)
    }

    func reloadDisplays() {
        let popup = librarySection.displayPopup
        popup.removeAllItems()
        popup.addItem(withTitle: "All Displays")
        popup.lastItem?.representedObject = nil
        for screen in NSScreen.screens {
            let displayID = screen.lunoDisplayID
            let title = displayID.map { "Display \($0)" } ?? "Unknown Display"
            popup.addItem(withTitle: title)
            popup.lastItem?.representedObject = displayID.map { NSNumber(value: $0) }
        }
    }

    private func buildUI(in root: NSView) {
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(splitView)
        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: root.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        let sidebarContainer = NSView()
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebar.scrollView.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(sidebar.scrollView)
        NSLayoutConstraint.activate([
            sidebar.scrollView.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor),
            sidebar.scrollView.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            sidebar.scrollView.topAnchor.constraint(equalTo: sidebarContainer.topAnchor),
            sidebar.scrollView.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor)
        ])
        sidebarContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        sidebarContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 240).isActive = true

        detailContainer.translatesAutoresizingMaskIntoConstraints = false

        splitView.addArrangedSubview(sidebarContainer)
        splitView.addArrangedSubview(detailContainer)
        splitView.setHoldingPriority(NSLayoutConstraint.Priority(rawValue: 250), forSubviewAt: 0)
    }

    private func wireSections() {
        sidebar.delegate = self
        librarySection.delegate = self
        librarySection.setPackagePopupTarget(self, action: #selector(packageSelectionChanged))
        basicSection.delegate = self
        appearanceSection.delegate = self
        reactivitySection.delegate = self
        audioReactorSection.delegate = self
    }

    private func showSection(_ section: SettingsSection) {
        detailContainer.subviews.forEach { $0.removeFromSuperview() }
        let view: NSView
        switch section {
        case .library: view = librarySection
        case .nowPlayingBasic: view = basicSection
        case .nowPlayingAppearance: view = appearanceSection
        case .nowPlayingReactivity: view = reactivitySection
        case .audioReactor: view = audioReactorSection
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
            view.topAnchor.constraint(equalTo: detailContainer.topAnchor),
            view.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor)
        ])
    }

    private func reloadPackages() {
        let popup = librarySection.packagePopup
        popup.removeAllItems()
        for package in packages {
            popup.addItem(withTitle: package.manifest.name)
            popup.lastItem?.representedObject = package.manifest.id
        }
        librarySection.rebuildParameterControls(with: selectedPackage, presets: presets)
    }

    private var selectedPackage: LunoPackageRecord? {
        let index = librarySection.packagePopup.indexOfSelectedItem
        guard packages.indices.contains(index) else { return nil }
        return packages[index]
    }

    private var selectedDisplayID: CGDirectDisplayID? {
        guard let number = librarySection.displayPopup.selectedItem?.representedObject as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private func selectedPreset(for package: LunoPackageRecord) -> WallpaperPreset {
        let values = librarySection.currentParameterValues(for: package.manifest)
        let trimmed = librarySection.presetNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Default" : trimmed
        let id = name.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return WallpaperPreset(
            id: id.isEmpty ? "default" : id,
            packageID: package.manifest.id,
            name: name,
            values: values
        )
    }

    private func applySelectedPackage() {
        guard let package = selectedPackage else { return }
        delegate?.settingsWindow(
            self,
            didRequestApply: package,
            preset: selectedPreset(for: package),
            displayID: selectedDisplayID
        )
    }

    @objc private func packageSelectionChanged() {
        librarySection.rebuildParameterControls(with: selectedPackage, presets: presets)
        applySelectedPackage()
    }
}

extension SettingsWindowController: SettingsSidebarDelegate {
    func sidebar(_ sidebar: SettingsSidebar, didSelect section: SettingsSection) {
        showSection(section)
    }
}

extension SettingsWindowController: LibrarySectionViewDelegate {
    func librarySectionDidRequestApply(_ view: LibrarySectionView) {
        applySelectedPackage()
    }

    func librarySectionDidRequestSavePreset(_ view: LibrarySectionView) {
        guard let package = selectedPackage else { return }
        delegate?.settingsWindow(self, didSave: selectedPreset(for: package))
    }

    func librarySectionDidRequestImport(_ view: LibrarySectionView) {
        delegate?.settingsWindowDidRequestImport(self)
    }

    func librarySectionDidRequestExport(_ view: LibrarySectionView) {
        guard let package = selectedPackage else { return }
        delegate?.settingsWindow(self, didRequestExport: package)
    }

    func librarySectionDidChangeLiveSelection(_ view: LibrarySectionView) {
        applySelectedPackage()
    }
}

extension SettingsWindowController: NowPlayingBasicSectionViewDelegate {
    func nowPlayingBasicSection(_ view: NowPlayingBasicSectionView, didChange preferences: NowPlayingPreferences) {
        nowPlayingPreferences = preferences
        delegate?.settingsWindow(self, didChange: nowPlayingPreferences)
    }
}

extension SettingsWindowController: NowPlayingAppearanceSectionViewDelegate {
    func nowPlayingAppearanceSection(_ view: NowPlayingAppearanceSectionView, didChange appearance: NowPlayingAppearance) {
        nowPlayingPreferences.appearance = appearance
        delegate?.settingsWindow(self, didChange: nowPlayingPreferences)
        reactivitySection.configure(nowPlayingPreferences)
    }
}

extension SettingsWindowController: NowPlayingReactivitySectionViewDelegate {
    func nowPlayingReactivitySection(_ view: NowPlayingReactivitySectionView, didChange preferences: NowPlayingPreferences) {
        nowPlayingPreferences = preferences
        delegate?.settingsWindow(self, didChange: nowPlayingPreferences)
        appearanceSection.configure(preferences.appearance)
    }
}

extension SettingsWindowController: AudioReactorSectionViewDelegate {
    func audioReactorSection(_ view: AudioReactorSectionView, didChange preferences: AudioReactorPreferences) {
        audioReactorPreferences = preferences
        delegate?.settingsWindow(self, didChange: preferences, shouldPersist: true)
    }
}
