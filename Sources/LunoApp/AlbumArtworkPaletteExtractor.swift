import Foundation
import ImageIO
import LunoEngineCore

enum AlbumArtworkPaletteExtractor {
    static func extract(from artworkData: Data) -> AlbumPalette? {
        guard let source = CGImageSourceCreateWithData(artworkData as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCache: false,
                kCGImageSourceThumbnailMaxPixelSize: 48
              ] as CFDictionary)
        else {
            return nil
        }

        let size = 48
        let bytesPerPixel = 4
        let bytesPerRow = size * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: size * size * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        let didDraw = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: size,
                    height: size,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                  )
            else {
                return false
            }

            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
            return true
        }

        guard didDraw else { return nil }

        var samples: [AlbumPaletteExtractor.Sample] = []
        samples.reserveCapacity(size * size)
        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let alpha = pixels[index + 3]
            samples.append(
                AlbumPaletteExtractor.Sample(
                    red: unpremultiplied(pixels[index], alpha: alpha),
                    green: unpremultiplied(pixels[index + 1], alpha: alpha),
                    blue: unpremultiplied(pixels[index + 2], alpha: alpha),
                    alpha: alpha
                )
            )
        }

        return AlbumPaletteExtractor.extract(from: samples)
    }

    private static func unpremultiplied(_ component: UInt8, alpha: UInt8) -> UInt8 {
        guard alpha > 0, alpha < 255 else { return component }
        return UInt8(min(255, (Int(component) * 255) / Int(alpha)))
    }
}
