import Foundation

public protocol ArtworkURLLoader: Sendable {
    func loadData(from url: URL) async throws -> Data
}

public struct URLSessionArtworkLoader: ArtworkURLLoader {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func loadData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

public actor ArtworkFetcher {
    private let loader: ArtworkURLLoader
    private let cacheLimit: Int
    private var cache: [URL: Data] = [:]

    public init(loader: ArtworkURLLoader = URLSessionArtworkLoader(), cacheLimit: Int = 64) {
        self.loader = loader
        self.cacheLimit = cacheLimit
    }

    public func data(for url: URL) async throws -> Data {
        if let cached = cache[url] {
            return cached
        }

        let data = try await loader.loadData(from: url)
        cache[url] = data
        if cache.count > cacheLimit,
           let key = cache.keys.first(where: { $0 != url }) {
            cache.removeValue(forKey: key)
        }
        return data
    }
}
