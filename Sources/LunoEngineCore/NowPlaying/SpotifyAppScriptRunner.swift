import AppKit
import Foundation

public final class SpotifyAppScriptRunner: AppleScriptRunner, @unchecked Sendable {
    private static let bundleIdentifier = "com.spotify.client"

    public init() {}

    public func fetchTrack() async throws -> RawTrackInfo? {
        try await MainActor.run {
            guard Self.isSpotifyRunning() else {
                return nil
            }
            guard let script = NSAppleScript(source: Self.fetchSource) else {
                throw AppleScriptRunnerError.scriptError("script not compiled")
            }
            var error: NSDictionary?
            let descriptor = script.executeAndReturnError(&error)
            if let error {
                throw Self.mapError(error)
            }
            return Self.parse(descriptor)
        }
    }

    public func sendControl(_ command: NowPlayingControlCommand) async throws {
        let action: String
        switch command {
        case .play:
            action = "play"
        case .pause:
            action = "pause"
        case .playPause:
            action = "playpause"
        case .nextTrack:
            action = "next track"
        case .previousTrack:
            action = "previous track"
        }

        let source = "tell application id \"\(Self.bundleIdentifier)\" to \(action)"
        let invalidScriptMessage = "invalid script for \(command)"

        try await MainActor.run {
            guard Self.isSpotifyRunning() else {
                return
            }
            guard let script = NSAppleScript(source: source) else {
                throw AppleScriptRunnerError.scriptError(invalidScriptMessage)
            }
            var error: NSDictionary?
            _ = script.executeAndReturnError(&error)
            if let error {
                throw Self.mapError(error)
            }
        }
    }

    private static let fetchSource = """
    tell application id "\(bundleIdentifier)"
        set playState to player state as string
        if playState is "playing" or playState is "paused" then
            set isPlayingFlag to ((playState is "playing") as integer)
            set trk to current track
            set trackName to (name of trk as string)
            try
                set trackArtist to (artist of trk as string)
            on error
                set trackArtist to ""
            end try
            try
                set trackAlbum to (album of trk as string)
            on error
                set trackAlbum to ""
            end try
            try
                set trackArtURL to (artwork url of trk as string)
            on error
                set trackArtURL to ""
            end try
            try
                set trackSpotID to (spotify url of trk as string)
            on error
                set trackSpotID to ""
            end try
            return {trackName, trackArtist, trackAlbum, trackSpotID, isPlayingFlag, trackArtURL}
        end if
    end tell
    return {}
    """

    private static func isSpotifyRunning() -> Bool {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .contains { !$0.isTerminated }
    }

    private static func parse(_ descriptor: NSAppleEventDescriptor) -> RawTrackInfo? {
        guard descriptor.numberOfItems >= 5 else { return nil }
        let name = descriptor.atIndex(1)?.stringValue ?? ""
        guard !name.isEmpty else { return nil }
        let artist = descriptor.atIndex(2)?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let album = descriptor.atIndex(3)?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let trackID = descriptor.atIndex(4)?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let playingFlag = descriptor.atIndex(5)?.int32Value ?? 0
        let artURL: URL? = {
            guard descriptor.numberOfItems >= 6,
                  let urlString = descriptor.atIndex(6)?.stringValue,
                  !urlString.isEmpty,
                  let url = URL(string: urlString) else {
                return nil
            }
            return url
        }()

        return RawTrackInfo(
            title: name,
            artist: artist,
            album: album,
            composer: nil,
            artworkData: nil,
            artworkURL: artURL,
            trackID: trackID,
            isPlaying: playingFlag == 1
        )
    }

    private static func mapError(_ error: NSDictionary) -> AppleScriptRunnerError {
        let code = (error["NSAppleScriptErrorNumber"] as? Int) ?? 0
        if code == -1743 {
            return .permissionDenied
        }
        if code == -1728 {
            return .appNotInstalled
        }
        let message = (error["NSAppleScriptErrorMessage"] as? String) ?? "unknown AppleScript error \(code)"
        return .scriptError(message)
    }
}
