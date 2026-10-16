import AppKit
import SwiftUI

/// User text size, stepped with ⌘+ / ⌘- and reset with ⌘0. It multiplies the
/// window-size-based font sizes, so text still scales with the window too.
enum TextScale {
    static let key = "textScale"
    /// 80% to 175%: small enough for a compact window, large enough to read across a room.
    static let steps: [Double] = [0.8, 0.9, 1.0, 1.15, 1.3, 1.5, 1.75]
    static let standard = 1.0

    static func bigger(than value: Double) -> Double {
        steps.first { $0 > value + 0.001 } ?? steps.last!
    }

    static func smaller(than value: Double) -> Double {
        steps.last { $0 < value - 0.001 } ?? steps.first!
    }

    static func label(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    /// ⌘= also makes text bigger, since + is Shift-= on most keyboards.
    @MainActor
    static func installEqualsShortcut() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard mods == .command, event.charactersIgnoringModifiers == "=" else { return event }
            let defaults = UserDefaults.standard
            let current = defaults.object(forKey: key) as? Double ?? standard
            defaults.set(bigger(than: current), forKey: key)
            return nil
        }
    }
}

extension EnvironmentValues {
    @Entry var textScale: CGFloat = 1
    /// Multiplies the size caps that keep text tidy in small windows; raised in
    /// Big Boy Spooterfy Mode™ so text can grow with the whole screen.
    @Entry var textCeiling: CGFloat = 1
}
