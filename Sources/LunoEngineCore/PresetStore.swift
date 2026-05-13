import Foundation

public struct WallpaperPreset: Codable, Equatable, Sendable {
    public var id: String
    public var packageID: String
    public var name: String
    public var values: [String: ParameterValue]

    public init(id: String, packageID: String, name: String, values: [String: ParameterValue]) {
        self.id = id
        self.packageID = packageID
        self.name = name
        self.values = values
    }
}

public struct PresetStore: Sendable {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public func load() throws -> [WallpaperPreset] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([WallpaperPreset].self, from: data)
    }

    public func save(_ presets: [WallpaperPreset]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(presets)
        try data.write(to: fileURL, options: .atomic)
    }
}
