import AppKit
import SwiftUI

/// Matches the macOS Liquid Glass choice in System Settings → Appearance.
enum GlassStyle: String, CaseIterable, Identifiable {
    case clear, tinted
    var id: String { rawValue }
    var title: String { self == .clear ? "Clear" : "Tinted" }
    var nsStyle: NSGlassEffectView.Style { self == .clear ? .clear : .regular }
    var swiftUI: Glass { self == .clear ? .clear : .regular }
}

enum GlassDefaults {
    /// Frosted while you're using the window, clear when it's in the background.
    static let focused = GlassStyle.tinted
    static let background = GlassStyle.clear
    static let darkness = 0.1
    static let albumGlow = true
}

/// Window-filling Liquid Glass that samples whatever is behind the window.
struct WindowGlass: NSViewRepresentable {
    var style: GlassStyle

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.cornerRadius = 0 // the window's own rounded frame clips the corners
        view.style = style.nsStyle
        return view
    }

    func updateNSView(_ view: NSGlassEffectView, context: Context) {
        view.style = style.nsStyle
    }
}
