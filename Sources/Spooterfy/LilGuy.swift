import AppKit
import SwiftUI

// MARK: - The lil' guy

/// Spooterfy's lil' green guy, drawn from the app icon's own artwork
/// (Resources/spooterfy.icon/Assets, a 1024-point canvas), plus two arms for grabbing.
struct LilGuy: View {
    /// 0 = arms down at his sides, 1 = arms up over his head.
    var armsUp: Double = 0
    /// Blink the open eye.
    var blink = false

    static let green = Color(red: 0x1E / 255, green: 0xD7 / 255, blue: 0x60 / 255)
    static let ink = Color(white: 0x1E / 255)

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 1024
            ZStack {
                // Arms, behind the body, pivoting at the shoulders.
                arm(side: -1, s: s)
                arm(side: 1, s: s)
                Circle()
                    .fill(Self.green)
                    .frame(width: 822 * s, height: 822 * s)
                    .shadow(color: .black.opacity(0.35), radius: 30 * s, y: 12 * s)
                Face(blink: blink)
                    .frame(width: 1024 * s, height: 1024 * s)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func arm(side: Double, s: CGFloat) -> some View {
        Capsule()
            .fill(Self.green)
            .frame(width: 120 * s, height: 360 * s)
            // Hang from the shoulder, then swing from down (±25°) to up (±160°).
            .offset(y: 180 * s)
            .rotationEffect(.degrees(-side * (25 + 135 * armsUp)), anchor: .center)
            .offset(x: side * 360 * s, y: 40 * s)
    }

    /// The icon's face: an open eye, a winking eye and a smile.
    private struct Face: View {
        var blink: Bool

        var body: some View {
            Canvas { ctx, size in
                let k = size.width / 1024
                func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * k, y: y * k) }

                var smile = Path()
                smile.move(to: p(310.118, 560.405))
                smile.addCurve(to: p(345.147, 549.972), control1: p(316.905, 547.873), control2: p(332.609, 543.189))
                smile.addCurve(to: p(510.861, 604.297), control1: p(396.642, 577.804), control2: p(452.397, 596.084))
                smile.addCurve(to: p(685.126, 597.727), control1: p(569.325, 612.51), control2: p(627.941, 610.289))
                smile.addCurve(to: p(694.287, 597.362), control1: p(688.231, 597.058), control2: p(691.304, 596.936))
                smile.addCurve(to: p(715.926, 617.407), control1: p(704.665, 598.822), control2: p(713.552, 606.548))
                smile.addCurve(to: p(696.235, 648.189), control1: p(718.999, 631.338), control2: p(710.174, 645.117))
                smile.addCurve(to: p(503.648, 655.489), control1: p(633.023, 662.09), control2: p(568.229, 664.554))
                smile.addCurve(to: p(320.557, 595.446), control1: p(439.097, 646.425), control2: p(377.468, 626.228))
                smile.addCurve(to: p(310.118, 560.435), control1: p(307.987, 588.663), control2: p(303.331, 572.998))
                smile.closeSubpath()
                ctx.fill(smile, with: .color(LilGuy.ink))

                var wink = Path()
                wink.move(to: p(573.516, 429.5))
                wink.addCurve(to: p(616.016, 450.5), control1: p(573.516, 429.5), control2: p(590.016, 445.5))
                wink.addCurve(to: p(668.516, 442.5), control1: p(642.016, 455.5), control2: p(668.516, 442.5))
                ctx.stroke(wink, with: .color(LilGuy.ink), style: StrokeStyle(lineWidth: 31 * k, lineCap: .round))

                let eye = CGRect(x: (435.016 - 47) * k, y: (410 - (blink ? 8 : 47)) * k,
                                 width: 94 * k, height: (blink ? 16 : 94) * k)
                ctx.fill(Path(ellipseIn: eye), with: .color(LilGuy.ink))
            }
        }
    }
}

// MARK: - Throwing things into Spotify

/// Asks the main window to have the lil' guy throw the artwork into Spotify.
@MainActor
final class LilGuyThrower: ObservableObject {
    static let shared = LilGuyThrower()

    enum Target { case song, playlist }
    struct Request: Equatable {
        let id = UUID()
        let target: Target
    }

    @Published private(set) var request: Request?
    /// True while the lil' guy is holding the artwork, so the real one is hidden.
    @Published var artworkTaken = false

    func toss(_ target: Target) { request = Request(target: target) }
}

/// The artwork's frame in the window, so the thrown copy starts exactly on top of it.
struct ArtworkFrameKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

/// Plays the throw: the lil' guy rises from the bottom of the window, grabs the
/// artwork, and hurls it spinning out of the window towards the middle of the
/// screen while Spotify opens. The artwork fades back in once he's gone. With nothing to open (P when not playing from a playlist)
/// he pops up and shakes his head instead.
struct LilGuyStage: View {
    let artFrame: CGRect?
    let artwork: NSImage?
    let windowSize: CGSize
    let open: (LilGuyThrower.Target) -> URL?

    @ObservedObject private var thrower = LilGuyThrower.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase { case hidden, risen, grabbed, tossed, gone }
    @State private var phase = Phase.hidden
    @State private var shaking = false
    @State private var shakeAngle = 0.0
    @State private var blink = false
    @State private var busy = false
    /// Unit vector (SwiftUI coordinates, y down) from the window towards the screen's centre.
    @State private var aim = CGSize(width: 0, height: -1)

