import Foundation

public struct RawTrackInfo: Equatable, Sendable {
    public var title: String
    public var artist: String?
    public var album: String?
    public var composer: String?
    public var artworkData: Data?
    public var artworkURL: URL?
    public var trackID: String?
    public var isPlaying: Bool

    public init(
        title: String,
        artist: String?,
        album: String?,
        composer: String?,
        artworkData: Data?,
        artworkURL: URL?,
        trackID: String?,
        isPlaying: Bool
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.composer = composer
        self.artworkData = artworkData
        self.artworkURL = artworkURL
        self.trackID = trackID
        self.isPlaying = isPlaying
    }
}
