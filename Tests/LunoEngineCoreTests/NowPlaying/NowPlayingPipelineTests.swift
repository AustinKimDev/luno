import XCTest
@testable import LunoEngineCore

final class NowPlayingPipelineTests: XCTestCase {
    func testResolvesURLArtworkIntoData() async throws {
        let loader = StubURLLoader()
        let url = URL(string: "https://example.com/art.jpg")!
        loader.results[url] = .success(Data([0xDE, 0xAD]))
        let fetcher = ArtworkFetcher(loader: loader)

        let upstream = AsyncStream<NowPlayingTrack?> { continuation in
            continuation.yield(NowPlayingTrack(
                title: "Aja",
                artist: "Steely Dan",
                album: "Aja",
                composer: nil,
                artwork: .url(url),
                source: .spotify,
                isPlaying: true,
                isAdvertisement: false,
                updatedAt: Date(timeIntervalSince1970: 100)
            ))
            continuation.finish()
        }

        let pipeline = NowPlayingPipeline(upstream: upstream, fetcher: fetcher)
        var iter = pipeline.output.makeAsyncIterator()
        let resolved = await iter.next() ?? nil
        XCTAssertEqual(resolved?.artworkData, Data([0xDE, 0xAD]))
        XCTAssertEqual(resolved?.title, "Aja")
    }

    func testDedupsIdenticalConsecutiveTracks() async throws {
        let fetcher = ArtworkFetcher(loader: StubURLLoader())
        let upstream = AsyncStream<NowPlayingTrack?> { continuation in
            let track = NowPlayingTrack(
                title: "X",
                artist: "Y",
                album: "Z",
                composer: nil,
                artwork: nil,
                source: .appleMusic,
                isPlaying: true,
                isAdvertisement: false,
                updatedAt: Date(timeIntervalSince1970: 1)
            )
            continuation.yield(track)
            continuation.yield(track)
            continuation.finish()
        }
        let pipeline = NowPlayingPipeline(upstream: upstream, fetcher: fetcher)
        var iter = pipeline.output.makeAsyncIterator()
        let first = await iter.next() ?? nil
        let second = await iter.next()
        XCTAssertEqual(first?.title, "X")
        switch second {
        case .none:
            break
        case .some:
            XCTFail("Expected stream to finish without a second resolved track")
        }
    }

    func testDedupsBeforeFetchingArtwork() async throws {
        let loader = StubURLLoader()
        let firstURL = URL(string: "https://example.com/first.jpg")!
        let secondURL = URL(string: "https://example.com/second.jpg")!
        loader.results[firstURL] = .success(Data([0x01]))
        loader.results[secondURL] = .success(Data([0x02]))
        let fetcher = ArtworkFetcher(loader: loader)

        let upstream = AsyncStream<NowPlayingTrack?> { continuation in
            continuation.yield(NowPlayingTrack(
                title: "X",
                artist: "Y",
                album: "Z",
                composer: nil,
                artwork: .url(firstURL),
                source: .appleMusic,
                isPlaying: true,
                isAdvertisement: false,
                updatedAt: Date(timeIntervalSince1970: 1)
            ))
            continuation.yield(NowPlayingTrack(
                title: "X",
                artist: "Y",
                album: "Z",
                composer: nil,
                artwork: .url(secondURL),
                source: .appleMusic,
                isPlaying: true,
                isAdvertisement: false,
                updatedAt: Date(timeIntervalSince1970: 2)
            ))
            continuation.finish()
        }

        let pipeline = NowPlayingPipeline(upstream: upstream, fetcher: fetcher)
        var iter = pipeline.output.makeAsyncIterator()
        let first = await iter.next() ?? nil
        let second = await iter.next() ?? nil

        XCTAssertEqual(first?.artworkData, Data([0x01]))
        XCTAssertNil(second)
        XCTAssertEqual(loader.fetchedURLs, [firstURL])
    }
}
