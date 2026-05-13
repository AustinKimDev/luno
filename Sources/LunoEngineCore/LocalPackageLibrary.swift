import Foundation

public final class LocalPackageLibrary {
    public let libraryURL: URL
    private let archiveService: PackageArchiveService
    private let fileManager: FileManager

    public init(
        libraryURL: URL,
        archiveService: PackageArchiveService = PackageArchiveService(),
        fileManager: FileManager = .default
    ) {
        self.libraryURL = libraryURL
        self.archiveService = archiveService
        self.fileManager = fileManager
    }

    public func packages() throws -> [LunoPackageRecord] {
        guard fileManager.fileExists(atPath: libraryURL.path) else {
            return []
        }

        let children = try fileManager.contentsOfDirectory(
            at: libraryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return try children
            .filter { $0.pathExtension.lowercased() == "luno" }
            .map { packageURL in
                let manifest = try archiveService.loadManifest(at: packageURL)
                return LunoPackageRecord(manifest: manifest, packageURL: packageURL)
            }
            .sorted { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
    }

    @discardableResult
    public func importPackage(from sourceURL: URL) throws -> LunoPackageRecord {
        try archiveService.importPackage(from: sourceURL, into: libraryURL)
    }
}
