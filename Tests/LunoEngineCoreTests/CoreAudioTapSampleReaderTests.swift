import AudioToolbox
import XCTest
@testable import LunoEngineCore

final class CoreAudioTapSampleReaderTests: XCTestCase {
    func testCopiesFirstFloatChannelFromNonInterleavedAudioBufferList() {
        var left: [Float] = [0.1, -0.2, 0.3, -0.4]
        var right: [Float] = [0.9, 0.8, 0.7, 0.6]
        let leftByteCount = UInt32(left.count * MemoryLayout<Float>.stride)
        let rightByteCount = UInt32(right.count * MemoryLayout<Float>.stride)

        let samples = left.withUnsafeMutableBufferPointer { leftPointer in
            right.withUnsafeMutableBufferPointer { rightPointer in
                let list = allocateAudioBufferList([
                    AudioBuffer(
                        mNumberChannels: 1,
                        mDataByteSize: leftByteCount,
                        mData: leftPointer.baseAddress
                    ),
                    AudioBuffer(
                        mNumberChannels: 1,
                        mDataByteSize: rightByteCount,
                        mData: rightPointer.baseAddress
                    )
                ])
                defer { list.deallocate() }

                return CoreAudioTapSampleReader.copyFirstFloatChannel(from: list)
            }
        }

        XCTAssertEqual(samples, [0.1, -0.2, 0.3, -0.4])
    }
}

private func allocateAudioBufferList(_ buffers: [AudioBuffer]) -> UnsafeMutablePointer<AudioBufferList> {
    let byteCount = MemoryLayout<AudioBufferList>.size
        + max(0, buffers.count - 1) * MemoryLayout<AudioBuffer>.stride
    let rawPointer = UnsafeMutableRawPointer.allocate(
        byteCount: byteCount,
        alignment: MemoryLayout<AudioBufferList>.alignment
    )
    let list = rawPointer.assumingMemoryBound(to: AudioBufferList.self)
    list.pointee.mNumberBuffers = UInt32(buffers.count)
    let mutableBuffers = UnsafeMutableAudioBufferListPointer(list)
    for index in buffers.indices {
        mutableBuffers[index] = buffers[index]
    }
    return list
}
