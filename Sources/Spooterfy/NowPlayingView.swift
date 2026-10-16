import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var store: PlayerStore
    @EnvironmentObject private var auth: SpotifyAuth
    @AppStorage(TextScale.key) private var textScale = TextScale.standard
    @AppStorage("albumTextColors") private var albumTextColors = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                BackdropView(image: store.artwork)
                if !auth.isSignedIn {
                    ConnectPrompt()
                        .padding(20)
                } else if let current = store.current {
                    PlayerLayout(size: geo.size, current: current)
                } else {
                    EmptyState(message: store.problem ?? "Connecting to Spotify…")
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .environment(\.textScale, CGFloat(textScale))
        .environment(\.textPalette, albumTextColors ? store.albumTextPalette ?? .white : .white)
        .animation(.easeInOut(duration: 0.2), value: textScale)
        .frame(minWidth: 140, minHeight: 140)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) { store.playPause(); return .handled }
        .onKeyPress(.rightArrow) { store.next(); return .handled }
        .onKeyPress(.leftArrow) { store.previousTrack(); return .handled }
    }
}

// MARK: - Layout

/// Every size is derived from the window size, so the layout scales
/// continuously while resizing instead of jumping between breakpoints.
private struct PlayerLayout: View {
    let size: CGSize
    let current: Item
    @EnvironmentObject private var store: PlayerStore

    @Environment(\.textScale) private var textScale

    var body: some View {
        let w = size.width, h = size.height
        let pad = clamp(min(w, h) * 0.05, 8, 24)
        let gap = pad * 0.6
        let wide = w > h * 1.3

        if wide {
            // Side by side: artwork left, previous + up next on the right.
            let art = min(h - pad * 2, w * 0.62)
            let colWidth = w - art - pad * 3
            let font = clamp(colWidth * 0.055, 10, 15) * textScale
            HStack(alignment: .top, spacing: pad) {
                ArtworkCard(item: current, side: art)
                if colWidth > 90 {
                    VStack(alignment: .leading, spacing: gap) {
                        if let previous = store.previous {
                            PreviousRow(item: previous, font: font)
                                .idleFaded(store.isIdle)
                        }
                        QueueList(items: store.upNext, font: font)
                            .idleFaded(store.isIdle)
                    }
                    .frame(width: colWidth, height: art, alignment: .top)
                }
            }
            .padding(pad)
            .frame(width: w, height: h, alignment: .leading)
        } else {
            // Stacked: previous above, artwork, up next below.
            let font = clamp(w * 0.034, 10, 15) * textScale
            let rowH = font * 2.6
            let showPrev = store.previous != nil && h > 220
            let prevH = showPrev ? font * 1.5 + gap : 0
            let avail = h - pad * 2 - prevH
            // Keep room for a couple of queue rows once the window is tall enough.
            let reserve = h > 320 ? rowH * 2.2 + gap : 0
            let art = max(60, min(w - pad * 2, avail - reserve))
            let queueH = avail - art - gap

            VStack(spacing: gap) {
                if showPrev, let previous = store.previous {
                    PreviousRow(item: previous, font: font)
                        .frame(width: art, alignment: .leading)
                        .idleFaded(store.isIdle)
                }
                ArtworkCard(item: current, side: art)
                if queueH > rowH {
                    QueueList(items: store.upNext, font: font)
                        .frame(width: art, height: queueH, alignment: .top)
                        .idleFaded(store.isIdle)
                }
            }
            .padding(pad)
            .frame(width: w, height: h, alignment: .top)
        }
    }
}

// MARK: - Artwork

private struct ArtworkCard: View {
    let item: Item
    let side: CGFloat
    @EnvironmentObject private var store: PlayerStore
    @AppStorage("showControlsOnHover") private var showControls = true
    @State private var hovering = false

    @Environment(\.textScale) private var textScale

    @Environment(\.textPalette) private var palette

    var body: some View {
        let radius = clamp(side * 0.03, 4, 14)
        let titleSize = clamp(side * 0.075, 12, 46) * textScale
        let artistSize = clamp(side * 0.05, 10, 30) * textScale
        let inset = clamp(side * 0.055, 8, 28)

        ZStack(alignment: .bottomLeading) {
          // Artwork and titles fade when Spotify has stopped; the controls don't,
          // so hovering still offers a full-strength play button.
          ZStack(alignment: .bottomLeading) {
            artwork
                .frame(width: side, height: side)
                .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.35), .black.opacity(0.8)],
                           startPoint: .init(x: 0.5, y: 0.45), endPoint: .bottom)

