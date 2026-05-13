import Foundation

public struct LunoPackageRecord: Equatable, Sendable {
    public var manifest: WallpaperPackageManifest
    public var packageURL: URL

    public init(manifest: WallpaperPackageManifest, packageURL: URL) {
        self.manifest = manifest
        self.packageURL = packageURL
    }
}

public enum PackageArchiveError: Error, Equatable, LocalizedError {
    case manifestNotFound(URL)
    case unsupportedSource(URL)
    case invalidArchive(URL)
    case missingPackageFile(String)
    case processFailed(String)

    public var errorDescription: String? {
        switch self {
        case .manifestNotFound(let url):
            "manifest.json was not found in \(url.path)."
        case .unsupportedSource(let url):
            "Unsupported Luno package source: \(url.path)."
        case .invalidArchive(let url):
            "The archive did not contain a valid .luno package: \(url.path)."
        case .missingPackageFile(let path):
            "The package references a missing file: \(path)."
        case .processFailed(let output):
            "Package archive command failed: \(output)"
        }
    }
}

public final class PackageArchiveService {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func importPackage(from sourceURL: URL, into libraryURL: URL) throws -> LunoPackageRecord {
        let readablePackageURL = try prepareReadablePackage(from: sourceURL)
        let manifest = try loadManifest(at: readablePackageURL)
        try manifest.validate()
        try validatePackageFiles(at: readablePackageURL, manifest: manifest)

        try fileManager.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        let destinationURL = libraryURL.appending(path: "\(manifest.id).luno", directoryHint: .isDirectory)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: readablePackageURL, to: destinationURL)
        return LunoPackageRecord(manifest: manifest, packageURL: destinationURL)
    }

    public func exportPackage(from packageURL: URL, to archiveURL: URL) throws {
        let manifest = try loadManifest(at: packageURL)
        try manifest.validate()
        try validatePackageFiles(at: packageURL, manifest: manifest)

        if fileManager.fileExists(atPath: archiveURL.path) {
            try fileManager.removeItem(at: archiveURL)
        }

        try runDitto(arguments: ["-c", "-k", "--keepParent", packageURL.path, archiveURL.path])
    }

    public func loadManifest(at packageURL: URL) throws -> WallpaperPackageManifest {
        let manifestURL = packageURL.appending(path: "manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw PackageArchiveError.manifestNotFound(packageURL)
        }

        let data = try Data(contentsOf: manifestURL)
        return try JSONDecoder().decode(WallpaperPackageManifest.self, from: data)
    }

    private func prepareReadablePackage(from sourceURL: URL) throws -> URL {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else {
            throw PackageArchiveError.unsupportedSource(sourceURL)
        }

        if isDirectory.boolValue {
            return sourceURL
        }

        guard ["luno", "zip"].contains(sourceURL.pathExtension.lowercased()) else {
            throw PackageArchiveError.unsupportedSource(sourceURL)
        }

        let extractionRoot = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: extractionRoot, withIntermediateDirectories: true)
        try runDitto(arguments: ["-x", "-k", sourceURL.path, extractionRoot.path])

        let children = try fileManager.contentsOfDirectory(
            at: extractionRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        if let packageDirectory = children.first(where: { $0.pathExtension.lowercased() == "luno" }) {
            return packageDirectory
        }

        if fileManager.fileExists(atPath: extractionRoot.appending(path: "manifest.json").path) {
            return extractionRoot
        }

        throw PackageArchiveError.invalidArchive(sourceURL)
    }

    private func validatePackageFiles(at packageURL: URL, manifest: WallpaperPackageManifest) throws {
        let requiredPaths = [manifest.entryShader, manifest.preview] + manifest.assets
        for path in requiredPaths where !path.isEmpty {
            let fileURL = packageURL.appending(path: path)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                throw PackageArchiveError.missingPackageFile(path)
            }
        }
    }

    private func runDitto(arguments: [String]) throws {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw PackageArchiveError.processFailed(output)
        }
    }
}
