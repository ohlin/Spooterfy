import AppKit
import SwiftUI

/// Clear and Tinted match the Liquid Glass choice in System Settings → Appearance.
/// Both still blur what's behind them, so Transparent drops the glass entirely.
enum GlassStyle: String, CaseIterable, Identifiable {
    case transparent, clear, tinted
    var id: String { rawValue }
    var title: String {
        switch self {
        case .transparent: "Transparent"
        case .clear: "Clear"
        case .tinted: "Tinted"
        }
    }
    var nsStyle: NSGlassEffectView.Style { self == .tinted ? .regular : .clear }
    /// How strongly the album-colour wash shows over this style.
    var albumGlowOpacity: Double {
        switch self {
        case .transparent: 0.08
        case .clear: 0.12
        case .tinted: 0.45
        }
    }
}

enum GlassDefaults {
    /// The same clear glass whether or not the window is focused.
    static let focused = GlassStyle.clear
    static let background = GlassStyle.clear
    static let darkness = 0.1
    static let albumGlow = true
}

/// Window-filling Liquid Glass that samples whatever is behind the window.
struct WindowGlass: NSViewRepresentable {
    var style: GlassStyle

    func makeNSView(context: Context) -> SteadyGlassView {
        let view = SteadyGlassView()
        view.cornerRadius = 0 // the window's own rounded frame clips the corners
        view.style = style.nsStyle
        return view
    }

    func updateNSView(_ view: SteadyGlassView, context: Context) {
        view.style = style.nsStyle
    }
}

/// Glass that looks the same whether or not its window is focused.
///
/// While the window is key, AppKit fades in a vibrancy layer over the glass
/// (a sibling of the backdrop layer, filtered with `vibrantColorMatrix`), which
/// tints it; when the window resigns key it fades back out. Hiding that layer
/// keeps the focused look identical to the background look. If a future macOS
/// changes the layer tree, nothing matches and the glass simply behaves as stock.
final class SteadyGlassView: NSGlassEffectView {
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        guard let window else { return }
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.hideFocusTint() }
            })
        }
        hideFocusTint()
    }

    override func layout() {
        super.layout()
        hideFocusTint()
    }

    private func hideFocusTint() {
        // Now, and again once AppKit has applied the new key state.
        apply()
        DispatchQueue.main.async { [weak self] in self?.apply() }
    }

    private func apply() {
        guard let root = layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for tint in Self.focusTintLayers(in: root) where !tint.isHidden {
            tint.isHidden = true
        }
        CATransaction.commit()
    }

    /// Layers with a `vibrantColorMatrix` filter that sit beside a backdrop layer.
    private static func focusTintLayers(in layer: CALayer) -> [CALayer] {
        var found: [CALayer] = []
        let children = layer.sublayers ?? []
        if children.contains(where: { NSStringFromClass(type(of: $0)) == "CABackdropLayer" }) {
            found += children.filter { child in
                (child.filters as? [NSObject])?.contains { ($0.value(forKey: "name") as? String) == "vibrantColorMatrix" } ?? false
            }
        }
        for child in children { found += focusTintLayers(in: child) }
        return found
    }
}
