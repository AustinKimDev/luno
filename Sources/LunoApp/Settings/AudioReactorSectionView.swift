// Sources/LunoApp/Settings/AudioReactorSectionView.swift
import AppKit
import LunoEngineCore

@MainActor
protocol AudioReactorSectionViewDelegate: AnyObject {
    func audioReactorSection(_ view: AudioReactorSectionView, didChange preferences: AudioReactorPreferences)
}

@MainActor
final class AudioReactorSectionView: NSView {
    weak var delegate: AudioReactorSectionViewDelegate?

    private let previewView = AudioReactorPreviewView()
    private let presetPopup = NSPopUpButton()
    private let enableSwitch = NSSwitch()
    private let intensitySlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let responseControl = NSSegmentedControl(labels: ["Soft", "Punchy", "Hard"], trackingMode: .selectOne, target: nil, action: nil)
    private let overlayOpacitySlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let scaleSlider = LabeledValueSlider(minValue: 0.5, maxValue: 1.5, displayAsPercent: true)
    private let layerPopup = NSPopUpButton()
    private let addLayerButton = NSButton(title: "+", target: nil, action: nil)
    private let removeLayerButton = NSButton(title: "-", target: nil, action: nil)

    private let primaryColorWell = NSColorWell()
    private let secondaryColorWell = NSColorWell()
    private let accentColorWell = NSColorWell()
    private let glowColorWell = NSColorWell()
    private let paletteSourcePopup = NSPopUpButton()

    private let albumModeControl = NSSegmentedControl(
        labels: ["Match", "Contrast", "Vivid"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let albumModeLabel = NSTextField(labelWithString: "Album mode")
    private lazy var albumModeRow: NSStackView = {
        let stack = NSStackView(views: [albumModeLabel, albumModeControl])
        stack.orientation = .horizontal
        stack.spacing = 8
        return stack
    }()

    private let spectrumLayoutPopup = NSPopUpButton()
    private let spectrumBarCountSlider = LabeledValueSlider(minValue: 8, maxValue: 96)
    private let spectrumBarWidthSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let spectrumBarHeightSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let spectrumSpacingSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let spectrumRadiusSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let spectrumRoundnessSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let spectrumSmoothingSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let spectrumGlowSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let spectrumArcStartSlider = LabeledValueSlider(minValue: -180, maxValue: 180)
    private let spectrumArcEndSlider = LabeledValueSlider(minValue: -180, maxValue: 180)

    private let mirrorSpectrumSwitch = NSSwitch()
    private let colorCycleSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)

    private var preferences: AudioReactorPreferences = .defaults
    private var isInternallyUpdating = false
    private var selectedLayerID: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func configure(_ preferences: AudioReactorPreferences) {
        self.preferences = preferences
        isInternallyUpdating = true
        defer {
            isInternallyUpdating = false
            previewView.configure(preferences)
            applyEnabledState()
        }

        rebuildPresetMenu()
        enableSwitch.state = preferences.isEnabled ? .on : .off
        intensitySlider.value = preferences.intensity
        responseControl.selectedSegment = AudioReactorResponse.allCases.firstIndex(of: preferences.response) ?? 1
        overlayOpacitySlider.value = preferences.overlayOpacity
        scaleSlider.value = preferences.style.scale
        if selectedLayerID == nil || !preferences.style.spectrumLayers.contains(where: { $0.id == selectedLayerID }) {
            selectedLayerID = preferences.style.spectrumLayers.first?.id
        }

        primaryColorWell.color = NSColor(hexString: preferences.style.palette.primaryColor) ?? .white
        secondaryColorWell.color = NSColor(hexString: preferences.style.palette.secondaryColor) ?? .white
        accentColorWell.color = NSColor(hexString: preferences.style.palette.accentColor) ?? .white
        glowColorWell.color = NSColor(hexString: preferences.style.palette.glowColor) ?? .white
        selectPaletteSource(preferences.style.palette.source)
        let modeIndex = AudioReactorAlbumColorMode.allCases.firstIndex(of: preferences.style.palette.albumColorMode) ?? 1
        albumModeControl.selectedSegment = modeIndex
        albumModeRow.isHidden = preferences.style.palette.source != .albumArtwork

        rebuildLayerMenu()
        updateLayerControls()

        colorCycleSlider.value = preferences.style.colorCycle
    }

    private func buildLayout() {
        translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = content
        addSubview(scrollView)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])

