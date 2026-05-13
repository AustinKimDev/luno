// Sources/LunoApp/Settings/NowPlayingAppearanceSectionView.swift
import AppKit
import LunoEngineCore

@MainActor
protocol NowPlayingAppearanceSectionViewDelegate: AnyObject {
    func nowPlayingAppearanceSection(_ view: NowPlayingAppearanceSectionView, didChange appearance: NowPlayingAppearance)
}

@MainActor
final class NowPlayingAppearanceSectionView: NSView {
    weak var delegate: NowPlayingAppearanceSectionViewDelegate?

    private let presetPopup = NSPopUpButton()
    private let cornerSlider = LabeledValueSlider(minValue: 0, maxValue: 28)
    private let paddingSlider = LabeledValueSlider(minValue: 8, maxValue: 24)
    private let borderWidthSlider = LabeledValueSlider(minValue: 0, maxValue: 6)
    private let borderOpacitySlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let titleWeightPopup = NSPopUpButton()
    private let subtitleWeightPopup = NSPopUpButton()
    private let textColorWell = NSColorWell()
    private let accentColorWell = NSColorWell()
    private let glowColorWell = NSColorWell()

    private var widgetAppearance: NowPlayingAppearance = .default
    private var isInternallyUpdating = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func configure(_ appearance: NowPlayingAppearance) {
        self.widgetAppearance = appearance
        isInternallyUpdating = true
        defer { isInternallyUpdating = false }

        rebuildPresetMenu(selecting: appearance)
        cornerSlider.value = appearance.cornerRadius
        paddingSlider.value = appearance.padding
        borderWidthSlider.value = appearance.borderWidth
        borderOpacitySlider.value = appearance.borderOpacity
        selectWeight(titleWeightPopup, appearance.titleWeight)
        selectWeight(subtitleWeightPopup, appearance.subtitleWeight)
        textColorWell.color = NSColor(hexString: appearance.textColor) ?? .white
        accentColorWell.color = NSColor(hexString: appearance.accentColor) ?? .white
        glowColorWell.color = NSColor(hexString: appearance.glowTint) ?? .white
    }

