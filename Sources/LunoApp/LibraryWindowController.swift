import AppKit
import CoreGraphics
import LunoEngineCore
import UniformTypeIdentifiers

@MainActor
protocol LibraryWindowControllerDelegate: AnyObject {
    func libraryWindowDidRequestImport(_ controller: LibraryWindowController)
    func libraryWindow(_ controller: LibraryWindowController, didRequestExport package: LunoPackageRecord)
    func libraryWindow(
        _ controller: LibraryWindowController,
        didRequestApply package: LunoPackageRecord,
        preset: WallpaperPreset?,
        displayID: CGDirectDisplayID?
    )
    func libraryWindow(_ controller: LibraryWindowController, didSave preset: WallpaperPreset)
    func libraryWindow(_ controller: LibraryWindowController, didChange nowPlayingPreferences: NowPlayingPreferences)
}

@MainActor
final class LibraryWindowController: NSWindowController {
    weak var delegate: LibraryWindowControllerDelegate?

    private var packages: [LunoPackageRecord] = []
    private var presets: [WallpaperPreset] = []
    private var controlsByParameterID: [String: NSControl] = [:]

    private let packagePopup = NSPopUpButton()
    private let presetNameField = NSTextField()
    private let displayPopup = NSPopUpButton()
    private let parameterStack = NSStackView()
    private var nowPlayingPreferences: NowPlayingPreferences = .defaults
    private let nowPlayingEnableSwitch = NSSwitch()
    private let nowPlayingStylePopup = NSPopUpButton()
    private let nowPlayingReactivitySwitch = NSSwitch()
    private let nowPlayingKeepVisibleSwitch = NSSwitch()

