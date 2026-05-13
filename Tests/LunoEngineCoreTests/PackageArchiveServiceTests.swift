import XCTest
@testable import LunoEngineCore

final class PackageArchiveServiceTests: XCTestCase {
    func testImportCopiesFolderPackageIntoLibrary() throws {
        let root = try temporaryDirectory()
        let source = root.appending(path: "Aurora.luno")
        let library = root.appending(path: "Library")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: source.appending(path: "Assets"), withIntermediateDirectories: true)
        try manifestJSON.write(to: source.appending(path: "manifest.json"), atomically: true, encoding: .utf8)
        try "shader-source".write(to: source.appending(path: "Aurora.metal"), atomically: true, encoding: .utf8)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: source.appending(path: "preview.png"))
        try Data([1, 2, 3]).write(to: source.appending(path: "Assets/noise.png"))

        let service = PackageArchiveService()
        let record = try service.importPackage(from: source, into: library)

        XCTAssertEqual(record.manifest.id, "com.luno.samples.aurora")
        XCTAssertTrue(FileManager.default.fileExists(atPath: record.packageURL.appending(path: "manifest.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: record.packageURL.appending(path: "Aurora.metal").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: record.packageURL.appending(path: "Assets/noise.png").path))
    }
}
