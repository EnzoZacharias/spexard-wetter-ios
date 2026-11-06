import CoreGraphics
import Foundation
import ImageIO
import MapKit
import SwiftUI

/// The PNG frames of the model maps (`/api/v1/karten/bild`). The URL names the run, so a frame
/// never changes: the PNGs stay in a disk cache (also offline) and in memory, and only a few
/// decoded images are kept (one decoded frame is about 4.6 MB).
actor MapFrames {
    static let shared = MapFrames()

    private var pngs: [String: Data] = [:]
    private var pngOrder: [String] = []
    private var decoded: [String: CGImage] = [:]
    private var decodedOrder: [String] = []
    private let maxPngs = 200
    private let maxDecoded = 8

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("karten", isDirectory: true)
        config.urlCache = URLCache(memoryCapacity: 4 << 20, diskCapacity: 80 << 20, directory: folder)
        config.timeoutIntervalForRequest = 25
        return URLSession(configuration: config)
    }()

    /// Decoded image of a frame; nil when the server has none (or it cannot be read).
    func image(path: String, mock: String?) async -> CGImage? {
        if let image = decoded[path] {
            touch(&decodedOrder, path)
            return image
        }
        guard let data = await png(path: path, mock: mock), let image = Self.decode(data) else { return nil }
        decoded[path] = image
        touch(&decodedOrder, path)
        while decodedOrder.count > maxDecoded {
            decoded[decodedOrder.removeFirst()] = nil
        }
        return image
    }

    /// Loads the PNG only (prefetch of a layer before it is played).
    func prefetch(path: String, mock: String?) async {
        _ = await png(path: path, mock: mock)
    }

    private func png(path: String, mock: String?) async -> Data? {
        if let data = pngs[path] { return data }
        let data: Data?
        if APIClient.isMock {
            data = mock.flatMap { Bundle.main.url(forResource: $0, withExtension: "png") }.flatMap { try? Data(contentsOf: $0) }
        } else {
            data = await download(path)
        }
        guard let data else { return nil }
        pngs[path] = data
        touch(&pngOrder, path)
        while pngOrder.count > maxPngs {
            pngs[pngOrder.removeFirst()] = nil
        }
        return data
    }

    private func download(_ path: String) async -> Data? {
        let base = ServerSettings.normalized(ServerSettings.current)
        guard !base.isEmpty, let url = URL(string: base + path) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("image/png", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return data
    }

    private func touch(_ order: inout [String], _ key: String) {
        order.removeAll { $0 == key }
        order.append(key)
    }

    /// Decodes the PNG into a bitmap now (not lazily while MapKit draws its tiles).
    private static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        return CGImageSourceCreateImageAtIndex(source, 0, options)
    }
}

/// Reads the class under a map position from a frame: the PNG holds one palette colour per
/// legend class, so the colour of the pixel names the class.
enum MapProbe {
    struct RGB { let r: Double; let g: Double; let b: Double }

    static func rgb(_ hex: String) -> RGB? {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        return RGB(r: Double((v >> 16) & 0xff), g: Double((v >> 8) & 0xff), b: Double(v & 0xff))
    }

    static func color(_ hex: String) -> Color {
        guard let c = rgb(hex) else { return .gray }
        return Color(red: c.r / 255, green: c.g / 255, blue: c.b / 255)
    }

    /// Pixel of `coordinate` in an image covering `bounds` (Web Mercator), nil outside.
    static func pixel(_ bounds: RadarResponse.Bounds, width: Int, height: Int, at coordinate: CLLocationCoordinate2D) -> (x: Int, y: Int)? {
        let rect = RadarOverlay(bounds: bounds).boundingMapRect
        let p = MKMapPoint(coordinate)
        guard rect.contains(p), width > 0, height > 0 else { return nil }
        let x = Int((p.x - rect.minX) / rect.width * Double(width))
        let y = Int((p.y - rect.minY) / rect.height * Double(height))
        guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }
        return (x, y)
    }

    /// Class of the legend at a pixel: index into `classes`, -1 = nothing drawn, nil = unreadable.
    static func classIndex(_ image: CGImage, x: Int, y: Int, classes: [MapsResponse.LegendClass]) -> Int? {
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn: Bool = pixel.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .none
            // the image's pixel (x, y) from the top lands on the context's only pixel
            context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
            return true
        }
        guard drawn else { return nil }
        let alpha = Double(pixel[3])
        if alpha < 8 { return -1 }
        let r = Double(pixel[0]) * 255 / alpha, g = Double(pixel[1]) * 255 / alpha, b = Double(pixel[2]) * 255 / alpha
        var best: (Int, Double)?
        for (i, c) in classes.enumerated() {
            guard let k = rgb(c.color) else { continue }
            let d = (k.r - r) * (k.r - r) + (k.g - g) * (k.g - g) + (k.b - b) * (k.b - b)
            if best == nil || d < best!.1 { best = (i, d) }
        }
        return best?.0
    }
}
