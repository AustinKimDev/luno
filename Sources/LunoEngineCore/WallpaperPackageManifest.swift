import Foundation

public struct WallpaperPackageManifest: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var version: String
    public var engineVersion: String
    public var author: String
    public var entryShader: String
    public var assets: [String]
    public var parameters: [WallpaperParameterDefinition]
    public var audioBindings: [AudioBinding]
    public var preview: String
    public var tags: [String]

    public init(
        id: String,
        name: String,
        version: String,
        engineVersion: String,
        author: String,
        entryShader: String,
        assets: [String],
        parameters: [WallpaperParameterDefinition],
        audioBindings: [AudioBinding],
        preview: String,
        tags: [String]
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.engineVersion = engineVersion
        self.author = author
        self.entryShader = entryShader
        self.assets = assets
        self.parameters = parameters
        self.audioBindings = audioBindings
        self.preview = preview
        self.tags = tags
    }

    public func validate() throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ManifestValidationError.emptyField("id")
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ManifestValidationError.emptyField("name")
        }
        guard !entryShader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ManifestValidationError.emptyField("entryShader")
        }

        var seenParameterIDs = Set<String>()
        for parameter in parameters {
            guard !parameter.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ManifestValidationError.emptyField("parameter.id")
            }
            guard seenParameterIDs.insert(parameter.id).inserted else {
                throw ManifestValidationError.duplicateParameterID(parameter.id)
            }
            try parameter.validate()
        }
    }
}

public struct WallpaperParameterDefinition: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var type: WallpaperParameterType
    public var defaultValue: ParameterValue
    public var min: Double?
    public var max: Double?
    public var options: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case defaultValue = "default"
        case min
        case max
        case options
    }

    public init(
        id: String,
        name: String,
        type: WallpaperParameterType,
        defaultValue: ParameterValue,
        min: Double? = nil,
        max: Double? = nil,
        options: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.min = min
        self.max = max
        self.options = options
    }

    func validate() throws {
        switch type {
        case .float:
            guard case .float(let value) = defaultValue else {
                throw ManifestValidationError.defaultTypeMismatch(parameterID: id)
            }
            if let min, value < min {
                throw ManifestValidationError.floatDefaultOutOfRange(parameterID: id)
            }
            if let max, value > max {
                throw ManifestValidationError.floatDefaultOutOfRange(parameterID: id)
            }
            if let min, let max, min > max {
                throw ManifestValidationError.invalidRange(parameterID: id)
            }
        case .color:
            guard case .color(let value) = defaultValue, value.isHexColor else {
                throw ManifestValidationError.defaultTypeMismatch(parameterID: id)
            }
        case .bool:
            guard case .bool = defaultValue else {
                throw ManifestValidationError.defaultTypeMismatch(parameterID: id)
            }
        case .enum:
            guard case .string(let value) = defaultValue else {
                throw ManifestValidationError.defaultTypeMismatch(parameterID: id)
            }
            guard let options, !options.isEmpty, options.contains(value) else {
                throw ManifestValidationError.enumDefaultMissingFromOptions(parameterID: id)
            }
        }
    }
}

public enum WallpaperParameterType: String, Codable, Equatable, Sendable {
    case float
    case color
    case bool
    case `enum`
}

public enum ParameterValue: Codable, Equatable, Sendable {
    case float(Double)
    case color(String)
    case bool(Bool)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .float(value)
        } else {
            let value = try container.decode(String.self)
            if value.isHexColor {
                self = .color(value)
            } else {
                self = .string(value)
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .float(let value):
            try container.encode(value)
        case .color(let value), .string(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        }
    }

    public var floatValue: Double? {
        guard case .float(let value) = self else { return nil }
        return value
    }

    public var stringValue: String? {
        switch self {
        case .color(let value), .string(let value):
            return value
        case .float, .bool:
            return nil
        }
    }

    public var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }
}

public enum AudioBinding: String, Codable, Equatable, Sendable {
    case rms
    case bass
    case mid
    case treble
    case spectrum
}

public enum ManifestValidationError: Error, Equatable, LocalizedError {
    case emptyField(String)
    case duplicateParameterID(String)
    case defaultTypeMismatch(parameterID: String)
    case floatDefaultOutOfRange(parameterID: String)
    case invalidRange(parameterID: String)
    case enumDefaultMissingFromOptions(parameterID: String)

    public var errorDescription: String? {
        switch self {
        case .emptyField(let field):
            "\(field) cannot be empty."
        case .duplicateParameterID(let parameterID):
            "Duplicate parameter id: \(parameterID)."
        case .defaultTypeMismatch(let parameterID):
            "Default value does not match parameter type: \(parameterID)."
        case .floatDefaultOutOfRange(let parameterID):
            "Float default is outside its allowed range: \(parameterID)."
        case .invalidRange(let parameterID):
            "Float range is invalid: \(parameterID)."
        case .enumDefaultMissingFromOptions(let parameterID):
            "Enum default is not included in options: \(parameterID)."
        }
    }
}

private extension String {
    var isHexColor: Bool {
        let pattern = #"^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$"#
        return range(of: pattern, options: .regularExpression) != nil
    }
}
