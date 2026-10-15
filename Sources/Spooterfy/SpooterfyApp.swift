import AppKit
import SwiftUI

@main
struct SpooterfyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = PlayerStore(auth: SpotifyAuth())

    var body: some Scene {
        Window("Spooterfy", id: "main") {
            NowPlayingView()
                .environmentObject(store)
                .environmentObject(store.auth)
                .background(WindowConfigurator())
                .onAppear { MediaKeys.shared.store = store }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 380, height: 640)
        .windowResizability(.contentMinSize)
        .commands {
            CommandMenu("Playback") {
                Button(store.isPlaying ? "Pause" : "Play") { store.playPause() }
                Button("Next Track") { store.next() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Previous Track") { store.previousTrack() }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store.auth)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        MainActor.assumeIsolated { Snapshots.runIfRequested() }
        #endif
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// Reaches the hosting NSWindow to apply "keep on top" and drag-anywhere.
private struct WindowConfigurator: NSViewRepresentable {
    @AppStorage("alwaysOnTop") private var alwaysOnTop = false

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        let onTop = alwaysOnTop
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .black
            window.level = onTop ? .floating : .normal
            // Stay visible over full-screen apps and on every Space while pinned.
            if onTop {
                window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
            } else {
                window.collectionBehavior.remove([.canJoinAllSpaces, .fullScreenAuxiliary])
            }
        }
    }
}
