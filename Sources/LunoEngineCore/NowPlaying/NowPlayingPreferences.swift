import Foundation

public struct NowPlayingPreferences: Codable, Equatable, Sendable {
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
    public var positionsByDisplay: [String: Position]

    public init(
        isEnabled: Bool,
        style: Style,
        audioReactivityEnabled: Bool,
        keepVisibleWhilePaused: Bool,
        positionsByDisplay: [String: Position]
    ) {
        self.isEnabled = isEnabled
        self.style = style
        self.audioReactivityEnabled = audioReactivityEnabled
        self.keepVisibleWhilePaused = keepVisibleWhilePaused
        self.positionsByDisplay = positionsByDisplay
    }

    public static let defaults = NowPlayingPreferences(
        isEnabled: false,
        style: .compactBar,
        audioReactivityEnabled: true,
        keepVisibleWhilePaused: false,
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
