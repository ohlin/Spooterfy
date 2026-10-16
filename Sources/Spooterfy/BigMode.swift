import AppKit
import SwiftUI

/// Big Boy Spooterfy Mode™.
///
/// Press F in the main window to grow it to fill the screen (leaving the menu
/// bar and Dock alone) with the largest text, and F (or Esc) again to go back
/// to exactly the frame it had before.
///
/// This grows the window in place rather than using macOS full screen, which
/// would move it to its own black Space and lose the glass over the desktop.
@MainActor
final class BigMode: ObservableObject {
    static let shared = BigMode()
    static let name = "Big Boy Spooterfy Mode™"

    @Published private(set) var isOn = false
    weak var window: NSWindow?
    private var savedFrame: NSRect?

    func toggle() {
        isOn ? exit() : enter()
    }

    func enter() {
        guard !isOn, let window, let screen = window.screen ?? NSScreen.main else { return }
        savedFrame = window.frame
        isOn = true
        // visibleFrame is the screen minus the menu bar and Dock.
        animate(window, to: screen.visibleFrame)
    }

    func exit() {
        guard isOn, let window else { return }
        isOn = false
        if let savedFrame { animate(window, to: savedFrame) }
        savedFrame = nil
    }

    #if DEBUG
    func setOnForSnapshots(_ on: Bool) { isOn = on }
    #endif

    private func animate(_ window: NSWindow, to frame: NSRect) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(frame, display: true)
        }
    }
}
