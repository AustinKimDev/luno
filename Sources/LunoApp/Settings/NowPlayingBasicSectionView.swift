import AppKit
import LunoEngineCore

@MainActor
protocol NowPlayingBasicSectionViewDelegate: AnyObject {
    func nowPlayingBasicSection(_ view: NowPlayingBasicSectionView, didChange preferences: NowPlayingPreferences)
}

@MainActor
final class NowPlayingBasicSectionView: NSView {
    weak var delegate: NowPlayingBasicSectionViewDelegate?

    private let enableSwitch = NSSwitch()
    private let stylePopup = NSPopUpButton()
    private let reactivitySwitch = NSSwitch()
    private let keepVisibleSwitch = NSSwitch()

    private var preferences: NowPlayingPreferences = .defaults

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func configure(_ preferences: NowPlayingPreferences) {
        self.preferences = preferences
        enableSwitch.state = preferences.isEnabled ? .on : .off
        reactivitySwitch.state = preferences.audioReactivityEnabled ? .on : .off
        keepVisibleSwitch.state = preferences.keepVisibleWhilePaused ? .on : .off
        let index = NowPlayingPreferences.Style.allCases.firstIndex(of: preferences.style) ?? 0
        stylePopup.selectItem(at: index)
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

        let heading = NSTextField(labelWithString: "Now Playing widget")
        heading.font = .boldSystemFont(ofSize: 13)
        stack.addArrangedSubview(heading)

        enableSwitch.target = self
        enableSwitch.action = #selector(enableChanged)
        stack.addArrangedSubview(labeled("Enable widget", control: enableSwitch))

        stylePopup.removeAllItems()
        stylePopup.addItems(withTitles: ["A — Album-art dominant", "B — Compact bar", "C — Minimal"])
        stylePopup.target = self
        stylePopup.action = #selector(styleChanged)
        stack.addArrangedSubview(labeled("Style", control: stylePopup))

        reactivitySwitch.target = self
        reactivitySwitch.action = #selector(reactivityChanged)
        stack.addArrangedSubview(labeled("React to music", control: reactivitySwitch))

        keepVisibleSwitch.target = self
        keepVisibleSwitch.action = #selector(keepVisibleChanged)
        stack.addArrangedSubview(labeled("Keep visible while paused", control: keepVisibleSwitch))
    }

    private func labeled(_ title: String, control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 200).isActive = true
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    @objc private func enableChanged(_ sender: NSSwitch) {
        preferences.isEnabled = sender.state == .on
        delegate?.nowPlayingBasicSection(self, didChange: preferences)
    }

    @objc private func styleChanged(_ sender: NSPopUpButton) {
        let styles = NowPlayingPreferences.Style.allCases
        let index = sender.indexOfSelectedItem
        guard styles.indices.contains(index) else { return }
        preferences.style = styles[index]
        delegate?.nowPlayingBasicSection(self, didChange: preferences)
    }

    @objc private func reactivityChanged(_ sender: NSSwitch) {
        preferences.audioReactivityEnabled = sender.state == .on
        delegate?.nowPlayingBasicSection(self, didChange: preferences)
    }

    @objc private func keepVisibleChanged(_ sender: NSSwitch) {
        preferences.keepVisibleWhilePaused = sender.state == .on
        delegate?.nowPlayingBasicSection(self, didChange: preferences)
    }
}
