#if canImport(ScreenCaptureKit)
import AudioToolbox
import CoreMedia
import Foundation
import ScreenCaptureKit

@available(macOS 15.0, *)
public final class SystemAudioCaptureService: NSObject, SCStreamOutput, SCStreamDelegate {
    private let queue = DispatchQueue(label: "com.luno.audio-capture", qos: .userInteractive)
    private let lock = NSLock()
    private let analyzer = AudioSpectrumAnalyzer()
    private var stream: SCStream?
    private var latestFeatures = AudioFeatures.silent

    public override init() {
        super.init()
    }

    public var scalars: AudioScalars {
        features.scalars
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
        configuration.sampleRate = 48_000
        configuration.channelCount = 2

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
        guard outputType == .audio, sampleBuffer.isValid else { return }
        let sampleRate = sampleRate(from: sampleBuffer) ?? 48_000

        withFloatSamples(from: sampleBuffer) { buffer in
            guard !buffer.isEmpty else { return }
            let features = analyzer.analyzeFeatures(samples: buffer, sampleRate: sampleRate)
            lock.lock()
            latestFeatures = features
            lock.unlock()
        }
    }

    private func sampleRate(from sampleBuffer: CMSampleBuffer) -> Double? {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(format)
        else {
            return nil
        }
        return streamDescription.pointee.mSampleRate
    }

    private func withFloatSamples(
        from sampleBuffer: CMSampleBuffer,
        _ body: (UnsafeBufferPointer<Float>) -> Void
    ) {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(format)
        else {
            return
        }

        let description = streamDescription.pointee
        guard description.mFormatID == kAudioFormatLinearPCM,
              description.mFormatFlags & kAudioFormatFlagIsFloat != 0
        else {
            return
        }

        // ScreenCaptureKit delivers non-interleaved stereo Float32, so the AudioBufferList
        // needs one slot per channel. A stack-allocated AudioBufferList only reserves one
        // slot, which produces kCMSampleBufferError_ArrayTooSmall (-12737). Query the
        // required size first, then allocate raw bytes to hold N buffers.
        var sizeNeeded = 0
        let sizeStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &sizeNeeded,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: nil
        )
        guard sizeStatus == noErr, sizeNeeded > 0 else { return }

        let listPtr = UnsafeMutableRawPointer.allocate(
            byteCount: sizeNeeded,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { listPtr.deallocate() }
        let listAddr = listPtr.assumingMemoryBound(to: AudioBufferList.self)

        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: listAddr,
            bufferListSize: sizeNeeded,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment),
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else { return }

        let abl = UnsafeMutableAudioBufferListPointer(listAddr)
        guard abl.count > 0, let data = abl[0].mData else { return }
        let count = Int(abl[0].mDataByteSize) / MemoryLayout<Float>.stride
        let pointer = data.assumingMemoryBound(to: Float.self)
        let buffer = UnsafeBufferPointer(start: pointer, count: count)
        withExtendedLifetime(blockBuffer) {
            body(buffer)
        }
    }
}
#endif
