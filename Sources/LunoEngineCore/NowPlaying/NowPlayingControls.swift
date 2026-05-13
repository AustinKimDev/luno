import Foundation

public protocol NowPlayingControls: Sendable {
    func send(_ command: NowPlayingControlCommand) async throws
}
