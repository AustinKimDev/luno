import Foundation

public enum AppleScriptRunnerError: Error, Equatable {
    case appNotInstalled
    case permissionDenied
    case scriptError(String)
}

public protocol AppleScriptRunner: Sendable {
    func fetchTrack() async throws -> RawTrackInfo?
    func sendControl(_ command: NowPlayingControlCommand) async throws
}
