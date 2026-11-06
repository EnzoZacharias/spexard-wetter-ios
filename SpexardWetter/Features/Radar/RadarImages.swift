import CoreGraphics
import SwiftUI
import UIKit

/// Colours of the rain-rate classes of the radar (class 1 = lightest). Own scale: light rain in
/// blues, moderate in green and yellow, heavy in orange and red, extreme in violet.
enum RadarPalette {
    static let rgb: [(UInt8, UInt8, UInt8)] = [
        (168, 216, 255), // 1: 0,1–0,5
        (108, 184, 255), // 2: 0,5–1
        (47, 140, 255),  // 3: 1–2,5
        (47, 196, 107),  // 4: 2,5–5
        (242, 209, 41),  // 5: 5–10
        (242, 140, 30),  // 6: 10–25
        (224, 53, 43),   // 7: 25–50
        (176, 47, 201),  // 8: ab 50
    ]

    static func rgba(forClass value: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        guard value > 0 else { return (0, 0, 0, 0) }
        let c = rgb[min(value, rgb.count) - 1]
        return (c.0, c.1, c.2, 255)
    }

    static func color(forClass value: Int) -> Color {
        let c = rgba(forClass: value)
        return Color(red: Double(c.0) / 255, green: Double(c.1) / 255, blue: Double(c.2) / 255)
    }
}

enum RadarImages {
    /// `[class, count, class, count, ...]` -> one class per pixel, or nil if the runs do not fill the raster.
    static func decode(_ rle: [Int]?, pixels: Int) -> [UInt8]? {
        guard let rle, rle.count % 2 == 0, pixels > 0 else { return nil }
        var out = [UInt8](repeating: 0, count: pixels)
        var pos = 0
        var i = 0
        while i < rle.count {
            let value = rle[i]
            let count = rle[i + 1]
            if count < 0 || pos + count > pixels { return nil }
            if value != 0 {
                out.replaceSubrange(pos..<(pos + count), with: repeatElement(UInt8(clamping: value), count: count))
            }
            pos += count
            i += 2
        }
        return pos == pixels ? out : nil
    }

    /// RGBA image of one frame (dry pixels transparent).
    static func image(classes: [UInt8], size: Int) -> CGImage? {
        guard classes.count == size * size else { return nil }
        var lut = [(UInt8, UInt8, UInt8, UInt8)](repeating: (0, 0, 0, 0), count: 256)
        for v in 1..<256 { lut[v] = RadarPalette.rgba(forClass: v) }
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        for (i, c) in classes.enumerated() where c != 0 {
            let color = lut[Int(c)]
            let o = i * 4
            bytes[o] = color.0
            bytes[o + 1] = color.1
            bytes[o + 2] = color.2
            bytes[o + 3] = color.3
        }
        let data = Data(bytes) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(
            width: size,
            height: size,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    /// Images of all frames (nil where a frame has no readable raster).
    static func images(for response: RadarResponse) -> [CGImage?] {
        let size = response.map.size
        return response.frames.map { frame in
            decode(frame.rle, pixels: size * size).flatMap { image(classes: $0, size: size) }
        }
    }
}
