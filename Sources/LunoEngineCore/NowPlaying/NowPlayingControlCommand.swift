import Foundation

public enum NowPlayingControlCommand: String, Sendable {
    case play
    case pause
    case playPause
    case nextTrack
    case previousTrack
}
