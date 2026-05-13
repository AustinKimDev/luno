import Darwin
import Foundation

public typealias MRGetNowPlayingInfoFunction = @convention(c) (
    DispatchQueue,
    @escaping ([String: Any]) -> Void
) -> Void
public typealias MRRegisterFunction = @convention(c) () -> Void
public typealias MRUnregisterFunction = @convention(c) () -> Void

public struct MediaRemoteSymbols: @unchecked Sendable {
    public let getNowPlayingInfo: MRGetNowPlayingInfoFunction?
    public let registerForNotifications: MRRegisterFunction?
    public let unregisterForNotifications: MRUnregisterFunction?

    public init(
        getNowPlayingInfo: MRGetNowPlayingInfoFunction?,
        registerForNotifications: MRRegisterFunction?,
        unregisterForNotifications: MRUnregisterFunction?
    ) {
        self.getNowPlayingInfo = getNowPlayingInfo
        self.registerForNotifications = registerForNotifications
        self.unregisterForNotifications = unregisterForNotifications
    }

    public var isAvailable: Bool {
        getNowPlayingInfo != nil
    }

    public static func load() -> MediaRemoteSymbols {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            return MediaRemoteSymbols(
                getNowPlayingInfo: nil,
                registerForNotifications: nil,
                unregisterForNotifications: nil
            )
        }

        func resolve<T>(_ name: String) -> T? {
            guard let symbol = dlsym(handle, name) else { return nil }
            return unsafeBitCast(symbol, to: T.self)
        }

        let get: MRGetNowPlayingInfoFunction? = resolve("MRMediaRemoteGetNowPlayingInfo")
        let register: MRRegisterFunction? = resolve("MRMediaRemoteRegisterForNowPlayingNotifications")
        let unregister: MRUnregisterFunction? = resolve("MRMediaRemoteUnregisterForNowPlayingNotifications")

        return MediaRemoteSymbols(
            getNowPlayingInfo: get,
            registerForNotifications: register,
            unregisterForNotifications: unregister
        )
    }
}
