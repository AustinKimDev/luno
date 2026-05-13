// Sources/LunoApp/Settings/SettingsSection.swift
import Foundation

enum SettingsSection: Hashable, CaseIterable {
    case library
    case nowPlayingBasic
    case nowPlayingAppearance
    case nowPlayingReactivity
    case audioReactor

    var title: String {
        switch self {
        case .library: "Library"
        case .nowPlayingBasic: "Basic"
        case .nowPlayingAppearance: "Appearance"
        case .nowPlayingReactivity: "Reactivity"
        case .audioReactor: "Audio Reactor"
        }
    }
}

/// Outline nodes for the sidebar: top-level groups and their child sections.
enum SettingsOutlineNode: Hashable {
    case group(title: String, children: [SettingsSection])
    case leaf(SettingsSection)

    var title: String {
        switch self {
        case .group(let title, _): title
        case .leaf(let section): section.title
        }
    }
}

enum SettingsOutline {
    /// The tree shown in the sidebar.
    static let nodes: [SettingsOutlineNode] = [
        .leaf(.library),
        .group(title: "Now Playing", children: [
            .nowPlayingBasic,
            .nowPlayingAppearance,
            .nowPlayingReactivity
        ]),
        .leaf(.audioReactor)
    ]
}
