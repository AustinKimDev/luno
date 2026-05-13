import Foundation

public final class MusicAppScriptRunner: AppleScriptRunner, @unchecked Sendable {
    private let fetchScript: NSAppleScript?

    public init() {
        let source = """
        if application "Music" is running then
            tell application "Music"
                if player state is playing or player state is paused then
                    set isPlayingFlag to (player state is playing) as integer
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
                        set trackComposer to (composer of trk as string)
                    on error
                        set trackComposer to ""
                    end try
                    try
                        set trackPID to (persistent ID of trk as string)
                    on error
                        set trackPID to ""
                    end try
                    set artData to ""
                    try
                        set artList to artworks of trk
                        if (count of artList) > 0 then
                            set artData to (raw data of item 1 of artList)
                        end if
                    on error
                        set artData to ""
                    end try
                    return {trackName, trackArtist, trackAlbum, trackComposer, trackPID, isPlayingFlag, artData}
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
        try await MainActor.run {
            guard let script = fetchScript else {
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

        let source = """
        if application "Music" is running then
            tell application "Music" to \(action)
        end if
        """
        let invalidScriptMessage = "invalid script for \(command)"

        try await MainActor.run {
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

    private static func parse(_ descriptor: NSAppleEventDescriptor) -> RawTrackInfo? {
        guard descriptor.numberOfItems >= 6 else { return nil }
        let name = descriptor.atIndex(1)?.stringValue ?? ""
        guard !name.isEmpty else { return nil }
        let artist = descriptor.atIndex(2)?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let album = descriptor.atIndex(3)?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let composer = descriptor.atIndex(4)?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let trackID = descriptor.atIndex(5)?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        let playingFlag = descriptor.atIndex(6)?.int32Value ?? 0

        var artData: Data?
        if descriptor.numberOfItems >= 7,
           let data = descriptor.atIndex(7)?.data,
           !data.isEmpty {
            artData = data
        }

        return RawTrackInfo(
            title: name,
            artist: artist,
            album: album,
            composer: composer,
            artworkData: artData,
            artworkURL: nil,
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