        let heading = NSTextField(labelWithString: "Audio Reactor")
        heading.font = .boldSystemFont(ofSize: 13)
        stack.addArrangedSubview(heading)

        presetPopup.target = self
        presetPopup.action = #selector(presetChanged)
        presetPopup.widthAnchor.constraint(equalToConstant: 180).isActive = true
        stack.addArrangedSubview(labeled("Preset", control: presetPopup))

        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.heightAnchor.constraint(equalToConstant: 168).isActive = true
        previewView.widthAnchor.constraint(greaterThanOrEqualToConstant: 420).isActive = true
        stack.addArrangedSubview(previewView)

        stack.addArrangedSubview(group("Core", rows: [
            labeled("Enabled", control: enableSwitch),
            labeled("Intensity", control: intensitySlider),
            labeled("Response", control: responseControl),
            labeled("Overlay opacity", control: overlayOpacitySlider),
            labeled("Scale", control: scaleSlider)
        ]))

        stack.addArrangedSubview(group("Palette", rows: [
            labeled("Color source", control: paletteSourcePopup),
            albumModeRow,
            labeled("Primary", control: primaryColorWell),
            labeled("Secondary", control: secondaryColorWell),
            labeled("Accent", control: accentColorWell),
            labeled("Glow", control: glowColorWell)
        ]))

        configureLayoutPopup(spectrumLayoutPopup, selector: #selector(spectrumLayoutChanged))
        stack.addArrangedSubview(group("Spectrum Layers", rows: [
            layerControlsRow(),
            labeled("Layout", control: spectrumLayoutPopup),
            labeled("Count", control: spectrumBarCountSlider),
            labeled("Width", control: spectrumBarWidthSlider),
            labeled("Height", control: spectrumBarHeightSlider),
            labeled("Spacing", control: spectrumSpacingSlider),
            labeled("Radius", control: spectrumRadiusSlider),
            labeled("Roundness", control: spectrumRoundnessSlider),
            labeled("Smoothing", control: spectrumSmoothingSlider),
            labeled("Glow", control: spectrumGlowSlider),
            labeled("Arc start", control: spectrumArcStartSlider),
            labeled("Arc end", control: spectrumArcEndSlider)
        ]))

        stack.addArrangedSubview(makeAdvancedGroup())

        wireActions()
        rebuildPresetMenu()
    }