    var body: some View {
        let art = artFrame ?? CGRect(x: windowSize.width * 0.2, y: windowSize.height * 0.2,
                                     width: windowSize.width * 0.6, height: windowSize.width * 0.6)
        let guy = clamp(min(windowSize.width, windowSize.height) * 0.24, 48, 180)
        // Where he stands: peeking up over the bottom-left of the artwork.
        let standX = art.minX + art.width * 0.28
        let standY = min(art.maxY - guy * 0.15, windowSize.height - guy * 0.45)
        let hiddenY = windowSize.height + guy

        ZStack(alignment: .topLeading) {
            if let artwork, phase != .hidden, !shaking {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: art.width, height: art.height)
                    .clipShape(RoundedRectangle(cornerRadius: clamp(art.width * 0.03, 4, 14), style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                    .scaleEffect(copyScale)
                    .rotationEffect(.degrees(copyRotation))
                    .position(x: art.midX + copyOffset(art).width, y: art.midY + copyOffset(art).height)
                    .opacity(phase == .gone ? 0 : 1)
            }

            LilGuy(armsUp: phase == .grabbed ? 1 : (phase == .tossed ? 0.55 : 0), blink: blink)
                .frame(width: guy, height: guy)
                .scaleEffect(x: 1, y: phase == .grabbed ? 0.9 : 1, anchor: .bottom)
                .rotationEffect(.degrees(shaking ? shakeAngle : (phase == .tossed ? 10 : 0)), anchor: .bottom)
                .position(x: standX, y: guyY(standY: standY, hiddenY: hiddenY, guy: guy))
        }
        .frame(width: windowSize.width, height: windowSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .onChange(of: thrower.request) { _, request in
            if let request { Task { await run(request.target) } }
        }
    }

    private func guyY(standY: CGFloat, hiddenY: CGFloat, guy: CGFloat) -> CGFloat {
        switch phase {
        case .hidden, .gone: hiddenY
        case .risen: standY
        case .grabbed: standY + guy * 0.04
        case .tossed: standY - guy * 0.18 // a little hop as he lets go
        }
    }

    /// Where the thrown copy is relative to the real artwork.
    private func copyOffset(_ art: CGRect) -> CGSize {
        switch phase {
        case .hidden, .risen: .zero
        case .grabbed: CGSize(width: -art.width * 0.02, height: art.height * 0.05)
        // Far enough along the aim to leave the window from anywhere inside it.
        case .tossed, .gone:
            CGSize(width: aim.width * throwDistance(art), height: aim.height * throwDistance(art))
        }
    }

    private var copyScale: CGFloat {
        switch phase {
        case .grabbed: 0.92
        case .tossed, .gone: 0.35
        default: 1
        }
    }

    private var copyRotation: Double {
        switch phase {
        case .grabbed: -6
        case .tossed, .gone: aim.width < 0 ? -200 : 200 // spin the way it's thrown
        default: 0
        }
    }

    private func throwDistance(_ art: CGRect) -> CGFloat {
        hypot(windowSize.width, windowSize.height) + art.width
    }

    /// Points from the window's centre to the centre of its screen (menu bar and
    /// Dock excluded). Straight up when the window is already near the middle.
    private static func aimAtScreenCentre() -> CGSize {
        guard let window = BigMode.shared.window, let screen = window.screen ?? NSScreen.main else {
            return CGSize(width: 0, height: -1)
        }
        let target = screen.visibleFrame
        let dx = target.midX - window.frame.midX
        let dy = -(target.midY - window.frame.midY) // AppKit's y points up; SwiftUI's points down
        let length = hypot(dx, dy)
        guard length > 40 else { return CGSize(width: 0, height: -1) }
        return CGSize(width: dx / length, height: dy / length)
    }

    private func run(_ target: LilGuyThrower.Target) async {
        guard !busy else { return }
        let url = open(target)
        if reduceMotion {
            if let url { NSWorkspace.shared.open(url) }
            return
        }
        busy = true
        defer { busy = false }
        func step(_ animation: Animation, _ seconds: Double, _ change: () -> Void) async {
            withAnimation(animation, change)
            try? await Task.sleep(for: .seconds(seconds))
        }

        guard let url, artwork != nil else {
            // Nothing to throw: pop up, shake head, duck back down.
            shaking = true
            await step(.spring(response: 0.35, dampingFraction: 0.7), 0.35) { phase = .risen }
            for angle in [-14.0, 14, -10, 10, 0] {
                await step(.easeInOut(duration: 0.09), 0.09) { shakeAngle = angle }
            }
            await step(.easeIn(duration: 0.25), 0.3) { phase = .gone }
            phase = .hidden
            shaking = false
            return
        }

        aim = Self.aimAtScreenCentre()
        await step(.spring(response: 0.32, dampingFraction: 0.72), 0.3) { phase = .risen }
        // The copy sits exactly on the artwork, so swapping them is invisible.
        thrower.artworkTaken = true
        await step(.easeOut(duration: 0.14), 0.16) { phase = .grabbed }
        await step(.easeIn(duration: 0.45), 0.12) { phase = .tossed }
        NSWorkspace.shared.open(url)
        try? await Task.sleep(for: .seconds(0.35))
        await step(.easeInOut(duration: 0.08), 0.1) { blink = true }
        await step(.easeInOut(duration: 0.08), 0.08) { blink = false }
        await step(.easeIn(duration: 0.28), 0.3) { phase = .gone }
        phase = .hidden
        withAnimation(.easeInOut(duration: 0.6)) { thrower.artworkTaken = false }
    }
}
