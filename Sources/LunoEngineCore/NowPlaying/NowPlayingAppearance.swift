import Foundation

public struct NowPlayingAppearance: Codable, Equatable, Sendable {
    public enum FontWeight: String, Codable, Sendable, CaseIterable {
        case regular
        case medium
        case semibold
        case bold
        case heavy
        case black
    }
}
