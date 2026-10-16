import AppKit
import MaterialColorUtilities
import SwiftUI

/// Text colours for the main window. Plain white unless "Color text with album
/// colors" is on, in which case they're derived from the artwork.
struct TextPalette: Equatable {
    /// Song titles.
    var title: Color
    /// Artists, and the previous-song line.
    var subtitle: Color
    /// Small labels such as "UP NEXT".
    var label: Color

    // Element opacities stack on these, matching the original all-white look.
    static let white = TextPalette(title: .white, subtitle: .white.opacity(0.9), label: .white.opacity(0.45))
}

extension EnvironmentValues {
    @Entry var textPalette = TextPalette.white
}

/// Picks legible text colours from album artwork with Google's Material Color
/// Utilities, the same pipeline Android uses for wallpaper-based theming:
///
/// 1. **Quantize** a 128×128 copy of the art to at most 128 colours with the
///    Celebi quantizer (Wu's method, refined by weighted k-means in L*a*b*).
/// 2. **Score** those colours and take the best two: Score favours hues that
///    cover a lot of the image and are colourful, and filters out muddy ones.
/// 3. **Re-tone** them in HCT (hue, chroma, tone). Tone is perceptual
///    lightness, so tones 70–92 read clearly on Spooterfy's dark artwork
///    gradient and glass whatever the hue. Chroma is capped so text never
///    turns neon, and floored so it's visibly tinted.
enum AlbumTextColors {
    static func palette(for image: NSImage) -> TextPalette? {
        guard let pixels = argbPixels(image, side: 128), !pixels.isEmpty else { return nil }
        let counts = QuantizerCelebi().quantize(pixels, 128).colorToCount

        // Score falls back to Google Blue when nothing qualifies (black-and-white
        // art); a sentinel lets us spot that and stay neutral instead.
        let none = 0xFF00_0000
        let ranked = Score.score(counts, desired: 2, fallbackColorARGB: none)
        guard let seed = ranked.first, seed != none else { return nil }

        let primary = Hct.fromInt(seed)
        let secondary = ranked.dropFirst().first.map(Hct.fromInt) ?? primary
        let main = TonalPalette.of(primary.hue, min(max(primary.chroma, 24), 48))
        let accent = TonalPalette.of(secondary.hue, min(max(secondary.chroma, 24), 56))

        return TextPalette(
            title: color(main.tone(92)),
            subtitle: color(main.tone(80)),
            label: color(accent.tone(70))
        )
    }

    private static func color(_ argb: Int) -> Color {
        Color(.sRGB,
              red: Double(ColorUtils.redFromArgb(argb)) / 255,
              green: Double(ColorUtils.greenFromArgb(argb)) / 255,
              blue: Double(ColorUtils.blueFromArgb(argb)) / 255)
    }

    /// The image redrawn at side×side, as opaque ARGB ints (transparent pixels skipped).
    private static func argbPixels(_ image: NSImage, side: Int) -> [Int]? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data
        else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        let px = data.bindMemory(to: UInt8.self, capacity: side * side * 4)
        var out: [Int] = []
        out.reserveCapacity(side * side)
        for i in 0..<(side * side) where px[i * 4 + 3] == 255 {
            out.append(ColorUtils.argbFromRgb(Int(px[i * 4]), Int(px[i * 4 + 1]), Int(px[i * 4 + 2])))
        }
        return out
    }
}
