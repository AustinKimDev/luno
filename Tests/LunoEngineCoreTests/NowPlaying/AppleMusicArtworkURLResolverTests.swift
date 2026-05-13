import XCTest
@testable import LunoEngineCore

final class AppleMusicArtworkURLResolverTests: XCTestCase {
    func testLookupURLIncludesTrackMetadata() throws {
        let url = try XCTUnwrap(ITunesSearchArtworkURLResolver.lookupURL(
            title: "Susususu Suki Daaisuki",
            artist: "Yamane Mah",
            album: "すすすす、すき、だあいすき - 今週のシングル"
        ))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "itunes.apple.com")
        XCTAssertEqual(queryItems["media"], "music")
        XCTAssertEqual(queryItems["entity"], "song")
        XCTAssertEqual(queryItems["limit"], "1")
        let term = try XCTUnwrap(queryItems["term"] ?? nil)
        XCTAssertTrue(term.contains("Yamane Mah"))
        XCTAssertTrue(term.contains("Susususu Suki Daaisuki"))
    }

    func testHighResolutionURLUpscalesArtworkSize() throws {
        let url = try XCTUnwrap(URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/example/100x100bb.jpg"))
        let highResolutionURL = ITunesSearchArtworkURLResolver.highResolutionURL(from: url)

        XCTAssertEqual(
            highResolutionURL.absoluteString,
            "https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/example/600x600bb.jpg"
        )
    }
}
