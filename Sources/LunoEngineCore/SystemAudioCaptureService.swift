import AudioToolbox
import CoreAudio
import Foundation

@available(macOS 15.0, *)
public enum SystemAudioCaptureError: Error {
    case processTapUnavailable
    case aggregateDeviceUnavailable
    case ioProcCreationFailed(OSStatus)
    case ioProcStartFailed(OSStatus)
}

enum CoreAudioTapSampleReader {
    static func copyFirstFloatChannel(from audioBufferList: UnsafePointer<AudioBufferList>) -> [Float] {
        let buffers = UnsafeMutableAudioBufferListPointer(
            UnsafeMutablePointer(mutating: audioBufferList)
        )
        guard let firstBuffer = buffers.first,
              let data = firstBuffer.mData
        else {
            return []
        }

        let sampleCount = Int(firstBuffer.mDataByteSize) / MemoryLayout<Float>.stride
        guard sampleCount > 0 else { return [] }

        let samples = data.assumingMemoryBound(to: Float.self)
        return Array(UnsafeBufferPointer(start: samples, count: sampleCount))
    }
}

@available(macOS 15.0, *)
public final class SystemAudioCaptureService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.luno.audio-capture", qos: .userInteractive)
    private let lock = NSLock()
    private let analyzer = AudioSpectrumAnalyzer()
    private let nowPlayingPulseAnalyzer = NowPlayingAudioPulseAnalyzer()
    private var tap: AudioHardwareTap?
    private var aggregateDevice: AudioHardwareAggregateDevice?
    private var ioProcID: AudioDeviceIOProcID?
    private var sampleRate: Double = 48_000
    private var analysisSamples: [Float] = []
    private var lastAnalysisUptime: UInt64 = 0
    private var latestFeatures = AudioFeatures.silent
    private var latestNowPlayingBassLevel: Float = 0
    @MainActor public var didStop: (() -> Void)?

    public init() {}

    public var scalars: AudioScalars {
        features.scalars
    }

    public var features: AudioFeatures {
        lock.lock()
        defer { lock.unlock() }
        return latestFeatures
    }

    public var nowPlayingBassLevel: Float {
        lock.lock()
        defer { lock.unlock() }
        return latestNowPlayingBassLevel
    }

    @MainActor
    public func start() async throws {
        guard tap == nil, aggregateDevice == nil, ioProcID == nil else { return }

        let system = AudioHardwareSystem.shared
        let excludedProcesses = (try? system.process(for: getpid())?.id).map { [$0] } ?? []
        let tapDescription = CATapDescription(monoGlobalTapButExcludeProcesses: excludedProcesses)
        tapDescription.name = "Luno Audio Reactor Tap"
        tapDescription.isPrivate = true
        tapDescription.muteBehavior = CATapMuteBehavior(rawValue: 0)!

        guard let tap = try system.makeProcessTap(description: tapDescription) else {
            throw SystemAudioCaptureError.processTapUnavailable
        }
        self.tap = tap

        do {
            sampleRate = max(1, (try? tap.format.mSampleRate) ?? 48_000)

            let aggregateUID = "com.luno.audio-reactor.\(UUID().uuidString)"
            let aggregateDescription: [String: Any] = [
                kAudioAggregateDeviceNameKey: "Luno Audio Reactor",
                kAudioAggregateDeviceUIDKey: aggregateUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceTapListKey: [
                    [
                        kAudioSubTapUIDKey: try tap.uid,
                        kAudioSubTapDriftCompensationKey: true,
                        kAudioSubTapDriftCompensationQualityKey: kAudioAggregateDriftCompensationHighQuality
                    ]
                ]
            ]

            guard let aggregateDevice = try system.makeAggregateDevice(description: aggregateDescription) else {
                throw SystemAudioCaptureError.aggregateDeviceUnavailable
            }
            self.aggregateDevice = aggregateDevice

            analysisSamples.reserveCapacity(AudioSpectrumAnalyzer.analysisSampleCount)

            var ioProcID: AudioDeviceIOProcID?
            let createStatus = AudioDeviceCreateIOProcID(
                aggregateDevice.id,
                Self.audioIOProc,
                Unmanaged.passUnretained(self).toOpaque(),
                &ioProcID
            )
            guard createStatus == noErr, let ioProcID else {
                throw SystemAudioCaptureError.ioProcCreationFailed(createStatus)
            }
            self.ioProcID = ioProcID

            let startStatus = AudioDeviceStart(aggregateDevice.id, ioProcID)
            guard startStatus == noErr else {
                throw SystemAudioCaptureError.ioProcStartFailed(startStatus)
            }
        } catch {
            stopCapture(reset: true)
            throw error
        }
    }

    @MainActor
    public func stop() async {
        stopCapture(reset: true)
    }

    private func stopCapture(reset: Bool) {
        let system = AudioHardwareSystem.shared
        if let aggregateDevice, let ioProcID {
            AudioDeviceStop(aggregateDevice.id, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateDevice.id, ioProcID)
        }
        if let aggregateDevice {
            try? system.destroyAggregateDevice(aggregateDevice)
        }
        if let tap {
            try? system.destroyProcessTap(tap)
        }

        ioProcID = nil
        aggregateDevice = nil
        tap = nil
        queue.async { [weak self] in
            self?.analysisSamples.removeAll(keepingCapacity: true)
            self?.lastAnalysisUptime = 0
        }
        if reset {
            resetFeatures()
        }
    }

    private static let audioIOProc: AudioDeviceIOProc = { _, _, inputData, _, _, _, clientData in
        guard let clientData else { return noErr }
        let service = Unmanaged<SystemAudioCaptureService>
            .fromOpaque(clientData)
            .takeUnretainedValue()
        service.processInput(audioBufferList: inputData)
        return noErr
    }

    private func processInput(audioBufferList: UnsafePointer<AudioBufferList>) {
        let samples = CoreAudioTapSampleReader.copyFirstFloatChannel(from: audioBufferList)
        guard !samples.isEmpty else { return }
        let sampleRate = self.sampleRate
        queue.async { [analyzer, nowPlayingPulseAnalyzer, lock] in
            self.analysisSamples.append(contentsOf: samples)
            if self.analysisSamples.count > AudioSpectrumAnalyzer.analysisSampleCount {
                self.analysisSamples.removeFirst(
                    self.analysisSamples.count - AudioSpectrumAnalyzer.analysisSampleCount
                )
            }

            let now = DispatchTime.now().uptimeNanoseconds
            guard self.lastAnalysisUptime == 0
                    || now - self.lastAnalysisUptime >= 33_000_000
            else {
                return
            }
            self.lastAnalysisUptime = now

            let nowPlayingBassLevel = nowPlayingPulseAnalyzer.bassLevel(
                samples: samples,
                sampleRate: sampleRate
            )
            let features = analyzer.analyze(samples: self.analysisSamples, sampleRate: sampleRate)
            lock.lock()
            self.latestFeatures = features
            self.latestNowPlayingBassLevel = nowPlayingBassLevel
            lock.unlock()
        }
    }

    private func resetFeatures() {
        lock.lock()
        latestFeatures = .silent
        latestNowPlayingBassLevel = 0
        lock.unlock()
    }

    deinit {
        stopCapture(reset: false)
    }
}
