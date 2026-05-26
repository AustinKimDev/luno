import XCTest
@testable import LunoEngineCore

final class LocalPackageLibraryTests: XCTestCase {
    func testRemovePackageDeletesPackageDirectoryByID() throws {
        let root = try temporaryDirectory()
        let libraryURL = root.appending(path: "Library", directoryHint: .isDirectory)
        let packageURL = libraryURL.appending(path: "com.luno.samples.aurora.luno", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

        let library = LocalPackageLibrary(libraryURL: libraryURL)

        try library.removePackage(id: "com.luno.samples.aurora")

        XCTAssertFalse(FileManager.default.fileExists(atPath: packageURL.path))
    }
}
