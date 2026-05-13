import Foundation

public struct NowPlayingPreferences: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case style
        case audioReactivityEnabled
        case keepVisibleWhilePaused
        case isPinned
        case positionsByDisplay
    }

    public enum Style: String, Codable, Sendable, CaseIterable {
        case albumDominant
        case compactBar
        case minimal
    }

    public struct Position: Codable, Equatable, Sendable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public var isEnabled: Bool
    public var style: Style
    public var audioReactivityEnabled: Bool
    public var keepVisibleWhilePaused: Bool
    public var isPinned: Bool
    public var positionsByDisplay: [String: Position]

    public init(
        isEnabled: Bool,
        style: Style,
        audioReactivityEnabled: Bool,
        keepVisibleWhilePaused: Bool,
        isPinned: Bool = false,
        positionsByDisplay: [String: Position]
    ) {
        self.isEnabled = isEnabled
        self.style = style
        self.audioReactivityEnabled = audioReactivityEnabled
        self.keepVisibleWhilePaused = keepVisibleWhilePaused
        self.isPinned = isPinned
        self.positionsByDisplay = positionsByDisplay
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        self.style = try container.decode(Style.self, forKey: .style)
        self.audioReactivityEnabled = try container.decode(Bool.self, forKey: .audioReactivityEnabled)
        self.keepVisibleWhilePaused = try container.decode(Bool.self, forKey: .keepVisibleWhilePaused)
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.positionsByDisplay = try container.decode([String: Position].self, forKey: .positionsByDisplay)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(style, forKey: .style)
        try container.encode(audioReactivityEnabled, forKey: .audioReactivityEnabled)
        try container.encode(keepVisibleWhilePaused, forKey: .keepVisibleWhilePaused)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(positionsByDisplay, forKey: .positionsByDisplay)
    }

    public static let defaults = NowPlayingPreferences(
        isEnabled: false,
        style: .compactBar,
        audioReactivityEnabled: true,
        keepVisibleWhilePaused: false,
        isPinned: false,
        positionsByDisplay: [:]
    )
}

public struct NowPlayingPreferencesStore: Sendable {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public func load() throws -> NowPlayingPreferences {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .defaults
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(NowPlayingPreferences.self, from: data)
    }

    public func save(_ preferences: NowPlayingPreferences) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(preferences)
        try data.write(to: fileURL, options: .atomic)
    }
}
