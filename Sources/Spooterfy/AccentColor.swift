import AppKit
import SwiftUI

/// Picks the most vivid colour in a piece of album art, brightened enough to
/// read against the dark bottom of the artwork. Mostly grey art gives white.
enum AccentColor {
    static func from(_ image: NSImage) -> Color {
        let size = 32
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                                  bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data
        else { return .white }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))
        let px = data.bindMemory(to: UInt8.self, capacity: size * size * 4)

        // Weight each hue bucket by how saturated and bright its pixels are.
        let buckets = 18
        var weight = [Double](repeating: 0, count: buckets)
        var sums = [(h: Double, s: Double, b: Double)](repeating: (0, 0, 0), count: buckets)
        for i in 0..<(size * size) {
            let r = CGFloat(px[i * 4]) / 255, g = CGFloat(px[i * 4 + 1]) / 255, b = CGFloat(px[i * 4 + 2]) / 255
            var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
            NSColor(srgbRed: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &s, brightness: &v, alpha: &a)
            guard s > 0.2, v > 0.2 else { continue }
            let w = Double(s * s * v)
            let k = min(buckets - 1, Int(h * CGFloat(buckets)))
            weight[k] += w
            sums[k].h += Double(h) * w
            sums[k].s += Double(s) * w
            sums[k].b += Double(v) * w
        }
        guard let best = weight.indices.max(by: { weight[$0] < weight[$1] }),
              weight[best] > Double(size * size) * 0.02
        else { return .white }

        let w = weight[best]
        let hue = sums[best].h / w
        let sat = min(0.85, max(0.45, sums[best].s / w))
        let bri = max(0.85, sums[best].b / w)
        return Color(hue: hue, saturation: sat, brightness: bri)
    }
}