    convenience init() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 460))
        let window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Luno Library"
        window.contentView = contentView
        self.init(window: window)
        buildUI(in: contentView)
    }

    func configure(packages: [LunoPackageRecord], presets: [WallpaperPreset]) {
        self.packages = packages
        self.presets = presets
        reloadPackages()
        reloadDisplays()
        rebuildParameterControls()
    }

    func configureNowPlaying(_ preferences: NowPlayingPreferences) {
        nowPlayingPreferences = preferences
        nowPlayingEnableSwitch.state = preferences.isEnabled ? .on : .off
        nowPlayingReactivitySwitch.state = preferences.audioReactivityEnabled ? .on : .off
        nowPlayingKeepVisibleSwitch.state = preferences.keepVisibleWhilePaused ? .on : .off

        let index = NowPlayingPreferences.Style.allCases.firstIndex(of: preferences.style) ?? 0
        nowPlayingStylePopup.selectItem(at: index)
    }

    func reloadDisplays() {
        displayPopup.removeAllItems()
        displayPopup.addItem(withTitle: "All Displays")
        displayPopup.lastItem?.representedObject = nil

        for screen in NSScreen.screens {
            let displayID = screen.lunoDisplayID
            let title = displayID.map { "Display \($0)" } ?? "Unknown Display"
            displayPopup.addItem(withTitle: title)
            displayPopup.lastItem?.representedObject = displayID.map { NSNumber(value: $0) }
        }
    }

    private func buildUI(in root: NSView) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -20)
        ])

        let title = NSTextField(labelWithString: "Luno")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        stack.addArrangedSubview(title)

        packagePopup.target = self
        packagePopup.action = #selector(packageSelectionChanged)
        packagePopup.widthAnchor.constraint(equalToConstant: 340).isActive = true
        stack.addArrangedSubview(labeledRow(label: "Wallpaper", view: packagePopup))

        displayPopup.widthAnchor.constraint(equalToConstant: 220).isActive = true
        stack.addArrangedSubview(labeledRow(label: "Display", view: displayPopup))

        presetNameField.placeholderString = "Preset name"
        presetNameField.stringValue = "Default"
        presetNameField.widthAnchor.constraint(equalToConstant: 220).isActive = true
        stack.addArrangedSubview(labeledRow(label: "Preset", view: presetNameField))

        parameterStack.orientation = .vertical
        parameterStack.alignment = .leading
        parameterStack.spacing = 10
        stack.addArrangedSubview(parameterStack)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.addArrangedSubview(NSButton(title: "Apply", target: self, action: #selector(applySelectedPackage)))
        buttonRow.addArrangedSubview(NSButton(title: "Save Preset", target: self, action: #selector(savePreset)))
        buttonRow.addArrangedSubview(NSButton(title: "Import", target: self, action: #selector(importPackage)))
        buttonRow.addArrangedSubview(NSButton(title: "Export", target: self, action: #selector(exportPackage)))
        stack.addArrangedSubview(buttonRow)

        buildNowPlayingSection(in: stack)
    }

    private func labeledRow(label: String, view: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = NSTextField(labelWithString: label)
        labelView.widthAnchor.constraint(equalToConstant: 90).isActive = true
        row.addArrangedSubview(labelView)
        row.addArrangedSubview(view)
        return row
    }

    private func buildNowPlayingSection(in stack: NSStackView) {
        let heading = NSTextField(labelWithString: "Now Playing widget")
        heading.font = .boldSystemFont(ofSize: 13)
        stack.addArrangedSubview(heading)

        nowPlayingEnableSwitch.target = self
        nowPlayingEnableSwitch.action = #selector(nowPlayingToggleChanged)
        stack.addArrangedSubview(labeled("Enable widget", control: nowPlayingEnableSwitch))

        nowPlayingStylePopup.removeAllItems()
        nowPlayingStylePopup.addItems(withTitles: ["A - Album-art dominant", "B - Compact bar", "C - Minimal"])
        nowPlayingStylePopup.target = self
        nowPlayingStylePopup.action = #selector(nowPlayingStyleChanged)
        stack.addArrangedSubview(labeled("Style", control: nowPlayingStylePopup))

        nowPlayingReactivitySwitch.target = self
        nowPlayingReactivitySwitch.action = #selector(nowPlayingReactivityChanged)
        stack.addArrangedSubview(labeled("React to music", control: nowPlayingReactivitySwitch))

        nowPlayingKeepVisibleSwitch.target = self
        nowPlayingKeepVisibleSwitch.action = #selector(nowPlayingKeepVisibleChanged)
        stack.addArrangedSubview(labeled("Keep visible while paused", control: nowPlayingKeepVisibleSwitch))
    }

    private func labeled(_ title: String, control: NSControl) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 150).isActive = true

        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func reloadPackages() {
        packagePopup.removeAllItems()
        for package in packages {
            packagePopup.addItem(withTitle: package.manifest.name)
            packagePopup.lastItem?.representedObject = package.manifest.id
        }
    }

    private var selectedPackage: LunoPackageRecord? {
        let index = packagePopup.indexOfSelectedItem
        guard packages.indices.contains(index) else { return nil }
        return packages[index]
    }

    private var selectedDisplayID: CGDirectDisplayID? {
        guard let number = displayPopup.selectedItem?.representedObject as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private func selectedPreset(for package: LunoPackageRecord) -> WallpaperPreset {
        let values = currentParameterValues(for: package.manifest)
        let safeName = presetNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = safeName.isEmpty ? "Default" : safeName
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

    private func rebuildParameterControls() {
        controlsByParameterID.removeAll()
        parameterStack.arrangedSubviews.forEach {
            parameterStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard let package = selectedPackage else {
            parameterStack.addArrangedSubview(NSTextField(labelWithString: "Import a .luno package to begin."))
            return
        }

        let matchingPreset = presets.first { $0.packageID == package.manifest.id }
        presetNameField.stringValue = matchingPreset?.name ?? "Default"

        for parameter in package.manifest.parameters {
            let currentValue = matchingPreset?.values[parameter.id] ?? parameter.defaultValue
            let control = makeControl(for: parameter, value: currentValue)
            controlsByParameterID[parameter.id] = control
            parameterStack.addArrangedSubview(labeledRow(label: parameter.name, view: control))
        }
    }

    private func makeControl(for parameter: WallpaperParameterDefinition, value: ParameterValue) -> NSControl {
        switch parameter.type {
        case .float:
            let slider = NSSlider(value: value.floatValue ?? 0, minValue: parameter.min ?? 0, maxValue: parameter.max ?? 1, target: nil, action: nil)
            slider.widthAnchor.constraint(equalToConstant: 220).isActive = true
            return slider
        case .bool:
            let button = NSButton(checkboxWithTitle: "", target: nil, action: nil)
            button.state = (value.boolValue ?? false) ? .on : .off
            return button
        case .color:
            let well = NSColorWell()
            well.color = NSColor(hexString: value.stringValue ?? "#FFFFFF") ?? .white
            return well
        case .enum:
            let popup = NSPopUpButton()
            popup.addItems(withTitles: parameter.options ?? [])
            if let selected = value.stringValue {
                popup.selectItem(withTitle: selected)
            }
            popup.widthAnchor.constraint(equalToConstant: 220).isActive = true
            return popup
        }
    }

    private func currentParameterValues(for manifest: WallpaperPackageManifest) -> [String: ParameterValue] {
        var values: [String: ParameterValue] = [:]

        for parameter in manifest.parameters {
            guard let control = controlsByParameterID[parameter.id] else {
                values[parameter.id] = parameter.defaultValue
                continue
            }

            switch parameter.type {
            case .float:
                values[parameter.id] = .float((control as? NSSlider)?.doubleValue ?? parameter.defaultValue.floatValue ?? 0)
            case .bool:
                values[parameter.id] = .bool((control as? NSButton)?.state == .on)
            case .color:
                let color = (control as? NSColorWell)?.color.hexString ?? parameter.defaultValue.stringValue ?? "#FFFFFF"
                values[parameter.id] = .color(color)
            case .enum:
                let selected = (control as? NSPopUpButton)?.selectedItem?.title ?? parameter.defaultValue.stringValue ?? ""
                values[parameter.id] = .string(selected)
            }
        }

        return values
    }

    @objc private func packageSelectionChanged() {
        rebuildParameterControls()
    }

    @objc private func applySelectedPackage() {
        guard let package = selectedPackage else { return }
        delegate?.libraryWindow(
            self,
            didRequestApply: package,
            preset: selectedPreset(for: package),
            displayID: selectedDisplayID
        )
    }

    @objc private func savePreset() {
        guard let package = selectedPackage else { return }
        delegate?.libraryWindow(self, didSave: selectedPreset(for: package))
    }

    @objc private func importPackage() {
        delegate?.libraryWindowDidRequestImport(self)
    }

    @objc private func exportPackage() {
        guard let package = selectedPackage else { return }
        delegate?.libraryWindow(self, didRequestExport: package)
    }

    @objc private func nowPlayingToggleChanged(_ sender: NSSwitch) {
        nowPlayingPreferences.isEnabled = sender.state == .on
        delegate?.libraryWindow(self, didChange: nowPlayingPreferences)
    }

    @objc private func nowPlayingStyleChanged(_ sender: NSPopUpButton) {
        let styles = NowPlayingPreferences.Style.allCases
        let index = sender.indexOfSelectedItem
        guard styles.indices.contains(index) else { return }

        nowPlayingPreferences.style = styles[index]
        delegate?.libraryWindow(self, didChange: nowPlayingPreferences)
    }

    @objc private func nowPlayingReactivityChanged(_ sender: NSSwitch) {
        nowPlayingPreferences.audioReactivityEnabled = sender.state == .on
        delegate?.libraryWindow(self, didChange: nowPlayingPreferences)
    }

    @objc private func nowPlayingKeepVisibleChanged(_ sender: NSSwitch) {
        nowPlayingPreferences.keepVisibleWhilePaused = sender.state == .on
        delegate?.libraryWindow(self, didChange: nowPlayingPreferences)
    }
}

private extension NSColor {
    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let value = Int(hex, radix: 16) else {
            return nil
        }
        self.init(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255.0,
            green: CGFloat((value >> 8) & 0xFF) / 255.0,
            blue: CGFloat(value & 0xFF) / 255.0,
            alpha: 1
        )
    }

    var hexString: String {
        let color = usingColorSpace(.deviceRGB) ?? self
        return String(
            format: "#%02X%02X%02X",
            Int(round(color.redComponent * 255)),
            Int(round(color.greenComponent * 255)),
            Int(round(color.blueComponent * 255))
        )
    }
}
