import XCTest
import Metal
@testable import LunoEngineCore

final class WallpaperPackageManifestTests: XCTestCase {
    func testManifestDecodesShaderPackageContract() throws {
        let manifest = try JSONDecoder().decode(WallpaperPackageManifest.self, from: Data(manifestJSON.utf8))

        XCTAssertEqual(manifest.id, "com.luno.samples.aurora")
        XCTAssertEqual(manifest.name, "Aurora Field")
        XCTAssertEqual(manifest.entryShader, "Aurora.metal")
        XCTAssertEqual(manifest.assets, ["Assets/noise.png"])
        XCTAssertEqual(manifest.audioBindings, [.rms, .bass, .mid, .treble, .spectrum])
        XCTAssertEqual(manifest.parameters.count, 4)
        XCTAssertEqual(manifest.parameters[0].id, "speed")
        XCTAssertEqual(manifest.parameters[0].defaultValue, .float(0.8))
    }

    func testManifestValidationRejectsFloatDefaultOutsideRange() throws {
        let json = manifestJSON.replacingOccurrences(of: #""default": 0.8"#, with: #""default": 3.0"#)
        let manifest = try JSONDecoder().decode(WallpaperPackageManifest.self, from: Data(json.utf8))

        XCTAssertThrowsError(try manifest.validate()) { error in
            XCTAssertEqual(error as? ManifestValidationError, .floatDefaultOutOfRange(parameterID: "speed"))
        }
    }

    func testBundledSampleManifestsExposeCommonColorControls() throws {
        let samplesURL = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/LunoApp/Resources/SamplePackages", directoryHint: .isDirectory)
        let packageURLs = try FileManager.default.contentsOfDirectory(
            at: samplesURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
            .filter { $0.pathExtension == "luno" }

        XCTAssertGreaterThan(packageURLs.count, 0)
        XCTAssertTrue(packageURLs.contains { $0.lastPathComponent == "AlbumPalette.luno" })

        for packageURL in packageURLs {
            let manifestURL = packageURL.appending(path: "manifest.json")
            let manifestData = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(WallpaperPackageManifest.self, from: manifestData)

            try manifest.validate()
            XCTAssertNotNil(manifest.parameters.first { $0.id == "tint" && $0.type == .color })
            XCTAssertNotNil(manifest.parameters.first { $0.id == "tintStrength" && $0.type == .float })
            XCTAssertNotNil(manifest.parameters.first { $0.id == "brightness" && $0.type == .float })
            XCTAssertNotNil(manifest.parameters.first { $0.id == "saturation" && $0.type == .float })
        }
    }

    func testBundledSampleShadersCompile() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let samplesURL = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/LunoApp/Resources/SamplePackages", directoryHint: .isDirectory)
        let packageURLs = try FileManager.default.contentsOfDirectory(
            at: samplesURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
            .filter { $0.pathExtension == "luno" }

        for packageURL in packageURLs {
            let manifestData = try Data(contentsOf: packageURL.appending(path: "manifest.json"))
            let manifest = try JSONDecoder().decode(WallpaperPackageManifest.self, from: manifestData)
            let shaderSource = try String(
                contentsOf: packageURL.appending(path: manifest.entryShader),
                encoding: .utf8
            )
            let library = try device.makeLibrary(source: shaderSource, options: nil)

            XCTAssertNotNil(library.makeFunction(name: "lunoVertex"))
            XCTAssertNotNil(library.makeFunction(name: "lunoFragment"))
        }
    }

    func testBuiltInOverlayShaderCompiles() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal is not available on this Mac.")
        }

        let library = try device.makeLibrary(source: LunoOverlayShaderSource.source, options: nil)

        XCTAssertNotNil(library.makeFunction(name: "lunoOverlayVertex"))
        XCTAssertNotNil(library.makeFunction(name: "lunoOverlayFragment"))
    }
}
