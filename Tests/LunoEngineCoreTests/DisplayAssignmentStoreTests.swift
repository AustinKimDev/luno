import XCTest
@testable import LunoEngineCore

final class DisplayAssignmentStoreTests: XCTestCase {
    func testRoundTripsPerDisplayAssignments() throws {
        let directory = try temporaryDirectory()
        let store = DisplayAssignmentStore(fileURL: directory.appending(path: "assignments.json"))
        let assignments = [
            DisplayAssignment(displayID: "main-display", packageID: "com.example.aurora", presetID: "night"),
            DisplayAssignment(displayID: "studio-display", packageID: "com.example.plasma", presetID: "calm")
        ]

        try store.save(assignments)

        XCTAssertEqual(try store.load(), assignments)
    }
}
