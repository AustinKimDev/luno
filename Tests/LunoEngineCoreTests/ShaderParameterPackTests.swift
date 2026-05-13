import XCTest
@testable import LunoEngineCore

final class ShaderParameterPackTests: XCTestCase {
    func testPacksFirstFourNumericParametersAndSkipsColors() throws {
        let manifest = WallpaperPackageManifest(
            id: "com.example.wallpaper",
            name: "Example",
            version: "1.0.0",
            engineVersion: "1.0",
            author: "Luno",
            entryShader: "Example.metal",
            assets: [],
            parameters: [
                .init(id: "speed", name: "Speed", type: .float, defaultValue: .float(0.5)),
                .init(id: "tint", name: "Tint", type: .color, defaultValue: .color("#3366FF")),
                .init(id: "reactive", name: "Reactive", type: .bool, defaultValue: .bool(true)),
                .init(id: "brightness", name: "Brightness", type: .float, defaultValue: .float(1.2)),
                .init(id: "saturation", name: "Saturation", type: .float, defaultValue: .float(0.8)),
                .init(id: "extra", name: "Extra", type: .float, defaultValue: .float(9.0))
            ],
            audioBindings: [],
            preview: "preview.png",
            tags: []
        )

        let pack = ShaderParameterPack.make(manifest: manifest, preset: nil)

        XCTAssertEqual(pack.numeric, SIMD4<Float>(0.5, 1.0, 1.2, 0.8))
    }

    func testPacksFirstFourColorParametersAsNormalizedRGBA() throws {
        let manifest = WallpaperPackageManifest(
            id: "com.example.wallpaper",
            name: "Example",
            version: "1.0.0",
            engineVersion: "1.0",
            author: "Luno",
            entryShader: "Example.metal",
            assets: [],
            parameters: [
                .init(id: "tint", name: "Tint", type: .color, defaultValue: .color("#3366FF")),
                .init(id: "accent", name: "Accent", type: .color, defaultValue: .color("#00000080"))
            ],
            audioBindings: [],
            preview: "preview.png",
            tags: []
        )

        let pack = ShaderParameterPack.make(manifest: manifest, preset: nil)

        XCTAssertEqual(pack.color0, SIMD4<Float>(0.2, 0.4, 1.0, 1.0))
        XCTAssertEqual(pack.color1, SIMD4<Float>(0.0, 0.0, 0.0, 128.0 / 255.0))
        XCTAssertEqual(pack.color2, SIMD4<Float>(0.0, 0.0, 0.0, 0.0))
        XCTAssertEqual(pack.color3, SIMD4<Float>(0.0, 0.0, 0.0, 0.0))
    }

    func testPresetValuesOverrideManifestDefaults() throws {
        let manifest = WallpaperPackageManifest(
            id: "com.example.wallpaper",
            name: "Example",
            version: "1.0.0",
            engineVersion: "1.0",
            author: "Luno",
            entryShader: "Example.metal",
            assets: [],
            parameters: [
                .init(id: "speed", name: "Speed", type: .float, defaultValue: .float(0.5)),
                .init(id: "tint", name: "Tint", type: .color, defaultValue: .color("#3366FF"))
            ],
            audioBindings: [],
            preview: "preview.png",
            tags: []
        )
        let preset = WallpaperPreset(
            id: "custom",
            packageID: manifest.id,
            name: "Custom",
            values: [
                "speed": .float(1.4),
                "tint": .color("#FFCC00")
            ]
        )

        let pack = ShaderParameterPack.make(manifest: manifest, preset: preset)

        XCTAssertEqual(pack.numeric, SIMD4<Float>(1.4, 0.0, 0.0, 0.0))
        XCTAssertEqual(pack.color0, SIMD4<Float>(1.0, 0.8, 0.0, 1.0))
    }

    func testPacksEnumParametersAsSelectedOptionIndex() throws {
        let manifest = WallpaperPackageManifest(
            id: "com.example.wallpaper",
            name: "Example",
            version: "1.0.0",
            engineVersion: "1.0",
            author: "Luno",
            entryShader: "Example.metal",
            assets: [],
            parameters: [
                .init(
                    id: "mode",
                    name: "Mode",
                    type: .enum,
                    defaultValue: .string("Ambient Bloom"),
                    options: ["Ambient Bloom", "Spectrum Ribbons", "Particle Field"]
                ),
                .init(id: "brightness", name: "Brightness", type: .float, defaultValue: .float(1.0))
            ],
            audioBindings: [],
            preview: "preview.png",
            tags: []
        )
        let preset = WallpaperPreset(
            id: "custom",
            packageID: manifest.id,
            name: "Custom",
            values: [
                "mode": .string("Particle Field")
            ]
        )

        let pack = ShaderParameterPack.make(manifest: manifest, preset: preset)

        XCTAssertEqual(pack.numeric, SIMD4<Float>(2.0, 1.0, 0.0, 0.0))
    }
}
