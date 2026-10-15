#if DEBUG
import AppKit
import SwiftUI

/// `SPOOTERFY_SNAPSHOTS=<dir> Spooterfy` renders the main view at several
/// window sizes with sample data, writes PNGs and quits. For checking layout.
@MainActor
enum Snapshots {
    static func runIfRequested() {
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
        exit(0)
    }
}
#endif
