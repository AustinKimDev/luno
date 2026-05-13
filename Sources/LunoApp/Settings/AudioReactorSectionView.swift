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

    private let enableSwitch = NSSwitch()
    private let intensitySlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let responseControl = NSSegmentedControl(labels: ["Soft", "Punchy", "Hard"], trackingMode: .selectOne, target: nil, action: nil)
    private let bassPulseSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let pulseRingSwitch = NSSwitch()
    private let spectrumBarsSwitch = NSSwitch()
    private let waveLineSwitch = NSSwitch()
    private let overlayOpacitySlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)

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
        defer { isInternallyUpdating = false }
        enableSwitch.state = preferences.isEnabled ? .on : .off
        intensitySlider.value = preferences.intensity
        responseControl.selectedSegment = AudioReactorResponse.allCases.firstIndex(of: preferences.response) ?? 1
        bassPulseSlider.value = preferences.bassPulseStrength
        pulseRingSwitch.state = preferences.showsPulseRing ? .on : .off
        spectrumBarsSwitch.state = preferences.showsSpectrumBars ? .on : .off
        waveLineSwitch.state = preferences.showsWaveLine ? .on : .off
        overlayOpacitySlider.value = preferences.overlayOpacity
        applyEnabledState()
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

        let heading = NSTextField(labelWithString: "Audio Reactor")
        heading.font = .boldSystemFont(ofSize: 13)
        stack.addArrangedSubview(heading)

        enableSwitch.target = self
        enableSwitch.action = #selector(enabledChanged)
        stack.addArrangedSubview(labeled("Enabled", control: enableSwitch))

        intensitySlider.onChange = { [weak self] value in self?.commitField { $0.intensity = value } }
        stack.addArrangedSubview(labeled("Intensity", control: intensitySlider))

        responseControl.target = self
        responseControl.action = #selector(responseChanged)
        stack.addArrangedSubview(labeled("Response", control: responseControl))

        bassPulseSlider.onChange = { [weak self] value in self?.commitField { $0.bassPulseStrength = value } }
        stack.addArrangedSubview(labeled("Bass pulse", control: bassPulseSlider))

        pulseRingSwitch.target = self
        pulseRingSwitch.action = #selector(pulseRingChanged)
        stack.addArrangedSubview(labeled("Pulse ring", control: pulseRingSwitch))

        spectrumBarsSwitch.target = self
        spectrumBarsSwitch.action = #selector(spectrumBarsChanged)
        stack.addArrangedSubview(labeled("Spectrum bars", control: spectrumBarsSwitch))

        waveLineSwitch.target = self
        waveLineSwitch.action = #selector(waveLineChanged)
        stack.addArrangedSubview(labeled("Wave line", control: waveLineSwitch))

        overlayOpacitySlider.onChange = { [weak self] value in self?.commitField { $0.overlayOpacity = value } }
        stack.addArrangedSubview(labeled("Overlay opacity", control: overlayOpacitySlider))
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

    private func applyEnabledState() {
        let active = preferences.isEnabled
        intensitySlider.isEnabled = active
        responseControl.isEnabled = active
        bassPulseSlider.isEnabled = active
        pulseRingSwitch.isEnabled = active
        spectrumBarsSwitch.isEnabled = active
        waveLineSwitch.isEnabled = active
        overlayOpacitySlider.isEnabled = active
    }

    private func commitField(_ mutate: (inout AudioReactorPreferences) -> Void) {
        guard !isInternallyUpdating else { return }
        mutate(&preferences)
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
        preferences.response = cases[sender.selectedSegment]
        delegate?.audioReactorSection(self, didChange: preferences)
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
}