            VStack(alignment: .leading, spacing: side * 0.008) {
                Text(item.name)
                    .font(.atkinson(titleSize, .bold))
                    .lineLimit(2)
                Text(item.subtitle)
                    .font(.atkinson(artistSize, .medium))
                    .foregroundStyle(palette.subtitle.opacity(0.85))
                    .lineLimit(1)
            }
            .minimumScaleFactor(0.7)
            .foregroundStyle(palette.title)
            .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
            .padding(.horizontal, inset)
            .padding(.bottom, inset + 4)
            .id(item.id)
            .transition(.opacity)
          }
          .idleFaded(store.isIdle)

            if showControls && hovering {
                TransportControls(size: side)
                    .frame(width: side, height: side)
                    .transition(.opacity)
            }

            // Above the controls so it stays clickable while they're showing.
            if !store.isIdle {
                Scrubber(durationMs: item.durationMs, side: side)
                    .transition(.opacity)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: side * 0.04, y: side * 0.015)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
    }

    @ViewBuilder private var artwork: some View {
        if let image = store.artwork {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .transition(.opacity)
                .id(ObjectIdentifier(image))
        } else {
            ZStack {
                LinearGradient(colors: [Color(white: 0.22), Color(white: 0.1)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note")
                    .font(.system(size: side * 0.25))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
    }
}

/// Progress bar along the bottom of the artwork, tinted with the album's
/// accent colour. It thickens on hover; click or drag anywhere on it to seek.
private struct Scrubber: View {
    let durationMs: Int?
    let side: CGFloat
    @EnvironmentObject private var store: PlayerStore
    @State private var hoverX: CGFloat?
    @State private var dragFraction: Double?

    @Environment(\.textScale) private var textScale

    var body: some View {
        let thin = clamp(side * 0.008, 2, 4)
        let active = hoverX != nil || dragFraction != nil
        let thickness = active ? thin * 2.5 : thin
        let hitHeight = clamp(side * 0.07, 16, 30)
        let duration = Double(max(durationMs ?? 0, 1))

        TimelineView(.animation(minimumInterval: 0.5, paused: !store.isPlaying || dragFraction != nil)) { context in
            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                let elapsed = Double(store.progressMs)
                    + (store.isPlaying ? context.date.timeIntervalSince(store.progressStamp) * 1000 : 0)
                let fraction = dragFraction ?? min(1, max(0, elapsed / duration))
                // The bubble follows the drag, or the pointer while hovering.
                let bubbleFraction = dragFraction ?? hoverX.map { Double($0 / width) }

                ZStack(alignment: .bottomLeading) {
                    Rectangle().fill(.white.opacity(0.2))
                        .frame(height: thickness)
                    Rectangle().fill(store.accent)
                        .frame(width: width * fraction, height: thickness)
                        .shadow(color: store.accent.opacity(active ? 0.6 : 0), radius: 4)

                    if let bubbleFraction, durationMs != nil {
                        TimeBubble(ms: Int(bubbleFraction * duration), size: clamp(side * 0.035, 10, 14) * textScale)
                            .fixedSize()
                            .position(x: clamp(width * bubbleFraction, 28, width - 28),
                                      y: geo.size.height - thickness - clamp(side * 0.035, 10, 14) * textScale * 1.3)
                            .transition(.opacity)
                    }
                }
                .frame(width: width, height: geo.size.height, alignment: .bottomLeading)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let p): hoverX = min(max(p.x, 0), width)
                    case .ended: hoverX = nil
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in dragFraction = Double(min(max(g.location.x / width, 0), 1)) }
                        .onEnded { g in
                            let f = Double(min(max(g.location.x / width, 0), 1))
                            if durationMs != nil { store.seek(toMs: Int(f * duration)) }
                            dragFraction = nil
                        }
                )
            }
        }
        .frame(height: hitHeight)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .animation(.easeOut(duration: 0.15), value: active)
        .animation(.easeInOut(duration: 0.5), value: store.accent)
    }
}

private struct TimeBubble: View {
    let ms: Int
    let size: CGFloat

    var body: some View {
        let seconds = max(0, ms / 1000)
        Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
            .font(.atkinson(size, .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, size * 0.6)
            .padding(.vertical, size * 0.25)
            .glassEffect(.regular, in: Capsule())
    }
}

private struct TransportControls: View {
    let size: CGFloat
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        let button = clamp(size * 0.13, 26, 64)
        GlassEffectContainer(spacing: button * 0.3) {
            HStack(spacing: button * 0.45) {
                control("backward.fill", button * 0.75) { store.previousTrack() }
                control(store.isPlaying ? "pause.fill" : "play.fill", button) { store.playPause() }
                control("forward.fill", button * 0.75) { store.next() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.2))
    }