    private func buildLayout() {
        translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20)
        ])

        let heading = NSTextField(labelWithString: "Appearance")
        heading.font = .boldSystemFont(ofSize: 13)
        stack.addArrangedSubview(heading)

        presetPopup.target = self
        presetPopup.action = #selector(presetChanged)
        stack.addArrangedSubview(labeled("Preset", control: presetPopup))

        cornerSlider.onChange = { [weak self] value in self?.appearanceField(\.cornerRadius, value) }
        paddingSlider.onChange = { [weak self] value in self?.appearanceField(\.padding, value) }
        borderWidthSlider.onChange = { [weak self] value in self?.appearanceField(\.borderWidth, value) }
        borderOpacitySlider.onChange = { [weak self] value in self?.appearanceField(\.borderOpacity, value) }
        stack.addArrangedSubview(labeled("Corner radius", control: cornerSlider))
        stack.addArrangedSubview(labeled("Padding", control: paddingSlider))
        stack.addArrangedSubview(labeled("Border width", control: borderWidthSlider))
        stack.addArrangedSubview(labeled("Border opacity", control: borderOpacitySlider))

        configureWeightPopup(titleWeightPopup, selector: #selector(titleWeightChanged))
        configureWeightPopup(subtitleWeightPopup, selector: #selector(subtitleWeightChanged))
        stack.addArrangedSubview(labeled("Title weight", control: titleWeightPopup))
        stack.addArrangedSubview(labeled("Subtitle weight", control: subtitleWeightPopup))

        configureColorWell(textColorWell, selector: #selector(textColorChanged))
        configureColorWell(accentColorWell, selector: #selector(accentColorChanged))
        configureColorWell(glowColorWell, selector: #selector(glowColorChanged))
        stack.addArrangedSubview(labeled("Text color", control: textColorWell))
        stack.addArrangedSubview(labeled("Accent color", control: accentColorWell))
        stack.addArrangedSubview(labeled("Glow tint", control: glowColorWell))

        rebuildPresetMenu(selecting: widgetAppearance)
    }

    private func labeled(_ title: String, control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 150).isActive = true
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func configureWeightPopup(_ popup: NSPopUpButton, selector: Selector) {
        popup.removeAllItems()
        for weight in NowPlayingAppearance.FontWeight.allCases {
            popup.addItem(withTitle: weight.displayName)
        }
        popup.target = self
        popup.action = selector
        popup.widthAnchor.constraint(equalToConstant: 160).isActive = true
    }

    private func configureColorWell(_ well: NSColorWell, selector: Selector) {
        well.target = self
        well.action = selector
        well.widthAnchor.constraint(equalToConstant: 60).isActive = true
        well.heightAnchor.constraint(equalToConstant: 24).isActive = true
    }

    private func selectWeight(_ popup: NSPopUpButton, _ weight: NowPlayingAppearance.FontWeight) {
        guard let index = NowPlayingAppearance.FontWeight.allCases.firstIndex(of: weight) else { return }
        popup.selectItem(at: index)
    }

    private func rebuildPresetMenu(selecting appearance: NowPlayingAppearance) {
        presetPopup.removeAllItems()
        for preset in NowPlayingAppearance.presets {
            presetPopup.addItem(withTitle: preset.name)
            presetPopup.lastItem?.representedObject = preset.id
        }
        presetPopup.menu?.addItem(.separator())
        let customItem = NSMenuItem(title: "Custom", action: nil, keyEquivalent: "")
        customItem.representedObject = "custom"
        customItem.isEnabled = false
        presetPopup.menu?.addItem(customItem)

        if let match = appearance.matchingPreset(),
           let index = NowPlayingAppearance.presets.firstIndex(where: { $0.id == match.id }) {
            presetPopup.selectItem(at: index)
        } else {
            // Select the Custom item (the very last entry)
            presetPopup.selectItem(at: presetPopup.numberOfItems - 1)
        }
    }

    private func appearanceField(_ keyPath: WritableKeyPath<NowPlayingAppearance, Double>, _ value: Double) {
        guard !isInternallyUpdating else { return }
        widgetAppearance[keyPath: keyPath] = value
        commit(reconciledFromColorWells: false)
    }

    private func commit(reconciledFromColorWells: Bool) {
        if reconciledFromColorWells {
            widgetAppearance.textColor = textColorWell.color.hexString
            widgetAppearance.accentColor = accentColorWell.color.hexString
            widgetAppearance.glowTint = glowColorWell.color.hexString
        }
        // Re-clamp through the initializer so out-of-range slider values are normalized.
        let clamped = NowPlayingAppearance(
            cornerRadius: widgetAppearance.cornerRadius,
            padding: widgetAppearance.padding,
            borderWidth: widgetAppearance.borderWidth,
            borderOpacity: widgetAppearance.borderOpacity,
            titleWeight: widgetAppearance.titleWeight,
            subtitleWeight: widgetAppearance.subtitleWeight,
            textColor: widgetAppearance.textColor,
            accentColor: widgetAppearance.accentColor,
            glowTint: widgetAppearance.glowTint,
            scaleReaction: widgetAppearance.scaleReaction,
            glowReaction: widgetAppearance.glowReaction,
            borderReaction: widgetAppearance.borderReaction
        )
        widgetAppearance = clamped
        rebuildPresetMenu(selecting: widgetAppearance)
        delegate?.nowPlayingAppearanceSection(self, didChange: widgetAppearance)
    }

    @objc private func presetChanged(_ sender: NSPopUpButton) {
        guard let id = sender.selectedItem?.representedObject as? String,
              let preset = NowPlayingAppearance.presets.first(where: { $0.id == id })
        else { return }
        configure(preset.appearance)
        delegate?.nowPlayingAppearanceSection(self, didChange: preset.appearance)
    }

    @objc private func titleWeightChanged(_ sender: NSPopUpButton) {
        guard !isInternallyUpdating else { return }
        let weights = NowPlayingAppearance.FontWeight.allCases
        guard weights.indices.contains(sender.indexOfSelectedItem) else { return }
        widgetAppearance.titleWeight = weights[sender.indexOfSelectedItem]
        commit(reconciledFromColorWells: false)
    }

    @objc private func subtitleWeightChanged(_ sender: NSPopUpButton) {
        guard !isInternallyUpdating else { return }
        let weights = NowPlayingAppearance.FontWeight.allCases
        guard weights.indices.contains(sender.indexOfSelectedItem) else { return }
        widgetAppearance.subtitleWeight = weights[sender.indexOfSelectedItem]
        commit(reconciledFromColorWells: false)
    }

    @objc private func textColorChanged(_ sender: NSColorWell) {
        guard !isInternallyUpdating else { return }
        commit(reconciledFromColorWells: true)
    }

    @objc private func accentColorChanged(_ sender: NSColorWell) {
        guard !isInternallyUpdating else { return }
        commit(reconciledFromColorWells: true)
    }

    @objc private func glowColorChanged(_ sender: NSColorWell) {
        guard !isInternallyUpdating else { return }
        commit(reconciledFromColorWells: true)
    }
}

private extension NowPlayingAppearance.FontWeight {
    var displayName: String {
        switch self {
        case .regular: "Regular"
        case .medium: "Medium"
        case .semibold: "Semibold"
        case .bold: "Bold"
        case .heavy: "Heavy"
        case .black: "Black"
        }
    }
}

@MainActor
final class LabeledValueSlider: NSStackView {
    private let slider = NSSlider()
    private let valueLabel = NSTextField(labelWithString: "")
    private let displayAsPercent: Bool

    var onChange: ((Double) -> Void)?

    var value: Double {
        get { slider.doubleValue }
        set {
            slider.doubleValue = newValue
            updateLabel()
        }
    }

    /// Not `override` because NSStackView does not declare `isEnabled`.
    var isEnabled: Bool {
        get { slider.isEnabled }
        set {
            slider.isEnabled = newValue
            valueLabel.alphaValue = newValue ? 1 : 0.4
        }
    }

    init(minValue: Double, maxValue: Double, displayAsPercent: Bool = false) {
        self.displayAsPercent = displayAsPercent
        super.init(frame: .zero)

        slider.minValue = minValue
        slider.maxValue = maxValue
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.widthAnchor.constraint(equalToConstant: 180).isActive = true

        valueLabel.alignment = .right
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true

        orientation = .horizontal
        alignment = .centerY
        spacing = 8
        setViews([slider, valueLabel], in: .leading)
        updateLabel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    @objc private func sliderChanged() {
        updateLabel()
        onChange?(slider.doubleValue)
    }

    private func updateLabel() {
        if displayAsPercent {
            valueLabel.stringValue = "\(Int(round(slider.doubleValue * 100)))%"
        } else {
            valueLabel.stringValue = String(format: "%.0f", slider.doubleValue)
        }
    }
}
