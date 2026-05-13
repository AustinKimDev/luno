import XCTest
@testable import LunoEngineCore

final class PresetStoreTests: XCTestCase {
    func testRoundTripsTypedPresetValues() throws {
        let directory = try temporaryDirectory()
        let store = PresetStore(fileURL: directory.appending(path: "presets.json"))
        let preset = WallpaperPreset(
            id: "night",
            packageID: "com.example.aurora",
            name: "Night",
            values: [
                "speed": .float(0.7),
                "tint": .color("#3366FF"),
                "reactive": .bool(true),
                "mode": .string("ribbons")
            ]
        )

        try store.save([preset])

        XCTAssertEqual(try store.load(), [preset])
    }
}