    private func control(_ symbol: String, _ diameter: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: diameter * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
                .glassEffect(.clear.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previous / up next

private struct PreviousRow: View {
    let item: Item
    let font: CGFloat

    @Environment(\.textPalette) private var palette

    var body: some View {
        HStack(spacing: font * 0.4) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: font * 0.8, weight: .semibold))
            Text("\(Text(item.name).fontWeight(.semibold))\(Text("  ·  " + item.subtitle).foregroundStyle(palette.subtitle.opacity(0.8)))")
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.atkinson(font))
        .foregroundStyle(palette.subtitle.opacity(0.75))
        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
        .id(item.id)
        .transition(.opacity)
        .help("Previously played")
    }
}

private struct QueueList: View {
    let items: [Item]
    let font: CGFloat

    @Environment(\.textPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: font * 0.5) {
            Text("UP NEXT")
                .font(.atkinson(font * 0.75, .bold))
                .tracking(1.2)
                .foregroundStyle(palette.label)
            if items.isEmpty {
                Text("Queue is empty")
                    .font(.atkinson(font))
                    .foregroundStyle(palette.subtitle.opacity(0.65))
            } else {
                // Shows as many rows as fit; the rest fade out at the bottom edge.
                VStack(alignment: .leading, spacing: font * 0.55) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.atkinson(font, .semibold))
                                .foregroundStyle(palette.title.opacity(0.95))
                            Text(item.subtitle)
                                .font(.atkinson(font * 0.85))
                                .foregroundStyle(palette.subtitle.opacity(0.7))
                        }
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.85),
                                             .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
            }
        }
        // Keeps the list readable over a busy desktop when the window is transparent.
        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
    }
}

// MARK: - Backdrop and empty states

/// Liquid Glass over the desktop, an optional wash of album colour, then the
/// user's darkness on top so text stays legible over bright backgrounds.
private struct BackdropView: View {
    let image: NSImage?
    @AppStorage("glassFocused") private var focusedStyle = GlassDefaults.focused
    @AppStorage("glassBackground") private var backgroundStyle = GlassDefaults.background
    @Environment(\.appearsActive) private var appearsActive
    @AppStorage("glassDarkness") private var darkness = GlassDefaults.darkness
    @AppStorage("albumGlow") private var albumGlow = GlassDefaults.albumGlow

    var body: some View {
        let glassStyle = appearsActive ? focusedStyle : backgroundStyle
        ZStack {
            // A fresh glass view per style: a live NSGlassEffectView doesn't
            // reliably redraw when only its `style` changes.
            if glassStyle != .transparent {
                WindowGlass(style: glassStyle)
                    .id(glassStyle)
                    .transition(.opacity)
            }
            if albumGlow, let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 80, opaque: true)
                    .saturation(1.4)
                    // Faint over clear and transparent so the desktop still shows through.
                    .opacity(glassStyle.albumGlowOpacity)
                    .id(ObjectIdentifier(image))
                    .transition(.opacity)
            }
            Color.black.opacity(darkness)
        }
        .clipped()
        .animation(.easeInOut(duration: 0.2), value: darkness)
        .animation(.easeInOut(duration: 0.3), value: glassStyle)
    }
}

private struct ConnectPrompt: View {
    @EnvironmentObject private var auth: SpotifyAuth

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.6))
            Text("Connect Spotify")
                .font(.atkinson(.title2, .bold))
            Text("Add your Spotify Client ID in Settings, then connect your account.")
                .font(.atkinson(.body))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
            if let error = auth.lastError {
                Text(error).font(.atkinson(.caption)).foregroundStyle(.orange).multilineTextAlignment(.center)
            }
            HStack {
                SettingsLink { Text("Open Settings…") }
                if !auth.clientID.isEmpty {
                    Button("Connect") { auth.signIn() }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: 320)
    }
}

private struct EmptyState: View {
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "speaker.slash")
                .font(.system(size: 34))
            Text(message)
                .font(.atkinson(.body))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.6))
        .padding(20)
    }
}

extension View {
    /// Faded and desaturated, for the last song shown after Spotify stops.
    func idleFaded(_ idle: Bool) -> some View {
        opacity(idle ? 0.4 : 1)
            .saturation(idle ? 0.4 : 1)
            .animation(.easeInOut(duration: 0.8), value: idle)
    }
}

func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
    min(max(value, lower), upper)
}
