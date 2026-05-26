import Foundation

struct LunoAppPaths {
    var root: URL
    var packages: URL
    var presets: URL
    var assignments: URL
    var audioReactorPreferences: URL
    var nowPlayingPreferences: URL

    static func `default`() throws -> LunoAppPaths {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appending(path: "Luno", directoryHint: .isDirectory)

        return LunoAppPaths(
            root: root,
            packages: root.appending(path: "Packages", directoryHint: .isDirectory),
            presets: root.appending(path: "presets.json"),
            assignments: root.appending(path: "assignments.json"),
            audioReactorPreferences: root.appending(path: "audio-reactor.json"),
            nowPlayingPreferences: root.appending(path: "now-playing.json")
        )
    }
}
