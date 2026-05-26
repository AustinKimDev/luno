import Foundation

struct WallpaperAudioRouting: Equatable {
    var usesAudioReactor: Bool
    var backgroundAudioReactiveEnabled: Bool

    func backgroundScalars(rawAudio: AudioFeatures, preferences: AudioReactorPreferences) -> AudioScalars {
        guard backgroundAudioReactiveEnabled else { return .silent }
        guard usesAudioReactor else { return rawAudio.scalars }
        return AudioScalars(
            rms: preferences.shaped(rawAudio.rms),
            bass: preferences.shaped(rawAudio.bass),
            mid: preferences.shaped(rawAudio.mid),
            treble: preferences.shaped(rawAudio.treble)
        )
    }

    func reactorScalars(rawAudio: AudioFeatures, preferences: AudioReactorPreferences) -> AudioScalars {
        guard usesAudioReactor else { return rawAudio.scalars }
        guard preferences.isEnabled else { return .silent }
        return AudioScalars(
            rms: preferences.shaped(rawAudio.rms),
            bass: preferences.shaped(rawAudio.bass),
            mid: preferences.shaped(rawAudio.mid),
            treble: preferences.shaped(rawAudio.treble)
        )
    }
}
