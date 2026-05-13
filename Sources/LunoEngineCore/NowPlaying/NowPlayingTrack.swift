import Foundation

public struct NowPlayingTrack: Codable, Equatable, Sendable {
    public var title: String
    public var artist: String?
    public var album: String?
    public var composer: String?
    public var artwork: Artwork?
    public var source: NowPlayingSource
    public var isPlaying: Bool
    public var isAdvertisement: Bool
    public var updatedAt: Date

    public init(
        title: String,
        artist: String?,
        album: String?,
        composer: String?,
        artwork: Artwork?,
        source: NowPlayingSource,
        isPlaying: Bool,
        isAdvertisement: Bool,
        updatedAt: Date
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.composer = composer
        self.artwork = artwork
        self.source = source
        self.isPlaying = isPlaying
        self.isAdvertisement = isAdvertisement
        self.updatedAt = updatedAt
    }

    public enum Artwork: Codable, Equatable, Sendable {
        case data(Data)
        case url(URL)
    }
}
