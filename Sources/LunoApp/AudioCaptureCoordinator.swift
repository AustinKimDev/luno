import Foundation
import LunoEngineCore

@MainActor
final class AudioCaptureCoordinator {
    var needsAudioProvider: () -> Bool = { false }
    var accessFailureHandler: ((String) -> Void)?

    @available(macOS 15.0, *)
    private var audioCapture: SystemAudioCaptureService?

    var features: AudioFeatures {
        if #available(macOS 15.0, *) {
            return audioCapture?.features ?? .silent
        }
        return .silent
    }

    var nowPlayingBassLevel: Double {
        if #available(macOS 15.0, *) {
            return Double(audioCapture?.nowPlayingBassLevel ?? 0)
        }
        return 0
    }

    func reconcile() {
        if needsAudioProvider() {
            startIfAvailable()
        } else {
            stopIfRunning()
        }
    }

    func reconnect() {
        guard #available(macOS 15.0, *) else { return }
        let capture = audioCapture
        audioCapture = nil
        Task { @MainActor in
            await capture?.stop()
            self.reconcile()
        }
    }

    private func startIfAvailable() {
        guard #available(macOS 15.0, *) else { return }
        guard audioCapture == nil else { return }

        let capture = SystemAudioCaptureService()
        capture.didStop = { [weak self, weak capture] in
            guard let self,
                  let capture,
                  self.audioCapture === capture
            else { return }
            self.audioCapture = nil
            self.reconcile()
        }
        audioCapture = capture

        Task { @MainActor in
            do {
                try await capture.start()
            } catch {
                if self.audioCapture === capture {
                    self.audioCapture = nil
                }
                self.accessFailureHandler?("Luno is running without system audio access.")
            }
        }
    }

    private func stopIfRunning() {
        guard #available(macOS 15.0, *) else { return }
        guard let capture = audioCapture else { return }
        audioCapture = nil
        Task { @MainActor in
            await capture.stop()
        }
    }
}
