import Foundation

public final class SpotifyAppScriptRunner: AppleScriptRunner, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.luno.applescript.spotify")
    private let fetchScript: NSAppleScript?

    public init() {
        let source = """
        if application "Spotify" is running then
            tell application "Spotify"
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
        end if
        return {}
        """
        self.fetchScript = NSAppleScript(source: source)
        var compileError: NSDictionary?
        _ = self.fetchScript?.compileAndReturnError(&compileError)
    }

    public func fetchTrack() async throws -> RawTrackInfo? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                guard let script = self.fetchScript else {
                    continuation.resume(throwing: AppleScriptRunnerError.scriptError("script not compiled"))
                    return
                }
                var error: NSDictionary?
                let descriptor = script.executeAndReturnError(&error)
                if let error {
                    continuation.resume(throwing: Self.mapError(error))
                    return
                }
                continuation.resume(returning: Self.parse(descriptor))
            }
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

        let source = """
        if application "Spotify" is running then
            tell application "Spotify" to \(action)
        end if
        """
        let invalidScriptMessage = "invalid script for \(command)"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard let script = NSAppleScript(source: source) else {
                    continuation.resume(throwing: AppleScriptRunnerError.scriptError(invalidScriptMessage))
                    return
                }
                var error: NSDictionary?
                _ = script.executeAndReturnError(&error)
                if let error {
                    continuation.resume(throwing: Self.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
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