    private func wireActions() {
        enableSwitch.target = self
        enableSwitch.action = #selector(enabledChanged)
        responseControl.target = self
        responseControl.action = #selector(responseChanged)
        layerPopup.target = self
        layerPopup.action = #selector(layerSelectionChanged)
        addLayerButton.target = self
        addLayerButton.action = #selector(addLayer)
        removeLayerButton.target = self
        removeLayerButton.action = #selector(removeLayer)

        intensitySlider.onChange = { [weak self] value in self?.commitField { $0.intensity = value } }
        overlayOpacitySlider.onChange = { [weak self] value in self?.commitField { $0.overlayOpacity = value } }
        scaleSlider.onChange = { [weak self] value in self?.styleField { $0.scale = value } }

        configureColorWell(primaryColorWell, selector: #selector(colorChanged))
        configureColorWell(secondaryColorWell, selector: #selector(colorChanged))
        configureColorWell(accentColorWell, selector: #selector(colorChanged))
        configureColorWell(glowColorWell, selector: #selector(colorChanged))
        configurePaletteSourcePopup()
        albumModeControl.target = self
        albumModeControl.action = #selector(albumModeChanged)

        spectrumBarCountSlider.onChange = { [weak self] value in self?.layerField { $0.spectrum.barCount = Int(round(value)) } }
        spectrumBarWidthSlider.onChange = { [weak self] value in self?.layerField { $0.spectrum.barWidth = value } }
        spectrumBarHeightSlider.onChange = { [weak self] value in self?.layerField { $0.spectrum.barHeight = value } }
        spectrumSpacingSlider.onChange = { [weak self] value in self?.layerField { $0.spectrum.spacing = value } }
        spectrumRadiusSlider.onChange = { [weak self] value in self?.layerField { $0.spectrum.radius = value } }
        spectrumRoundnessSlider.onChange = { [weak self] value in self?.layerField { $0.spectrum.roundness = value } }
        spectrumSmoothingSlider.onChange = { [weak self] value in self?.layerField { $0.spectrum.smoothing = value } }
        spectrumGlowSlider.onChange = { [weak self] value in self?.layerField { $0.spectrum.glow = value } }
        spectrumArcStartSlider.onChange = { [weak self] value in self?.layerField { $0.spectrum.arcStartDegrees = value } }
        spectrumArcEndSlider.onChange = { [weak self] value in self?.layerField { $0.spectrum.arcEndDegrees = value } }

        mirrorSpectrumSwitch.target = self
        mirrorSpectrumSwitch.action = #selector(mirrorSpectrumChanged)
        colorCycleSlider.onChange = { [weak self] value in self?.styleField { $0.colorCycle = value } }
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

    private func layerControlsRow() -> NSStackView {
        layerPopup.widthAnchor.constraint(equalToConstant: 180).isActive = true
        addLayerButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        removeLayerButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        let controls = NSStackView(views: [layerPopup, addLayerButton, removeLayerButton])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 6
        return labeled("Layer", control: controls)
    }

    private func group(_ title: String, rows: [NSView]) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 4, right: 0)
        stack.addArrangedSubview(label)
        rows.forEach(stack.addArrangedSubview)
        return stack
    }

    private func configureColorWell(_ well: NSColorWell, selector: Selector) {
        well.target = self
        well.action = selector
        well.widthAnchor.constraint(equalToConstant: 62).isActive = true
        well.heightAnchor.constraint(equalToConstant: 24).isActive = true
    }

    private func configureLayoutPopup(_ popup: NSPopUpButton, selector: Selector) {
        popup.removeAllItems()
        for layout in AudioReactorVisualizerLayout.allCases {
            popup.addItem(withTitle: layout.displayName)
            popup.lastItem?.representedObject = layout.rawValue
        }
        popup.target = self
        popup.action = selector
        popup.widthAnchor.constraint(equalToConstant: 180).isActive = true
    }

    private func configurePaletteSourcePopup() {
        paletteSourcePopup.removeAllItems()
        for source in AudioReactorPaletteSource.allCases {
            paletteSourcePopup.addItem(withTitle: source.displayName)
            paletteSourcePopup.lastItem?.representedObject = source.rawValue
        }
        paletteSourcePopup.target = self
        paletteSourcePopup.action = #selector(paletteSourceChanged)
        paletteSourcePopup.widthAnchor.constraint(equalToConstant: 180).isActive = true
    }

    private func selectLayout(_ popup: NSPopUpButton, _ layout: AudioReactorVisualizerLayout) {
        guard let index = AudioReactorVisualizerLayout.allCases.firstIndex(of: layout) else { return }
        popup.selectItem(at: index)
    }

    private func makeAdvancedGroup() -> NSStackView {
        group("Advanced", rows: [
            labeled("Mirror spectrum", control: mirrorSpectrumSwitch),
            labeled("Color cycle", control: colorCycleSlider)
        ])
    }

    private func selectPaletteSource(_ source: AudioReactorPaletteSource) {
        guard let index = AudioReactorPaletteSource.allCases.firstIndex(of: source) else { return }
        paletteSourcePopup.selectItem(at: index)
    }

    private func rebuildPresetMenu() {
        presetPopup.removeAllItems()
        for preset in AudioReactorStyle.presets {
            presetPopup.addItem(withTitle: preset.name)
            presetPopup.lastItem?.representedObject = preset.id
        }
        presetPopup.menu?.addItem(.separator())
        let customItem = NSMenuItem(title: "Custom", action: nil, keyEquivalent: "")
        customItem.representedObject = "custom"
        customItem.isEnabled = false
        presetPopup.menu?.addItem(customItem)

        if let presetID = preferences.style.presetID,
           let index = AudioReactorStyle.presets.firstIndex(where: { $0.id == presetID }) {
            presetPopup.selectItem(at: index)
        } else {
            presetPopup.selectItem(at: presetPopup.numberOfItems - 1)
        }
    }

    private func rebuildLayerMenu() {
        layerPopup.removeAllItems()
        for layer in preferences.style.spectrumLayers {
            layerPopup.addItem(withTitle: layer.name)
            layerPopup.lastItem?.representedObject = layer.id
        }
        if let selectedLayerID,
           let index = preferences.style.spectrumLayers.firstIndex(where: { $0.id == selectedLayerID }) {
            layerPopup.selectItem(at: index)
        } else if !preferences.style.spectrumLayers.isEmpty {
            selectedLayerID = preferences.style.spectrumLayers[0].id
            layerPopup.selectItem(at: 0)
        } else {
            selectedLayerID = nil
        }
    }

    private func updateLayerControls() {
        guard let layer = selectedLayer else {
            selectLayout(spectrumLayoutPopup, .bottom)
            spectrumBarCountSlider.value = 8
            spectrumBarWidthSlider.value = 0
            spectrumBarHeightSlider.value = 0
            spectrumSpacingSlider.value = 0
            spectrumRadiusSlider.value = 0
            spectrumRoundnessSlider.value = 0
            spectrumSmoothingSlider.value = 0
            spectrumGlowSlider.value = 0
            spectrumArcStartSlider.value = -150
            spectrumArcEndSlider.value = 150
            mirrorSpectrumSwitch.state = .off
            return
        }

        selectLayout(spectrumLayoutPopup, layer.spectrum.layout)
        spectrumBarCountSlider.value = Double(layer.spectrum.barCount)
        spectrumBarWidthSlider.value = layer.spectrum.barWidth
        spectrumBarHeightSlider.value = layer.spectrum.barHeight
        spectrumSpacingSlider.value = layer.spectrum.spacing
        spectrumRadiusSlider.value = layer.spectrum.radius
        spectrumRoundnessSlider.value = layer.spectrum.roundness
        spectrumSmoothingSlider.value = layer.spectrum.smoothing
        spectrumGlowSlider.value = layer.spectrum.glow
        spectrumArcStartSlider.value = layer.spectrum.arcStartDegrees
        spectrumArcEndSlider.value = layer.spectrum.arcEndDegrees
        mirrorSpectrumSwitch.state = layer.spectrum.mirrored ? .on : .off
    }

    private var selectedLayer: AudioReactorSpectrumLayer? {
        guard let selectedLayerID else { return nil }
        return preferences.style.spectrumLayers.first { $0.id == selectedLayerID }
    }

    private func applyEnabledState() {
        let active = preferences.isEnabled
        [
            intensitySlider,
            overlayOpacitySlider,
            scaleSlider,
            spectrumBarCountSlider,
            spectrumBarWidthSlider,
            spectrumBarHeightSlider,
            spectrumSpacingSlider,
            spectrumRadiusSlider,
            spectrumRoundnessSlider,
            spectrumSmoothingSlider,
            spectrumGlowSlider,
            spectrumArcStartSlider,
            spectrumArcEndSlider,
            colorCycleSlider
        ].forEach { $0.isEnabled = active }

        [
            responseControl,
            layerPopup,
            addLayerButton,
            removeLayerButton,
            primaryColorWell,
            secondaryColorWell,
            accentColorWell,
            glowColorWell,
            paletteSourcePopup,
            spectrumLayoutPopup,
            albumModeControl,
            mirrorSpectrumSwitch
        ].forEach { $0.isEnabled = active }

        let hasLayer = active && selectedLayerID != nil
        removeLayerButton.isEnabled = active && selectedLayerID != nil
        spectrumBarCountSlider.isEnabled = hasLayer
        spectrumBarWidthSlider.isEnabled = hasLayer
        spectrumBarHeightSlider.isEnabled = hasLayer
        spectrumSpacingSlider.isEnabled = hasLayer
        spectrumRadiusSlider.isEnabled = hasLayer
        spectrumRoundnessSlider.isEnabled = hasLayer
        spectrumSmoothingSlider.isEnabled = hasLayer
        spectrumGlowSlider.isEnabled = hasLayer
        spectrumArcStartSlider.isEnabled = hasLayer
        spectrumArcEndSlider.isEnabled = hasLayer
        spectrumLayoutPopup.isEnabled = hasLayer
        mirrorSpectrumSwitch.isEnabled = hasLayer

        let usesManualColors = active && preferences.style.palette.source == .manual
        [primaryColorWell, secondaryColorWell, accentColorWell, glowColorWell].forEach {
            $0.isEnabled = usesManualColors
        }
    }

    private func commitField(_ mutate: (inout AudioReactorPreferences) -> Void) {
        guard !isInternallyUpdating else { return }
        mutate(&preferences)
        previewView.configure(preferences)
        delegate?.audioReactorSection(self, didChange: preferences)
    }

    private func styleField(_ mutate: (inout AudioReactorStyle) -> Void) {
        commitField {
            $0.style.presetID = nil
            mutate(&$0.style)
        }
        isInternallyUpdating = true
        rebuildPresetMenu()
        isInternallyUpdating = false
    }

    private func layerField(_ mutate: (inout AudioReactorSpectrumLayer) -> Void) {
        guard let selectedLayerID else { return }
        commitField { preferences in
            guard let index = preferences.style.spectrumLayers.firstIndex(where: { $0.id == selectedLayerID }) else { return }
            preferences.style.presetID = nil
            mutate(&preferences.style.spectrumLayers[index])
            preferences.style.spectrum = preferences.style.spectrumLayers[index].spectrum
        }
        isInternallyUpdating = true
        rebuildPresetMenu()
        rebuildLayerMenu()
        isInternallyUpdating = false
    }

    @objc private func presetChanged(_ sender: NSPopUpButton) {
        guard !isInternallyUpdating,
              let id = sender.selectedItem?.representedObject as? String,
              let presetID = AudioReactorStylePresetID(rawValue: id)
        else { return }
        let updated = AudioReactorStyle.preset(presetID)
        preferences.style = updated
        configure(preferences)
        delegate?.audioReactorSection(self, didChange: preferences)
    }

    @objc private func enabledChanged(_ sender: NSSwitch) {
        commitField { $0.isEnabled = sender.state == .on }
        applyEnabledState()
    }

    @objc private func responseChanged(_ sender: NSSegmentedControl) {
        guard !isInternallyUpdating else { return }
        let cases = AudioReactorResponse.allCases
        guard cases.indices.contains(sender.selectedSegment) else { return }
        commitField { $0.response = cases[sender.selectedSegment] }
    }

    @objc private func colorChanged(_ sender: NSColorWell) {
        guard !isInternallyUpdating else { return }
        styleField {
            $0.palette = AudioReactorPalette(
                source: .manual,
                primaryColor: primaryColorWell.color.hexString,
                secondaryColor: secondaryColorWell.color.hexString,
                accentColor: accentColorWell.color.hexString,
                glowColor: glowColorWell.color.hexString
            )
        }
    }

    @objc private func paletteSourceChanged(_ sender: NSPopUpButton) {
        guard !isInternallyUpdating,
              let rawValue = sender.selectedItem?.representedObject as? String,
              let source = AudioReactorPaletteSource(rawValue: rawValue)
        else { return }
        styleField { $0.palette.source = source }
        albumModeRow.isHidden = source != .albumArtwork
        applyEnabledState()
    }

    @objc private func albumModeChanged(_ sender: NSSegmentedControl) {
        guard let mode = AudioReactorAlbumColorMode.allCases[safe: sender.selectedSegment] else { return }
        commitField { $0.style.palette.albumColorMode = mode }
    }

    @objc private func spectrumLayoutChanged(_ sender: NSPopUpButton) {
        guard !isInternallyUpdating,
              let rawValue = sender.selectedItem?.representedObject as? String,
              let layout = AudioReactorVisualizerLayout(rawValue: rawValue)
        else { return }
        layerField { $0.spectrum.layout = layout }
    }

    @objc private func mirrorSpectrumChanged(_ sender: NSSwitch) {
        layerField { $0.spectrum.mirrored = sender.state == .on }
    }

    @objc private func layerSelectionChanged(_ sender: NSPopUpButton) {
        guard !isInternallyUpdating else { return }
        selectedLayerID = sender.selectedItem?.representedObject as? String
        isInternallyUpdating = true
        updateLayerControls()
        applyEnabledState()
        isInternallyUpdating = false
    }

    @objc private func addLayer(_ sender: NSButton) {
        guard !isInternallyUpdating else { return }
        var updated = preferences
        if let addedID = updated.addSpectrumLayer(duplicating: selectedLayerID) {
            selectedLayerID = addedID
        }
        configure(updated)
        delegate?.audioReactorSection(self, didChange: preferences)
    }

    @objc private func removeLayer(_ sender: NSButton) {
        guard !isInternallyUpdating, let selectedLayerID else { return }
        var updated = preferences
        updated.removeSpectrumLayer(id: selectedLayerID)
        self.selectedLayerID = updated.style.spectrumLayers.first?.id
        configure(updated)
        delegate?.audioReactorSection(self, didChange: preferences)
    }
}

private extension AudioReactorVisualizerLayout {
    var displayName: String {
        switch self {
        case .bottom: "Bottom"
        case .circle: "Circle"
        case .arc: "Arc"
        }
    }
}

private extension AudioReactorPaletteSource {
    var displayName: String {
        switch self {
        case .manual: "Manual"
        case .albumArtwork: "Album Artwork"
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}

@MainActor
private final class AudioReactorPreviewView: NSView {
    private var preferences: AudioReactorPreferences = .defaults
    private let sampleValues: [Double] = (0..<96).map { index in
        let x = Double(index) / 95
        return 0.18 + 0.52 * abs(sin(x * .pi * 3.3)) + 0.22 * abs(sin(x * .pi * 11.0))
    }

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func configure(_ preferences: AudioReactorPreferences) {
        self.preferences = preferences
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let rect = bounds.insetBy(dx: 1, dy: 1)
        context.setFillColor(NSColor(calibratedWhite: 0.055, alpha: 1).cgColor)
        context.fill(bounds)

        let resolvedPalette = preferences.style.palette.resolved(with: .fallback)
        for layer in preferences.activeSpectrumLayers {
            var style = preferences.style
            style.palette = resolvedPalette
            style.spectrum = layer.spectrum
            drawSpectrum(in: rect, style: style, context: context)
        }

        context.setStrokeColor(NSColor.white.withAlphaComponent(0.08).cgColor)
        context.stroke(rect, width: 1)
    }

    private func drawSpectrum(in rect: CGRect, style: AudioReactorStyle, context: CGContext) {
        switch style.spectrum.layout {
        case .bottom:
            drawBottomBars(in: rect, style: style, context: context)
        case .circle, .arc:
            drawRadialBars(in: rect, style: style, context: context)
        }
    }

    private func drawBottomBars(in rect: CGRect, style: AudioReactorStyle, context: CGContext) {
        let count = min(style.spectrum.barCount, sampleValues.count)
        let scale = CGFloat(style.scale)
        let railWidth = rect.width * min(max(0.85 * scale, 0.52), 0.9)
        let rail = CGRect(
            x: rect.midX - railWidth / 2,
            y: rect.minY + 24,
            width: railWidth,
            height: rect.height - 48
        )
        let cellWidth = rail.width / CGFloat(count)
        let baseY = rect.maxY - 26
        let colorA = NSColor(hexString: style.palette.primaryColor) ?? .systemCyan
        let colorB = NSColor(hexString: style.palette.secondaryColor) ?? .systemPink

        for index in 0..<count {
            let value = sampleValues[index]
            let height = CGFloat(10 + value * (44 + style.spectrum.barHeight * 56)) * scale
            let width = cellWidth * CGFloat(0.18 + style.spectrum.barWidth * 0.48) * CGFloat(1.15 - style.spectrum.spacing * 0.45)
            let x = rail.minX + CGFloat(index) * cellWidth + (cellWidth - width) / 2
            let y = baseY - height
            let color = colorA.blended(withFraction: CGFloat(index) / CGFloat(max(count - 1, 1)), of: colorB) ?? colorA
            context.setFillColor(color.withAlphaComponent(0.74).cgColor)
            roundedPath(CGRect(x: x, y: y, width: width, height: height), radius: min(width, height) * CGFloat(style.spectrum.roundness) * 0.5).fill()
        }
    }

    private func drawRadialBars(in rect: CGRect, style: AudioReactorStyle, context: CGContext) {
        let count = min(style.spectrum.barCount, sampleValues.count)
        let center = CGPoint(x: rect.midX, y: rect.midY + 4)
        let scale = CGFloat(style.scale)
        let baseRadius = min(rect.width, rect.height) * CGFloat(0.18 + style.spectrum.radius * 0.28) * scale
        let colorA = NSColor(hexString: style.palette.primaryColor) ?? .systemCyan
        let colorB = NSColor(hexString: style.palette.accentColor) ?? .systemPurple
        let start = style.spectrum.layout == .circle ? -180 : style.spectrum.arcStartDegrees
        let end = style.spectrum.layout == .circle ? 180 : style.spectrum.arcEndDegrees

        context.setLineCap(.round)
        context.setLineWidth(max(1.5, 2 + CGFloat(style.spectrum.barWidth) * 5))
        for index in 0..<count {
            let unit = Double(index) / Double(max(count - 1, 1))
            let angle = (start + (end - start) * unit) * .pi / 180
            let value = sampleValues[index]
            let length = CGFloat(10 + value * (24 + style.spectrum.barHeight * 42)) * scale
            let inner = point(center: center, radius: baseRadius, angle: angle)
            let outer = point(center: center, radius: baseRadius + length, angle: angle)
            let color = colorA.blended(withFraction: CGFloat(unit), of: colorB) ?? colorA
            context.setStrokeColor(color.withAlphaComponent(0.78).cgColor)
            context.move(to: inner)
            context.addLine(to: outer)
            context.strokePath()
        }
    }

    private func roundedPath(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }
}
