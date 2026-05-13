import XCTest
@testable import LunoEngineCore

final class StubURLLoader: ArtworkURLLoader, @unchecked Sendable {
    var results: [URL: Result<Data, Error>] = [:]
    private(set) var fetchedURLs: [URL] = []

    func loadData(from url: URL) async throws -> Data {
        fetchedURLs.append(url)
        if let result = results[url] {
            return try result.get()
        }
        throw URLError(.cannotConnectToHost)
    }
}

final class ArtworkFetcherTests: XCTestCase {
    func testReturnsCachedDataAfterFirstFetch() async throws {
        let loader = StubURLLoader()
        let url = URL(string: "https://example.com/art.jpg")!
        loader.results[url] = .success(Data([0xAA, 0xBB]))
        let fetcher = ArtworkFetcher(loader: loader)

        let first = try await fetcher.data(for: url)
        let second = try await fetcher.data(for: url)

        XCTAssertEqual(first, Data([0xAA, 0xBB]))
        XCTAssertEqual(second, Data([0xAA, 0xBB]))
        XCTAssertEqual(loader.fetchedURLs.count, 1, "Second fetch must hit cache")
    }

    func testThrowsWhenLoaderFails() async {
        let loader = StubURLLoader()
        let url = URL(string: "https://example.com/missing.jpg")!
        loader.results[url] = .failure(URLError(.fileDoesNotExist))
        let fetcher = ArtworkFetcher(loader: loader)
        do {
            _ = try await fetcher.data(for: url)
            XCTFail("Expected error")
        } catch {
        }
    }
}
