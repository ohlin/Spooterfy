import CoreText
import SwiftUI

/// Atkinson Hyperlegible Next (Braille Institute, SIL Open Font License),
/// bundled in Contents/Resources/Fonts so it works without being installed.
enum Typography {
    static let family = "Atkinson Hyperlegible Next"
    static let monoFamily = "Atkinson Hyperlegible Mono"

    static func registerFonts() {
        var dirs: [URL] = []
        if let res = Bundle.main.resourceURL { dirs.append(res.appendingPathComponent("Fonts")) }
        #if DEBUG
        // `swift run` has no app bundle; use the fonts in the source tree.
        dirs.append(URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Fonts"))
        #endif
        for dir in dirs {
            guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            let fonts = files.filter { ["otf", "ttf"].contains($0.pathExtension.lowercased()) }
            CTFontManagerRegisterFontURLs(fonts as CFArray, .process, true, nil)
            if !fonts.isEmpty { return }
        }
    }
}

extension Font {
    /// The interface font at a fixed point size (used by the scaling layout).
    static func atkinson(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(Typography.family, fixedSize: size).weight(weight)
    }

    /// The interface font following a Dynamic Type style (used in Settings).
    static func atkinson(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        .custom(Typography.family, size: NSFont.preferredFont(forTextStyle: style.nsStyle).pointSize, relativeTo: style)
            .weight(weight)
    }

    static func atkinsonMono(_ style: Font.TextStyle) -> Font {
        .custom(Typography.monoFamily, size: NSFont.preferredFont(forTextStyle: style.nsStyle).pointSize, relativeTo: style)
    }
}

private extension Font.TextStyle {
    var nsStyle: NSFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}
