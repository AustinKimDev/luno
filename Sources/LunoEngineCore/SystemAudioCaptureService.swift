#if canImport(ScreenCaptureKit)
import AudioToolbox
import CoreMedia
import Foundation
import ScreenCaptureKit

@available(macOS 15.0, *)
public final class SystemAudioCaptureService: NSObject, SCStreamOutput, SCStreamDelegate {
    private let queue = DispatchQueue(label: "com.luno.audio-capture")
    private let lock = NSLock()
    private let analyzer = AudioSpectrumAnalyzer()
    private var stream: SCStream?
    private var latestFeatures = AudioFeatures.silent

    public override init() {
        super.init()
    }

    public var features: AudioFeatures {
        lock.lock()
        defer { lock.unlock() }
        return latestFeatures
    }

    @MainActor
    public func start() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            return
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        configuration.queueDepth = 3
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    @MainActor
    public func stop() async {
        guard let stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
    }

    public func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .audio,
              sampleBuffer.isValid,
              let samples = floatSamples(from: sampleBuffer),
              !samples.isEmpty
        else {
            return
        }

        let sampleRate = sampleRate(from: sampleBuffer) ?? 48_000
        let features = analyzer.analyze(samples: samples, sampleRate: sampleRate)
        lock.lock()
        latestFeatures = features
        lock.unlock()
    }

    private func sampleRate(from sampleBuffer: CMSampleBuffer) -> Double? {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(format)
        else {
            return nil
        }
        return streamDescription.pointee.mSampleRate
    }

    private func floatSamples(from sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(format)
        else {
            return nil
        }

        let description = streamDescription.pointee
        guard description.mFormatID == kAudioFormatLinearPCM,
              description.mFormatFlags & kAudioFormatFlagIsFloat != 0
        else {
            return nil
        }

        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.stride,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment),
            blockBufferOut: &blockBuffer
        )

        guard status == noErr,
              let data = audioBufferList.mBuffers.mData
        else {
            return nil
        }

        let count = Int(audioBufferList.mBuffers.mDataByteSize) / MemoryLayout<Float>.stride
        let buffer = data.assumingMemoryBound(to: Float.self)
        return Array(UnsafeBufferPointer(start: buffer, count: count))
    }
}
#endif
