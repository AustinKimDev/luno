import Foundation

public protocol AppleMusicArtworkURLResolving: Sendable {
    func artworkURL(title: String, artist: String?, album: String?) async -> URL?
}

public struct NoopAppleMusicArtworkURLResolver: AppleMusicArtworkURLResolving {
    public init() {}

    public func artworkURL(title: String, artist: String?, album: String?) async -> URL? {
        nil
    }
}

public actor ITunesSearchArtworkURLResolver: AppleMusicArtworkURLResolving {
    private struct SearchResponse: Decodable {
        var results: [SearchResult]
    }

    private struct SearchResult: Decodable {
        var artworkUrl100: URL?
    }

    private var cache: [String: URL?] = [:]

    public init() {}

    public func artworkURL(title: String, artist: String?, album: String?) async -> URL? {
        let cacheKey = [title, artist ?? "", album ?? ""].joined(separator: "\u{1F}")
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let lookupURL = Self.lookupURL(title: title, artist: artist, album: album) else {
            cache[cacheKey] = nil
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: lookupURL)
            let response = try JSONDecoder().decode(SearchResponse.self, from: data)
            let artworkURL = response.results
                .compactMap(\.artworkUrl100)
                .first
                .map(Self.highResolutionURL)
            cache[cacheKey] = artworkURL
            return artworkURL
        } catch {
            cache[cacheKey] = nil
            return nil
        }
    }

    static func lookupURL(title: String, artist: String?, album: String?) -> URL? {
        let term = [artist, album, title]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " ")

        guard !term.isEmpty else { return nil }

        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1")
        ]
        return components?.url
    }

    static func highResolutionURL(from url: URL) -> URL {
        let string = url.absoluteString.replacingOccurrences(of: "100x100", with: "600x600")
        return URL(string: string) ?? url
    }
}
