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
    private let bassPulseSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let pulseRingSwitch = NSSwitch()
    private let spectrumBarsSwitch = NSSwitch()
    private let waveLineSwitch = NSSwitch()

    private let primaryColorWell = NSColorWell()
    private let secondaryColorWell = NSColorWell()
    private let accentColorWell = NSColorWell()
    private let glowColorWell = NSColorWell()
    private let paletteSourcePopup = NSPopUpButton()

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

    private let ringRadiusSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let ringThicknessSlider = LabeledValueSlider(minValue: 0, maxValue: 0.08, displayAsPercent: true)
    private let ringSoftnessSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let ringGlowSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let ringRoundnessSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)

    private let waveLayoutPopup = NSPopUpButton()
    private let waveThicknessSlider = LabeledValueSlider(minValue: 0, maxValue: 0.08, displayAsPercent: true)
    private let waveAmplitudeSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let waveSmoothingSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let waveGlowSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let waveRadiusSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let waveArcStartSlider = LabeledValueSlider(minValue: -180, maxValue: 180)
    private let waveArcEndSlider = LabeledValueSlider(minValue: -180, maxValue: 180)

    private var preferences: AudioReactorPreferences = .defaults
    private var isInternallyUpdating = false

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
        bassPulseSlider.value = preferences.bassPulseStrength
        pulseRingSwitch.state = preferences.showsPulseRing ? .on : .off
        spectrumBarsSwitch.state = preferences.showsSpectrumBars ? .on : .off
        waveLineSwitch.state = preferences.showsWaveLine ? .on : .off

        primaryColorWell.color = NSColor(hexString: preferences.style.palette.primaryColor) ?? .white
        secondaryColorWell.color = NSColor(hexString: preferences.style.palette.secondaryColor) ?? .white
        accentColorWell.color = NSColor(hexString: preferences.style.palette.accentColor) ?? .white
        glowColorWell.color = NSColor(hexString: preferences.style.palette.glowColor) ?? .white
        selectPaletteSource(preferences.style.palette.source)

        selectLayout(spectrumLayoutPopup, preferences.style.spectrum.layout)
        spectrumBarCountSlider.value = Double(preferences.style.spectrum.barCount)
        spectrumBarWidthSlider.value = preferences.style.spectrum.barWidth
        spectrumBarHeightSlider.value = preferences.style.spectrum.barHeight
        spectrumSpacingSlider.value = preferences.style.spectrum.spacing
        spectrumRadiusSlider.value = preferences.style.spectrum.radius
        spectrumRoundnessSlider.value = preferences.style.spectrum.roundness
        spectrumSmoothingSlider.value = preferences.style.spectrum.smoothing
        spectrumGlowSlider.value = preferences.style.spectrum.glow
        spectrumArcStartSlider.value = preferences.style.spectrum.arcStartDegrees
        spectrumArcEndSlider.value = preferences.style.spectrum.arcEndDegrees

        ringRadiusSlider.value = preferences.style.ring.radius
        ringThicknessSlider.value = preferences.style.ring.thickness
        ringSoftnessSlider.value = preferences.style.ring.softness
        ringGlowSlider.value = preferences.style.ring.glow
        ringRoundnessSlider.value = preferences.style.ring.roundness

        selectLayout(waveLayoutPopup, preferences.style.wave.layout)
        waveThicknessSlider.value = preferences.style.wave.thickness
        waveAmplitudeSlider.value = preferences.style.wave.amplitude
        waveSmoothingSlider.value = preferences.style.wave.smoothing
        waveGlowSlider.value = preferences.style.wave.glow
        waveRadiusSlider.value = preferences.style.wave.radius
        waveArcStartSlider.value = preferences.style.wave.arcStartDegrees
        waveArcEndSlider.value = preferences.style.wave.arcEndDegrees
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
            labeled("Bass pulse", control: bassPulseSlider),
            labeled("Pulse ring", control: pulseRingSwitch),
            labeled("Spectrum bars", control: spectrumBarsSwitch),
            labeled("Wave line", control: waveLineSwitch)
        ]))

        stack.addArrangedSubview(group("Palette", rows: [
            labeled("Color source", control: paletteSourcePopup),
            labeled("Primary", control: primaryColorWell),
            labeled("Secondary", control: secondaryColorWell),
            labeled("Accent", control: accentColorWell),
            labeled("Glow", control: glowColorWell)
        ]))

        configureLayoutPopup(spectrumLayoutPopup, selector: #selector(spectrumLayoutChanged))
        stack.addArrangedSubview(group("Spectrum Bars", rows: [
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

        stack.addArrangedSubview(group("Pulse Ring", rows: [
            labeled("Radius", control: ringRadiusSlider),
            labeled("Weight", control: ringThicknessSlider),
            labeled("Softness", control: ringSoftnessSlider),
            labeled("Glow", control: ringGlowSlider),
            labeled("Roundness", control: ringRoundnessSlider)
        ]))

        configureLayoutPopup(waveLayoutPopup, selector: #selector(waveLayoutChanged))
        stack.addArrangedSubview(group("Wave Line", rows: [
            labeled("Layout", control: waveLayoutPopup),
            labeled("Weight", control: waveThicknessSlider),
            labeled("Height", control: waveAmplitudeSlider),
            labeled("Smoothing", control: waveSmoothingSlider),
            labeled("Glow", control: waveGlowSlider),
            labeled("Radius", control: waveRadiusSlider),
            labeled("Arc start", control: waveArcStartSlider),
            labeled("Arc end", control: waveArcEndSlider)
        ]))

        wireActions()
        rebuildPresetMenu()
    }

    private func wireActions() {
        enableSwitch.target = self
        enableSwitch.action = #selector(enabledChanged)
        responseControl.target = self
        responseControl.action = #selector(responseChanged)
        pulseRingSwitch.target = self
        pulseRingSwitch.action = #selector(pulseRingChanged)
        spectrumBarsSwitch.target = self
        spectrumBarsSwitch.action = #selector(spectrumBarsChanged)
        waveLineSwitch.target = self
        waveLineSwitch.action = #selector(waveLineChanged)

        intensitySlider.onChange = { [weak self] value in self?.commitField { $0.intensity = value } }
        overlayOpacitySlider.onChange = { [weak self] value in self?.commitField { $0.overlayOpacity = value } }
        bassPulseSlider.onChange = { [weak self] value in self?.commitField { $0.bassPulseStrength = value } }

        configureColorWell(primaryColorWell, selector: #selector(colorChanged))
        configureColorWell(secondaryColorWell, selector: #selector(colorChanged))
        configureColorWell(accentColorWell, selector: #selector(colorChanged))
        configureColorWell(glowColorWell, selector: #selector(colorChanged))
        configurePaletteSourcePopup()

        spectrumBarCountSlider.onChange = { [weak self] value in self?.styleField { $0.spectrum.barCount = Int(round(value)) } }
        spectrumBarWidthSlider.onChange = { [weak self] value in self?.styleField { $0.spectrum.barWidth = value } }
        spectrumBarHeightSlider.onChange = { [weak self] value in self?.styleField { $0.spectrum.barHeight = value } }
        spectrumSpacingSlider.onChange = { [weak self] value in self?.styleField { $0.spectrum.spacing = value } }
        spectrumRadiusSlider.onChange = { [weak self] value in self?.styleField { $0.spectrum.radius = value } }
        spectrumRoundnessSlider.onChange = { [weak self] value in self?.styleField { $0.spectrum.roundness = value } }
        spectrumSmoothingSlider.onChange = { [weak self] value in self?.styleField { $0.spectrum.smoothing = value } }
        spectrumGlowSlider.onChange = { [weak self] value in self?.styleField { $0.spectrum.glow = value } }
        spectrumArcStartSlider.onChange = { [weak self] value in self?.styleField { $0.spectrum.arcStartDegrees = value } }
        spectrumArcEndSlider.onChange = { [weak self] value in self?.styleField { $0.spectrum.arcEndDegrees = value } }

        ringRadiusSlider.onChange = { [weak self] value in self?.styleField { $0.ring.radius = value } }
        ringThicknessSlider.onChange = { [weak self] value in self?.styleField { $0.ring.thickness = value } }
        ringSoftnessSlider.onChange = { [weak self] value in self?.styleField { $0.ring.softness = value } }
        ringGlowSlider.onChange = { [weak self] value in self?.styleField { $0.ring.glow = value } }
        ringRoundnessSlider.onChange = { [weak self] value in self?.styleField { $0.ring.roundness = value } }

        waveThicknessSlider.onChange = { [weak self] value in self?.styleField { $0.wave.thickness = value } }
        waveAmplitudeSlider.onChange = { [weak self] value in self?.styleField { $0.wave.amplitude = value } }
        waveSmoothingSlider.onChange = { [weak self] value in self?.styleField { $0.wave.smoothing = value } }
        waveGlowSlider.onChange = { [weak self] value in self?.styleField { $0.wave.glow = value } }
        waveRadiusSlider.onChange = { [weak self] value in self?.styleField { $0.wave.radius = value } }
        waveArcStartSlider.onChange = { [weak self] value in self?.styleField { $0.wave.arcStartDegrees = value } }
        waveArcEndSlider.onChange = { [weak self] value in self?.styleField { $0.wave.arcEndDegrees = value } }
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

    private func applyEnabledState() {
        let active = preferences.isEnabled
        [
            intensitySlider,
            overlayOpacitySlider,
            bassPulseSlider,
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
            ringRadiusSlider,
            ringThicknessSlider,
            ringSoftnessSlider,
            ringGlowSlider,
            ringRoundnessSlider,
            waveThicknessSlider,
            waveAmplitudeSlider,
            waveSmoothingSlider,
            waveGlowSlider,
            waveRadiusSlider,
            waveArcStartSlider,
            waveArcEndSlider
        ].forEach { $0.isEnabled = active }

        [
            responseControl,
            pulseRingSwitch,
            spectrumBarsSwitch,
            waveLineSwitch,
            primaryColorWell,
            secondaryColorWell,
            accentColorWell,
            glowColorWell,
            paletteSourcePopup,
            spectrumLayoutPopup,
            waveLayoutPopup
        ].forEach { $0.isEnabled = active }

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

    @objc private func pulseRingChanged(_ sender: NSSwitch) {
        commitField { $0.showsPulseRing = sender.state == .on }
    }

    @objc private func spectrumBarsChanged(_ sender: NSSwitch) {
        commitField { $0.showsSpectrumBars = sender.state == .on }
    }

    @objc private func waveLineChanged(_ sender: NSSwitch) {
        commitField { $0.showsWaveLine = sender.state == .on }
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
        applyEnabledState()
    }

    @objc private func spectrumLayoutChanged(_ sender: NSPopUpButton) {
        guard !isInternallyUpdating,
              let rawValue = sender.selectedItem?.representedObject as? String,
              let layout = AudioReactorVisualizerLayout(rawValue: rawValue)
        else { return }
        styleField { $0.spectrum.layout = layout }
    }

    @objc private func waveLayoutChanged(_ sender: NSPopUpButton) {
        guard !isInternallyUpdating,
              let rawValue = sender.selectedItem?.representedObject as? String,
              let layout = AudioReactorVisualizerLayout(rawValue: rawValue)
        else { return }
        styleField { $0.wave.layout = layout }
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

        var style = preferences.style
        style.palette = style.palette.resolved(with: .fallback)
        if preferences.showsPulseRing {
            drawRing(in: rect, style: style, context: context)
        }
        if preferences.showsSpectrumBars {
            drawSpectrum(in: rect, style: style, context: context)
        }
        if preferences.showsWaveLine {
            drawWave(in: rect, style: style, context: context)
        }

        context.setStrokeColor(NSColor.white.withAlphaComponent(0.08).cgColor)
        context.stroke(rect, width: 1)
    }

    private func drawRing(in rect: CGRect, style: AudioReactorStyle, context: CGContext) {
        let center = CGPoint(x: rect.midX, y: rect.midY + 4)
        let radius = min(rect.width, rect.height) * (0.18 + style.ring.radius * 0.25)
        let lineWidth = max(1, rect.height * CGFloat(style.ring.thickness))
        let color = NSColor(hexString: style.palette.secondaryColor) ?? .systemCyan
        context.setStrokeColor(color.withAlphaComponent(0.42 + style.ring.glow * 0.34).cgColor)
        context.setLineWidth(lineWidth)
        context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
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
        let rail = rect.insetBy(dx: 28, dy: 24)
        let cellWidth = rail.width / CGFloat(count)
        let baseY = rect.maxY - 26
        let colorA = NSColor(hexString: style.palette.primaryColor) ?? .systemCyan
        let colorB = NSColor(hexString: style.palette.secondaryColor) ?? .systemPink

        for index in 0..<count {
            let value = sampleValues[index]
            let height = CGFloat(10 + value * (44 + style.spectrum.barHeight * 56))
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
        let baseRadius = min(rect.width, rect.height) * CGFloat(0.18 + style.spectrum.radius * 0.28)
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
            let length = CGFloat(10 + value * (24 + style.spectrum.barHeight * 42))
            let inner = point(center: center, radius: baseRadius, angle: angle)
            let outer = point(center: center, radius: baseRadius + length, angle: angle)
            let color = colorA.blended(withFraction: CGFloat(unit), of: colorB) ?? colorA
            context.setStrokeColor(color.withAlphaComponent(0.78).cgColor)
            context.move(to: inner)
            context.addLine(to: outer)
            context.strokePath()
        }
    }

    private func drawWave(in rect: CGRect, style: AudioReactorStyle, context: CGContext) {
        let color = NSColor(hexString: style.palette.glowColor) ?? .white
        context.setStrokeColor(color.withAlphaComponent(0.62 + style.wave.glow * 0.22).cgColor)
        context.setLineWidth(max(1, rect.height * CGFloat(style.wave.thickness)))
        context.setLineCap(.round)

        if style.wave.layout == .bottom {
            let path = CGMutablePath()
            let rail = rect.insetBy(dx: 28, dy: 26)
            for index in 0..<sampleValues.count {
                let x = rail.minX + CGFloat(index) / CGFloat(sampleValues.count - 1) * rail.width
                let y = rect.maxY - 62 - CGFloat(sampleValues[index]) * CGFloat(22 + style.wave.amplitude * 44)
                index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }
            context.addPath(path)
            context.strokePath()
        } else {
            let center = CGPoint(x: rect.midX, y: rect.midY + 4)
            let baseRadius = min(rect.width, rect.height) * CGFloat(0.16 + style.wave.radius * 0.3)
            let start = style.wave.layout == .circle ? -180 : style.wave.arcStartDegrees
            let end = style.wave.layout == .circle ? 180 : style.wave.arcEndDegrees
            let path = CGMutablePath()
            for index in 0..<sampleValues.count {
                let unit = Double(index) / Double(sampleValues.count - 1)
                let angle = (start + (end - start) * unit) * .pi / 180
                let radius = baseRadius + CGFloat(sampleValues[index]) * CGFloat(8 + style.wave.amplitude * 34)
                let point = point(center: center, radius: radius, angle: angle)
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            context.addPath(path)
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
