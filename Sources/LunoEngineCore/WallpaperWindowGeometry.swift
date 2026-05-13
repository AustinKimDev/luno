import CoreGraphics

public struct WallpaperWindowGeometry: Equatable, Sendable {
    public var windowFrame: CGRect
    public var contentFrame: CGRect

    public init(screenFrame: CGRect) {
        self.windowFrame = screenFrame
        self.contentFrame = CGRect(origin: .zero, size: screenFrame.size)
    }
}
