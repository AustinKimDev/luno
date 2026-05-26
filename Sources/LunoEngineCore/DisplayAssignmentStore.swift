import Foundation

public struct DisplayAssignment: Codable, Equatable, Sendable {
    public var displayID: String
    public var packageID: String
    public var presetID: String
    public var values: [String: ParameterValue]?

    public init(
        displayID: String,
        packageID: String,
        presetID: String,
        values: [String: ParameterValue]? = nil
    ) {
        self.displayID = displayID
        self.packageID = packageID
        self.presetID = presetID
        self.values = values
    }
}

public struct DisplayAssignmentStore: Sendable {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public func load() throws -> [DisplayAssignment] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([DisplayAssignment].self, from: data)
    }

    public func save(_ assignments: [DisplayAssignment]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(assignments)
        try data.write(to: fileURL, options: .atomic)
    }
}
