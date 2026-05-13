#if canImport(AppKit)
import AppKit

public struct WallpaperWindowConfiguration: Equatable, Sendable {
    public var collectionBehavior: NSWindow.CollectionBehavior

    public init(
        collectionBehavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
    ) {
        self.collectionBehavior = collectionBehavior
    }
}
#endif
