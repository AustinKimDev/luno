// Sources/LunoApp/Settings/NowPlayingReactivitySectionView.swift
import AppKit
import LunoEngineCore

@MainActor
protocol NowPlayingReactivitySectionViewDelegate: AnyObject {
    func nowPlayingReactivitySection(_ view: NowPlayingReactivitySectionView, didChange preferences: NowPlayingPreferences)
}

@MainActor
final class NowPlayingReactivitySectionView: NSView {
    weak var delegate: NowPlayingReactivitySectionViewDelegate?

    private let masterSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let glowSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let scaleSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)
    private let borderSlider = LabeledValueSlider(minValue: 0, maxValue: 1, displayAsPercent: true)

    private var preferences: NowPlayingPreferences = .defaults
    private var isInternallyUpdating = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func configure(_ preferences: NowPlayingPreferences) {
        self.preferences = preferences
        isInternallyUpdating = true
        defer { isInternallyUpdating = false }
        masterSlider.value = preferences.audioReactivityIntensity
        glowSlider.value = preferences.appearance.glowReaction
        scaleSlider.value = preferences.appearance.scaleReaction
        borderSlider.value = preferences.appearance.borderReaction
        applyMasterEnabledState()
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

        let heading = NSTextField(labelWithString: "Reactivity")
        heading.font = .boldSystemFont(ofSize: 13)
        stack.addArrangedSubview(heading)

        masterSlider.onChange = { [weak self] value in
            guard let self, !isInternallyUpdating else { return }
            preferences.audioReactivityIntensity = value
            applyMasterEnabledState()
            delegate?.nowPlayingReactivitySection(self, didChange: preferences)
        }
        stack.addArrangedSubview(labeled("Master intensity", control: masterSlider))

        let divider = NSTextField(labelWithString: "Per-effect weights")
        divider.font = .systemFont(ofSize: 11)
        divider.textColor = .secondaryLabelColor
        stack.addArrangedSubview(divider)

        glowSlider.onChange = { [weak self] value in self?.setReactionField(\.glowReaction, value) }
        scaleSlider.onChange = { [weak self] value in self?.setReactionField(\.scaleReaction, value) }
        borderSlider.onChange = { [weak self] value in self?.setReactionField(\.borderReaction, value) }
        stack.addArrangedSubview(labeled("Glow", control: glowSlider))
        stack.addArrangedSubview(labeled("Scale", control: scaleSlider))
        stack.addArrangedSubview(labeled("Border", control: borderSlider))
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

    private func applyMasterEnabledState() {
        let masterActive = preferences.audioReactivityIntensity > 0 && preferences.audioReactivityEnabled
        glowSlider.isEnabled = masterActive
        scaleSlider.isEnabled = masterActive
        borderSlider.isEnabled = masterActive
    }

    private func setReactionField(_ keyPath: WritableKeyPath<NowPlayingAppearance, Double>, _ value: Double) {
        guard !isInternallyUpdating else { return }
        preferences.appearance[keyPath: keyPath] = value
        // Re-clamp through the initializer (writing the keypath bypasses clamping).
        preferences.appearance = NowPlayingAppearance(
            cornerRadius: preferences.appearance.cornerRadius,
            padding: preferences.appearance.padding,
            borderWidth: preferences.appearance.borderWidth,
            borderOpacity: preferences.appearance.borderOpacity,
            titleWeight: preferences.appearance.titleWeight,
            subtitleWeight: preferences.appearance.subtitleWeight,
            textColor: preferences.appearance.textColor,
            accentColor: preferences.appearance.accentColor,
            glowTint: preferences.appearance.glowTint,
            scaleReaction: preferences.appearance.scaleReaction,
            glowReaction: preferences.appearance.glowReaction,
            borderReaction: preferences.appearance.borderReaction
        )
        delegate?.nowPlayingReactivitySection(self, didChange: preferences)
    }
}
