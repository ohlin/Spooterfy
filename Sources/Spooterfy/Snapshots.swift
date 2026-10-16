#if DEBUG
import AppKit
import SwiftUI

/// `SPOOTERFY_SNAPSHOTS=<dir> Spooterfy` renders the main view at several
/// window sizes with sample data, writes PNGs and quits. For checking layout.
@MainActor
enum Snapshots {
    static func runIfRequested() {
        guard ProcessInfo.processInfo.environment["SPOOTERFY_SNAPSHOTS"] != nil else { return }
        Task { await render() }
    }

    private static func render() async {
        guard let dir = ProcessInfo.processInfo.environment["SPOOTERFY_SNAPSHOTS"] else { return }
        let auth = SpotifyAuth()
        auth.pretendSignedIn()
        let store = PlayerStore(auth: auth)
        func item(_ name: String, _ artist: String) -> Item {
            let json = #"{"id":"\#(UUID())","name":"\#(name)","duration_ms":215000,"artists":[{"name":"\#(artist)"}]}"#
            let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
            return try! d.decode(Item.self, from: Data(json.utf8))
        }
        let art = NSImage(size: NSSize(width: 640, height: 640), flipped: false) { rect in
            NSGradient(colors: [.systemPink, .systemOrange, .systemPurple])!.draw(in: rect, angle: 45)
            return true
        }
        store.loadSample(
            current: item("Midnight City", "M83"),
            previous: item("Breezeblocks", "alt-J"),
            upNext: [item("Kids", "MGMT"), item("Electric Feel", "MGMT"), item("Dreams", "Fleetwood Mac"),
                     item("Little Dark Age", "MGMT"), item("Do I Wanna Know?", "Arctic Monkeys"),
                     item("The Less I Know the Better", "Tame Impala")],
            artwork: art)
        store.stopPollingForSnapshots()

        let sizes: [(Int, Int)] = [(380, 640), (200, 200), (260, 420), (700, 380), (1100, 700), (500, 1000)]
        for (w, h) in sizes {
            let view = NowPlayingView()
                .environmentObject(store)
                .environmentObject(auth)
                .frame(width: CGFloat(w), height: CGFloat(h))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            if let cg = renderer.cgImage {
                let rep = NSBitmapImageRep(cgImage: cg)
                let url = URL(fileURLWithPath: dir).appendingPathComponent("snap-\(w)x\(h).png")
                try? rep.representation(using: .png, properties: [:])?.write(to: url)
            }
        }
        // Smallest and largest text sizes. (The debug binary has its own defaults domain.)
        for scale in [TextScale.steps.first!, TextScale.steps.last!] {
            UserDefaults.standard.set(scale, forKey: TextScale.key)
            for (w, h) in [(380, 640), (700, 380)] {
                let view = NowPlayingView()
                    .environmentObject(store)
                    .environmentObject(auth)
                    .frame(width: CGFloat(w), height: CGFloat(h))
                let renderer = ImageRenderer(content: view)
                renderer.scale = 1
                if let cg = renderer.cgImage,
                   let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("snap-text\(Int(scale * 100))-\(w)x\(h).png"))
                }
            }
        }
        UserDefaults.standard.removeObject(forKey: TextScale.key)

        // Album-coloured text, for this art and for a few typical covers.
        UserDefaults.standard.set(true, forKey: "albumTextColors")
        func solid(_ colors: [NSColor]) -> NSImage {
            NSImage(size: NSSize(width: 640, height: 640), flipped: false) { rect in
                NSGradient(colors: colors)!.draw(in: rect, angle: -60)
                return true
            }
        }
        let covers: [(String, NSImage)] = [
            ("sample", art),
            ("teal", solid([.black, NSColor(srgbRed: 0.05, green: 0.45, blue: 0.5, alpha: 1), NSColor(srgbRed: 0.9, green: 0.85, blue: 0.7, alpha: 1)])),
            ("red", solid([NSColor(srgbRed: 0.55, green: 0.05, blue: 0.08, alpha: 1), NSColor(srgbRed: 0.95, green: 0.35, blue: 0.2, alpha: 1)])),
            ("grey", solid([.black, .gray, .white])),
        ]
        for (name, cover) in covers {
            store.loadSample(current: store.current!, previous: store.previous!, upNext: store.upNext, artwork: cover)
            try? await Task.sleep(for: .seconds(1)) // palette is computed off the main thread
            FileHandle.standardError.write(Data("\(name): palette \(store.albumTextPalette == nil ? "none (stays white)" : "picked")\n".utf8))
            let view = NowPlayingView()
                .environmentObject(store)
                .environmentObject(auth)
                .frame(width: 380, height: 640)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            if let cg = renderer.cgImage,
               let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("snap-color-\(name).png"))
            }
        }
        UserDefaults.standard.removeObject(forKey: "albumTextColors")

        // The same window after Spotify stops.
        store.setIdleForSnapshots(true)
        let idleView = NowPlayingView()
            .environmentObject(store)
            .environmentObject(auth)
            .frame(width: 380, height: 640)
        let idleRenderer = ImageRenderer(content: idleView)
        idleRenderer.scale = 1
        if let cg = idleRenderer.cgImage,
           let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("snap-idle-380x640.png"))
        }
        exit(0)
    }
}
#endif
