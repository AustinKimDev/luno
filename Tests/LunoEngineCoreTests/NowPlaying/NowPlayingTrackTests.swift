import XCTest
@testable import LunoEngineCore

final class NowPlayingTrackTests: XCTestCase {
    func testTracksAreEqualWhenAllFieldsMatch() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let a = NowPlayingTrack(
            title: "Clair de Lune",
            artist: "Lang Lang",
            album: "Suite bergamasque",
            composer: "Claude Debussy",
            artwork: .url(URL(string: "https://example.com/a.jpg")!),
            source: .appleMusic,
            isPlaying: true,
            isAdvertisement: false,
            updatedAt: timestamp
        )
        let b = NowPlayingTrack(
            title: "Clair de Lune",
            artist: "Lang Lang",
            album: "Suite bergamasque",
            composer: "Claude Debussy",
            artwork: .url(URL(string: "https://example.com/a.jpg")!),
            source: .appleMusic,
            isPlaying: true,
            isAdvertisement: false,
            updatedAt: timestamp
        )
        XCTAssertEqual(a, b)
    }

    func testArtworkDataRoundTrips() {
        let payload = Data([0x01, 0x02, 0x03])
        let artwork = NowPlayingTrack.Artwork.data(payload)
        XCTAssertEqual(artwork, .data(payload))
        XCTAssertNotEqual(artwork, .data(Data([0x01, 0x02])))
    }

    func testCodableRoundTripPreservesAllFields() throws {
        let track = NowPlayingTrack(
            title: "Aja",
            artist: "Steely Dan",
            album: "Aja",
            composer: nil,
            artwork: .data(Data([0xDE, 0xAD])),
            source: .spotify,
            isPlaying: true,
            isAdvertisement: false,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let encoded = try JSONEncoder().encode(track)
        let decoded = try JSONDecoder().decode(NowPlayingTrack.self, from: encoded)
        XCTAssertEqual(decoded, track)
    }
}
