// Sources/LunoApp/Settings/LibrarySectionView.swift
import AppKit
import CoreGraphics
import LunoEngineCore

@MainActor
protocol LibrarySectionViewDelegate: AnyObject {
    func librarySectionDidRequestApply(_ view: LibrarySectionView)
    func librarySectionDidRequestSavePreset(_ view: LibrarySectionView)
    func librarySectionDidRequestImport(_ view: LibrarySectionView)
    func librarySectionDidRequestExport(_ view: LibrarySectionView)
    func librarySectionDidChangeLiveSelection(_ view: LibrarySectionView)
}

@MainActor
final class LibrarySectionView: NSView {
    weak var delegate: LibrarySectionViewDelegate?

    static let audioReactiveParameterID = "reactive"

    let packagePopup = NSPopUpButton()
    let displayPopup = NSPopUpButton()
    let presetNameField = NSTextField()
    let parameterStack = NSStackView()

    private(set) var controlsByParameterID: [String: NSControl] = [:]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func buildLayout() {
        translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20)
        ])

        packagePopup.widthAnchor.constraint(equalToConstant: 340).isActive = true
        packagePopup.target = self
        packagePopup.action = #selector(noop)
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
        buttonRow.addArrangedSubview(NSButton(title: "Apply", target: self, action: #selector(applyTapped)))
        buttonRow.addArrangedSubview(NSButton(title: "Save Preset", target: self, action: #selector(saveTapped)))
        buttonRow.addArrangedSubview(NSButton(title: "Import", target: self, action: #selector(importTapped)))
        buttonRow.addArrangedSubview(NSButton(title: "Export", target: self, action: #selector(exportTapped)))
        stack.addArrangedSubview(buttonRow)
    }

    func setPackagePopupTarget(_ target: AnyObject, action: Selector) {
        packagePopup.target = target
        packagePopup.action = action
    }

    func rebuildParameterControls(
        with package: LunoPackageRecord?,
        presets: [WallpaperPreset]
    ) {
        controlsByParameterID.removeAll()
        parameterStack.arrangedSubviews.forEach {
            parameterStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard let package else {
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

        if usesSyntheticAudioReactiveControl(for: package.manifest) {
            let value = matchingPreset?.values[Self.audioReactiveParameterID] ?? .bool(true)
            let control = makeBoolControl(value: value)
            controlsByParameterID[Self.audioReactiveParameterID] = control
            parameterStack.addArrangedSubview(labeledRow(label: "Audio Reactive", view: control))
        }
    }

    @objc private func applyTapped() { delegate?.librarySectionDidRequestApply(self) }
    @objc private func saveTapped() { delegate?.librarySectionDidRequestSavePreset(self) }
    @objc private func importTapped() { delegate?.librarySectionDidRequestImport(self) }
    @objc private func exportTapped() { delegate?.librarySectionDidRequestExport(self) }
    @objc private func parameterControlChanged() { delegate?.librarySectionDidChangeLiveSelection(self) }
    @objc private func noop() {}

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

    private func makeControl(for parameter: WallpaperParameterDefinition, value: ParameterValue) -> NSControl {
        switch parameter.type {
        case .float:
            let slider = NSSlider(
                value: value.floatValue ?? 0,
                minValue: parameter.min ?? 0,
                maxValue: parameter.max ?? 1,
                target: self,
                action: #selector(parameterControlChanged)
            )
            slider.isContinuous = true
            slider.widthAnchor.constraint(equalToConstant: 220).isActive = true
            return slider
        case .bool:
            return makeBoolControl(value: value)
        case .color:
            let well = NSColorWell()
            well.color = NSColor(hexString: value.stringValue ?? "#FFFFFF") ?? .white
            well.target = self
            well.action = #selector(parameterControlChanged)
            return well
        case .enum:
            let popup = NSPopUpButton()
            popup.addItems(withTitles: parameter.options ?? [])
            if let selected = value.stringValue {
                popup.selectItem(withTitle: selected)
            }
            popup.target = self
            popup.action = #selector(parameterControlChanged)
            popup.widthAnchor.constraint(equalToConstant: 220).isActive = true
            return popup
        }
    }

    private func makeBoolControl(value: ParameterValue) -> NSButton {
        let button = NSButton(checkboxWithTitle: "", target: self, action: #selector(parameterControlChanged))
        button.state = (value.boolValue ?? false) ? .on : .off
        return button
    }

    private func usesSyntheticAudioReactiveControl(for manifest: WallpaperPackageManifest) -> Bool {
        !manifest.audioBindings.isEmpty
            && !manifest.parameters.contains { $0.id == Self.audioReactiveParameterID }
    }

    func currentParameterValues(for manifest: WallpaperPackageManifest) -> [String: ParameterValue] {
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
        if usesSyntheticAudioReactiveControl(for: manifest),
           let control = controlsByParameterID[Self.audioReactiveParameterID] as? NSButton {
            values[Self.audioReactiveParameterID] = .bool(control.state == .on)
        }
        return values
    }
}
